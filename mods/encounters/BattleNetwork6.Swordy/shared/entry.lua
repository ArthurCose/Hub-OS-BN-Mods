---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.ai
local AiLib = require("dev.konstinople.library.ai")
local IteratorLib = AiLib.IteratorLib
---@type dev.konstinople.library.turn_based
local TurnBasedLib = require("dev.konstinople.library.turn_based")

local attack_lock = TurnBasedLib.new_per_team_lock()
local chip_lock = TurnBasedLib.new_per_team_lock()

local TEXTURE = Resources.load_texture("battle.grayscale.png")
local ANIMATION_PATH = "battle.animation"
local BLADE_ANIM_PATH = "blade.animation"

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")

local SWORD_SFX = bn_assets.load_audio("sword.ogg")

---@class _BattleNetwork6.SwordyProps
---@field name string
---@field element Element
---@field health number
---@field ai "V1" | "AQUA" | "RARE"
---@field attack number
---@field attack_delay number
---@field attack_endlag number
---@field movement_time number

---@param entity Entity
local function get_tile(entity, x_dist, y_offset)
  local h_tile = entity:get_tile(entity:facing(), x_dist)
  if not h_tile then return end
  return h_tile:get_tile(Direction.Down, y_offset)
end

---@param entity Entity
local function warn(entity, x_dist, y_offset)
  local tile = get_tile(entity, x_dist, y_offset)

  if tile then
    tile:set_highlight(Highlight.Flash)
  end
end

local WIDE_OFFSETS = {
  { 1, -1 },
  { 1, 0 },
  { 1, 1 }
}

local LONG_OFFSETS = {
  { 1, 0 },
  { 2, 0 },
}

---@param character Entity
---@param props _BattleNetwork6.SwordyProps
---@param shape_state string
local function spawn_slash(character, props, shape_state, offsets)
  local tile = character:get_tile(character:facing(), 1)

  if not tile then
    return
  end

  local spell = Spell.new(character:team())
  spell:set_facing(character:facing())
  spell:set_texture(SLASH_TEXTURE)

  local animation = spell:animation()
  animation:load(SLASH_ANIM_PATH)

  if character:element() == Element.Fire then
    animation:set_state("FIRE_" .. shape_state)
  elseif character:element() == Element.Aqua then
    animation:set_state("AQUA_" .. shape_state)
  else
    animation:set_state(shape_state)
  end

  animation:on_complete(function()
    spell:delete()
  end)

  -- attack on spawn
  spell:set_hit_props(
    HitProps.new(
      props.attack,
      Hit.Flinch | Hit.Flash,
      props.element,
      Element.Sword,
      character:context()
    )
  )

  spell.on_spawn_func = function()
    local tiles = {}

    for _, offset in ipairs(offsets) do
      tiles[#tiles + 1] = get_tile(spell, offset[1] - 1, offset[2])
    end

    spell:attack_tiles(tiles)
  end

  Field.spawn(spell, tile)
end

---@param character Entity
local function offsets_have_enemy(character, offsets, additional_x_offset)
  local team = character:team()
  local has_enemy = false

  additional_x_offset = additional_x_offset or 0

  for _, offset in ipairs(offsets) do
    local tile = get_tile(character, offset[1] + additional_x_offset, offset[2])

    if not tile then
      goto continue
    end

    tile:find_characters(function(c)
      if c:hittable() and not c:is_team(team) then
        has_enemy = true
      end

      return false
    end)

    if has_enemy then
      return true
    end

    ::continue::
  end

  return false
end

---@param character Entity
---@param props _BattleNetwork6.SwordyProps
local function create_attack_factory(character, props)
  local animation = character:animation()

  return function()
    local shape_state, offsets

    -- resolve what attack we'll perform
    local can_wide = offsets_have_enemy(character, WIDE_OFFSETS)
    local can_long = offsets_have_enemy(character, LONG_OFFSETS)

    if can_wide == can_long then
      if math.random(2) == 1 then
        can_wide, can_long = true, false
      else
        can_wide, can_long = false, true
      end
    end

    if can_wide then
      shape_state = "WIDE"
      offsets = WIDE_OFFSETS
    else
      shape_state = "LONG"
      offsets = LONG_OFFSETS
    end

    -- build the action
    local action = Action.new(character, shape_state .. "_SWING_START")
    action:set_lockout(ActionLockout.new_sequence())

    local warn_step = action:create_step()
    local attack_step = action:create_step()

    local warn_remaining_time = props.attack_delay
    warn_step.on_update_func = function()
      for _, offset in ipairs(offsets) do
        warn(character, offset[1], offset[2])
      end

      if warn_remaining_time > 0 then
        warn_remaining_time = warn_remaining_time - 1
      else
        warn_step:complete_step()

        character:set_counterable(false)

        animation:set_state(shape_state .. "_SWING_END")
        animation:on_complete(function()
          attack_step:complete_step()
        end)

        animation:on_frame(2, function()
          Resources.play_audio(SWORD_SFX)
          spawn_slash(character, props, shape_state, offsets)
        end)
      end
    end

    local endlag_step = action:create_step()
    local remaining_endlag = props.attack_delay
    endlag_step.on_update_func = function()
      if remaining_endlag <= 0 then
        endlag_step:complete_step()
      end

      remaining_endlag = remaining_endlag - 1
    end

    action.on_execute_func = function()
      character:set_counterable(true)
      animation:set_playback(Playback.Loop)

      animation:on_complete(function()
        animation:set_state(shape_state .. "_SWING_WAIT")
        animation:set_playback(Playback.Loop)
      end)
    end

    -- collision damage
    local collision_spell = Spell.new()
    collision_spell:set_hit_props(
      HitProps.new(
        props.attack,
        Hit.Flinch | Hit.Flash,
        props.element,
        character:context()
      )
    )

    action.on_update_func = function()
      collision_spell:attack_tile(character:current_tile())
    end

    action.on_action_end_func = function()
      character:set_counterable(false)
      collision_spell:delete()
    end

    return action
  end
end

---@param character Entity
---@param delay number
local function create_idle_factory(character, delay)
  return function()
    local action = Action.new(character)
    action:set_lockout(ActionLockout.new_sequence())

    local remaining_time = delay
    local step = action:create_step()
    step.on_update_func = function()
      remaining_time = remaining_time - 1

      if remaining_time <= 0 then
        step:complete_step()
      end
    end

    return action
  end
end

local GHOST_COLOR = Color.new(255, 128, 255)

---@param character Entity
---@param facing Direction
local function create_ghost(character, facing)
  local artifact = Artifact.new()
  artifact:set_facing(facing)
  artifact:set_texture(character:texture())

  local sprite = artifact:sprite()
  sprite:set_palette(character:palette())

  local anim = artifact:animation()
  anim:copy_from(character:animation())
  anim:set_state("CHARACTER_IDLE")

  local time = 0
  artifact.on_update_func = function()
    if time > 10 then
      artifact:delete()
    end

    sprite:set_color_mode(ColorMode.Multiply)
    sprite:set_color(GHOST_COLOR)
    sprite:set_visible(time // 2 % 2 == 0)

    time = time + 1
  end

  return artifact
end

-- step to a random enemy
local function try_create_step_action(character)
  local team = character:team()
  local reservation_exclusion_list = { character:id() }
  local facing_away = character:facing_away()

  local enemies = Field.find_characters(function(entity)
    if not entity:hittable() or entity:is_team(team) then
      return false
    end

    local tile = entity:get_tile(facing_away, 1)

    if not tile or not tile:is_walkable() or tile:is_reserved(reservation_exclusion_list) then
      return false
    end

    return true
  end)

  if #enemies == 0 then
    return nil
  end

  local tile = enemies[math.random(#enemies)]:get_tile(facing_away, 1)

  local action = bn_assets.MobMoveAction.new(character, "MEDIUM", function()
    return tile, character:facing()
  end)

  action.can_move_to_func = function(tile)
    return tile:is_walkable()
  end

  return action
end

---@param character Entity
local function create_chip_use_factory(character, cycle_delay)
  return function()
    if cycle_delay > 0 then
      cycle_delay = cycle_delay - 1
      return nil
    end

    local card = character:field_card(1)

    if not card then
      return nil
    end

    if not chip_lock:request_turn(character) then
      return nil
    end

    character:remove_field_card(1)
    local action = Action.from_card(character, card)

    if not action then
      chip_lock:unlock(character)
      return action
    end

    action:on_end(function()
      chip_lock:unlock(character)
    end)

    return action
  end
end

---@param character Entity
---@param props _BattleNetwork6.SwordyProps
local function apply_aqua_ai(character, props)
  local ai = AiLib.new_ai(character)

  local attack_factory = create_attack_factory(character, props)
  local idle_factory = create_idle_factory(character, props.movement_time)
  local chip_use_factory = create_chip_use_factory(character, 5)

  local movement_iter_factory = function()
    return IteratorLib.chain(
      IteratorLib.take(1, function()
        return bn_assets.MobMoveAction.new(character, "MEDIUM")
      end),
      -- try using a chip
      IteratorLib.take(1, chip_use_factory),
      -- short idle break
      IteratorLib.take(1, idle_factory)
    )
  end

  local last_tile = character:current_tile()
  local reserved_tile = nil
  local last_facing = character:facing()

  local function ghost_iter()
    if last_tile == character:current_tile() then
      return nil
    end

    local ghost = create_ghost(character, last_facing)
    Field.spawn(ghost, last_tile)

    return nil
  end

  local plan = ai:create_plan()
  plan:set_action_iter_factory(function()
    return IteratorLib.chain(
    -- random movement
      IteratorLib.flatten(IteratorLib.take(3, movement_iter_factory)),
      IteratorLib.short_circuiting_chain(
      -- fail or step towards an enemy
        IteratorLib.take(1, function()
          if not attack_lock:request_turn(character) then
            -- fail if we couldn't aquire the attack lock
            return nil
          end

          -- disable reserving tiles
          character:set_auto_reserve(false)

          last_tile = character:current_tile()
          last_facing = character:facing()

          reserved_tile = last_tile
          reserved_tile:reserve_for(character)

          return try_create_step_action(character)
        end),
        -- todo: there might be one perfect frame where swordy can fail the jump
        -- which will cause them to swing in place
        IteratorLib.chain(
        -- show ghost after we step forward
          ghost_iter,
          -- attack
          IteratorLib.take(1, attack_factory),
          -- return to our original tile
          IteratorLib.take(1, function()
            last_tile = character:current_tile()
            last_facing = character:facing()

            local action = bn_assets.MobMoveAction.new(character, "MEDIUM", function()
              return reserved_tile
            end)

            action:on_end(function()
              -- remove reservation
              if reserved_tile then
                reserved_tile:remove_reservation_for(character)
                reserved_tile = nil
              end

              -- start reserving tiles and end turn
              character:set_auto_reserve(true)
              attack_lock:end_turn(character)
            end)

            return action
          end),
          ghost_iter,
          -- idle
          IteratorLib.take(1, idle_factory)
        )
      )
    )
  end)
end

---@param character Entity
---@param tile Tile
---@param duration number
local function create_slide_action(character, tile, duration)
  local action = Action.new(character)
  action:set_lockout(ActionLockout.new_sequence())

  local step = action:create_step()
  step.on_update_func = function()
    if not character:is_moving() then
      step:complete_step()
    end
  end

  local reserved = false
  action.on_execute_func = function()
    character:slide(tile, duration)

    if not character:can_move_to(tile) then
      step:complete_step()
      return
    end

    tile:reserve_for(character)
    reserved = true
  end

  action.on_action_end_func = function()
    if reserved then
      tile:remove_reservation_for(character)
    end
  end

  return action
end

---@param character Entity
---@param props _BattleNetwork6.SwordyProps
local function apply_v1_ai(character, props)
  local ai = AiLib.new_ai(character)

  local attack_factory = create_attack_factory(character, props)
  local chip_use_factory = create_chip_use_factory(character, 3)

  local direction = Direction.Down
  local decision_factory = function()
    local can_hit = offsets_have_enemy(character, WIDE_OFFSETS) or
        offsets_have_enemy(character, LONG_OFFSETS)

    if can_hit and attack_lock:request_turn(character) then
      local action = attack_factory()

      action:on_end(function()
        attack_lock:end_turn(character)
      end)

      return action
    end

    local tile = character:get_tile(character:facing(), 1)

    if tile and character:can_move_to(tile) then
      return create_slide_action(character, tile, props.movement_time)
    end

    tile = character:get_tile(direction, 1)

    if not tile or not character:can_move_to(tile) then
      direction = Direction.reverse(direction)
      tile = character:get_tile(direction, 1)
    end

    if not tile then
      return nil
    end

    return create_slide_action(character, tile, props.movement_time)
  end

  local plan = ai:create_plan()
  plan:set_action_iter_factory(function()
    return IteratorLib.chain(
      IteratorLib.take(1, decision_factory),
      IteratorLib.take(1, chip_use_factory)
    )
  end)
end


---@param character Entity
---@param props _BattleNetwork6.SwordyProps
local function apply_rare_ai(character, props)
  local ai = AiLib.new_ai(character)

  local attack_factory = create_attack_factory(character, props)
  local chip_use_factory = create_chip_use_factory(character, 3)

  local direction = Direction.Down
  local idle_movement_factory = function()
    local tile = character:get_tile(direction, 1)

    if not tile or not character:can_move_to(tile) then
      direction = Direction.reverse(direction)
      tile = character:get_tile(direction, 1)
    end

    if not tile then
      return nil
    end

    return create_slide_action(character, tile, props.movement_time)
  end

  local decision_factory = function()
    local facing = character:facing()
    local furthest_tile = character:get_tile(facing, 1)
    local furthest_movement = 0

    while furthest_tile and character:can_move_to(furthest_tile) do
      furthest_tile = furthest_tile:get_tile(facing, 1)
      furthest_movement = furthest_movement + 1
    end

    local can_hit = offsets_have_enemy(character, WIDE_OFFSETS, furthest_movement) or
        offsets_have_enemy(character, LONG_OFFSETS, furthest_movement)

    if not can_hit or not attack_lock:request_turn(character) then
      return IteratorLib.take(1, idle_movement_factory)
    end

    return IteratorLib.chain(
    -- slide forward
      IteratorLib.take(furthest_movement, function()
        local tile = character:get_tile(character:facing(), 1)

        if tile and character:can_move_to(tile) then
          return create_slide_action(character, tile, 5)
        end
      end),
      IteratorLib.take(1, attack_factory),
      -- slide back
      IteratorLib.take(furthest_movement, function()
        local tile = character:get_tile(character:facing_away(), 1)
        if tile and character:can_move_to(tile) then
          return create_slide_action(character, tile, 5)
        end
      end),
      function()
        attack_lock:end_turn(character)
        return nil
      end
    )
  end

  local plan = ai:create_plan()
  plan:set_action_iter_factory(function()
    return IteratorLib.chain(
      IteratorLib.flatten(IteratorLib.take(1, decision_factory)),
      IteratorLib.take(1, chip_use_factory)
    )
  end)
end

---@param character Entity
---@param props _BattleNetwork6.SwordyProps
return function(character, props)
  character:set_name(props.name)
  character:set_health(props.health)
  character:set_height(33)
  character:set_texture(TEXTURE)
  character:load_animation(ANIMATION_PATH)
  character:set_element(props.element)

  local animation = character:animation()

  character.on_idle_func = function()
    if animation:state() ~= "CHARACTER_IDLE" then
      animation:set_state("CHARACTER_IDLE")
    end
    animation:set_playback(Playback.Loop)
  end

  -- create blade
  local blade_node = character:create_sync_node()
  blade_node:animation():load(BLADE_ANIM_PATH)
  local blade_sprite = blade_node:sprite()
  blade_sprite:set_texture(TEXTURE)
  blade_sprite:set_palette(character:palette())
  blade_sprite:use_parent_shader()

  -- defenses
  character:add_aux_prop(StandardEnemyAux.new())
  character:ignore_negative_tile_effects(true)

  -- idle after setup
  character:set_idle()

  -- ai
  if props.ai == "AQUA" then
    apply_aqua_ai(character, props)
  elseif props.ai == "RARE" then
    apply_rare_ai(character, props)
  else
    apply_v1_ai(character, props)
  end
end

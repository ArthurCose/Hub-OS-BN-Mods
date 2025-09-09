---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local SWIM_SFX = Resources.load_audio("swim.ogg")
local AQUA_TOWER_SFX = bn_assets.load_audio("dust_chute2.ogg") -- not accurate

local SHIELD_IMPACT_TEXTURE = bn_assets.load_texture("shield_impact.png")
local SHIELD_IMPACT_ANIM_PATH = bn_assets.fetch_animation_path("shield_impact.animation")

local TEXTURE = Resources.load_texture("battle.png")
local ANIM_PATH = "battle.animation"
local SPLASH_TEXTURE = Resources.load_texture("splash.png")
local SPLASH_ANIM_PATH = "splash.animation"
local AQUA_TOWER_TEXTURE = Resources.load_texture("aqua_tower.png")
local AQUA_TOWER_ANIMATION_PATH = "aqua_tower.animation"

---@class _BattleNetwork1.Sharkman.Data
---@field real_fin Entity
---@field fins Entity[]
---@field hooked boolean

local stats_by_rank = {
  [Rank.V1] = {
    health = 700,
  },
  [Rank.V2] = {
    health = 800,
  },
  [Rank.V3] = {
    health = 900,
  }
}

---@param fin Entity
local function spawn_guard_particle(fin)
  local fx = Artifact.new()
  fx:set_layer(-1)
  fx:set_texture(SHIELD_IMPACT_TEXTURE)
  local fx_anim = fx:animation()
  fx_anim:load(SHIELD_IMPACT_ANIM_PATH)
  fx_anim:set_state("DEFAULT")
  fx_anim:on_complete(function()
    fx:delete()
  end)

  local movement_offset = fin:offset()

  fx:set_offset(
    movement_offset.x + math.random(-8, 8),
    movement_offset.y + math.random(-32, -16)
  )

  Field.spawn(fx, fin:current_tile())
end

---@param entity Entity
local function spawn_splash_particle(entity)
  local fx = Artifact.new()
  fx:set_layer(-1)
  fx:set_facing(entity:facing())

  fx:set_texture(SPLASH_TEXTURE)
  local fx_anim = fx:animation()
  fx_anim:load(SPLASH_ANIM_PATH)
  fx_anim:set_state("DEFAULT")
  fx_anim:on_complete(function()
    fx:delete()
  end)

  Field.spawn(fx, entity:current_tile())
end

---@param entity Entity
---@param prev_tile Tile
---@param direction Direction
local function find_next_tower_tile(entity, prev_tile, direction)
  local x = prev_tile:x()
  local y = prev_tile:y()

  local direction_filter

  if direction == Direction.Left then
    direction_filter = function(e) return e:current_tile():x() < x end
  else
    direction_filter = function(e) return e:current_tile():x() > x end
  end

  local enemies = Field.find_nearest_characters(entity, function(e)
    return direction_filter(e) and e:hittable() and e:team() ~= entity:team()
  end)

  local enemy_y = (enemies[1] and enemies[1]:current_tile():y()) or y

  if enemy_y > y then
    return prev_tile:get_tile(Direction.join(direction, Direction.Down), 1)
  elseif enemy_y < y then
    return prev_tile:get_tile(Direction.join(direction, Direction.Up), 1)
  else
    return prev_tile:get_tile(direction, 1)
  end
end

---@param team Team
---@param context AttackContext
---@param damage number
---@param direction Direction
local function create_aqua_tower(team, context, damage, direction)
  local spell = Spell.new(team)
  spell:set_facing(Direction.Right)
  spell:set_never_flip(true)
  spell:set_hit_props(HitProps.new(
    damage,
    Hit.Flinch | Hit.Flash,
    Element.Aqua,
    context,
    Drag.None
  ))

  spell:set_texture(AQUA_TOWER_TEXTURE)

  local animation = spell:animation()
  animation:load(AQUA_TOWER_ANIMATION_PATH)
  animation:set_state("SPAWN")

  local can_attack = false

  animation:on_complete(function()
    animation:set_state("LOOP")
    animation:set_playback(Playback.Loop)

    can_attack = true

    local i = 0

    animation:on_complete(function()
      i = i + 1

      if i == 1 then
        -- spawn another tower after the first idle loop
        local tile = find_next_tower_tile(spell, spell:current_tile(), direction)

        if tile and tile:is_walkable() then
          local aqua_tower = create_aqua_tower(team, context, damage, direction)
          Field.spawn(aqua_tower, tile)
        end

        return
      end

      -- disable attack and despawn after playing twice
      can_attack = false

      animation:set_state("DESPAWN")
      animation:on_complete(function()
        spell:erase()
      end)
    end)
  end)

  spell.on_spawn_func = function()
    Resources.play_audio(AQUA_TOWER_SFX)
  end

  spell.on_update_func = function()
    if can_attack then
      spell:attack_tile()
      spell:current_tile():set_highlight(Highlight.Solid)
    end
  end

  spell.on_collision_func = function()
    spell:erase()
  end

  spell.on_attack_func = function(_, other)
    local movement_offset = other:movement_offset()
    local particle = bn_assets.HitParticle.new(
      "AQUA",
      movement_offset.x + math.random(-16, 16),
      movement_offset.y + math.random(-16, 16) - other:height() // 2
    )
    Field.spawn(particle, spell:current_tile())
  end

  return spell
end

---@param fin Entity
local function create_fin_attack_action(fin)
  local action = Action.new(fin, "FIN_ATTACK_START")
  action:set_lockout(ActionLockout.new_sequence())

  local fin_anim = fin:animation()
  local original_tile = fin:current_tile()

  local startup_step = action:create_step()

  action.on_execute_func = function()
    fin_anim:on_complete(function()
      startup_step:complete_step()
      fin_anim:set_state("FIN_ATTACK_LOOP")
      fin_anim:set_playback(Playback.Loop)

      Resources.play_audio(SWIM_SFX)
    end)

    original_tile = fin:current_tile()
    original_tile:reserve_for(fin)

    fin:enable_sharing_tile()
  end

  action.can_move_to_func = function(tile)
    return tile:is_walkable()
  end

  local move_step = action:create_step()
  move_step.on_update_func = function()
    if fin:is_moving() then
      return
    end

    local next_tile = fin:get_tile(fin:facing(), 1)

    if next_tile and fin:can_move_to(next_tile) then
      fin:slide(next_tile, 4)
      return
    end

    move_step:complete_step()
  end

  local wrap_up_step = action:create_step()
  wrap_up_step.on_update_func = function()
    wrap_up_step.on_update_func = nil

    fin_anim:set_state("FIN_SUBMERGE")
    fin_anim:on_complete(function()
      original_tile:add_entity(fin)
      fin_anim:set_state("FIN_SURFACE")
      fin_anim:on_complete(function()
        wrap_up_step:complete_step()
      end)
    end)
  end

  action.on_action_end_func = function()
    original_tile:remove_reservation_for(fin)

    fin:enable_sharing_tile(false)
  end

  return action
end

---@param fin Entity
---@param fins Entity[]
local function can_attack(fin, fins)
  for _, related_fin in ipairs(fins) do
    if related_fin:has_actions() then
      return false
    end
  end

  local current_tile = fin:current_tile()
  local x = current_tile:x()
  local y = current_tile:y()

  ---@type fun(entity: Entity): boolean
  local is_ahead

  if fin:facing() == Direction.Left then
    is_ahead = function(other)
      local tile = other:current_tile()
      return tile:y() == y and tile:x() < x
    end
  else
    is_ahead = function(other)
      local tile = other:current_tile()
      return tile:y() == y and tile:x() > x
    end
  end

  local total = #Field.find_characters(function(other)
    return other:hittable() and other:team() ~= fin:team() and is_ahead(other)
  end)

  return total > 0
end

---@param character Entity
---@param data _BattleNetwork1.Sharkman.Data
local function create_fin(character, data)
  local fin = Obstacle.new(character:team())
  fin:set_texture(TEXTURE)
  fin:set_health(9999)

  fin:set_hit_props(HitProps.new(
    120,
    Hit.Flinch | Hit.Flash,
    Element.Aqua,
    character:context()
  ))

  local fin_anim = fin:animation()
  fin_anim:load(ANIM_PATH)
  fin_anim:set_state("FIN_IDLE")
  fin_anim:set_playback(Playback.Loop)

  fin.on_idle_func = function()
    fin_anim:set_state("FIN_IDLE")
    fin_anim:set_playback(Playback.Loop)
  end

  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
  defense_rule.defense_func = function(defense, _, _, hit_props)
    defense:block_damage()

    if hit_props.flags & Hit.Drain == 0 then
      spawn_guard_particle(fin)
    end
  end
  fin:add_defense_rule(defense_rule)

  local moving_direction = Direction.Down
  local cooling_down = true

  ---@type Component?
  local fishing_component

  fin.on_update_func = function()
    if character:deleted() then
      fin:delete()
      return
    end

    if fishing_component or fin == data.real_fin and (character:is_inactionable() or character:is_immobile()) then
      -- fishing specific, since sharkman is so janky

      if fishing_component then
        return
      end

      data.hooked = true

      fishing_component = fin:create_component(Lifetime.Scene)
      fishing_component.on_update_func = function()
        if fin ~= data.real_fin then
          fishing_component:eject()
          fishing_component = nil
          return
        end

        character:current_tile():add_entity(fin)

        local offset = character:movement_offset()
        fin:set_movement_offset(offset.x, offset.y)

        if not (character:is_inactionable() or character:is_immobile()) then
          fishing_component:eject()
          fishing_component = nil
        end
      end

      return
    end

    if fin == data.real_fin then
      data.hooked = false
    end

    -- forcibly maintain health
    fin:set_health(9999)
    fin:attack_tile()

    if fin:has_actions() then
      cooling_down = true
      return
    end

    if fin:is_moving() then
      return
    end

    if not cooling_down and can_attack(fin, data.fins) then
      fin:queue_action(create_fin_attack_action(fin))
      return
    end

    cooling_down = false

    local next_tile = fin:get_tile(moving_direction, 1)

    if not next_tile or not fin:can_move_to(next_tile) then
      moving_direction = Direction.reverse(moving_direction)
      return
    end

    fin:slide(next_tile, 32)
  end

  fin.can_move_to_func = function(tile)
    return character:can_move_to(tile)
  end

  return fin
end

---@param character Entity
function character_init(character)
  local character_stats = stats_by_rank[character:rank()] or stats_by_rank[Rank.V1]

  if character:rank() == Rank.V1 then
    character:set_name("SharkMan")
  else
    character:set_name("SharkMn")
  end

  character:set_element(Element.Aqua)
  character:set_health(character_stats.health)
  character:set_height(48)

  character:set_texture(TEXTURE)
  local animation = character:animation()
  animation:load(ANIM_PATH)
  animation:set_state("FIN_IDLE")
  character:hide()

  ---@type _BattleNetwork1.Sharkman.Data
  local data = {
    real_fin = character, -- this is just to satisfy the type, we'll switch this soon
    fins = {},
    hooked = false
  }

  local reservation_exclusion_ids = {}

  character.can_move_to_func = function(tile)
    if not tile:is_walkable() or tile:team() ~= character:team() then
      return false
    end

    return not tile:is_reserved(reservation_exclusion_ids)
  end

  local function find_valid_column_tiles(x)
    local tiles = {}

    for y = 1, Field.height() - 2 do
      local tile = Field.tile_at(x, y)

      if not tile then
        -- y should be in range, so this must not be a valid column
        return tiles
      end

      if tile:team() ~= character:team() or not tile:is_walkable() then
        goto continue
      end

      if tile:is_reserved(reservation_exclusion_ids) then
        goto continue
      end

      tiles[#tiles + 1] = tile

      ::continue::
    end

    return tiles
  end

  character.on_spawn_func = function()
    local current_tile = character:current_tile()

    data.real_fin = create_fin(character, data)
    Field.spawn(data.real_fin, current_tile)
    data.fins[#data.fins + 1] = data.real_fin

    local try_offsets = {
      { -1, -1 },
      { 1,  1 },
      { 2,  -1 },
      { -2, 1 }
    }

    for _, offset in ipairs(try_offsets) do
      local x = current_tile:x() + offset[1]
      local y = current_tile:y() + offset[2]
      local tile = Field.tile_at(x, y)

      if not tile or not tile:is_walkable() or tile:team() ~= character:team() then
        tile = find_valid_column_tiles(x)[1]
      end

      if tile then
        local fin = create_fin(character, data)
        Field.spawn(fin, tile)
        data.fins[#data.fins + 1] = fin

        -- todo listen for delete just in case?
      end

      if #data.fins >= 3 then
        break
      end
    end

    table.insert(reservation_exclusion_ids, character:id())

    for _, fin in ipairs(data.fins) do
      table.insert(reservation_exclusion_ids, fin:id())
    end
  end

  -- hit detection
  local hit = false
  local surfaced = false
  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
  defense_rule.defense_func = function()
    hit = true
  end
  character:add_defense_rule(defense_rule)

  local function create_retaliate_action()
    local action = Action.new(character)
    action:set_lockout(ActionLockout.new_sequence())

    action.on_execute_func = function()
      -- prevent real_fin from attacking by queueing an action
      local fin_action = Action.new(data.real_fin)
      fin_action:set_lockout(ActionLockout.new_sequence())
      fin_action:create_step()
      data.real_fin:queue_action(fin_action)

      -- submerge
      spawn_splash_particle(character)
      animation:set_state("CHARACTER_SURFACE")
      data.real_fin:current_tile():add_entity(character)
      character:reveal()
      data.real_fin:hide()
    end

    local tower_wait_time = 0
    local aqua_tower_step = action:create_step()
    aqua_tower_step.on_update_func = function()
      tower_wait_time = tower_wait_time + 1

      if tower_wait_time == 50 then
        -- spawn aqua tower
        local tile = character:get_tile(character:facing(), 1)

        while tile and tile:team() == character:team() do
          tile = tile:get_tile(character:facing(), 1)
        end

        if tile and tile:is_walkable() then
          local tower = create_aqua_tower(
            character:team(),
            character:context(),
            80,
            character:facing()
          )

          Field.spawn(tower, tile)
        end
      elseif tower_wait_time >= 200 then
        aqua_tower_step:complete_step()
      end
    end

    local wait_for_fins_step = action:create_step()
    wait_for_fins_step.on_update_func = function()
      local waiting = 0

      for _, fin in ipairs(data.fins) do
        if fin ~= data.real_fin then
          waiting = waiting + 1

          -- queue an action to stop the fin
          local fin_action = Action.new(fin)
          fin_action:set_lockout(ActionLockout.new_sequence())
          fin_action:create_step()
          fin_action.on_execute_func = function()
            waiting = waiting - 1

            if waiting == 0 then wait_for_fins_step:complete_step() end
          end

          fin:queue_action(fin_action)
        end
      end

      wait_for_fins_step.on_update_func = nil
    end

    local wait_time = 0
    local respawn_step = action:create_step()
    respawn_step.on_update_func = function()
      if wait_time == 0 then
        -- hide fins
        for _, fin in ipairs(data.fins) do
          if fin ~= data.real_fin then
            local fin_anim = fin:animation()
            fin_anim:set_state("FIN_SUBMERGE")
            fin_anim:on_complete(function()
              fin:hide()
            end)
          end
        end

        -- hide character
        animation:set_state("CHARACTER_SUBMERGE")
        animation:on_complete(function()
          character:current_tile():remove_entity(character)
          character:hide()
        end)

        spawn_splash_particle(character)
      end

      if wait_time < 12 then
        wait_time = wait_time + 1
        return
      end

      respawn_step:complete_step()

      -- respawn + reveal fins
      for _, fin in ipairs(data.fins) do
        -- find a new position
        local tiles = find_valid_column_tiles(fin:current_tile():x())

        if #tiles > 0 then
          local tile = tiles[math.random(#tiles)]
          tile:add_entity(fin)
        end

        -- reveal
        spawn_splash_particle(fin)
        fin:reveal()
        fin:enable_hitbox()

        local fin_anim = fin:animation()
        fin_anim:set_state("FIN_SURFACE")
        fin_anim:on_complete(function()
          -- end the action locking this fin from earlier
          fin:cancel_actions()
        end)
      end
    end

    action.on_action_end_func = function()
      hit = false
      surfaced = false

      data.real_fin = data.fins[math.random(#data.fins)]
      data.real_fin:enable_hitbox(false)
      data.real_fin:current_tile():add_entity(character)
      character:hide()
    end

    return action
  end

  character.on_update_func = function()
    if character:has_actions() or data.hooked then
      return
    end

    if data.real_fin:has_actions() then
      -- allow the fin to take over for actions
      character:current_tile():remove_entity(character)
      data.real_fin:enable_hitbox()
      return
    end

    -- sync to movement
    data.real_fin:enable_hitbox(false)
    data.real_fin:current_tile():add_entity(character)

    local offset = data.real_fin:movement_offset()
    character:set_movement_offset(offset.x, offset.y)

    if not hit then
      return
    end

    if not surfaced then
      surfaced = true
      character:queue_action(create_retaliate_action())
    end
  end

  character.intro_func = function()
    return Action.new(character)
  end
end

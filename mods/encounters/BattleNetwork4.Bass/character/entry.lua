---@type dev.konstinople.library.ai
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local create_helz_rolling = require("./helz_rolling")

local TEXTURE = Resources.load_texture("battle.png")
local ANIM_PATH = "battle.animation"

local CAPE_TEXTURE = Resources.load_texture("cape.png")
local CAPE_ANIM_PATH = "cape.animation"

local SHOT_TEXTURE = bn_assets.load_texture("gunner_shot_burst.png")
local SHOT_ANIMATION = bn_assets.fetch_animation_path("gunner_shot_burst.animation")
local SHOT_SFX = bn_assets.load_audio("gunner_shot.ogg")

local DARKNESS_SFX = bn_assets.load_audio("darkness.ogg")
local DARKNESS_OVERLOAD_SFX = bn_assets.load_audio("darkness_overload.ogg")

local SLASH_SFX = bn_assets.load_audio("feather.ogg")

---@generic T
---@param t table<Rank, T>
---@return table<Rank, T>
local function apply_bn6_ranks(t)
  t[Rank.V2] = t[Rank.Alpha]
  t[Rank.V3] = t[Rank.Beta]
  t[Rank.SP] = t[Rank.Omega]
  return t
end

local RANK_TO_HP = apply_bn6_ranks({
  [Rank.V1] = 2000,
  [Rank.Omega] = 3000
})

local RANK_TO_MOVEMENT_DELAY = apply_bn6_ranks({
  [Rank.V1] = 22,
  [Rank.Omega] = 16,
})

local RANK_TO_BASE_DAMAGE = apply_bn6_ranks({
  [Rank.V1] = 100,
  [Rank.Omega] = 200,
})

local RANK_TO_HELZ_ROLLING_DAMAGE = apply_bn6_ranks({
  [Rank.V1] = 200,
  [Rank.Omega] = 400,
})

local RANK_TO_OVERLOAD_DAMAGE = apply_bn6_ranks({
  [Rank.V1] = 300,
  [Rank.Omega] = 600,
})

---@param state string
---@param tile Tile
---@param delay number
---@param color Color
local function create_ghost(state, tile, delay, color)
  local ghost = Artifact.new()
  local sprite = ghost:sprite()
  sprite:set_texture(TEXTURE)

  local animation = ghost:animation()
  animation:load(ANIM_PATH)
  animation:set_state(state)

  local cape = ghost:create_sync_node()
  cape:sprite():set_texture(CAPE_TEXTURE)
  cape:sprite():use_parent_shader()
  cape:animation():load(CAPE_ANIM_PATH)

  local time = 0
  ghost.on_update_func = function()
    if TurnGauge.frozen() then
      return
    end

    sprite:set_visible((time // 2) % 2 == 0)
    sprite:set_color(color)

    time = time + 1

    if time == delay then
      ghost:slide(tile, 9)
    end
  end

  return ghost
end

---@param action Action
---@param state string
---@param tile_callback fun(): Tile?
local function create_movement_step(action, state, tile_callback)
  local entity = action:owner()

  local ghosts = {}

  local movement_step = action:create_step()
  movement_step.on_update_func = function()
    local tile = tile_callback()

    if not tile or not entity:can_move_to(tile) or tile == entity:current_tile() then
      movement_step:complete_step()
      return
    end

    ghosts[#ghosts + 1] = create_ghost(state, tile, 3, Color.new(50, 25, 75))
    ghosts[#ghosts + 1] = create_ghost(state, tile, 6, Color.new(75, 75, 75))
    ghosts[#ghosts + 1] = create_ghost(state, tile, 12, Color.new(100, 100, 100))

    for i, ghost in ipairs(ghosts) do
      ghost:sprite():set_layer(i)
      ghost:set_facing(entity:facing())
      Field.spawn(ghost, entity:current_tile())
    end

    ghosts[1].on_spawn_func = function()
      entity:hide()
      entity:enable_hitbox(false)
    end

    entity:slide(tile, 9)

    movement_step.on_update_func = function()
      if not entity:is_moving() then
        movement_step:complete_step()

        entity:reveal()
        entity:enable_hitbox(true)
      end
    end
  end

  return function()
    entity:reveal()
    entity:enable_hitbox(true)

    for _, ghost in ipairs(ghosts) do
      ghost:delete()
    end
  end
end

---@param entity Entity
---@param state string
---@param end_idle_duration number
---@param select_tile fun(): Tile?
local function create_move_factory(entity, state, end_idle_duration, select_tile)
  return function()
    local action = Action.new(entity, state)
    action:set_lockout(ActionLockout.new_sequence())

    local movement_cleanup_func
    local reserved_tile

    action.on_execute_func = function()
      reserved_tile = select_tile()

      if reserved_tile then
        reserved_tile:reserve_for(entity)
      end

      movement_cleanup_func = create_movement_step(action, state, function()
        return reserved_tile
      end)

      local idle_time = 0

      local idle_wait_step = action:create_step()
      idle_wait_step.on_update_func = function(self)
        if idle_time == 0 then
          entity:set_facing(entity:current_tile():facing())

          local animation = entity:animation()
          animation:set_state("CHARACTER_IDLE")
          animation:set_playback(Playback.Loop)
        end

        idle_time = idle_time + 1

        if idle_time >= end_idle_duration then
          self:complete_step()
        end
      end
    end

    action.on_action_end_func = function()
      if movement_cleanup_func then
        movement_cleanup_func()
      end

      if reserved_tile then
        reserved_tile:remove_reservation_for(entity)
      end
    end

    return action
  end
end

---@param entity Entity
---@param end_idle_duration number
local function create_random_move_factory(entity, end_idle_duration)
  return create_move_factory(entity, "CHARACTER_IDLE", end_idle_duration, function()
    return Ai.pick_same_team_tile(entity)
  end)
end

---@param entity Entity
---@param end_idle_duration number
local function create_back_center_factory(entity, end_idle_duration)
  return create_move_factory(entity, "CHARACTER_IDLE", end_idle_duration, function()
    local y = Field.height() // 2
    local start_x = 1
    local end_x = Field.width() - 1
    local inc_x = 1

    if entity:facing() == Direction.Left then
      start_x, end_x = end_x, start_x
      inc_x = -inc_x
    end

    for x = start_x, end_x, inc_x do
      local tile = Field.tile_at(x, y)

      if tile and tile:team() == entity:team() and not tile:is_edge() then
        return tile
      end
    end

    return nil
  end)
end

---@param entity Entity
---@param tile Tile
local function spawn_shot_spell(entity, tile)
  local hit_props = HitProps.new(
    RANK_TO_BASE_DAMAGE[entity:rank()],
    Hit.Flinch | Hit.Flash | Hit.PierceGround,
    Element.None,
    entity:context()
  )

  local spell = Spell.new(entity:team())
  spell:set_facing(entity:facing())
  spell:set_hit_props(hit_props)
  spell:set_tile_highlight(Highlight.Flash)

  local time = 0

  spell.on_update_func = function()
    time = time + 1

    if time < 9 then
      return
    end

    spell.on_update_func = nil
    spell:set_tile_highlight(Highlight.None)
    spell:attack_tile()

    Resources.play_audio(SHOT_SFX)

    spell:set_texture(SHOT_TEXTURE)
    spell:sprite():set_layer(-3)

    local animation = spell:animation()
    animation:load(SHOT_ANIMATION)
    animation:set_state("DEFAULT")

    animation:on_complete(function()
      spell:delete()
    end)
  end

  Field.spawn(spell, tile)
end

---@param entity Entity
local function create_buster_shooting_factory(entity)
  local animation = entity:animation()

  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())
    action:create_step()

    action.on_execute_func = function()
      animation:set_state("BUSTER_SHOOTING_START")
      animation:on_complete(function()
        animation:set_state("BUSTER_SHOOTING")
        animation:set_playback(Playback.Loop)

        local shots_remaining = 18
        local last_tile

        animation:on_frame(1, function()
          if shots_remaining == 0 then
            action:end_action()
            return
          end

          -- resolve range for tiles
          local min_x
          local max_x

          Field.find_characters(function(c)
            if c:team() == entity:team() then
              return false
            end

            local x = c:current_tile():x()

            if not min_x then
              min_x = x - 2
              max_x = x + 2
            else
              min_x = math.min(min_x, x - 2)
              max_x = math.max(max_x, x + 2)
            end

            return false
          end)

          -- find target tiles
          local x = entity:current_tile():x()
          local facing = entity:facing()
          local tiles = Field.find_tiles(function(tile)
            if tile:is_edge() or tile == last_tile or tile:team() == entity:team() then
              return false
            end

            local tile_x = tile:x()

            if min_x and (tile_x < min_x or tile_x > max_x) then
              return false
            end

            if facing == Direction.Left then
              return tile_x < x
            end

            return tile_x > x
          end)

          shots_remaining = shots_remaining - 1

          -- attack a tile
          if #tiles == 0 then
            return
          end

          last_tile = tiles[math.random(#tiles)]
          spawn_shot_spell(entity, last_tile)

          -- spawn sparks
          local x_offset = math.random(-16, 16)
          local y_offset = math.random(-16, 16) - entity:height() // 2

          if facing == Direction.Left then
            x_offset = x_offset - 16
          else
            x_offset = x_offset + 16
          end

          local spark = bn_assets.HitParticle.new("SPARK_1", x_offset, y_offset)
          Field.spawn(spark, entity:current_tile())
        end)
      end)
    end

    return action
  end
end

---@param animation Animation
---@param ... string | function
local function animation_chain(animation, ...)
  local list = table.pack(...)
  local i = 1

  local function execute_next()
    local state_or_callback = list[i]
    i = i + 1

    if not state_or_callback then
      return
    end

    if type(state_or_callback) == "string" then
      animation:set_state(state_or_callback)
      animation:on_complete(function()
        execute_next()
      end)
    else
      state_or_callback()
      execute_next()
    end
  end

  execute_next()
end

---@param entity Entity
local function create_helz_rolling_factory(entity)
  return function()
    if Field.height() // 2 ~= entity:current_tile():y() then
      return
    end

    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())

    local damage = RANK_TO_HELZ_ROLLING_DAMAGE[entity:rank()]
    local hit_props = HitProps.new(
      damage,
      Hit.Flinch | Hit.Flash,
      Element.None,
      entity:context()
    )

    local start_step = action:create_step()

    local time = 0
    local attack_step = action:create_step()
    attack_step.on_update_func = function()
      time = time + 1

      if time == 16 then
        local direction = Direction.join(entity:facing(), Direction.Up)
        local tile = entity:get_tile(direction, 1)

        if tile then
          local wheel = create_helz_rolling(entity, hit_props, Direction.Down)
          Field.spawn(wheel, tile)
        end
      elseif time == 44 then
        local direction = Direction.join(entity:facing(), Direction.Down)
        local tile = entity:get_tile(direction, 1)

        if tile then
          local wheel = create_helz_rolling(entity, hit_props, Direction.Up)
          Field.spawn(wheel, tile)
        end
      elseif time == 60 then
        attack_step:complete_step()
      end
    end

    local animation = entity:animation()
    action.on_execute_func = function()
      local attachment = action:create_attachment("ORBS")

      local attachment_sprite = attachment:sprite()
      attachment_sprite:set_texture(TEXTURE)

      local attachment_animation = attachment:animation()
      attachment_animation:load(ANIM_PATH)
      attachment_animation:set_state("DARKNESS_ORBS")
      attachment_animation:set_playback(Playback.Loop)

      animation_chain(
        animation,
        "DARKNESS_START",
        function()
          Resources.play_audio(DARKNESS_SFX)
        end,
        "DARKNESS_START_LOOP",
        "DARKNESS_START_LOOP",
        "DARKNESS_START_LOOP",
        "DARKNESS_START_END",
        function()
          animation:set_state("DARKNESS_LOOP")
          animation:set_playback(Playback.Loop)
          start_step:complete_step()
        end
      )
    end

    return action
  end
end

---@param entity Entity
local function create_spell_base(entity, damage)
  local spell = Spell.new(entity:team())

  spell:set_hit_props(
    HitProps.new(
      damage,
      Hit.Flinch | Hit.Flash,
      Element.None,
      entity:context()
    )
  )

  spell:set_facing(entity:facing())
  spell:set_texture(TEXTURE)
  spell:load_animation(ANIM_PATH)

  return spell
end

---@param entity Entity
local function create_darkness_overload(entity)
  local damage = RANK_TO_OVERLOAD_DAMAGE[entity:rank()]
  local spell = create_spell_base(entity, damage)

  local animation = spell:animation()
  animation:set_state("OVERLOAD_SPELL")
  animation:on_complete(function()
    spell:delete()
  end)

  local tiles = {}

  spell.on_spawn_func = function()
    Resources.play_audio(DARKNESS_OVERLOAD_SFX)

    -- build tile list
    local directions = {
      Direction.Up,
      Direction.None,
      Direction.Down
    }

    for _, direction in ipairs(directions) do
      direction = Direction.join(spell:facing(), direction)
      local tile = spell:get_tile(direction, 1)

      if not tile then
        goto continue
      end

      tiles[#tiles + 1] = tile
      tile = tile:get_tile(spell:facing(), 1)

      if tile then
        tiles[#tiles + 1] = tile
      end

      ::continue::
    end

    -- crack tiles
    for _, tile in ipairs(tiles) do
      tile:set_state(TileState.Cracked)
    end
  end

  spell.on_update_func = function()
    for _, tile in ipairs(tiles) do
      spell:attack_tile(tile)
    end
  end

  return spell
end

---@param action Action
---@param point string
---@param state string
local function create_attachment(action, point, state)
  local attachment = action:create_attachment(point)

  local attachment_sprite = attachment:sprite()
  attachment_sprite:set_texture(TEXTURE)
  attachment_sprite:use_parent_shader(true)

  local attachment_animation = attachment:animation()
  attachment_animation:load(ANIM_PATH)
  attachment_animation:set_state(state)

  return attachment
end

---@param entity Entity
local function create_darkness_overload_factory(entity)
  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())
    action:allow_auto_tile_reservation(false)

    ---@type Tile?
    local reserved_tile
    local cleanup = {}

    local animation = entity:animation()
    action.on_execute_func = function()
      reserved_tile = entity:current_tile()
      reserved_tile:reserve_for(entity)

      local attachment = create_attachment(action, "ORBS", "DARKNESS_ORBS")
      attachment:animation():set_playback(Playback.Loop)

      -- wind up step
      local start_step = action:create_step()

      animation_chain(
        animation,
        "DARKNESS_START",
        function()
          Resources.play_audio(DARKNESS_SFX)
        end,
        "DARKNESS_START_LOOP",
        "DARKNESS_START_LOOP",
        function()
          start_step:complete_step()
        end
      )

      -- resolve target tile movement step
      local target_tile

      local target_start_x = 1
      local target_end_x = Field.width() - 1
      local target_inc_x = 1
      local target_y = Field.height() // 2

      if entity:facing() == Direction.Right then
        target_start_x, target_end_x = target_end_x, target_start_x
        target_y = 0
      end

      for x = target_start_x, target_end_x, target_inc_x do
        local tile = Field.tile_at(x, target_y)

        if tile and not tile:is_edge() then
          target_tile = tile:get_tile(entity:facing_away(), 2)
          break
        end
      end

      if not target_tile then
        -- failed to find a tile to move to
        action:end_action()
        return
      end

      cleanup[#cleanup + 1] = create_movement_step(action, "DARKNESS_START_LOOP", function()
        return target_tile
      end)

      -- continue startup at the target tile
      local wait_step = action:create_step()
      wait_step.on_update_func = function()
        animation_chain(
          animation,
          "DARKNESS_START_LOOP",
          "DARKNESS_START_END",
          function()
            animation:set_state("DARKNESS_LOOP")
            animation:set_playback(Playback.Loop)
            wait_step:complete_step()

            table.remove(cleanup, 1)()
          end
        )

        wait_step.on_update_func = nil
      end

      -- spawn the attack and wait for it to complete
      local time = 0
      local attack_step = action:create_step()

      attack_step.on_update_func = function()
        if time == 0 then
          local spell = create_darkness_overload(entity)
          Field.spawn(spell, target_tile)
        end

        time = time + 1

        if time < 60 then
          return
        end

        attack_step:complete_step()
      end

      -- move to a new tile
      cleanup[#cleanup + 1] = create_movement_step(action, "CHARACTER_IDLE", function()
        action.can_move_to_func = nil
        local end_tile = Ai.pick_same_team_tile(entity)

        if end_tile then
          reserved_tile:remove_reservation_for(entity)
          reserved_tile = end_tile
          reserved_tile:reserve_for(entity)
        else
          end_tile = reserved_tile
        end

        return end_tile
      end)
    end

    action.on_action_end_func = function()
      if reserved_tile then
        reserved_tile:add_entity(entity)
        reserved_tile:remove_reservation_for(entity)
      end

      for _, callback in ipairs(cleanup) do
        callback()
      end
    end

    action.can_move_to_func = function(tile)
      return tile:is_walkable() and not tile:is_edge()
    end

    return action
  end
end

---@param entity Entity
local function create_long_blade(entity)
  local damage = RANK_TO_BASE_DAMAGE[entity:rank()]
  local spell = create_spell_base(entity, damage)

  local animation = spell:animation()
  animation:set_state("LONG_BLADE")
  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
    spell:attack_tile(spell:get_tile(spell:facing(), 1))
  end

  return spell
end

---@param entity Entity
local function create_wide_blade(entity)
  local damage = RANK_TO_BASE_DAMAGE[entity:rank()]
  local spell = create_spell_base(entity, damage)

  local animation = spell:animation()
  animation:set_state("WIDE_BLADE")
  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
    spell:attack_tile(spell:get_tile(Direction.Up, 1))
    spell:attack_tile(spell:get_tile(Direction.Down, 1))
  end

  return spell
end

---@param action Action
---@param cleanup fun()[]
---@param resolve_tile fun(): Tile?, Tile?
local function add_slash_step(action, cleanup, resolve_tile)
  local entity = action:owner()
  local animation = entity:animation()

  ---@type Tile?
  local target_tile

  cleanup[#cleanup + 1] = create_movement_step(action, "CHARACTER_IDLE", function()
    local dest_tile

    target_tile, dest_tile = resolve_tile()

    return dest_tile
  end)

  local wait_time = 0
  local wait_step = action:create_step()
  wait_step.on_update_func = function()
    if wait_time == 0 then
      if not target_tile then
        wait_step:complete_step()
        return
      end

      if target_tile:x() < entity:current_tile():x() then
        entity:set_facing(Direction.Left)
      else
        entity:set_facing(Direction.Right)
      end
    end

    wait_time = wait_time + 1

    if wait_time == 10 then
      wait_step:complete_step()
    end
  end

  -- slash
  local attack_step = action:create_step()
  attack_step.on_update_func = function()
    if not target_tile then
      attack_step:complete_step()
      return
    end

    attack_step.on_update_func = nil

    animation:set_state("SLASH")

    animation:on_frame(2, function()
      local tile = entity:get_tile(entity:facing(), 1)

      if not tile then
        return
      end

      local blade

      if target_tile:y() == entity:current_tile():y() then
        blade = create_long_blade(entity)
      else
        blade = create_wide_blade(entity)
      end

      Field.spawn(blade, tile)
    end)

    animation:on_complete(function()
      attack_step:complete_step()
      animation:set_state("CHARACTER_IDLE")

      table.remove(cleanup, 1)()
    end)

    Resources.play_audio(SLASH_SFX)
  end
end

---@param entity Entity
---@param relative_direction Direction
---@param tiles Tile[]
---@param prev_tile Tile?
local function add_target_tiles(entity, relative_direction, tiles, prev_tile)
  local directions = { Direction.Up, Direction.None, Direction.Down }

  for _, direction in ipairs(directions) do
    direction = Direction.join(relative_direction, direction)

    local tile = entity:get_tile(direction, 1)

    if tile ~= prev_tile and tile and tile:is_walkable() then
      tiles[#tiles + 1] = tile
    end
  end
end

---@param entity Entity
local function create_triple_slash_factory(entity)
  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())
    action:allow_auto_tile_reservation(false)

    ---@type Tile?
    local reserved_tile
    local cleanup = {}

    local prev_tile

    local function random_slash_tile_resolver()
      -- find a target
      local targets = Field.find_nearest_characters(entity, function(c)
        return c:team() ~= entity:team() and c:hittable()
      end)

      local target = targets[1]

      if not target then
        return nil
      end

      -- resolve tiles we can move to
      local dest_tiles = {}

      add_target_tiles(target, target:facing(), dest_tiles, prev_tile)

      -- avoid attacking from behind on the first slash
      if prev_tile then
        add_target_tiles(target, target:facing_away(), dest_tiles, prev_tile)
      end

      if #dest_tiles == 0 then
        return nil
      end

      local target_tile = target:current_tile()
      local dest_tile = dest_tiles[math.random(#dest_tiles)]

      prev_tile = dest_tile

      return target_tile, dest_tile
    end

    action.on_execute_func = function()
      reserved_tile = entity:current_tile()
      reserved_tile:reserve_for(entity)

      create_attachment(action, "HAND", "SLASH_OVERLAY")

      add_slash_step(action, cleanup, random_slash_tile_resolver)
      add_slash_step(action, cleanup, random_slash_tile_resolver)
      add_slash_step(action, cleanup, random_slash_tile_resolver)

      cleanup[#cleanup + 1] = create_movement_step(action, "CHARACTER_IDLE", function()
        -- move to a new tile
        action.can_move_to_func = nil
        local end_tile = Ai.pick_same_team_tile(entity)

        if end_tile then
          reserved_tile:remove_reservation_for(entity)
          reserved_tile = end_tile
          reserved_tile:reserve_for(entity)
        else
          end_tile = reserved_tile
        end

        return end_tile
      end)
    end

    action.on_action_end_func = function()
      if reserved_tile then
        reserved_tile:add_entity(entity)
        reserved_tile:remove_reservation_for(entity)
      end

      for _, callback in ipairs(cleanup) do
        callback()
      end
    end

    action.can_move_to_func = function(tile)
      return tile:is_walkable() and not tile:is_edge()
    end

    return action
  end
end

---@param entity Entity
local function create_jab_factory(entity)
  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())
    action:allow_auto_tile_reservation(false)

    ---@type Tile?
    local reserved_tile
    local cleanup = {}

    action.on_execute_func = function()
      reserved_tile = entity:current_tile()
      reserved_tile:reserve_for(entity)

      local targets = Field.find_nearest_characters(entity, function(c)
        return c:team() ~= entity:team() and c:hittable()
      end)

      if #targets == 0 then
        action:end_action()
        return
      end

      local target_tile
      local attack_start_tile

      for _, target in ipairs(targets) do
        attack_start_tile = target:get_tile(target:facing(), 1)

        if attack_start_tile and attack_start_tile:is_walkable() then
          target_tile = target:current_tile()
          break
        end
      end

      if not attack_start_tile then
        -- failed to find a tile to move to
        action:end_action()
        return
      end

      create_attachment(action, "HAND", "SLASH_OVERLAY")

      add_slash_step(action, cleanup, function()
        return target_tile, attack_start_tile
      end)

      cleanup[#cleanup + 1] = create_movement_step(action, "CHARACTER_IDLE", function()
        -- move to a new tile
        action.can_move_to_func = nil
        local end_tile = Ai.pick_same_team_tile(entity)

        if end_tile then
          reserved_tile:remove_reservation_for(entity)
          reserved_tile = end_tile
          reserved_tile:reserve_for(entity)
        else
          end_tile = reserved_tile
        end

        return end_tile
      end)
    end

    action.on_action_end_func = function()
      if reserved_tile then
        reserved_tile:add_entity(entity)
        reserved_tile:remove_reservation_for(entity)
      end

      for _, callback in ipairs(cleanup) do
        callback()
      end
    end

    action.can_move_to_func = function(tile)
      return tile:is_walkable() and not tile:is_edge()
    end

    return action
  end
end

---@param entity Entity
local function spawn_contact_spell(entity)
  local spell = Spell.new(entity:team())

  local damage = RANK_TO_BASE_DAMAGE[entity:rank()]
  spell:set_hit_props(
    HitProps.new(
      damage,
      Hit.Flinch | Hit.Flash,
      Element.None
    )
  )

  spell.on_update_func = function()
    if entity:deleted() then
      spell:delete()
      return
    end

    if not entity:hitbox_enabled() then
      return
    end

    spell:set_team(entity:team())
    spell:attack_tile(entity:current_tile())
  end

  Field.spawn(spell, 0, 0)
end

---@param entity Entity
function character_init(entity)
  local rank = entity:rank()
  spawn_contact_spell(entity)

  entity:set_name("Bass")
  entity:set_height(63)
  entity:set_health(RANK_TO_HP[rank])
  entity:ignore_negative_tile_effects()
  entity:set_texture(TEXTURE)

  local animation = entity:animation()
  animation:load(ANIM_PATH)
  animation:set_state("CHARACTER_IDLE")
  animation:set_playback(Playback.Loop)

  local cape = entity:create_sync_node()
  cape:sprite():set_texture(CAPE_TEXTURE)
  cape:sprite():use_parent_shader()
  cape:animation():load(CAPE_ANIM_PATH)

  entity.on_idle_func = function()
    animation:set_state("CHARACTER_IDLE")
    animation:set_playback(Playback.Loop)
  end

  local ai = Ai.new_ai(entity)

  local movement_delay = RANK_TO_MOVEMENT_DELAY[rank]

  local random_movement_factory = create_random_move_factory(entity, movement_delay)
  local shoot_factory = create_buster_shooting_factory(entity)

  local shoot_plan = ai:create_plan()
  shoot_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(0, 5), random_movement_factory),
      Ai.IteratorLib.take(1, shoot_factory)
    )
  end)

  local back_center_movement_factory = create_back_center_factory(entity, movement_delay)
  local helz_rolling_factory = create_helz_rolling_factory(entity)

  local helz_rolling_plan = ai:create_plan()
  helz_rolling_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(0, 4), random_movement_factory),
      Ai.IteratorLib.take(1, back_center_movement_factory),
      Ai.IteratorLib.take(1, helz_rolling_factory)
    )
  end)

  local darkness_overload_factory = create_darkness_overload_factory(entity)

  local darkness_overload_plan = ai:create_plan()
  darkness_overload_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(0, 5), random_movement_factory),
      Ai.IteratorLib.take(1, darkness_overload_factory)
    )
  end)

  local jab_factory = create_jab_factory(entity)

  local darkness_overload_plan = ai:create_plan()
  darkness_overload_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(0, 1), random_movement_factory),
      Ai.IteratorLib.take(1, jab_factory)
    )
  end)

  local triple_slash_factory = create_triple_slash_factory(entity)

  local triple_slash_plan = ai:create_plan()
  triple_slash_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(0, 5), random_movement_factory),
      Ai.IteratorLib.take(1, triple_slash_factory)
    )
  end)
end

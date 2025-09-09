-- recreated using clips on youtube and customizations, so it may be inaccurate
-- fire arm: https://www.youtube.com/watch?v=lMDkRZETDTU
-- fire bomb: https://www.youtube.com/watch?v=2rAElil2XBU
-- full set: https://www.youtube.com/watch?v=g-Qpxq0ytRg&list=PL4Lscasoi2uu-48fYpyZkyhPpYVXxZF73&index=62

---@type dev.konstinople.library.ai
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local FIRE_ARM_SFX = bn_assets.load_audio("dragon4.ogg")
local FIRE_BOMB_SFX = bn_assets.load_audio("fire_bomb.ogg")

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local FIRE_ARM_TEXTURE = bn_assets.load_texture("bn4_spell_firearm.png")
local FIRE_ARM_ANIMATION_PATH = bn_assets.fetch_animation_path("bn4_spell_firearm.animation")

local FIRE_TOWER_TEXTURE = bn_assets.load_texture("fire_tower.png")
local FIRE_TOWER_ANIMATION_PATH = bn_assets.fetch_animation_path("fire_tower.animation")

local FIRE_BOMB_TEXTURE = bn_assets.load_texture("bomb.png")
local FIRE_BOMB_ANIMATION_PATH = bn_assets.fetch_animation_path("bomb.animation")
local FIRE_BOMB_SHADOW_TEXTURE = bn_assets.load_texture("bomb_shadow.png")
local FLAME_RINGS_TEXTURE = bn_assets.load_texture("flame_rings.png")
local FLAME_RINGS_ANIMATION_PATH = bn_assets.fetch_animation_path("flame_rings.animation")

---@generic T
---@param t table<Rank, T>
---@return table<Rank, T>
local function apply_bn4_ranks(t)
  t[Rank.Alpha] = t[Rank.V2]
  t[Rank.Beta]  = t[Rank.V3]
  t[Rank.Omega] = t[Rank.SP]
  return t
end

local RANK_TO_HP = apply_bn4_ranks({
  [Rank.V1] = 500,
  [Rank.V2] = 1000,
  [Rank.V3] = 1500,
  [Rank.SP] = 2000
})

-- bombs and fire rings
local FIRE_BOMB_DAMAGE_MULTIPLIER = 0.5

local RANK_TO_BASE_DAMAGE = apply_bn4_ranks({
  [Rank.V1] = 20,
  [Rank.V2] = 80,
  [Rank.V3] = 160,
  [Rank.SP] = 200,
})

local RANK_TO_BOMB_COUNT = apply_bn4_ranks({
  [Rank.V1] = 2,
  [Rank.V2] = 2,
  [Rank.V3] = 3,
  [Rank.SP] = 3
})

local RANK_TO_FLAME_RING_DURATION = apply_bn4_ranks({
  [Rank.V1] = 64,
  [Rank.V2] = 96,
  [Rank.V3] = 128,
  [Rank.SP] = 160
})

local RANK_TO_MOVEMENT_DELAY = apply_bn4_ranks({
  [Rank.V1] = 60,
  [Rank.V2] = 32,
  [Rank.V3] = 20,
  [Rank.SP] = 10
})

---@param entity Entity
local function get_nearby_target_tiles(entity)
  local team = entity:team()
  local closest_enemies = Field.find_nearest_characters(entity, function(e)
    return e:team() ~= team
  end)

  local closest_enemy = closest_enemies[1]

  local target_tiles = {}

  if not closest_enemy then
    return target_tiles
  end

  local center_tile = closest_enemy:current_tile()

  local start_x = center_tile:x() - 1
  local start_y = center_tile:y() - 1

  for y = start_y, start_y + 2 do
    for x = start_x, start_x + 2 do
      local tile = Field.tile_at(x, y)

      if tile and not tile:is_edge() and (tile:team() == Team.Other or tile:team() ~= team) then
        target_tiles[#target_tiles + 1] = tile
      end
    end
  end

  return target_tiles
end

---@param entity Entity
---@param end_idle_duration number
---@param select_tile fun(): Tile?
local function create_move_factory(entity, end_idle_duration, select_tile)
  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())

    action.on_execute_func = function()
      local tile = select_tile()

      if tile then
        entity:queue_default_player_movement(tile)
      end
    end

    local move_step = action:create_step()
    move_step.on_update_func = function()
      entity:set_facing(entity:current_tile():facing())

      if not entity:is_moving() then
        move_step:complete_step()

        local animation = entity:animation()
        animation:set_state("CHARACTER_IDLE")
        animation:set_playback(Playback.Loop)
      end
    end

    local idle_time = 0

    local idle_wait_step = action:create_step()
    idle_wait_step.on_update_func = function(self)
      entity:set_facing(entity:current_tile():facing())
      idle_time = idle_time + 1

      if idle_time >= end_idle_duration then
        self:complete_step()
      end
    end

    return action
  end
end

---@param entity Entity
---@param end_idle_duration number
local function create_random_move_factory(entity, end_idle_duration)
  return create_move_factory(entity, end_idle_duration, function()
    return Ai.pick_same_team_tile(entity)
  end)
end

---@param entity Entity
---@param end_idle_duration number
local function create_random_far_movement_factory(entity, end_idle_duration)
  return create_move_factory(entity, end_idle_duration, function()
    return Ai.pick_far_tile(entity)
  end)
end

---@param entity Entity
---@param end_idle_duration number
local function create_random_same_row_movement_factory(entity, end_idle_duration)
  return create_move_factory(entity, end_idle_duration, function()
    return Ai.pick_same_row_tile(entity)
  end)
end

---@param character Entity
---@param offset_y number?
local function spawn_hit_artifact(character, offset_y)
  local artifact = Artifact.new()
  artifact:set_facing(Direction.Right)
  artifact:set_never_flip()
  artifact:set_texture(HIT_TEXTURE)

  artifact:load_animation(HIT_ANIMATION_PATH)
  local anim = artifact:animation()
  anim:set_state("FIRE")
  anim:apply(artifact:sprite())

  anim:on_complete(function()
    artifact:erase()
  end)

  local tile_width = Tile:width()
  artifact:set_offset(
    math.random(-tile_width, tile_width) // 2,
    offset_y or 0
  )

  Field.spawn(artifact, character:current_tile())
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
local function create_fire_tower(team, context, damage, direction)
  local spell = Spell.new(team)
  spell:set_facing(Direction.Right)
  spell:set_never_flip(true)
  spell:set_hit_props(HitProps.new(
    damage,
    Hit.Flinch | Hit.Flash,
    Element.Fire,
    context,
    Drag.None
  ))

  spell:set_texture(FIRE_TOWER_TEXTURE)

  local animation = spell:animation()
  animation:load(FIRE_TOWER_ANIMATION_PATH)
  animation:set_state("SPAWN")

  animation:on_complete(function()
    animation:set_state("LOOP")
    animation:set_playback(Playback.Loop)

    local i = 0

    animation:on_complete(function()
      i = i + 1

      if i < 12 then
        return
      end

      animation:set_state("DESPAWN")
      animation:on_complete(function()
        spell:erase()
      end)
    end)
  end)

  local i = 0

  spell.on_spawn_func = function()
    Resources.play_audio(FIRE_ARM_SFX)
  end

  spell.on_update_func = function()
    i = i + 1

    if i == 24 then
      local tile = find_next_tower_tile(spell, spell:current_tile(), direction)

      if tile and tile:is_walkable() then
        local fire_tower = create_fire_tower(team, context, damage, direction)
        Field.spawn(fire_tower, tile)
      end
    end

    spell:attack_tile()
    spell:current_tile():set_highlight(Highlight.Solid)
  end

  spell.on_collision_func = function(_, other)
    spawn_hit_artifact(other, -math.random(math.floor(other:height())))
    spell:erase()
  end

  return spell
end

---@param entity Entity
local function create_flame_tower_factory(entity, damage)
  local animation = entity:animation()

  return function()
    local action = Action.new(entity, "FLAME_TOWER")
    action:set_lockout(ActionLockout.new_sequence())

    local spawn_towers_step = action:create_step()

    action.on_execute_func = function()
      animation:set_playback(Playback.Loop)
      entity:set_counterable(true)

      local i = 0

      animation:on_complete(function()
        i = i + 1

        if i == 1 then
          local direction = entity:facing()
          local tile = entity:get_tile(direction, 1)

          if tile and tile:is_walkable() then
            local spell = create_fire_tower(entity:team(), entity:context(), damage, direction)
            Field.spawn(spell, tile)
          end
        elseif i == 2 then
          entity:set_counterable(false)
        elseif i == 10 then
          spawn_towers_step:complete_step()
        end
      end)
    end

    action.on_action_end_func = function()
      entity:set_counterable(false)
    end

    return action
  end
end

---@param entity Entity
---@param damage number
local function create_fire_arm_flame(entity, damage)
  local spell = Spell.new(entity:team())
  spell:set_facing(entity:facing())
  spell:sprite():set_layer(-1)
  spell:set_hit_props(HitProps.new(
    damage,
    Hit.Flinch | Hit.Flash,
    Element.Fire,
    entity:context(),
    Drag.None
  ))

  if entity:facing() == Direction.Right then
    spell:set_offset(-20, -32)
  else
    spell:set_offset(20, -32)
  end

  spell:set_texture(FIRE_ARM_TEXTURE)

  local animation = spell:animation()
  animation:load(FIRE_ARM_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  spell.on_update_func = function()
    spell:attack_tile()
    spell:current_tile():set_highlight(Highlight.Solid)
  end

  spell.on_collision_func = function(_, other)
    spawn_hit_artifact(other)
  end

  return spell
end

---@param entity Entity
local function create_fire_arm_factory(entity, damage)
  local animation = entity:animation()

  return function()
    local action = Action.new(entity, "FIRE_ARM_START")
    action:override_animation_frames({ { 1, 18 } })
    action:set_lockout(ActionLockout.new_sequence())

    local wind_up_step = action:create_step()

    local MAX_LOOPS = 12
    local loops = 0

    local i = 0

    local spawn_fire_step = action:create_step()
    spawn_fire_step.on_update_func = function()
      if i % 20 == 0 then
        Resources.play_audio(FIRE_ARM_SFX)
      end

      i = i + 1
    end

    local flames = {}

    local function spawn_fire(tile)
      local flame = create_fire_arm_flame(entity, damage)
      flames[#flames + 1] = flame
      Field.spawn(flame, tile)
    end

    action.on_execute_func = function()
      entity:set_counterable(true)

      animation:on_complete(function()
        wind_up_step:complete_step()
        entity:set_counterable(false)

        -- normal animation loop
        animation:set_state("FIRE_ARM")
        animation:set_playback(Playback.Loop)

        -- spawn initial fire
        local next_tile = entity:get_tile(entity:facing(), 1)

        if next_tile then
          spawn_fire(next_tile)
        end

        -- spawn fire on every loop
        animation:on_complete(function()
          loops = loops + 1

          if loops >= MAX_LOOPS then
            spawn_fire_step:complete_step()
            return
          end

          if next_tile then
            spawn_fire(next_tile)
            next_tile = next_tile:get_tile(entity:facing(), 1)
          end
        end)
      end)
    end

    action.on_action_end_func = function()
      entity:set_counterable(false)

      for _, flame in ipairs(flames) do
        flame:erase()
      end
    end

    return action
  end
end

---@param team Team
---@param duration number
---@param hit_props HitProps
local function create_fire_ring(team, duration, hit_props)
  local spell = Spell.new(team)
  spell:set_facing(Direction.Right)
  spell:set_never_flip()
  spell:set_hit_props(hit_props)
  spell:set_texture(FLAME_RINGS_TEXTURE)

  local animation = spell:animation()
  animation:load(FLAME_RINGS_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  local remaining_time = duration

  spell.on_update_func = function()
    remaining_time = remaining_time - 1

    if remaining_time <= 0 or not spell:current_tile():is_walkable() then
      spell:erase()
    else
      spell:attack_tile()
    end
  end

  spell.on_collision_func = function(_, other)
    spawn_hit_artifact(other)
    spell:erase()
  end

  return spell
end

---@param entity Entity
---@param target_tile Tile
---@param damage number
local function spawn_fire_bomb(entity, target_tile, damage)
  local flame_ring_duration = RANK_TO_FLAME_RING_DURATION[entity:rank()]

  local spell = Spell.new(entity:team())
  spell:set_facing(entity:facing_away())
  spell:set_shadow(FIRE_BOMB_SHADOW_TEXTURE)
  spell:set_texture(FIRE_BOMB_TEXTURE)

  local animation = spell:animation()
  animation:load(FIRE_BOMB_ANIMATION_PATH)
  animation:set_state("FIRE")

  local elevation = entity:height() // 2
  spell:set_elevation(elevation)

  local hit_props = HitProps.new(
    damage,
    Hit.Flinch,
    Element.Fire,
    entity:context(),
    Drag.None
  )
  spell:set_hit_props(hit_props)

  spell.on_spawn_func = function()
    spell:jump(target_tile, Tile:height() * 4, 60)
  end

  local tested_direct_hit = false

  spell.on_collision_func = function()
    spell:erase()
  end

  spell.on_update_func = function()
    if elevation > 0 then
      elevation = math.max(elevation - 2, 0)
      spell:set_elevation(elevation)
    end

    if spell:is_moving() then
      return
    end

    local tile = spell:current_tile()

    if not tested_direct_hit then
      -- avoid spawning a fire ring if an entity is hit by the bomb directly
      tested_direct_hit = true
      spell:attack_tile()
      return
    end

    if tile:is_walkable() then
      hit_props.flags = hit_props.flags | Hit.Flash
      local fire_ring = create_fire_ring(spell:team(), flame_ring_duration, hit_props)
      Field.spawn(fire_ring, tile)
    end

    spell:erase()
  end

  Field.spawn(spell, entity:current_tile())
end

---@param entity Entity
local function create_fire_bomb_factory(entity, damage)
  -- generate frame_data
  local frame_data = {
    { 1, 6 }
  }

  local bomb_count = RANK_TO_BOMB_COUNT[entity:rank()]

  for _ = 1, RANK_TO_BOMB_COUNT[entity:rank()] do
    frame_data[#frame_data + 1] = { 2, 3 }
    frame_data[#frame_data + 1] = { 3, 3 }
    frame_data[#frame_data + 1] = { 1, 3 }
  end

  -- end
  frame_data[#frame_data + 1] = { 4, 3 }
  frame_data[#frame_data + 1] = { 5, 3 }
  frame_data[#frame_data + 1] = { 7, 1 }

  -- create fire bomb factory
  return function()
    local action = Action.new(entity, "FIRE_BOMB")
    action:override_animation_frames(frame_data)

    local target_tiles = get_nearby_target_tiles(entity)

    local spawn_fire_bomb_callback = function()
      if #target_tiles > 0 then
        local tile = table.remove(target_tiles, math.random(#target_tiles))
        spawn_fire_bomb(entity, tile, damage)
        Resources.play_audio(FIRE_BOMB_SFX)
      end
    end

    action.on_execute_func = function()
      entity:set_counterable(true)
    end

    action.on_action_end_func = function()
      entity:set_counterable(false)
    end

    for i = 0, bomb_count - 1 do
      local frame = 3 + i * 3
      action:add_anim_action(frame, spawn_fire_bomb_callback)
    end

    return action
  end
end

---@param entity Entity
function character_init(entity)
  entity:set_name("FireMan")
  entity:set_element(Element.Fire)
  entity:set_height(60)
  entity:set_texture(Resources.load_texture("battle.png"))

  local anim = entity:animation()
  anim:load("battle.animation")

  entity.on_idle_func = function()
    anim:set_state("CHARACTER_IDLE")
    anim:set_playback(Playback.Loop)
  end

  anim:set_state("CHARACTER_IDLE")
  anim:set_playback(Playback.Loop)

  local flame_node = entity:create_sync_node()
  local flame_sprite = flame_node:sprite()
  flame_sprite:set_texture(Resources.load_texture("overlay.png"))
  flame_sprite:use_parent_shader()
  flame_node:animation():load("overlay.animation")

  local rank = entity:rank()
  entity:set_health(RANK_TO_HP[rank])
  local damage = RANK_TO_BASE_DAMAGE[rank]

  -- AI
  local ai = Ai.new_ai(entity)

  local random_movement_factory = create_random_move_factory(entity, RANK_TO_MOVEMENT_DELAY[rank])

  -- fire arm
  local fire_arm_factory = create_fire_arm_factory(entity, damage)
  local same_row_movement_factory = create_random_same_row_movement_factory(entity, 0)

  local fire_arm_plan = ai:create_plan()
  fire_arm_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(2, 3), random_movement_factory),
      Ai.IteratorLib.take(1, same_row_movement_factory),
      Ai.IteratorLib.take(1, fire_arm_factory)
    )
  end)

  -- flame tower
  local flame_tower_factory = create_flame_tower_factory(entity, damage)

  local flame_tower_plan = ai:create_plan()
  flame_tower_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.short_circuiting_chain(
      Ai.IteratorLib.take(1, function()
        if entity:health() > entity:max_health() // 2 then
          -- above max health, disable this plan by short circuiting
          return nil
        end
        -- return a random movement to continue the chain
        return random_movement_factory()
      end),
      Ai.IteratorLib.chain(
        Ai.IteratorLib.take(math.random(1, 2), random_movement_factory),
        Ai.IteratorLib.take(1, same_row_movement_factory),
        Ai.IteratorLib.take(1, flame_tower_factory)
      )
    )
  end)

  -- fire bomb
  local fire_bomb_factory = create_fire_bomb_factory(entity, damage * FIRE_BOMB_DAMAGE_MULTIPLIER)
  local far_tile_setup_factory = create_random_far_movement_factory(entity, 0)

  local fire_bomb_plan = ai:create_plan()
  fire_bomb_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(3, 4), random_movement_factory),
      Ai.IteratorLib.short_circuiting_chain(
        Ai.IteratorLib.take(1, far_tile_setup_factory),
        Ai.IteratorLib.take(1, fire_bomb_factory)
      )
    )
  end)
end

-- recreated using clips on youtube and customizations, so it may be inaccurate
-- https://www.youtube.com/watch?v=psUUPlNWE-0

---@type dev.konstinople.library.ai
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetwork.FallingRock
local FallingRockLib = require("BattleNetwork.FallingRock")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local IMPACT_SFX = bn_assets.load_audio("hit_impact.ogg")
local HAMMER_SFX = bn_assets.load_audio("gaia_hammer.ogg")
local GUTS_MACH_GUN_SFX = bn_assets.load_audio("guts_mach_gun.ogg")
local GUTS_PUNCH_LAUNCH_SFX = bn_assets.load_audio("dust_launch.ogg")

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local MACH_SHOT_TEXTURE = Resources.load_texture("mach_shot.png")
local MACH_SHOT_ANIMATION_PATH = "mach_shot.animation"

local GUTS_PUNCH_TEXTURE = bn_assets.load_texture("guts_punch.png")
local GUTS_PUNCH_ANIMATION_PATH = bn_assets.fetch_animation_path("guts_punch.animation")

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
  [Rank.V2] = 900,
  [Rank.V3] = 1300,
  [Rank.SP] = 1700
})

-- direct hit and rubble
local GUTS_QUAKE_DAMAGE_MULTIPLIER = 2 / 3

local RANK_TO_BASE_DAMAGE = apply_bn4_ranks({
  [Rank.V1] = 30,
  [Rank.V2] = 120,
  [Rank.V3] = 240,
  [Rank.SP] = 300,
})

local RANK_TO_MACH_GUN_DAMAGE = apply_bn4_ranks({
  [Rank.V1] = 5,
  [Rank.V2] = 15,
  [Rank.V3] = 30,
  [Rank.SP] = 50,
})

local RANK_TO_CRACKS = apply_bn4_ranks({
  [Rank.V1] = 1,
  [Rank.V2] = 2,
  [Rank.V3] = 3,
  [Rank.SP] = 3
})

local RANK_TO_PUNCH_RANGE = apply_bn4_ranks({
  [Rank.V1] = 1,
  [Rank.V2] = 2,
  [Rank.V3] = 3,
  [Rank.SP] = 6
})

local RANK_TO_MOVEMENT_DELAY = apply_bn4_ranks({
  [Rank.V1] = 60,
  [Rank.V2] = 48,
  [Rank.V3] = 32,
  [Rank.SP] = 16
})

---@param entity Entity
---@param end_idle_duration number
---@param select_tile fun(): Tile?
local function create_move_factory(entity, end_idle_duration, select_tile)
  return function()
    local tile = select_tile()

    if not tile then
      return
    end

    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())

    local old_tile

    action.on_execute_func = function()
      old_tile = entity:current_tile()

      entity:queue_default_player_movement(tile)
    end

    local move_step = action:create_step()
    move_step.on_update_func = function()
      entity:set_facing(entity:current_tile():facing())

      old_tile:remove_reservation_for(entity)
      entity:current_tile():reserve_for(entity)

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

    action.on_action_end_func = function()
      entity:current_tile():remove_reservation_for(entity)
    end

    return action
  end
end

---@param entity Entity
---@param end_idle_duration number
local function create_random_movements_factory(entity, end_idle_duration)
  local total_moves = math.random(1, 3)

  if entity:health() < entity:max_health() // 2 then
    total_moves = total_moves - 1
  end

  return Ai.IteratorLib.take(total_moves,
    create_move_factory(entity, end_idle_duration, function()
      return Ai.pick_same_team_tile(entity)
    end)
  )
end

---@param entity Entity
---@param max_dist number
---@param end_idle_duration number
local function create_short_range_setup_factory(entity, max_dist, end_idle_duration)
  return create_move_factory(entity, end_idle_duration, function()
    return Ai.pick_same_row_tile(entity, 1, max_dist)
  end)
end

---@param character Entity
---@param state string
---@param offset_x number
---@param offset_y number
local function spawn_hit_artifact(character, state, offset_x, offset_y)
  local artifact = Artifact.new()
  artifact:set_facing(Direction.Right)
  artifact:set_never_flip()
  artifact:set_texture(HIT_TEXTURE)

  artifact:load_animation(HIT_ANIMATION_PATH)
  local anim = artifact:animation()
  anim:set_state(state)
  anim:apply(artifact:sprite())

  anim:on_complete(function()
    artifact:erase()
  end)

  local movement_offset = character:movement_offset()
  artifact:set_offset(
    movement_offset.x + offset_x,
    movement_offset.y + offset_y
  )

  character:field():spawn(artifact, character:current_tile())
end

---@param entity Entity
local function create_guts_quake_factory(entity, damage)
  return function()
    local action = Action.new(entity, "GUTS_QUAKE")

    action.on_execute_func = function()
      entity:set_counterable(true)
    end

    local hammer_hitbox

    action:add_anim_action(5, function()
      entity:set_counterable(false)
      Resources.play_audio(HAMMER_SFX)
      local field = entity:field()
      field:shake(5, 40)

      -- create hitbox for hammer
      local hammer_tile = entity:get_tile(entity:facing(), 1)

      if hammer_tile then
        hammer_hitbox = Spell.new(entity:team())
        hammer_hitbox:set_hit_props(HitProps.new(
          damage,
          Hit.Impact | Hit.Flinch,
          Element.None,
          entity:context(),
          Drag.None
        ))

        hammer_hitbox.on_update_func = function()
          hammer_hitbox:attack_tile()
        end

        field:spawn(hammer_hitbox, hammer_tile)
      end

      -- spawn rocks
      FallingRockLib.spawn_falling_rocks(field, entity:team(), 3, damage)

      -- crack panels
      local cracks = RANK_TO_CRACKS[entity:rank()]
      FallingRockLib.crack_tiles(field, entity:team(), cracks)
    end)

    action.on_action_end_func = function()
      entity:set_counterable(false)

      if hammer_hitbox then
        hammer_hitbox:erase()
      end
    end

    return action
  end
end

---@param entity Entity
local function create_guts_mach_gun_spell(entity, damage)
  local spell = Spell.new(entity:team())
  spell:set_facing(entity:facing())
  spell:set_offset(0, -27)
  spell:set_hit_props(HitProps.new(
    damage,
    Hit.Impact | Hit.Flinch,
    Element.None,
    entity:context(),
    Drag.None
  ))

  spell:set_texture(MACH_SHOT_TEXTURE)

  local animation = spell:animation()
  animation:load(MACH_SHOT_ANIMATION_PATH)
  animation:set_state("DEFAULT")

  spell.on_spawn_func = function()
    Resources.play_audio(GUTS_MACH_GUN_SFX)
  end

  local tiles_hit = 0

  spell.on_update_func = function()
    spell:attack_tile()

    if spell:is_moving() then
      return
    end

    tiles_hit = tiles_hit + 1

    local next_tile = spell:get_tile(spell:facing(), 1)

    if tiles_hit == 3 or not next_tile then
      spell.on_update_func = nil
      animation:set_state("DESPAWN")
      animation:on_complete(function()
        spell:erase()
      end)

      return
    end

    spell:slide(next_tile, 2)
  end

  spell.on_collision_func = function(self, other)
    Resources.play_audio(IMPACT_SFX)

    spawn_hit_artifact(other, "PEASHOT", math.random(-8, 8), math.random(-8, 8) + spell:offset().y)
    spell:erase()
  end

  return spell
end

---@param entity Entity
local function create_guts_mach_gun_factory(entity, damage)
  local animation = entity:animation()
  local field = entity:field()

  return function()
    local action = Action.new(entity, "GUTS_MACH_GUN")
    action:set_lockout(ActionLockout.new_sequence())

    local step = action:create_step()

    action.on_execute_func = function()
      entity:set_counterable(true)

      local i = 0

      animation:set_playback(Playback.Loop)
      animation:on_complete(function()
        i = i + 1

        if i == 5 then
          step:complete_step()
        end
      end)

      animation:on_frame(2, function()
        entity:set_counterable(false)

        local tile = entity:get_tile(entity:facing(), 1)

        if tile then
          local spell = create_guts_mach_gun_spell(entity, damage)
          field:spawn(spell, tile)
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
---@param guts_punch_range number
---@param damage number
local function create_guts_punch_spell(entity, guts_punch_range, damage)
  local spell = Spell.new(entity:team())
  spell:set_facing(entity:facing())
  spell:set_hit_props(HitProps.new(
    damage,
    Hit.Impact | Hit.Flinch | Hit.Drag,
    Element.None,
    entity:context(),
    Drag.new(entity:facing(), 1)
  ))

  spell.on_collision_func = function(_, other)
    Resources.play_audio(IMPACT_SFX)

    spawn_hit_artifact(other, "SPARK_1", math.random(-8, 8), math.random(-8, 8) - 25)

    if guts_punch_range >= 1 then
      spell:erase()
    end
  end

  if guts_punch_range <= 1 then
    spell.on_update_func = function()
      spell:attack_tile()
    end
  else
    spell:set_texture(GUTS_PUNCH_TEXTURE)

    local animation = spell:animation()
    animation:load(GUTS_PUNCH_ANIMATION_PATH)
    animation:set_state("DEFAULT")

    spell.on_spawn_func = function()
      Resources.play_audio(GUTS_PUNCH_LAUNCH_SFX)
    end

    local tiles_hit = 0
    spell.on_update_func = function()
      spell:attack_tile()

      if spell:is_moving() then
        return
      end

      tiles_hit = tiles_hit + 1

      local next_tile = spell:get_tile(spell:facing(), 1)

      if tiles_hit == guts_punch_range or not next_tile then
        spell:erase()
        return
      end

      spell:slide(next_tile, 8)
    end
  end


  return spell
end

---@param entity Entity
---@param guts_punch_range number
---@param damage number
local function create_guts_punch_factory(entity, guts_punch_range, damage)
  local animation = entity:animation()
  local field = entity:field()

  return function()
    local action = Action.new(entity, "GUTS_PUNCH")

    action.on_execute_func = function()
      entity:set_counterable(true)
    end

    local spell

    action:add_anim_action(4, function()
      entity:set_counterable(false)

      local tile = entity:get_tile(entity:facing(), 1)

      if tile then
        spell = create_guts_punch_spell(entity, guts_punch_range, damage)
        field:spawn(spell, tile)
      end

      if guts_punch_range > 1 then
        -- avoid deleting the spell on action end
        spell = nil
      end
    end)

    action.on_action_end_func = function()
      entity:set_counterable(false)

      if spell then
        spell:erase()
      end
    end

    return action
  end
end


---@param entity Entity
function character_init(entity)
  entity:set_name("GutsMan")
  entity:set_height(42)
  entity:set_texture(Resources.load_texture("battle.png"))

  local anim = entity:animation()
  anim:load("battle.animation")
  anim:set_state("CHARACTER_IDLE")
  anim:set_playback(Playback.Loop)

  local rank = entity:rank()
  entity:set_health(RANK_TO_HP[rank])
  local damage = RANK_TO_BASE_DAMAGE[rank]

  -- AI
  local ai = Ai.new_ai(entity)

  local end_idle_duration = RANK_TO_MOVEMENT_DELAY[rank]

  -- guts quake
  local guts_quake_factory = create_guts_quake_factory(entity, damage * GUTS_QUAKE_DAMAGE_MULTIPLIER)

  local guts_quake_plan = ai:create_plan()
  guts_quake_plan:set_weight(1)
  guts_quake_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      create_random_movements_factory(entity, end_idle_duration),
      Ai.IteratorLib.take(1, guts_quake_factory)
    )
  end)

  -- guts machine gun
  local guts_mach_gun_factory = create_guts_mach_gun_factory(entity, RANK_TO_MACH_GUN_DAMAGE[rank])
  local guts_mach_gun_setup_factory = create_short_range_setup_factory(entity, 3, 0)

  local mach_gun_plan = ai:create_plan()
  mach_gun_plan:set_weight(3)
  mach_gun_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      create_random_movements_factory(entity, end_idle_duration),
      Ai.IteratorLib.take(1, guts_mach_gun_setup_factory),
      Ai.IteratorLib.take(1, guts_mach_gun_factory)
    )
  end)

  -- guts punch
  local guts_punch_range = RANK_TO_PUNCH_RANGE[rank]
  local guts_punch_factory = create_guts_punch_factory(entity, guts_punch_range, damage)
  local guts_punch_setup_factory = create_short_range_setup_factory(entity, guts_punch_range, 0)

  local guts_punch_plan = ai:create_plan()
  guts_punch_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.short_circuiting_chain(
      create_random_movements_factory(entity, end_idle_duration),
      Ai.IteratorLib.take(1, guts_punch_setup_factory),
      Ai.IteratorLib.take(1, guts_punch_factory)
    )
  end)
end

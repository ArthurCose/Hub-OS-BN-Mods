---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")
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
local function create_guts_punch_action(entity, guts_punch_range, damage)
  local action = Action.new(entity, "GUTS_PUNCH")

  action.on_execute_func = function()
    entity:set_counterable(true)
  end

  local spell

  action:add_anim_action(4, function()
    entity:set_counterable(false)

    local tile = entity:get_tile(entity:facing(), 1)

    if tile then
      local field = entity:field()
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

---@param entity Entity
---@param cracks number
---@param damage number
local function guts_quake(entity, cracks, damage)
  local action = Action.new(entity, "GUTS_QUAKE")

  action.on_execute_func = function()
    entity:set_counterable(true)
  end

  local hammer_hitbox

  action:add_anim_action(5, function()
    entity:set_counterable(false)
    local field = entity:field()

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

      if hammer_tile:is_walkable() then
        Resources.play_audio(HAMMER_SFX)
        field:shake(5, 40)

        -- spawn rocks and crack panels
        local hit_props = HitProps.new(
          damage,
          Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceGuard,
          Element.None
        )

        FallingRockLib.spawn_falling_rocks(field, entity:team(), 3, hit_props)
        FallingRockLib.crack_tiles(field, entity:team(), cracks)
      end
    end
  end)

  action.on_action_end_func = function()
    entity:set_counterable(false)

    if hammer_hitbox then
      hammer_hitbox:erase()
    end
  end

  return action
end

---@param player Entity
function player_init(player)
  player:set_height(42)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))
  player:set_fully_charged_color(Color.new(34, 199, 16))
  player:set_charge_position(3, -23)

  -- emotions
  local synchro = EmotionsLib.new_synchro()
  synchro:set_ring_animation_state("BIG")
  synchro:set_ring_offset(0, -13)
  synchro:implement(player)

  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  -- attacks
  local heat = 0
  local HEAT_PER_SHOT = 30
  local cooldown = 0
  local MAX_COOLDOWN = 60

  local function calculate_max_heat()
    local bonus_capacity_from_rapid = (player:rapid_level() - 1) / 4 * 2
    return (bonus_capacity_from_rapid + 3) * HEAT_PER_SHOT
  end

  -- use a component to handle heat, so it can cool down while the player is stunned
  local heat_component = player:create_component(Lifetime.ActiveBattle)
  heat_component.on_update_func = function()
    if heat > 0 then
      heat = heat - 1
    end

    if cooldown > 0 then
      heat = 0
      cooldown = cooldown - 1
    end
  end

  local MACH_GUN_FRAMES = { { 1, 3 }, { 2, 3 }, { 3, 3 }, { 4, 3 } }
  local MACH_GUN_FAIL_FRAMES = { { 1, 3 }, { 3, 3 }, { 4, 3 } }


  player.normal_attack_func = function()
    local max_heat = calculate_max_heat()

    local frames = MACH_GUN_FRAMES

    local action = Action.new(player, "CHARACTER_SHOOT")

    local buster = action:create_attachment("BUSTER")
    local buster_animation = buster:animation()
    buster_animation:copy_from(player:animation())
    local buster_sprite = buster:sprite()
    buster_sprite:set_texture(player:texture())
    buster_sprite:set_color_mode(ColorMode.Additive)

    action.on_execute_func = function()
      player:set_counterable(true)
      buster_animation:set_state("BUSTER", frames)
    end

    local requeued_normal_attack = false
    local holding_shoot = false

    action.on_update_func = function()
      if cooldown == 0 then
        -- prevent heat from decreasing while the action is active
        heat = heat + 1
      end

      -- display heat
      local visible_heat

      if cooldown > 0 then
        visible_heat = cooldown / MAX_COOLDOWN * .5 + .5
      else
        visible_heat = heat / max_heat
      end

      buster_sprite:set_color(Color.new(255 * math.min(visible_heat, 1), 0, 0))

      -- allow requeue
      local previously_holding_shoot = holding_shoot
      holding_shoot = player:input_has(Input.Held.Shoot)

      if not requeued_normal_attack and previously_holding_shoot and not holding_shoot then
        player:queue_normal_attack()
        requeued_normal_attack = true
      end
    end

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    local success = true

    if cooldown > 0 then
      success = false
    else
      if heat > max_heat then
        success = false
      end

      heat = heat + HEAT_PER_SHOT

      if heat > max_heat then
        cooldown = MAX_COOLDOWN
      end
    end

    if success then
      action:add_anim_action(2, function()
        player:set_counterable(false)

        local tile = player:get_tile(player:facing(), 1)

        if tile then
          local field = player:field()
          local spell = create_guts_mach_gun_spell(player, player:attack_level() * 2)
          field:spawn(spell, tile)
        end
      end)
    else
      frames = MACH_GUN_FAIL_FRAMES
    end

    action:override_animation_frames(frames)

    return action
  end

  player.charged_attack_func = function()
    cooldown = MAX_COOLDOWN * 2 // 3
    return create_guts_punch_action(player, player:attack_level(), 60 + player:attack_level() * 20)
  end

  player.calculate_card_charge_time_func = function(self, card)
    local can_charge =
        not card.time_freeze
        and card.element == Element.None

    if can_charge then
      return 100
    end
  end

  player.charged_card_func = function()
    return guts_quake(player, player:attack_level() // 2 + 1, 60 + player:attack_level() * 20)
  end

  -- intro
  player.intro_func = function()
    local action = Action.new(player, "GUTS_PUNCH")
    action:override_animation_frames({
      { 2, 4 },
      { 1, 6 },
      { 2, 8 },
      { 1, 6 },
      { 2, 4 },
      { 1, 8 },
    })
    return action
  end
end

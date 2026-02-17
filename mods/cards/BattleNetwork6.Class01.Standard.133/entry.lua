---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.sword
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:use_hand()

local OBSTACLE_TEXTURE = bn_assets.load_texture("air_spin.png")
local OBSTACLE_ANIMATION_PATH = bn_assets.fetch_animation_path("air_spin.animation")
local SPAWN_STATE = "SPAWN_3"
local SPIN_STATE = "SPIN_3"
local LAUNCH_SFX = bn_assets.load_audio("dust_launch.ogg")

local AIR_TEXTURE = bn_assets.load_texture("airspin.png")
local AIR_ANIMATION_PATH = bn_assets.fetch_animation_path("airspin.animation")
local AIR_SFX = bn_assets.load_audio("physical_projectile.ogg")

local MIN_LIFETIME = 45

local HIT_DIRECTIONS = {
  Direction.UpLeft,
  Direction.Up,
  Direction.UpRight,
  Direction.Left,
  Direction.Right,
  Direction.DownLeft,
  Direction.Down,
  Direction.DownRight,
}

---@param team Team
---@param facing Direction
---@param hit_props HitProps
local function create_spell(team, facing, hit_props)
  local spell = Spell.new(team)
  spell:set_facing(facing)
  spell:set_hit_props(hit_props)
  spell:set_texture(AIR_TEXTURE)

  local animation = spell:animation()
  animation:load(AIR_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    Resources.play_audio(AIR_SFX)

    for _, direction in ipairs(HIT_DIRECTIONS) do
      local tile = spell:get_tile(direction, 1)

      if tile then
        spell:attack_tile(tile)
      end
    end
  end

  return spell
end

---@param user Entity
---@param hit_props HitProps
local function create_obstacle(user, hit_props)
  local team = user:team()

  local obstacle = Obstacle.new(Team.Other)
  obstacle:set_facing(user:facing())
  obstacle:set_health(400)
  obstacle:set_hit_props(hit_props)
  obstacle:set_owner(user)

  obstacle:add_aux_prop(AuxProp.new():declare_immunity(~0))

  obstacle:set_texture(OBSTACLE_TEXTURE)
  local animation = obstacle:animation()
  animation:load(OBSTACLE_ANIMATION_PATH)
  animation:set_state(SPAWN_STATE)

  obstacle.on_spawn_func = function()
    Resources.play_audio(LAUNCH_SFX)
  end

  obstacle.on_collision_func = function()
    -- self destruct
    Field.spawn(Explosion.new(), obstacle:current_tile())
    obstacle:delete()
  end

  local sitting = false
  local sitting_time = 0
  local target_lifetime = MIN_LIFETIME

  obstacle.can_move_to_func = function(tile)
    return not sitting and not tile:is_reserved() and tile:is_walkable()
  end

  obstacle.on_update_func = function()
    obstacle:attack_tile()

    if obstacle:is_moving() then
      return
    end

    if not sitting then
      local tile = obstacle:get_tile(obstacle:facing(), 1)

      if obstacle:can_move_to(tile) then
        obstacle:slide(tile, 10)
        return
      end

      sitting = true
    end

    sitting_time = sitting_time + 1

    if sitting_time >= target_lifetime then
      obstacle.on_update_func = nil
      obstacle.on_collision_func = nil
      animation:set_state(SPAWN_STATE)
      animation:set_playback(Playback.Reverse)
      animation:on_complete(function()
        obstacle:delete()
      end)
    end

    local spin_time = sitting_time - 16

    if spin_time == 0 then
      animation:set_state(SPIN_STATE)
      animation:set_playback(Playback.Loop)
    end

    if spin_time % 10 ~= 0 then
      return
    end

    local spell = create_spell(team, obstacle:facing(), hit_props)
    Field.spawn(spell, obstacle:current_tile())
  end

  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)

  defense_rule.defense_func = function(defense, attacker, defender, hit_props)
    if hit_props.flags & Hit.Drain ~= 0 or not sitting then return end

    if hit_props.element == Element.Wind or hit_props.secondary_element == Element.Wind then
      target_lifetime = target_lifetime + 10
    end
  end

  obstacle:add_defense_rule(defense_rule)

  return obstacle
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  return sword:create_action(user, function()
    local tile = user:get_tile(user:facing(), 1)

    if not tile then return end

    if not tile:is_walkable() then
      local poof = bn_assets.MobMove.new("MEDIUM_END")
      poof:set_offset(0, -16)
      Field.spawn(poof, tile)
      return
    end

    local obstacle = create_obstacle(user, HitProps.from_card(props, user:context()))
    Field.spawn(obstacle, tile)
  end)
end

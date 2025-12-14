---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local FIRE_TEXTURE = bn_assets.load_texture("fire_tower.png")
local FIRE_ANIMATION_PATH = bn_assets.fetch_animation_path("fire_tower.animation")
-- not sure if it's this, but it sounds closer than fireburn.ogg
local FIRE_SFX = bn_assets.load_audio("dragon1.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 50 + user:attack_level() * 20
end

---@param spell Entity
---@param other Entity
local on_attack_func = function(spell, other)
  local particle = bn_assets.HitParticle.new("FIRE")
  local movement_offset = other:movement_offset()
  particle:set_offset(
    movement_offset.x + math.random(-16, 16),
    movement_offset.y + math.random(-16, 16)
  )
  Field.spawn(particle, spell:current_tile())
end

---@param team Team
---@param hit_props HitProps
---@param tile Tile?
local function spawn_single_tower(team, hit_props, tile)
  if not tile or not tile:is_walkable() then return end

  local spell = Spell.new(team)
  spell:set_hit_props(hit_props)

  local sprite = spell:sprite()
  sprite:set_texture(FIRE_TEXTURE)
  sprite:set_layer(-1)

  local anim = spell:animation()
  anim:load(FIRE_ANIMATION_PATH)
  anim:set_state("SPAWN")

  anim:on_complete(function()
    anim:set_state("LOOP")

    local loops = 0

    anim:set_playback(Playback.Loop)
    anim:on_complete(function()
      loops = loops + 1

      if loops < 4 then
        return
      end

      anim:set_state("DESPAWN")
      anim:on_complete(function()
        -- disable attack
        spell.on_update_func = nil
        spell:delete()
      end)
    end)
  end)

  spell.on_update_func = function()
    spell:attack_tile()
  end

  spell.on_attack_func = on_attack_func

  Field.spawn(spell, tile)
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local animation = user:animation()

  if not animation:has_state("HEAT_PRESS") then
    return
  end

  local action = Action.new(user, "HEAT_PRESS")
  action:set_lockout(ActionLockout.new_sequence())

  ---@type Tile?
  local original_tile
  ---@type Tile?
  local reserved_tile
  local facing = user:facing()

  local hit_props = HitProps.from_card(props, user:context())

  local contact_spell = Spell.new()
  contact_spell:set_hit_props(hit_props)
  contact_spell.on_attack_func = on_attack_func
  Field.spawn(contact_spell, 0, 0)

  local jump_step = action:create_step()
  local jump_time = 0
  local MAX_JUMP_TIME = 20
  local MAX_HEIGHT = 80
  jump_step.on_update_func = function()
    if jump_time < MAX_JUMP_TIME then
      -- resolve position due to jump
      local progress = jump_time / MAX_JUMP_TIME

      local height = math.sin(progress * math.pi) * MAX_HEIGHT
      user:set_elevation(height)
      user:set_movement_offset(progress * Tile:width() * 3, 0)

      jump_time = jump_time + 1
      return
    end

    jump_step:complete_step()
    user:set_elevation(0)

    action.can_move_to_func = nil

    -- warp to the new tile
    reserved_tile = user:get_tile(facing, 3)

    if not reserved_tile or not reserved_tile:is_walkable() then
      action:end_action()
      return
    end

    reserved_tile:reserve_for(user)
    reserved_tile:add_entity(user)

    -- spawn fire
    Resources.play_audio(FIRE_SFX)

    local team = user:team()

    local dirs = {
      Direction.Up,
      Direction.Down,
      Direction.Left,
      Direction.Right
    }

    for _, dir in ipairs(dirs) do
      spawn_single_tower(team, hit_props, reserved_tile:get_tile(dir, 1))
    end
  end

  local wait_time = 0
  local wait_step = action:create_step()
  wait_step.on_update_func = function()
    wait_time = wait_time + 1

    if wait_time >= 30 then
      wait_step:complete_step()
      return
    end

    user:current_tile():add_entity(contact_spell)
    contact_spell:attack_tile()
  end

  action.can_move_to_func = function()
    -- we have custom movement logic, we don't want to be moved by random effects
    return false
  end

  action.on_execute_func = function()
    user:enable_hitbox(false)
    original_tile = user:current_tile()
    facing = user:facing()
  end

  action.on_action_end_func = function()
    user:enable_hitbox(true)
    user:set_elevation(0)

    if reserved_tile then
      reserved_tile:remove_reservation_for(user)
    end

    if original_tile then
      original_tile:add_entity(user)
    end

    if not contact_spell:deleted() then
      contact_spell:delete()
    end
  end

  return action
end

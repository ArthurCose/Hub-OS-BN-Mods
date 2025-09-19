local bn_assets = require("BattleNetwork.Assets")
local idle

local JUMP_HEIGHT = 120
local DROP_ELEVATION = 120

local THUD_SFX = bn_assets.load_audio("golmhit_high.ogg") -- not the right audio, but close

local EXPLOSION_TEXTURE = bn_assets.load_texture("spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("spell_explosion.animation")

---@class _BattleNetwork5.Powie: Entity
---@field _damage number
---@field _shock_shape "cross" | "column" | nil
---@field _target_id EntityId?
---@field _target_tile Tile?
---@field _jumps number
---@field _ominous_shadow Entity | nil

---@param character _BattleNetwork5.Powie
local function run_post_movement(character, fn)
  local component = character:create_component(Lifetime.Local)

  component.on_update_func = function()
    if not character:is_moving() then
      component:eject()
      fn()
    end
  end
end

---@param character _BattleNetwork5.Powie
local function create_hitprops(character)
  return HitProps.new(
    character._damage,
    Hit.Flinch | Hit.Flash,
    Element.None,
    character:context(),
    Drag.None
  )
end

---@param character _BattleNetwork5.Powie
local function create_hitbody_spell(character)
  local spell = Spell.new(character:team())

  local hit_props = create_hitprops(character)
  hit_props.flags = hit_props.flags | Hit.PierceGuard | Hit.PierceGround
  spell:set_hit_props(hit_props)

  spell.on_update_func = function()
    if character:deleted() then
      spell:erase()
    end

    spell:attack_tile()
  end

  Field.spawn(spell, character:current_tile())

  return spell
end

---@param character _BattleNetwork5.Powie
local function spawn_after_shock(character, x_offset, y_offset)
  local start_tile = character:current_tile()

  local tile = Field.tile_at(start_tile:x() + x_offset, start_tile:y() + y_offset)

  if not tile then
    return false
  end

  local spell = Spell.new(character:team())
  spell:set_hit_props(create_hitprops(character))
  spell:set_texture(EXPLOSION_TEXTURE)

  local anim = spell:animation()
  anim:load(EXPLOSION_ANIM_PATH)
  anim:set_state("DEFAULT")
  anim:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
  end

  Field.spawn(spell, tile)

  return true
end

---@param character _BattleNetwork5.Powie
local function spawn_after_shocks(character)
  if character._shock_shape == "column" then
    spawn_after_shock(character, 0, -1)
    spawn_after_shock(character, 0, 1)
  elseif character._shock_shape == "cross" then
    spawn_after_shock(character, 0, -1)
    spawn_after_shock(character, 0, 1)
    spawn_after_shock(character, -1, 0)
    spawn_after_shock(character, 1, 0)
  end
end

---@param character _BattleNetwork5.Powie
local function create_ominous_shadow(character)
  local shadow = Artifact.new()
  shadow:sprite():set_layer(1)
  shadow:set_texture(character:texture())

  local animation = shadow:animation()
  animation:copy_from(character:animation())
  animation:set_state("BIG_SHADOW")

  shadow.on_update_func = function()
    if character:deleted() then
      shadow:erase()
    end
  end

  Field.spawn(shadow, character:current_tile())

  return shadow
end

---@param character _BattleNetwork5.Powie
---@param return_tile Tile
local function complete_attack(character, hitbody_spell, return_tile, landing_tile)
  character._target_tile = nil
  character:teleport(return_tile, function()
    run_post_movement(character, function()
      if landing_tile then
        landing_tile:set_state(TileState.Cracked)
      end

      return_tile:remove_reservation_for(character)

      character._ominous_shadow:erase()
      character._ominous_shadow = nil
      character:show_shadow(true)
      character:enable_sharing_tile(false)
      character:enable_hitbox(true)
      hitbody_spell:erase()
    end)

    local anim = character:animation()
    anim:set_state("LAND")

    anim:on_complete(function()
      idle(character)
    end)
  end)
end

---@param character _BattleNetwork5.Powie
local function land(character, return_tile, hitbody_spell)
  local ticks = 0

  local landing_tile = character:current_tile()

  if not landing_tile:is_walkable() then
    complete_attack(character, hitbody_spell, return_tile)
    character.on_update_func = function() end
    return
  end

  Resources.play_audio(THUD_SFX, AudioBehavior.Default)
  spawn_after_shocks(character)
  character:enable_hitbox(true)
  Field.shake(8.0, 1.0 * 60)

  character.on_update_func = function()
    ticks = ticks + 1

    if ticks < 40 then
      return
    end

    complete_attack(character, hitbody_spell, return_tile, landing_tile)
    character.on_update_func = function() end
  end
end

---@param character _BattleNetwork5.Powie
local function drop(character, return_tile)
  local ticks = 0

  local elevations = {
    DROP_ELEVATION,
    DROP_ELEVATION - DROP_ELEVATION * 1 / 5,
    DROP_ELEVATION - DROP_ELEVATION * 2 / 5,
    DROP_ELEVATION - DROP_ELEVATION * 3 / 5,
    DROP_ELEVATION - DROP_ELEVATION * 4 / 5,
    DROP_ELEVATION - DROP_ELEVATION * 4 / 5,
    0
  }

  local hitbody_spell = create_hitbody_spell(character)

  character.on_update_func = function()
    ticks = ticks + 1
    local elevation = elevations[ticks]

    if elevation < 0 then
      elevation = 0
    end

    character:set_offset(0 * 0.5, -elevation * 0.5)

    if elevation == 0 then
      land(character, return_tile, hitbody_spell)
    end
  end
end

---@param character _BattleNetwork5.Powie
---@param target Entity
local function attack(character, target)
  character._target_id = target:id()
  character._jumps = 0

  character:set_counterable(true)

  local anim = character:animation()
  anim:set_state("LAND")
  anim:set_playback(Playback.Once)

  anim:on_complete(function()
    local return_tile = character:current_tile()
    local target_tile = target:current_tile()

    return_tile:reserve_for(character)
    character._target_tile = target_tile
    character:teleport(target_tile)

    run_post_movement(character, function()
      character:set_counterable(false)

      if character:current_tile() ~= target_tile then
        character._target_tile = nil
        return_tile:remove_reservation_for(character)
        idle(character)
        return
      end

      character:enable_sharing_tile(true)
      character:enable_hitbox(false)
      character:show_shadow(false)

      character:set_offset(0 * 0.5, -DROP_ELEVATION * 0.5)

      anim:set_state("ATTACK")
      anim:set_playback(Playback.Once)

      anim:on_frame(2, function()
        character._ominous_shadow = create_ominous_shadow(character)
      end)

      anim:on_complete(function()
        drop(character, return_tile)
      end)
    end)
  end)
end

---@param character _BattleNetwork5.Powie
local function find_target(character)
  local enemies = Field.find_nearest_characters(character, function(c)
    return c:hittable() and c:team() ~= character:team()
  end)

  return enemies[1]
end

---@param character _BattleNetwork5.Powie
local function attempt_attack(character)
  local target = find_target(character)

  if target then
    attack(character, target)
  else
    idle(character)
  end
end

---@param character _BattleNetwork5.Powie
local function find_valid_jump_location(character)
  local tiles = Field.find_tiles(function(tile)
    return character:can_move_to(tile)
  end)

  if #tiles == 0 then
    return
  end

  local target_tile = tiles[math.random(#tiles)]
  local start_tile = character:get_tile()

  if #tiles > 1 then
    while target_tile == start_tile do
      -- pick another, don't try to jump on the same tile if it's not necessary
      target_tile = tiles[math.random(#tiles)]
    end
  end

  return target_tile
end

---@param character _BattleNetwork5.Powie
local function jump(character)
  character._jumps = character._jumps + 1

  local anim = character:animation()
  anim:set_state("LAND")
  anim:set_playback(Playback.Reverse)

  anim:on_complete(function()
    anim:set_state("JUMP")
    anim:set_playback(Playback.Once)

    local target_tile = find_valid_jump_location(character)
    character:enable_hitbox(false)

    character.on_update_func = function()
      character:set_facing(character:get_tile():facing())
    end

    run_post_movement(character, function()
      character:enable_hitbox(true)
      character.on_update_func = function() end

      if character._jumps > 1 or math.random(20) == 1 then
        attempt_attack(character)
      else
        idle(character)
      end
    end)

    character:jump(target_tile, JUMP_HEIGHT, 40)
  end)
end

---@param character _BattleNetwork5.Powie
idle = function(character)
  local anim = character:animation()
  anim:set_state("IDLE")
  anim:set_playback(Playback.Loop)
  character._target_id = nil

  local wait_time = 0

  -- wait 2s then jump
  character.on_update_func = function()
    wait_time = wait_time + 1

    if wait_time < 120 then
      return
    end

    character.on_update_func = function() end

    jump(character)
  end
end

---@param character _BattleNetwork5.Powie
local function shared_package_init(character)
  character:set_texture(Resources.load_texture("battle.greyscaled.png"))
  character:load_animation("battle.animation")
  character:set_shadow(Resources.load_texture("small_shadow.png"))
  character:set_height(38)
  character:ignore_negative_tile_effects(true)

  character:add_aux_prop(StandardEnemyAux.new())

  character._damage = 20
  character._shock_shape = nil -- "column" | "cross" | nil
  character._target_id = nil
  character._target_tile = nil
  character._jumps = 0

  character.can_move_to_func = function(tile)
    if character:is_immobile() then
      return false
    end

    if tile:reserve_count_for(character) > 0 then
      return true
    end

    if character._target_tile then
      local team = character:team()
      local has_teammate = false

      character._target_tile:find_characters(function(c)
        if c:team() == team and c:id() ~= character:id() then
          has_teammate = true
        end

        return false
      end)

      return not has_teammate and character._target_tile:x() == tile:x() and character._target_tile:y() == tile:y()
    end

    if tile:team() ~= character:team() and tile:team() ~= Team.Other then
      return false
    end

    if not tile:is_walkable() or tile:is_reserved({ character:id() }) then
      return false
    end

    local has_character = false

    tile:find_entities(function(c)
      if not c:hittable() then return false end
      if (Character.from(c) and c:id() ~= character:id()) or Obstacle.from(c) then
        has_character = true
      end
      return false
    end)

    return not has_character
  end

  idle(character)
end

return shared_package_init

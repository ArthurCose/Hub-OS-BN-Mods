---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.sword
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_blade_animation_state("ELEC")
sword:set_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))
sword:set_frame_data({ { 2, 0 }, { 2, 2 }, { 3, 2 }, { 4, 10 } })

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("sword.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 40 + user:attack_level() * 20
end

---@param user Entity
local function create_spell(spells, user, props, x_offset, y_offset)
  local h_tile = user:get_tile(user:facing(), x_offset)
  if not h_tile then return end
  local tile = h_tile:get_tile(Direction.Down, y_offset)

  if not tile then
    return
  end

  local spell = Spell.new(user:team())
  spell:set_facing(user:facing())
  spell:set_hit_props(
    HitProps.from_card(
      props,
      user:context(),
      Drag.None
    )
  )

  spell.on_update_func = function(self)
    self:current_tile():attack_entities(self)
  end

  Field.spawn(spell, tile)

  spells[#spells + 1] = spell
end

---@param user Entity
local function spawn_artifact(spells, user, state)
  local tile = user:get_tile(user:facing(), 1)
  if not tile then return end

  -- using spell to avoid weird time freeze quirks
  local fx = Spell.new()
  fx:set_facing(user:facing())
  local anim = fx:animation()
  fx:set_texture(SLASH_TEXTURE)
  anim:load(SLASH_ANIM_PATH)
  anim:set_state(state)
  anim:on_complete(function()
    fx:erase()

    for _, spell in ipairs(spells) do
      spell:delete()
    end
  end)

  Field.spawn(fx, tile)
end


---@param team Team
---@param tile Tile?
local function tile_contains_enemy(team, tile)
  if not tile then
    return false
  end

  local has_enemy = false
  tile:find_characters(function(c)
    if c:hittable() and c:team() ~= team then
      has_enemy = true
    end

    return false
  end)

  return has_enemy
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "ELEC_SWORD_GLIDE")
  action:set_lockout(ActionLockout.new_sequence())

  ---@type Tile?
  local original_tile

  action.on_execute_func = function()
    original_tile = user:current_tile()
    original_tile:reserve_for(user)
  end

  action.can_move_to_func = function(tile)
    return not tile:is_edge() and not tile:is_reserved()
  end

  local glide_step = action:create_step()
  glide_step.on_update_func = function()
    local team = user:team()
    local facing = user:facing()
    local tile_ahead = user:get_tile(facing, 1)

    local enemy_ahead =
        tile_contains_enemy(team, tile_ahead) or
        tile_contains_enemy(team, user:get_tile(Direction.join(facing, Direction.Up), 1)) or
        tile_contains_enemy(team, user:get_tile(Direction.join(facing, Direction.Down), 1))

    if enemy_ahead then
      -- stop even if we're mid movement
      local movement_offset = user:movement_offset()
      user:set_offset(movement_offset.x, movement_offset.y)
      local tile = user:current_tile()
      user:cancel_movement()
      tile:add_entity(user)
      user:set_movement_offset(0, 0)

      user:set_counterable(true)
      glide_step:complete_step()
      return
    end

    if user:is_moving() then
      return
    end

    if not tile_ahead or not user:can_move_to(tile_ahead) then
      glide_step:complete_step()
      user:set_counterable(true)
      return
    end

    user:slide(tile_ahead, 6)
  end

  sword:create_action_step(action, function()
    local spells = {}
    spawn_artifact(spells, user, "ELEC_WIDE")
    create_spell(spells, user, props, 1, -1)
    create_spell(spells, user, props, 1, 0)
    create_spell(spells, user, props, 1, 1)

    Resources.play_audio(AUDIO)
    user:set_counterable(false)
  end)

  local wait_time = 0
  local return_and_wait_step = action:create_step()
  return_and_wait_step.on_update_func = function()
    if wait_time == 0 and original_tile then
      original_tile:add_entity(user)
      original_tile:remove_reservation_for(user)
      original_tile = nil

      local animation = user:animation()
      animation:set_state("CHARACTER_MOVE")
      animation:set_playback(Playback.Reverse)

      user:set_offset(0, 0)
    end

    wait_time = wait_time + 1

    if wait_time >= 35 then
      return_and_wait_step:complete_step()
    else
    end
  end

  action.on_action_end_func = function()
    if original_tile then
      original_tile:remove_reservation_for(user)
      original_tile:add_entity(user)
    end

    user:set_offset(0, 0)
    user:set_counterable(false)
  end

  return action
end

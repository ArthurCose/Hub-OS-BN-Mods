---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.field_math
local FieldMath = require("dev.konstinople.library.field_math")

local TEXTURE = Resources.load_texture("satelite.png")
local ANIMATION_PATH = _folder_path .. "satelite.animation"

local SHADOW_TEXTURE = Resources.load_texture("shadow.png")
local SHADOW_ANIMATION_PATH = _folder_path .. "shadow.animation"

local LAUNCH_SFX = bn_assets.load_audio("thunder.ogg")
local HIT_EFFECT_STATE = "ELEC"
local COLUMN_AVERAGE = 26.5 -- the average time spent in a full column
local ORBITAL_PERIOD = 150

local Sword = SwordLib.new_sword()
Sword:set_frame_data({ { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 15 } })
Sword:use_hand()

---@param satellite Entity
---@param center_tile Tile
---@param angle number
local function begin_orbit(satellite, center_tile, angle)
  local TILE_W = Tile:width()
  local TILE_H = Tile:height()

  local time = 0

  local angle_vel = math.pi * 2 / ORBITAL_PERIOD

  if satellite:facing() == Direction.Left then
    angle_vel = -angle_vel
  end

  local function update()
    time = time + 1

    if time > 5 * 60 then
      satellite:delete()
      -- continue to allow the offset to update
    end

    local offset_x = math.cos(angle) * TILE_W
    local offset_y = math.sin(angle) * TILE_H

    angle = angle + angle_vel

    local global_x, global_y = FieldMath.local_to_global(center_tile, offset_x, offset_y)
    local tile = FieldMath.global_to_tile(global_x, global_y)

    if tile and tile ~= center_tile then
      tile:add_entity(satellite)
      satellite:attack_tile()
      satellite:enable_hitbox(true)

      offset_x, offset_y = FieldMath.global_to_relative(tile, global_x, global_y)
    else
      -- avoid attacking the obstacle we're orbiting
      center_tile:add_entity(satellite)
      satellite:enable_hitbox(false)
    end

    satellite:set_movement_offset(offset_x, offset_y)
  end

  satellite.on_update_func = update
  update()
end

---@param satellite Entity
local function recenter_for_orbit(satellite)
  local collision_offset = satellite:movement_offset()
  local center_tile = satellite:current_tile()

  local TILE_W = Tile:width()
  local TILE_H = Tile:height()

  local angle

  if math.abs(collision_offset.x / TILE_W) > math.abs(collision_offset.y / TILE_H) then
    if collision_offset.x > 0 then
      angle = 0
    else
      angle = -math.pi
    end
  elseif collision_offset.y < 0 then
    angle = -math.pi * 0.5
  else
    angle = -math.pi * 1.5
  end

  local target_x = math.cos(angle) * TILE_W
  local target_y = math.sin(angle) * TILE_H

  local time = 0

  local function update()
    time = time + 1

    local progress = time / 8

    if progress >= 1 then
      begin_orbit(satellite, center_tile, angle)
      return
    end

    local offset_x = (target_x - collision_offset.x) * progress + collision_offset.x
    local offset_y = (target_y - collision_offset.y) * progress + collision_offset.y

    local global_x, global_y = FieldMath.local_to_global(center_tile, offset_x, offset_y)
    local tile = FieldMath.global_to_tile(global_x, global_y)

    if tile and tile ~= center_tile then
      tile:add_entity(satellite)
      satellite:attack_tile()
      satellite:enable_hitbox(true)

      offset_x, offset_y = FieldMath.global_to_relative(tile, global_x, global_y)
    else
      -- avoid attacking the obstacle we're orbiting
      center_tile:add_entity(satellite)
      satellite:enable_hitbox(false)
    end

    satellite:set_movement_offset(offset_x, offset_y)
  end

  satellite.on_update_func = update
  update()
end

---@param user Entity
---@param hit_props HitProps
local function create_satellite(user, hit_props)
  local satellite = Obstacle.new(user:team())
  satellite:set_texture(TEXTURE)
  satellite:set_shadow(SHADOW_TEXTURE, SHADOW_ANIMATION_PATH)
  satellite:set_facing(user:facing())
  satellite:set_hit_props(hit_props)
  satellite:set_health(hit_props.damage // 2)
  satellite:set_tile_highlight(Highlight.Solid)

  satellite.can_move_to_func = function()
    return true
  end

  local animation = satellite:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  satellite.on_spawn_func = function()
    Resources.play_audio(LAUNCH_SFX)
  end

  -- hit artifact
  satellite.on_collision_func = function(_, other)
    local artifact = bn_assets.HitParticle.new(HIT_EFFECT_STATE)
    artifact:sprite():set_layer(-1)


    local offset = other:movement_offset()
    artifact:set_offset(
      offset.x + math.random(-16, 16),
      offset.y + math.random(-other:height(), 0)
    )

    Field.spawn(artifact, other:current_tile())
  end

  -- movement and attack
  local tile_width = Tile:width()
  local tile_height = Tile:height()
  local speed = tile_width / COLUMN_AVERAGE

  if user:facing() ~= Direction.Right then
    speed = -speed
  end

  local initial_tile
  local x = Tile:width() / 2
  local a = math.pi
  local a_speed = math.pi / COLUMN_AVERAGE

  satellite.on_update_func = function()
    local current_tile = satellite:current_tile()

    if not initial_tile then
      initial_tile = current_tile
    end

    -- move forward
    x = x + speed

    -- resolve tile_x and x_offset
    local tile_x = initial_tile:x() + math.floor(x / tile_width)
    local x_offset = x - (tile_x - initial_tile:x() + 0.5) * tile_width

    -- advance angle
    a = a + a_speed

    -- resolve y values
    local sine = math.sin(a)
    local y = sine * tile_height
    local tile_y = initial_tile:y()

    if sine >= 0.5 then
      tile_y = tile_y + 1
    elseif sine <= -0.5 then
      tile_y = tile_y - 1
    end

    local y_offset = y - (tile_y - initial_tile:y()) * tile_height

    -- update offset
    satellite:set_movement_offset(x_offset, y_offset)

    -- updating tile
    local tile = Field.tile_at(tile_x, tile_y)

    if not tile then
      satellite:erase()
      return
    end

    -- update tile
    if current_tile ~= tile then
      current_tile:remove_entity(satellite)
      tile:add_entity(satellite)

      if #tile:find_obstacles(function(o) return o:hittable() and o:owner() ~= nil end) > 0 then
        recenter_for_orbit(satellite)
        return
      end
    end

    satellite:attack_tile()
  end

  satellite.on_delete_func = function()
    Field.spawn(Explosion.new(), satellite:current_tile())
    satellite:erase()
  end

  return satellite
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  return Sword:create_action(user, function()
    local tile = user:get_tile(user:facing(), 1)

    if tile then
      local hit_props = HitProps.from_card(props, user:context())
      local star = create_satellite(user, hit_props)

      Field.spawn(star, tile)
    end
  end)
end

local DEFAULT_FRAME_DATA = { { 1, 5 }, { 2, 4 }, { 3, 3 }, { 4, 5 }, { 5, 4 } }
local TILE_WIDTH = Tile:width()
local HALF_TILE_WIDTH = TILE_WIDTH / 2

---@class Bomb
local Bomb = {}
Bomb.__index = Bomb

function Bomb:set_execute_sfx(audio)
  self._execute_sfx = audio
end

--- Specifies a bomb texture that must be used.
function Bomb:set_bomb_texture(texture)
  self._bomb_texture = texture
end

function Bomb:set_bomb_shadow(texture)
  self._shadow_texture = texture
end

--- Specifies a bomb animation that must be used.
function Bomb:set_bomb_animation_path(animation_path)
  self._bomb_animation_path = animation_path
end

--- Specifies a bomb animation that must be used.
function Bomb:set_bomb_animation_state(animation_state)
  self._bomb_animation_state = animation_state
end

--- Specifies a bomb animation that must be used.
function Bomb:set_bomb_held_animation_state(animation_state)
  self._bomb_held_animation_state = animation_state
end

---@return [number, number][]
function Bomb:frame_data()
  return self._user_frame_data
end

--- [frame_number, duration][]
--- Used for custom timing. Not required, as a default timing is provided.
function Bomb:set_frame_data(frame_data)
  self._user_frame_data = frame_data
end

---@param self Bomb
local function create_bomb(self)
  local bomb = Spell.new()

  local bomb_sprite = bomb:sprite()
  bomb_sprite:set_texture(self._bomb_texture)
  bomb_sprite:set_layer(-1)

  local bomb_anim = bomb:animation()
  bomb_anim:load(self._bomb_animation_path)
  bomb_anim:set_state(self._bomb_held_animation_state or self._bomb_animation_state or "DEFAULT")
  bomb_anim:set_playback(Playback.Loop)

  return bomb
end

local function ease_in(progress)
  return progress ^ 2.5
end

local function ease_out(progress)
  return 2.0 * progress - progress ^ 1.7
end

---@param user Entity
---@param spell_callback fun(tile?: Tile)
function Bomb:create_action(user, spell_callback)
  local action = Action.new(user, "CHARACTER_THROW")
  action:set_lockout(ActionLockout.new_animation())
  action:override_animation_frames(self._user_frame_data)

  local field = user:field()
  local bomb, component, target_tile, cancelled

  local synced_frames = 0

  for i = 1, 2 do
    local value = self._user_frame_data[i]
    synced_frames = synced_frames + value[2]
  end

  action.on_execute_func = function()
    if self._execute_sfx then
      Resources.play_audio(self._execute_sfx)
    end

    -- create and spawn bomb
    bomb = create_bomb(self)
    bomb:set_facing(user:facing())
    field:spawn(bomb, user:current_tile())

    -- sync bomb position to hand
    local user_anim = user:animation()
    local user_sprite = user:sprite()
    local i = 0
    local x = 0
    local y = 0
    local vel_x = 3
    local release_y = 0

    local PEAK = -60

    bomb.on_update_func = function()
      i = i + 1
    end

    local update_tile = function()
      -- necessary for proper sprite layering

      if x > HALF_TILE_WIDTH then
        local next_tile = bomb:get_tile(Direction.Right, 1)

        if next_tile then
          x = x - TILE_WIDTH

          next_tile:add_entity(bomb)
        end
      elseif x < -HALF_TILE_WIDTH then
        local next_tile = bomb:get_tile(Direction.Left, 1)

        if next_tile then
          x = x + TILE_WIDTH
          next_tile:add_entity(bomb)
        end
      end
    end

    local fall_func = function()
      local progress = i / 28

      x = x + vel_x
      y = PEAK - PEAK * ease_in(progress)

      update_tile()

      bomb:set_offset(x, 0)
      bomb:set_elevation(-y)

      if progress == 1 then
        bomb:erase()
        spell_callback(target_tile)
      end
    end

    local rise_func = function()
      local progress = i / 12

      x = x + vel_x
      y = ease_out(progress) * (PEAK - release_y) + release_y

      update_tile()

      bomb:set_offset(x, 0)
      bomb:set_elevation(-y)

      if progress == 1 then
        -- swap update func
        component.on_update_func = fall_func
        -- reset i
        i = 0
      end
    end

    local sync_func = function()
      if cancelled then
        bomb:erase()
        return
      end

      if i == synced_frames then
        -- create shadow
        if self._shadow_texture then
          bomb:set_shadow(self._shadow_texture)
          bomb:show_shadow(true)
        end

        -- switch update func and lifetime
        component:eject()
        component = bomb:create_component(Lifetime.Local)
        component.on_update_func = rise_func

        -- snap to x = 0, adjust y to make sense
        release_y = y - math.abs(x) * 0.5
        y = release_y
        x = 0

        -- resolve target tile
        local facing_direction = user:facing()
        target_tile = user:get_tile(user:facing(), 3)

        if facing_direction == Direction.Left then
          -- flip animation direction based on the user's facing direction
          vel_x = -vel_x
        end

        -- reset i
        i = 0

        -- update animation
        if self._bomb_held_animation_state then
          local bomb_anim = bomb:animation()
          bomb_anim:set_state(self._bomb_animation_state or "DEFAULT")
          bomb_anim:set_playback(Playback.Loop)
        end

        rise_func()
        return
      end

      if user:deleted() then
        bomb:erase()
        return
      end

      local user_offset = user_sprite:offset()
      local user_movement_offset = user:movement_offset()
      local point = user_anim:get_point("HAND")
      local user_origin = user_sprite:origin()

      local scale = user_sprite:scale()

      if user:facing() ~= Direction.Right then
        scale.x = -scale.x
      end

      x = user_offset.x + user_movement_offset.x + (point.x - user_origin.x) * scale.x
      y = user_offset.y + user_movement_offset.y + (point.y - user_origin.y) * scale.y

      bomb:set_offset(x, y)
    end

    component = bomb:create_component(Lifetime.Scene)
    component.on_update_func = sync_func
  end

  action.on_action_end_func = function()
    cancelled = true
  end

  return action
end

---@class BombLib
local BombLib = {}

---@alias dev.konstinople.library.bomb BombLib

---@return Bomb
function BombLib.new_bomb()
  local bomb = {}
  setmetatable(bomb, Bomb)

  bomb:set_frame_data(DEFAULT_FRAME_DATA)

  return bomb
end

return BombLib

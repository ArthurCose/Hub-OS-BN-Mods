local DEFAULT_FRAME_DATA = { { 1, 8 }, { 2, 2 }, { 3, 2 }, { 4, 15 } }

---@class Sword
local Sword = {}
Sword.__index = Sword

--- Ignores the blade + hilt settings, uses the "HAND" state on the player instead
function Sword:use_hand()
  self._use_hand = true
end

--- If there's no blade texture set and no BLADE state set on the player's animation,
--- the texture specified here will be used.
function Sword:set_default_blade_texture(texture)
  self._default_blade_texture = texture
end

--- If there's no blade texture set and no BLADE state set on the player's animation,
--- the animation specified here will be used.
---
--- Expects a 4 frame DEFAULT state on the animation.
function Sword:set_default_blade_animation_path(animation_path)
  self._default_blade_animation_path = animation_path
end

--- Specifies a blade animation state to use instead of DEFAULT.
function Sword:set_default_blade_animation_state(state)
  self._default_blade_animation_state = state
end

--- Specifies a blade texture that must be used.
function Sword:set_blade_texture(texture)
  self._blade_texture = texture
end

--- Specifies a blade animation that must be used.
--- Expects a 4 frame DEFAULT state on the animation.
function Sword:set_blade_animation_path(animation_path)
  self._blade_animation_path = animation_path
end

--- Specifies a blade animation state to use instead of DEFAULT.
function Sword:set_blade_animation_state(state)
  self._blade_animation_state = state
end

--- [frame_number, duration][]
--- Used for custom timing. Not required, as a default timing is provided.
--- Affects the user's animation and modified to work with the hilt's animation
--- The hilt will subtract 1 from the frame number to sync with the user's animation
---@param frame_data [number, number][]
function Sword:set_frame_data(frame_data)
  self._user_frame_data = frame_data
  self._hilt_frame_data = {}

  for i = 2, #self._user_frame_data do
    local user_frame = self._user_frame_data[i]
    self._hilt_frame_data[i - 1] = {
      user_frame[1] - 1,
      user_frame[2]
    }
  end
end

function Sword:frame_data()
  return self._user_frame_data
end

--- The animation frame to call the spell callback at, default is 2
---@param frame_index number
function Sword:set_spell_frame_index(frame_index)
  self._spell_frame_index = frame_index
end

---@param self Sword
---@param user Entity
local function resolve_state(self, user)
  local state = "CHARACTER_SWING_HILT"

  if self._use_hand then
    state = "CHARACTER_SWING_HAND"
  end

  if not user:animation():has_state(state) then
    -- backwards compat
    warn(
      "CHARACTER_SWING is deprecated, bake into CHARACTER_SWING_HAND and CHARACTER_SWING_HILT"
      .. "\nhttps://hub-os.github.io/Navi-Animation-Updater/"
    )
    state = "CHARACTER_SWING"
  end

  return state
end

---@param self Sword
---@param action Action
---@param user Entity
local function create_hilt(self, action, user)
  local hilt = action:create_attachment("HILT")
  local hilt_sprite = hilt:sprite()
  hilt_sprite:set_layer(-1)
  hilt_sprite:use_root_shader()

  local hilt_anim = hilt:animation()

  if self._use_hand then
    hilt_sprite:set_texture(user:texture())
    hilt_anim:copy_from(user:animation())
    hilt_anim:set_state("HAND", self._hilt_frame_data)
    hilt_sprite:set_palette(user:palette())
  else
    hilt_sprite:set_texture(user:texture())
    hilt_sprite:set_palette(user:palette())
    hilt_anim:copy_from(user:animation())

    hilt_anim:set_state("HILT", self._hilt_frame_data)
  end

  return hilt
end

---@param self Sword
---@param hilt Attachment | Action
---@param user Entity
local function create_blade(self, hilt, user)
  local blade = hilt:create_attachment("ENDPOINT")
  local blade_sprite = blade:sprite()
  blade_sprite:set_layer(-2)
  blade_sprite:use_root_shader()

  local blade_anim = blade:animation()

  local actor_animation = user:animation()

  if self._blade_texture then
    blade_sprite:set_texture(self._blade_texture)
    blade_anim:load(self._blade_animation_path)
    blade_anim:set_state(self._blade_animation_state or "DEFAULT")
  elseif actor_animation:has_state("BLADE") then
    blade_sprite:set_texture(user:texture())
    blade_sprite:set_palette(user:palette())
    blade_anim:copy_from(actor_animation)
    blade_anim:set_state("BLADE")
  else
    blade_sprite:set_texture(self._default_blade_texture)
    blade_anim:load(self._default_blade_animation_path)
    blade_anim:set_state(self._default_blade_animation_state or "DEFAULT")
  end

  return blade
end

---@param self Sword
---@param action Action
---@param state string
---@param user Entity
local function build_attachments(self, action, state, user)
  local hilt

  if state == "CHARACTER_SWING" then
    -- more backwards compat
    hilt = create_hilt(self, action, user)
  end

  if not self._use_hand then
    create_blade(self, hilt or action, user)
  end
end

---@param user Entity
function Sword:create_action(user, spell_callback)
  local state = resolve_state(self, user)
  local action = Action.new(user, state)
  action:set_lockout(ActionLockout.new_animation())
  action:override_animation_frames(self._user_frame_data)

  action.on_execute_func = function()
    action:on_anim_frame(self._spell_frame_index, spell_callback)
    action:on_anim_frame(2, function()
      build_attachments(self, action, state, user)
    end)
  end

  return action
end

---@param action Action
function Sword:create_action_step(action, spell_callback)
  local step = action:create_step()

  step.on_update_func = function()
    local user = action:owner()
    local state = resolve_state(self, user)

    local animation = user:animation()
    animation:set_state(state, self._user_frame_data)
    animation:on_frame(self._spell_frame_index, spell_callback)
    animation:on_frame(2, function()
      build_attachments(self, action, state, user)
    end)

    local cleanup = function()
      step:complete_step()
    end

    animation:on_complete(cleanup)

    step.on_update_func = nil
  end

  return step
end

---@class SwordLib
local SwordLib = {}

---@alias dev.konstinople.library.sword SwordLib

---@return Sword
function SwordLib.new_sword()
  local sword = {}
  setmetatable(sword, Sword)

  sword:set_frame_data(DEFAULT_FRAME_DATA)
  sword:set_spell_frame_index(2)

  return sword
end

return SwordLib

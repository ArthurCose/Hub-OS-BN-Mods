local DEFAULT_FRAME_DATA = { { 1, 8 }, { 2, 2 }, { 3, 2 }, { 4, 15 } }

---@class Sword
local Sword = {}
Sword.__index = Sword

function Sword:set_blade_texture(texture)
  self._blade_texture = texture
end

--- Expects a 4 frame DEFAULT state on the animation.
function Sword:set_blade_animation_path(texture)
  self._blade_animation_path = texture
end

--- Texture for the hilt, uses the actor's texture by default.
function Sword:set_hilt_texture(texture)
  self._hilt_texture = texture
end

--- Expects a 3 frame HILT state with ENDPOINT points on the animation.
--- Uses the actor's animation by default
function Sword:set_hilt_animation_path(animation_path)
  self._hilt_animation_path = animation_path
end

--- [frame_number, duration][]
--- Used for custom timing. Not required, as a default timing is provided.
--- Affects the actor's animation and modified to work with the hilt's animation
--- The hilt will subtract 1 from the frame number to sync with the actor's animation
function Sword:set_frame_data(frame_data)
  self._actor_frame_data = frame_data
  self._hilt_frame_data = {}

  for i = 2, #self._actor_frame_data do
    local actor_frame = self._actor_frame_data[i]
    self._hilt_frame_data[i - 1] = {
      actor_frame[1] - 1,
      actor_frame[2]
    }
  end
end

---@param actor Entity
function Sword:create_action(actor, spell_callback)
  local action = Action.new(actor, "PLAYER_SWORD")
  action:set_lockout(ActionLockout.new_animation())
  action:override_animation_frames(self._actor_frame_data)

  action.on_execute_func = function()
    action:add_anim_action(2,
      function()
        local hilt = action:create_attachment("HILT")
        local hilt_sprite = hilt:sprite()
        hilt_sprite:set_texture(self._hilt_texture or actor:texture())
        hilt_sprite:set_layer(-1)
        hilt_sprite:use_root_shader(true)

        local hilt_anim = hilt:animation()

        if self._hilt_animation_path then
          hilt_anim:load(self._hilt_animation_path)
        else
          hilt_anim:copy_from(actor:animation())
        end

        hilt_anim:set_state(hilt_anim:derive_state("HILT", self._hilt_frame_data))

        local blade = hilt:create_attachment("ENDPOINT")
        local blade_sprite = blade:sprite()
        blade_sprite:set_texture(self._blade_texture)
        blade_sprite:set_layer(-2)

        local blade_anim = blade:animation()
        blade_anim:load(self._blade_animation_path)
        blade_anim:set_state("DEFAULT")
      end
    )

    action:add_anim_action(3, function()
      spell_callback()
    end)
  end

  return action
end

---@class SwordLib
local SwordLib = {}

function SwordLib.new_sword()
  ---@type Sword
  local sword = {}
  setmetatable(sword, Sword)

  sword:set_frame_data(DEFAULT_FRAME_DATA)

  return sword
end

return SwordLib

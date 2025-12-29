local shared = {}

---@param color Color
local function is_black(color)
  return color.r == 0 and color.g == 0 and color.b == 0
end

---@param sprite Sprite
function shared.is_sprite_color_unmodified(sprite)
  return sprite:color_mode() == ColorMode.Add and is_black(sprite:color())
end

---@param player Entity
---@param emotion string
---@param callback fun()
function shared.detect_once(player, emotion, callback)
  if player:emotion() == emotion then
    callback()
  else
    local aux_prop = AuxProp.new():require_emotion(emotion):once():with_callback(callback)
    player:add_aux_prop(aux_prop)
  end
end

---@param player Entity
---@param emotion string
---@param callback fun()
function shared.detect_end_once(player, emotion, callback)
  local component = player:create_component(Lifetime.Scene)

  local ejected = false
  component.on_update_func = function()
    if player:emotion() ~= emotion then
      component:eject()
      ejected = true
      callback()
    end
  end

  return function()
    if not ejected then
      component:eject()
    end
  end
end

return shared

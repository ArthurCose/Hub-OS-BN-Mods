-- pattern:
-- 22 solid
-- 2 black
-- 2 solid
-- 2 transparent
-- 2 solid
-- 2 black
-- - every other loop restarts here
-- 2 solid
-- 2 black
-- 2 solid
-- 2 transparent
-- 2 solid
-- 2 black


---@param a Color
---@param b Color
local function same_color(a, b)
  return
      a.r == b.r and
      a.g == b.g and
      a.b == b.b and
      a.a == b.a
end

local function copy_color(a, b)
  a.r = b.r
  a.g = b.g
  a.b = b.b
  a.a = b.a
end

local TRANSPARENT = Color.new(255, 255, 255, 0)
local SOLID = Color.new(255, 255, 255)
local BLACK = Color.new(0, 0, 0)

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local node = player:emotion_node()

  local time = 0
  local last_mode = ColorMode.Multiply
  local last_color = Color.new(255, 255, 255)

  local function has_external_update()
    return not same_color(node:color(), last_color) or not node:color_mode() == last_mode
  end

  local function display_reset()
    local updated_externally = has_external_update()

    copy_color(last_color, SOLID)

    if not updated_externally then
      node:set_color(last_color)
    end
  end

  local component = player:create_component(Lifetime.Scene)
  component.on_update_func = function()
    time = time + 1

    if time // 22 % 2 == 0 then
      display_reset()
      return
    end

    local half_time = time // 2

    if half_time % 2 == 0 then
      display_reset()
    elseif half_time % 11 == 2 or half_time % 11 == 8 then
      copy_color(last_color, TRANSPARENT)
    else
      copy_color(last_color, BLACK)
    end

    node:set_color_mode(last_mode)
    node:set_color(last_color)


    -- one loop is 44 frames
    -- we reset 32 frames into the second loop to break up the pattern identically to bn6
    if time == 76 then
      time = 0
    end
  end

  augment.on_delete_func = function()
    component:eject()

    node:set_color_mode(last_mode)
    node:set_color(SOLID)
  end
end

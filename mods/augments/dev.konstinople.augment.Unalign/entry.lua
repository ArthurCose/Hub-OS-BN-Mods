---@param x number
local function sign(x)
  if x > 0 then
    return 1
  else
    return -1
  end
end

---@param owner Entity
---@param dir Direction
---@param dist number
local function try_move(owner, dir, dist)
  local tile = owner:get_tile(dir, dist)

  if not tile or not owner:can_move_to(tile) then
    return false
  end

  tile:add_entity(owner)

  return true
end

---@param owner Entity
---@param dir Direction
---@param offset number
---@param boundary number
local function axis_movement(owner, dir, offset, boundary)
  if math.abs(offset) <= boundary then
    return offset
  end

  local offset_sign = sign(offset)

  if try_move(owner, dir, offset_sign) then
    return -boundary * offset_sign
  else
    return boundary * offset_sign
  end
end

-- alternate axis_movement that has some padding before switching tiles
-- ---@param owner Entity
-- ---@param dir Direction
-- ---@param offset number
-- ---@param boundary number
-- local function axis_movement(owner, dir, offset, boundary)
--   if math.abs(offset) <= boundary then
--     -- free to move
--     return offset
--   end

--   local offset_sign = sign(offset)

--   local tile = owner:get_tile(dir, offset_sign)

--   if not tile or not owner:can_move_to(tile) then
--     -- can't move to this tile, snap back to the boundary
--     return boundary * offset_sign
--   end

--   if math.abs(offset) <= boundary * 1.5 then
--     -- did not meet the threshold to switch tiles
--     return offset
--   end

--   -- switch tile
--   tile:add_entity(owner)

--   -- adjust offset for the new tile
--   return offset + 2 * -boundary * offset_sign
-- end

---@param augment Augment
function augment_init(augment)
  local x_offset = 0
  local y_offset = 0

  local owner = augment:owner()

  augment.movement_func = function(_, dir)
    local tile_w = Tile:width()
    local tile_h = Tile:height()

    local v = Direction.unit_vector(dir)
    x_offset = x_offset + v.x * tile_w / 14
    y_offset = y_offset + v.y * tile_h / 14

    x_offset = axis_movement(owner, Direction.Right, x_offset, tile_w / 2)
    y_offset = axis_movement(owner, Direction.Down, y_offset, tile_h / 2)
  end

  local component = owner:create_component(Lifetime.Scene)
  component.on_update_func = function()
    local movement_offset = owner:movement_offset()

    if movement_offset.x ~= 0 or movement_offset.y ~= 0 then
      x_offset = movement_offset.x
      y_offset = movement_offset.y
      return
    end

    owner:set_movement_offset(x_offset, y_offset)
  end
end

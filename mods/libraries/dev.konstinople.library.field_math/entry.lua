---@class dev.konstinople.library.field_math
local Lib = {}

---Converts an offset relative to a tile to a global position
---@param tile Tile
---@param offset_x number
---@param offset_y number
function Lib.local_to_global(tile, offset_x, offset_y)
  local TILE_W = Tile:width()
  local TILE_H = Tile:height()

  local global_x = (tile:x() + 0.5) * TILE_W + offset_x
  local global_y = (tile:y() + 0.5) * TILE_H + offset_y

  return global_x, global_y
end

---Resolves the tile for a global position
---@param global_x number
---@param global_y number
function Lib.global_to_tile(global_x, global_y)
  local TILE_W = Tile:width()
  local TILE_H = Tile:height()

  return Field.tile_at(global_x // TILE_W, global_y // TILE_H)
end

---Converts a global position to an offset relative to a specific tile
---@param tile Tile
function Lib.global_to_relative(tile, global_x, global_y)
  local TILE_W = Tile:width()
  local TILE_H = Tile:height()

  local local_x = global_x - (tile:x() + 0.5) * TILE_W
  local local_y = global_y - (tile:y() + 0.5) * TILE_H

  return local_x, local_y
end

return Lib

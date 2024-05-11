---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()
  local field = owner:field()

  augment.movement_func = function(self, direction)
    local vector = Direction.vector(direction)
    local start_tile = owner:current_tile()
    local dest_tile = start_tile

    if vector.y ~= 0 then
      vector.x = 0
    end

    ---@type Tile | nil
    local next_tile = dest_tile

    while next_tile ~= nil do
      next_tile = field:tile_at(next_tile:x() + vector.x, next_tile:y() + vector.y)

      if next_tile and owner:can_move_to(next_tile) then
        dest_tile = next_tile
      end
    end

    if start_tile ~= dest_tile then
      owner:queue_default_player_movement(dest_tile)
    end
  end
end

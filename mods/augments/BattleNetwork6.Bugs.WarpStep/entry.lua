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

    while true do
      local next_tile = field:tile_at(dest_tile:x() + vector.x, dest_tile:y() + vector.y)

      if not owner:can_move_to(next_tile) then
        break
      end

      dest_tile = next_tile
    end

    if start_tile ~= dest_tile then
      owner:queue_default_player_movement(dest_tile)
    end
  end
end

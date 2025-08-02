---@param augment Augment
function augment_init(augment)
  local state = TileState.Grass

  local width = Field.width()
  local height = Field.height()
  local tile
  for x = 1, width, 1 do
    for y = 1, height, 1 do
      tile = Field.tile_at(x, y)
      if tile and tile:state() == TileState.Normal then
        tile:set_state(state)
      end
    end
  end
end

---@param custom_state CustomTileState
function tile_state_init(custom_state)
  custom_state.change_request_func = function(self, tile, tile_state)
    return tile_state ~= TileState.Broken
  end
end

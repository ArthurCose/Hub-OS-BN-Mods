---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  player:ignore_hole_tiles(true)

  augment.on_delete_func = function()
    player:ignore_hole_tiles(false)
  end
end

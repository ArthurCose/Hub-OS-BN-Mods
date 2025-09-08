---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  player:ignore_negative_tile_effects(true)

  augment.on_delete_func = function()
    player:ignore_negative_tile_effects(false)
  end
end

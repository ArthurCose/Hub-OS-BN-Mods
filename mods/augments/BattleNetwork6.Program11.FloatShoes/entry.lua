---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  player:boost_augment("HubOS.Augments.IgnoreNegativeTileEffects", 1)

  augment.on_delete_func = function()
    player:boost_augment("HubOS.Augments.IgnoreNegativeTileEffects", -1)
  end
end

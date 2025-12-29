---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  local open_component = player:create_component(Lifetime.CardSelectOpen)
  open_component.on_update_func = function()
    player:set_health(math.max(1, player:health() - 100))
  end

  augment.on_delete_func = function()
    open_component:eject()
  end
end

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local component = player:create_component(Lifetime.Battle)
  local time = 0

  component.on_update_func = function()
    time = time + 1

    -- [40, 10], changes at a rate of 5 frames per level
    local rate = math.max(45 - augment:level() * 5, 10)

    if time % rate ~= 0 then
      return
    end

    player:add_aux_prop(AuxProp.new():drain_health(1):once())
  end

  augment.on_delete_func = function()
    component:eject()
  end
end

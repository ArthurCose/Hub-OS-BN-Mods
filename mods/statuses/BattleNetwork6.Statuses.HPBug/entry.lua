---@param status Status
function status_init(status)
    local entity = status:owner()

    local component = entity:create_component(Lifetime.ActiveBattle)

    local time = 0
    local rate;
    component.on_init_func = function()
        rate = status:remaining_time()
    end
    component.on_update_func = function()
        status:set_remaining_time(rate)

        time = time + 1

        if time % rate ~= 0 then return end

        entity:add_aux_prop(AuxProp.new():drain_health(1):once())

        print(status:remaining_time())
    end

    -- cleanup
    status.on_delete_func = function()
        component:eject()
    end
end

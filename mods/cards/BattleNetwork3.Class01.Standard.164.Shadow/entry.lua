---@param user Entity
function card_init(user)
    local action = Action.new(user)
    action:set_lockout(ActionLockout.new_sequence())

    action.on_execute_func = function()
        user:apply_status(Hit.Shadow, 240)
    end

    return action
end

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_HIT")

    action:set_lockout(ActionLockout.new_animation())

    action.on_execute_func = function(self, user)
        user:boost_augment("BattleNetworkRealOperation.Augment.CannonMode", 1)
    end
    return action
end

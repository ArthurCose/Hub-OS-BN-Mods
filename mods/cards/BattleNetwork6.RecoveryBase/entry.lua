local bn_assets = require("BattleNetwork.Assets")

function card_init(user, props)
    local action = Action.new(user)
    action:set_lockout(ActionLockout.new_async(30))

    action.on_execute_func = function(self)
        local recov = bn_assets.Recovery.new(user, props.recover)
        Field.spawn(recov, user:current_tile())
    end

    return action
end

---@param user Entity
function card_init(user)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_async(20))

  action.on_execute_func = function()
    TurnGauge.complete_turn()
  end

  return action
end

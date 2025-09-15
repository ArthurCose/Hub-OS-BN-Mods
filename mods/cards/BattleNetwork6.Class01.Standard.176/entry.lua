---@type BattleNetwork.Assets
local bn_assets = require('BattleNetwork.Assets')

local audio = bn_assets.load_audio("turn_gauge_forced.ogg")

---@param user Entity
function card_init(user)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_async(20))

  -- Max out gauge & play sound effect
  action.on_execute_func = function()
    TurnGauge.set_time(TurnGauge.max_time())
    Resources.play_audio(audio, AudioBehavior.NoOverlap)
  end

  return action
end

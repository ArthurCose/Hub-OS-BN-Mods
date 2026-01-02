local JammedBuster = require("jammed_buster.lua")

---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()
  owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  local jam_aux = AuxProp.new()
      :require_action(ActionType.Charged)
      :intercept_action(function(action)
        if math.random(1, 16) > 10 then
          return action -- use the original action
        end

        -- swap with custom action
        return JammedBuster.new(owner)
      end)


  owner:add_aux_prop(jam_aux)

  augment.on_delete_func = function()
    owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
    owner:remove_aux_prop(jam_aux)
  end
end

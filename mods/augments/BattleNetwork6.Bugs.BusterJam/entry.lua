---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()
  owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
  end
end

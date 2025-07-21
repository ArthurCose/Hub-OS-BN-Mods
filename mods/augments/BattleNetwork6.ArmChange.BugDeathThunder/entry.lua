---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  augment.charged_attack_func = function()
    local props = CardProperties.from_package("BattleNetwork6.Class01.Standard.029.Thunder")
    local copy_props = CardProperties.from_package("BattleNetwork6.Class03.Giga.005.Falzar.BugDeathThunder")

    props.damage = copy_props.damage
    props.card_class = copy_props.card_class

    return Action.from_card(player, props)
  end

  augment.calculate_charge_time_func = function(self)
    return 200
  end
end

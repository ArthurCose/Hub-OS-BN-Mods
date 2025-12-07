---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  -- override rapid buster
  augment:set_charge_with_shoot(true)

  augment.charged_attack_func = function()
    local props = CardProperties.from_package("BattleNetwork4.Class05.Dark.002.Sword")
    local copy_props = CardProperties.from_package("BattleNetwork6.Class03.Giga.005.Gregar.BugRiseSword")

    props.damage = copy_props.damage
    props.card_class = copy_props.card_class

    return Action.from_card(player, props)
  end

  augment.calculate_charge_time_func = function(self)
    return 120
  end
end

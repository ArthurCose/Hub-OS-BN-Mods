function card_init(actor, props)
  if Player.from(actor) ~= nil then
    actor:boost_augment("BattleNetwork4.Bugs.PanelBug", 1)
  end

  props.package_id = "BattleNetwork6.Class01.Standard.052.DrillArm"

  return Action.from_card(actor, props)
end

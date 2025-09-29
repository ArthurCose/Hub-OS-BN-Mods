---@param user Entity
function card_dynamic_damage(user)
  return 70 + user:attack_level() * 10
end

function card_init(actor, props)
  props.package_id = "BattleNetwork6.Class01.Standard.012"
  return Action.from_card(actor, props)
end

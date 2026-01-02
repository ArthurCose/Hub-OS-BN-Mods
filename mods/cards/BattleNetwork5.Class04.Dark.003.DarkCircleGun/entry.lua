function card_mutate(user, index)
  if Player.from(user) == nil then return end

  user:boost_augment("BattleNetwork6.Bugs.CustomHPBug", 1)

  local damage_increase_prop = AuxProp.new()
      :require_hit_damage(Compare.GT, 0)
      :increase_hit_damage("DAMAGE / 2")

  user:add_aux_prop(damage_increase_prop)
end

function card_init(actor, props)
  props.package_id = "BattleNetwork6.Class01.Standard.137.CircGun"

  return Action.from_card(actor, props)
end

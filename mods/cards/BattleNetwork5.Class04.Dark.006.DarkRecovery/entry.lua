function card_mutate(user, index)
  if Player.from(user) == nil then return end

  user:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 2)

  local damage_increase_prop = AuxProp.new()
      :require_hit_damage(Compare.GT, 0)
      :increase_hit_damage("DAMAGE / 4")

  user:add_aux_prop(damage_increase_prop)
end

function card_init(actor, props)
  props.package_id = "BattleNetwork4.Class05.Dark.008.Recovery"

  return Action.from_card(actor, props)
end

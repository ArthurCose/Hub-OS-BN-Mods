function card_mutate(user, index)
    if Player.from(user) == nil then return end

    user:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 2)

    local damage_increase_prop = AuxProp.new()
        :require_hit_damage(Compare.GT, 0)
        :increase_hit_damage("DAMAGE / 2")

    user:add_aux_prop(damage_increase_prop)
end

function card_init(user, props)
    props.package_id = "BattleNetwork6.RecoveryBase"
    local action = Action.from_card(user, props)

    local amount = math.floor(user:max_health() / 4)

    user:boost_max_health(-amount)

    return action
end

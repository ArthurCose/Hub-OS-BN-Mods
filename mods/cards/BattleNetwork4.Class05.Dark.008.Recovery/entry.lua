function card_mutate(user, card_index)
    if Player.from(user) == nil then return end
    user:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 2)
end

function card_init(user, props)
    props.package_id = "BattleNetwork6.RecoveryBase"
    local action = Action.from_card(user, props)
    local amount = math.floor(user:max_health() / 3)
    user:boost_max_health(-amount)
    return action
end

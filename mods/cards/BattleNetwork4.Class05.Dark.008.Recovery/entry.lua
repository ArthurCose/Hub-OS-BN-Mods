function card_mutate(user, card_index)
    if Player.from(user) == nil then return end
    user:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 1)
end

function card_init(actor, props)
    props.package_id = "BattleNetwork6.RecoveryBase"
    return Action.from_card(actor, props)
end

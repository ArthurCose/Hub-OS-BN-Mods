function card_mutate(entity, card_index)
    entity:apply_status(Hit.Confuse, 512)
end

function card_init(actor, props)
    props.package_id = "BattleNetwork6.Class01.Standard.005"
    return Action.from_card(actor, props);
end

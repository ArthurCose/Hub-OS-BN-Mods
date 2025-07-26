function card_mutate(user, card_index)
    local health_drain = AuxProp.new()
        :require_interval(7)
        :require_health(Compare.GT, 1)
        :drain_health(1)

    user:add_aux_prop(health_drain)
end

function card_init(actor, props)
    props.package_id = "BattleNetwork6.RecoveryBase"
    return Action.from_card(actor, props)
end

local track_health;

---@param user Entity
function card_dynamic_damage(user)
    return math.min(999, user:max_health() - user:health())
end

function card_mutate(entity, card_index)
    if Player.from(entity) == nil then return end

    entity:boost_attack_level(-(entity:attack_level() - 1))
    entity:boost_charge_level(-(entity:charge_level() - 1))
    entity:boost_rapid_level(-(entity:rapid_level() - 1))
end

function card_init(actor, props)
    props.package_id = "BattleNetwork6.CannonBase"

    return Action.from_card(actor, props);
end

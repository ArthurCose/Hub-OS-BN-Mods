function card_init(actor, props)
    -- Only visuals and some stats change - reuse the chip.
    local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.015")

    -- Change the name
    card_properties.short_name = props.short_name;

    -- Return the new action
    return Action.from_card(actor, card_properties);
end

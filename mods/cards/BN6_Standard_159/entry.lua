function card_init(actor, props)
    -- Use a template chip.
    local card_properties = CardProperties.from_package("dev.GladeWoodsgrove.ZeroRecovery")

    -- Modify properties as needed.
    card_properties.recover = props.recover;
    card_properties.short_name = props.short_name;

    return Action.from_card(actor, card_properties);
end

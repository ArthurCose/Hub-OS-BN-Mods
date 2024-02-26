function card_init(actor, props)
	-- Almost identical to Cannon so reuse it
	local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.088")

	-- Change damage to what's taken in from toml + modifiers
	card_properties.damage = props.damage

	-- Change name as well
	card_properties.short_name = props.short_name;

    -- Attempt adding type
    card_properties.crackshoot_type = 2
	return Action.from_card(actor, card_properties);
end

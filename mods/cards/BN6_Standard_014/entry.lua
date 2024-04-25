function card_init(actor, props)
	-- Almost identical to Spreader 1, so reuse it
	local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.012")

	-- Change damage to what's taken in from toml + modifiers
	card_properties.damage = props.damage

	-- Change name as well
	card_properties.short_name = props.short_name;
	return Action.from_card(actor, card_properties);
end

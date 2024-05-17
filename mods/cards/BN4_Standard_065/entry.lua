function card_init(actor, props)
	-- Almost identical to Cannon so reuse it
	local card_properties = CardProperties.from_package("dev.GladeWoodsgrove.AirHockeyZero")

	-- Change sent props based on current toml in case of differences
	card_properties.damage = props.damage
	card_properties.hit_flags = props.hit_flags

	-- Change name as well
	card_properties.short_name = props.short_name;

	return Action.from_card(actor, card_properties);
end

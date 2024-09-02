function card_init(actor, props)
	-- Almost identical to Cannon so reuse it
	props.package_id = "dev.GladeWoodsgrove.ZeroDamageCannon"
	return Action.from_card(actor, props)
end

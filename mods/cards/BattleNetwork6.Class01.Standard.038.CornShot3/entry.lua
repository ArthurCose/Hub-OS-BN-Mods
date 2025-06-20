function card_init(actor, props)
	-- Almost identical to Cannon so reuse it
	props.package_id = "BattleNetwork6.Class01.Standard.036.CornShot1"
	return Action.from_card(actor, props)
end

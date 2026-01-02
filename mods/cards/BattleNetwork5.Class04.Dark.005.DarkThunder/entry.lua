function card_mutate(user, index)
	if Player.from(user) == nil then return end
	user:boost_augment("BattleNetwork6.Bugs.CustomHPBug", 1)
end

function card_init(actor, props)
	props.package_id = "BattleNetwork6.Class01.Standard.029.Thunder"

	return Action.from_card(actor, props)
end

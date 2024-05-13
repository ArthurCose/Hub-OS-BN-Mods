function augment_init(augment)
	augment.normal_attack_func = function(self)
		local actor = augment:owner()
		local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.001")
		return Action.from_card(actor, card_properties);
	end
end

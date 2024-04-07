function augment_init(augment)
	local player = augment:owner()
	local super_armor = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
	super_armor.filter_statuses_func = function(statuses)
		statuses.flags = statuses.flags & ~Hit.Flinch
		return statuses
	end
	player:add_defense_rule(super_armor)
end

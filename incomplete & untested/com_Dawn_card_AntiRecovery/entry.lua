nonce = function() end



function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")
	local field = actor:field()
	local target_array = {}
	action.on_execute_func = function(self, user)
		local Anti_Recover_Rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
		local Anti_Recover_Component = user:create_component(Lifetime.Battle)
		local is_attack = false
		local damage = 0
		local previous_hp_array = {}
		local target = nil
		local query = function(ent)
			return ent ~= nil and not ent:deleted() and ent:team() ~= user:team()
		end
		local targets = user:field():find_characters(query)
		for i = 1, #targets, 1 do
			table.insert(target_array, targets[i])
			table.insert(previous_hp_array, targets[i]:health())
		end
		Anti_Recover_Component.on_update_func = function(self)
			for t = 1, #targets, 1 do
				if not targets[t]:deleted() then
					if targets[t]:health() > previous_hp_array[t] then
						is_attack = true
						target = targets[t]
						damage = (targets[t]:health() - previous_hp_array[t]) * 2
						if target:health() - damage <= 0 then
							damage = target:health() - 1
						end
						local hitbox = Spell.new(Team.Other)
						hitbox:set_hit_props(
							HitProps.new(
								damage,
								Hit.Impact | Hit.PierceInvis,
								Element.None,
								self:owner():context(),
								Drag.None
							)
						)
						target:field():spawn(hitbox, target:current_tile())
						target:remove_defense_rule(Anti_Recover_Rule)
						hitbox.on_update_func = function(self)
							self:current_tile():attack_entities(self)
							self:erase()
						end
						self:eject()
						break
					elseif targets[t]:health() < previous_hp_array[t] then
						previous_hp_array[t] = targets[t]:health()
					end
				end
			end
			if Anti_Recover_Rule:replaced() then
				user:remove_defense_rule(Anti_Recover_Rule)
				Anti_Recover_Component:eject()
			end
		end
		user:add_defense_rule(Anti_Recover_Rule)
	end
	return action
end

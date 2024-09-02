function card_mutate(player, index)
	local left_card = player:field_card(index - 1)

	if left_card and left_card.can_boost then
		-- update the left_card
		left_card.damage = left_card.damage + 30
		left_card.boosted_damage = left_card.boosted_damage + 30
		player:set_field_card(index - 1, left_card)

		-- remove attack booster
		player:remove_field_card(index)
	end
end

function card_init(actor, props)
	local ParticlePoof = require("BattleNetwork.SmokePoof")
	local action = Action.new(actor, "CHARACTER_IDLE")
	action.on_execute_func = function(self, user)
		local fx = ParticlePoof.new()
		fx:set_height(user:height() * 2)
		actor:field():spawn(fx, actor:current_tile())
	end
	return action
end

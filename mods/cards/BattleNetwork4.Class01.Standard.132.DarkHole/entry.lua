function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:override_animation_frames(
		{ { 1, 40 } }
	)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local direction = actor:facing()
		local tile = actor:current_tile():get_tile(direction, 1)

		if tile and not tile:is_edge() then tile:set_state(TileState.Dark) end
	end
	return action
end

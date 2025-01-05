local bn_assets = require("BattleNetwork.Assets")
local hole_audio = bn_assets.load_audio("darkhole.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:override_animation_frames(
		{ { 1, 40 } }
	)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		Resources.play_audio(hole_audio)
		local field = actor:field()

		local y = actor:current_tile():y()

		local tile = nil

		for x = 1, 6, 1 do
			tile = field:tile_at(x, y)
			if tile and not tile:is_edge() then tile:set_state(TileState.Dark) end
		end
	end
	return action
end

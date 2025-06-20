local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("panel_change_indicate.ogg")
local FINISH_AUDIO = bn_assets.load_audio("panel_change_finish.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function(self, user)
		local field = actor:field()
		self._dir = actor:facing()
		self._count = 0
		self._max = field:width()

		local step1 = self:create_step()

		local ref = self
		local tile = nil
		local k = 0;
		local cooldown = 0
		local tracked_states = {}
		local y = actor:current_tile():y()

		local tiles = field:find_tiles(function(tile)
			if not tile then return false end
			if tile:is_edge() then return false end
			if tile:y() ~= y then return false end

			tracked_states[tile] = tile:state()

			return true
		end)

		step1.on_update_func = function(self)
			if k == 15 then
				Resources.play_audio(FINISH_AUDIO)
				self:complete_step()
				return
			end

			if cooldown <= 0 then
				k = k + 1
				cooldown = 4

				Resources.play_audio(AUDIO)

				for i = 1, #tiles, 1 do
					if k % 2 == 0 then
						tiles[i]:set_state(tracked_states[tiles[i]])
					else
						tiles[i]:set_state(TileState.Magnet)
					end
				end
			else
				cooldown = cooldown - 1
			end
		end
	end
	return action
end

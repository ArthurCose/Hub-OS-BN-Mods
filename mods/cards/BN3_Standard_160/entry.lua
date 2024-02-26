local AUDIO = Resources.load_audio("break.ogg")

function card_init(actor, props)
	local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")
	local action = Action.new(actor, "PLAYER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	local field = actor:field()
	local tile_array = {}
	local cooldown = 0
	action.on_execute_func = function(self, user)
		for i = 0, 6, 1 do
			for j = 0, 6, 1 do
				local tile = field:tile_at(i, j)
				if tile and not tile:is_edge() and tile:state() ~= TileState.Broken then
					table.insert(tile_array, tile)
				end
			end
		end
		local step1 = self:create_step()
		step1.on_update_func = function(self)
			for k = 0, #tile_array, 1 do
				if cooldown <= 0 then
					if #tile_array > 0 then
						local index = math.random(1, #tile_array)
						local tile2 = tile_array[index]
						if tile2:state() ~= TileState.Broken then
							local fx = bn_helpers.ParticlePoof.new()
							field:spawn(fx, tile2)
							tile2:set_state(TileState.Broken)
							Resources.play_audio(AUDIO)
						else
							k = k - 1
						end
						table.remove(tile_array, index)
						cooldown = 45
					else
						self:complete_step()
					end
				else
					cooldown = cooldown - 1
				end
			end
		end
	end
	return action
end

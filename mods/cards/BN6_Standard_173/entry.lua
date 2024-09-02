local AUDIO = Resources.load_audio("sfx.ogg")
local FINISH_AUDIO = Resources.load_audio("finish_sfx.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function(self, user)
		self.tile = actor:current_tile()
		self.dir = actor:facing()
		self.count = 0
		self.max = 6

		local step1 = self:create_step()

		local ref = self
		local tile = nil
		local k = 0
		local cooldown = 0
		local previous_state = nil
		step1.on_update_func = function(self)
			if cooldown <= 0 then
				k = k + 1
				cooldown = 5
				Resources.play_audio(AUDIO)
				for i = ref.count, ref.max, 1 do
					tile = ref.tile:get_tile(ref.dir, i)
					if tile and tile:state() ~= TileState.ConveyorLeft and tile:state() ~= TileState.ConveyorRight then
						previous_state = tile:state()
					end
					if tile and tile:team() ~= ref.tile:team() and not tile:is_edge() then
						if ref.dir == Direction.Left then
							if tile:state() == TileState.ConveyorLeft and previous_state ~= nil then
								tile:set_state(previous_state)
							else
								tile:set_state(TileState.ConveyorLeft)
							end
						else
							if tile:state() == TileState.ConveyorRight and previous_state ~= nil then
								tile:set_state(previous_state)
							else
								tile:set_state(TileState.ConveyorRight)
							end
						end
					end
				end
			else
				cooldown = cooldown - 1
			end
			if k == 14 then
				Resources.play_audio(FINISH_AUDIO)
				self:complete_step()
			end
		end
		for i = ref.count, ref.max, 1 do
			tile = ref.tile:get_tile(ref.dir, i)
			if tile and tile:team() ~= ref.tile:team() and not tile:is_edge() then
				if ref.dir == Direction.Left then
					tile:set_state(TileState.ConveyorLeft)
				else
					tile:set_state(TileState.ConveyorRight)
				end
			end
		end
	end
	return action
end

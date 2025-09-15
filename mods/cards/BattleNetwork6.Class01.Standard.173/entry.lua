local bn_assets = require("BattleNetwork.Assets")
local PANEL_CHANGE_SFX = bn_assets.load_audio("panel_change_indicate.ogg")
local FINISH_AUDIO = bn_assets.load_audio("panel_change_finish.ogg")

---@param user Entity
function card_init(user, props)
	local action = Action.new(user, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function()
		local step = action:create_step()

		local start_tile = user:current_tile()
		local facing = user:facing()

		-- resolve the target tile state based on the user's facing direction
		local target_state = TileState.ConveyorRight

		if facing == Direction.Left then
			target_state = TileState.ConveyorLeft
		end

		---@type table<Tile, TileState>
		local prev_states = {}
		local k = 0
		local cooldown = 0

		step.on_update_func = function()
			if cooldown > 0 then
				cooldown = cooldown - 1
				return
			end

			k = k + 1
			cooldown = 3

			for i = 0, Field.width(), 1 do
				local tile = start_tile:get_tile(facing, i)

				if not tile or tile:is_edge() then
					break
				end

				if tile:team() == user:team() then
					goto continue
				end

				if tile:state() ~= target_state then
					prev_states[tile] = tile:state()
				end

				local prev_state = prev_states[tile]

				if tile:state() == target_state and prev_state ~= nil then
					tile:set_state(prev_state)
				else
					tile:set_state(target_state)
				end

				::continue::
			end

			if k == 17 then
				Resources.play_audio(PANEL_CHANGE_SFX, AudioBehavior.EndLoop)
				Resources.play_audio(FINISH_AUDIO)
				step:complete_step()
			end
		end

		local SAMPLE_RATE = 44100
		Resources.play_audio(PANEL_CHANGE_SFX, AudioBehavior.LoopSection(0, SAMPLE_RATE / 60 * 4))
	end

	return action
end

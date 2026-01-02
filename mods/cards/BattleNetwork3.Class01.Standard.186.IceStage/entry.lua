---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local PANEL_CHANGE_SFX = bn_assets.load_audio("panel_change_indicate.ogg")
local PANEL_COMPLETE_SFX = bn_assets.load_audio("panel_change_finish.ogg")

---@param user Entity
function card_init(user)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())

	---@type Tile[]
	local tiles = {}

	local i = 0
	local step = action:create_step()
	local KEEP_FRAMES = 4
	local TOTAL = 16 * KEEP_FRAMES

	step.on_update_func = function()
		i = i + 1

		if math.floor(i / KEEP_FRAMES) % 2 == 0 then
			if i < TOTAL then
				-- update visual for flickering
				for _, tile in ipairs(tiles) do
					tile:set_visible_state(TileState.Ice)
				end
			else
				-- apply
				Resources.play_audio(PANEL_COMPLETE_SFX)
				step:complete_step()

				for _, tile in ipairs(tiles) do
					tile:set_state(TileState.Ice)
					tile:set_visible_state(nil)
				end
			end
		else
			-- clear visual for flickering
			for _, tile in ipairs(tiles) do
				tile:set_visible_state(nil)
			end
		end
	end

	action.on_execute_func = function()
		local SAMPLE_RATE = 44100
		Resources.play_audio(PANEL_CHANGE_SFX, AudioBehavior.LoopSection(0, SAMPLE_RATE / 60 * 4))

		tiles = Field.find_tiles(function(tile)
			return tile:can_set_state(TileState.Ice)
		end)
	end

	action.on_action_end_func = function()
		-- prevent the audio from looping forever
		Resources.play_audio(PANEL_CHANGE_SFX, AudioBehavior.EndLoop)
	end

	return action
end

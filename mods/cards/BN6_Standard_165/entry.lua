---@type BattleNetwork6.Libraries.PanelGrab
local PanelGrabLib = require("BattleNetwork6.Libraries.PanelGrab")

---@param user Entity
function card_init(user)
	local action = Action.new(user, "PLAYER_IDLE")
	action:override_animation_frames({ { 1, 1 } })
	action:set_lockout(ActionLockout.new_sequence())

	local i = 0
	local step = action:create_step()
	step.on_update_func = function()
		i = i + 1

		if i == 60 then
			step:complete_step()
		end
	end

	action.on_execute_func = function()
		local team = user:team()
		local direction = user:facing()

		local field = user:field()
		local x = user:current_tile():x()
		local found_opponent_panels = false

		local test_offset = 1

		if direction == Direction.Left then
			test_offset = -1
		end

		-- find opponent panels ahead of us
		while not found_opponent_panels do
			x = x + test_offset

			for y = 0, field:height() - 1 do
				local tile = field:tile_at(x, y)

				if not tile then
					-- reached out of bounds, give up
					return
				end

				if tile:team() ~= team and not tile:is_edge() then
					found_opponent_panels = true
					break
				end
			end
		end

		-- rewind to find area we've fully claimed, in case we're surrounded by opponent tiles
		while true do
			x = x - test_offset

			local has_opponent_panels = false

			for y = 0, field:height() - 1 do
				local tile = field:tile_at(x, y)

				if not tile then
					-- reached out of bounds, give up
					return
				end

				if tile:team() ~= team and not tile:is_edge() then
					has_opponent_panels = true
					break
				end
			end

			if not has_opponent_panels then
				-- no opponent panels in the column!
				break
			end
		end

		-- step forward once to get out of the area fully claimed by us
		x = x + test_offset

		-- spawn panel grab at every tile in the column
		for y = 0, field:height() - 1 do
			local tile = field:tile_at(x, y)

			if tile and not tile:is_edge() then
				local spell = PanelGrabLib.create_spell(team, direction)
				user:field():spawn(spell, tile)
			end
		end
	end

	return action
end

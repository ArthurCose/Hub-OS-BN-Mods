---@type BattleNetwork6.Libraries.PanelGrab
local PanelGrabLib = require("BattleNetwork6.Libraries.PanelGrab")

---@param user Entity
function card_init(user)
	local action = Action.new(user, "CHARACTER_IDLE")
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
		local tile = nil
		tile = user:current_tile()
		local direction = user:facing()

		while tile and tile:team() == team do
			local next_tile = tile:get_tile(direction, 1)
			tile = next_tile
		end

		if tile then
			local spell = PanelGrabLib.create_spell(team, direction)
			Field.spawn(spell, tile)
		end
	end

	return action
end

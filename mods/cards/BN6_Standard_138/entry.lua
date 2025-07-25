---@type BattleNetwork6.Libraries.CubesAndBoulders
local CubesAndBouldersLib = require("BattleNetwork6.Libraries.CubesAndBoulders")

local RockCube = CubesAndBouldersLib.new_rock_cube()
local sfx = Resources.load_audio("sfx.ogg")

function card_init(user, props)
	local action = Action.new(user, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function()
		Resources.play_audio(sfx)

		local cube = RockCube:create_obstacle()
		cube:set_owner(user:team())
		cube:set_facing(user:facing())
		local anim = cube:animation()
		anim:set_state("SPAWN")
		anim:apply(cube:sprite())
		anim:on_complete(function()
			local tile = cube:current_tile()
			if tile:is_walkable() then
				anim:set_state("ROCK")
				anim:apply(cube:sprite())
				anim:set_playback(Playback.Loop)
			else
				cube:delete()
			end
		end)

		local desired_tile = user:get_tile(user:facing(), 1)
		if desired_tile and not desired_tile:is_reserved() and desired_tile:is_walkable() then
			user:field():spawn(cube, desired_tile)
		end
	end

	return action
end

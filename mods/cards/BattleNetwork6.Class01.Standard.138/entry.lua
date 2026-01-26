---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork6.Libraries.CubesAndBoulders
local CubesAndBouldersLib = require("BattleNetwork6.Libraries.CubesAndBoulders")

local RockCube = CubesAndBouldersLib.new_rock_cube()
local SPAWN_SFX = bn_assets.load_audio("obstacle_spawn.ogg")

---@param user Entity
function card_init(user)
	local action = Action.new(user, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function()
		local desired_tile = user:get_tile(user:facing(), 1)

		if not desired_tile or desired_tile:is_reserved() or not desired_tile:is_walkable() then
			return
		end

		Resources.play_audio(SPAWN_SFX)

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

		Field.spawn(cube, desired_tile)
	end

	return action
end

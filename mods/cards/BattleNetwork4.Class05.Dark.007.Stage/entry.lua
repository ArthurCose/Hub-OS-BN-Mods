local bn_assets = require("BattleNetwork.Assets")
local hole_audio = bn_assets.load_audio("darkhole.ogg")

function card_mutate(user, card_index)
	if Player.from(user) == nil then return end

	user:boost_augment("BattleNetwork.Bugs.CustomDamageBug", 1)
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	action.on_execute_func = function(self, user)
		Resources.play_audio(hole_audio)

		local dark_holes = Field.find_tiles(function(tile)
			if tile:team() == user:team() then return true end
			return false
		end)

		local poison_tiles = Field.find_tiles(function(tile)
			if tile:team() ~= user:team() then return true end
			return false
		end)

		local cooldown = 30
		local step1 = self:create_step()

		for i = 1, #dark_holes, 1 do
			dark_holes[i]:set_state(TileState.Dark)
		end

		for i = 1, #poison_tiles, 1 do
			poison_tiles[i]:set_state(TileState.Dark)
		end

		step1.on_update_func = function(self)
			if cooldown > 0 then
				cooldown = cooldown - 1
			else
				self:complete_step()
			end
		end
	end
	return action
end

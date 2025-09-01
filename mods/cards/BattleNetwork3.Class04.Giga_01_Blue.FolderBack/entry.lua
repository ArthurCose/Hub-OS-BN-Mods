local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("folderbak_rumble.ogg")
local GAUGE_COMPLETE = bn_assets.load_audio("turn_gauge_forced.ogg")

local trackers = {}
local function folderback_initialize()
	local artifact = Artifact.new(Team.Other)

	local comp = artifact:create_component(Lifetime.Scene)

	artifact._delete_self = false

	artifact.on_update_func = function()
		if artifact._delete_self == true then artifact:delete() end
	end

	comp._delete_self = false
	comp.on_update_func = function(self)
		if self._delete_self then
			artifact._delete_self = true
			self:eject()
			return;
		end

		local players = Field.find_players(function() return true end)

		if #players > 0 then
			for i = 1, #players, 1 do
				local sprite = players[i]:sprite()
				local tracker = sprite:create_node()
				tracker:copy_from(sprite)

				tracker:hide()

				tracker._deck = players[i]:deck_cards()

				trackers[players[i]:id()] = tracker

				self._delete_self = true
			end
		end
	end

	Field.spawn(artifact, 0, 0)
end

function card_init(actor, props)
	local action = Action.new(actor)
	action:set_lockout(ActionLockout.new_sequence())

	local step = action:create_step()

	action.on_execute_func = function(self, user)
		local players = Field.find_players(function() return true end)

		Resources.play_audio(AUDIO)

		Field.shake(10, 120)

		TurnGauge.set_enabled(false)

		local health_drain = AuxProp.new()
			:drain_health(math.floor(user:max_health() / 4))
			:immediate()

		user:add_aux_prop(health_drain)

		for p = 1, #players, 1 do
			local player_id = players[p]:id()
			local tracker = trackers[player_id]
			if tracker ~= nil then
				for l = 1, #players[p]:deck_cards(), 1 do
					players[p]:remove_deck_card(l)
				end

				local shuffled = {}
				for i, v in ipairs(tracker._deck) do
					if v.package_id ~= "BattleNetwork3.Class04.Giga_01_Blue.FolderBack" then
						local pos = math.random(1, #shuffled + 1)
						table.insert(shuffled, pos, v)
					end
				end

				for c = 1, #shuffled, 1 do
					players[p]:insert_deck_card(c, shuffled[c])
				end
			end
		end

		local timer = 127
		step.on_update_func = function()
			if timer == 0 then
				Resources.play_audio(GAUGE_COMPLETE)

				TurnGauge.set_enabled(true)

				TurnGauge.complete_turn()

				step:complete_step()
				return
			end

			timer = timer - 1
		end
	end

	return action
end

folderback_initialize()

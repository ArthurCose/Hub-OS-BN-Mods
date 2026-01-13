local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("folderbak_rumble.ogg")
local GAUGE_COMPLETE = bn_assets.load_audio("turn_gauge_forced.ogg")

local decks = {}
local function folderback_initialize()
	local artifact = Artifact.new(Team.Other)

	local comp = artifact:create_component(Lifetime.Scene)

	local delete_self = false

	artifact.on_update_func = function()
		if delete_self == true then artifact:delete() end
	end

	comp.on_update_func = function(self)
		if delete_self == true then
			self:eject()
			return;
		end

		local players = Field.find_players(function() return true end)

		if #players > 0 then
			for i = 1, #players, 1 do
				local deck = players[i]:deck_cards()

				decks[players[i]:id()] = deck
			end

			delete_self = true
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

		for p = 1, #players, 1 do
			local player = players[p]
			local player_id = player:id()
			local tracker = decks[player_id]


			if tracker == nil then goto continue end

			while #player:deck_cards() > 0 do
				player:remove_deck_card(1)
			end

			local shuffled = {}
			for c = 1, #tracker, 1 do
				local card = tracker[c]
				if card.package_id == props.package_id then goto continue end

				local pos = math.random(1, #shuffled + 1)

				table.insert(shuffled, pos, card)

				::continue::
			end

			for c = 1, #shuffled, 1 do
				players[p]:insert_deck_card(c, shuffled[c])
			end

			::continue::
		end

		local drain_aux = AuxProp.new()
			:drain_health(math.min(user:health() - 1, 200))
			:immediate()
		user:add_aux_prop(drain_aux)

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

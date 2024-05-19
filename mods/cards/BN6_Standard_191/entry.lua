---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local PANEL_CHANGE_SFX = bn_assets.load_audio("panel_change_indicate.ogg")
local PANEL_COMPLETE_SFX = bn_assets.load_audio("break.ogg")
local POOF_COLOR = Color.new(240, 30, 210)

local function create_poof()
	local poof = bn_assets.ParticlePoof.new()
	local sprite = poof:sprite()
	sprite:set_layer(-5)

	poof.on_update_func = function()
		local offset = poof:offset()
		poof:set_offset(offset.x, offset.y - 2)

		sprite:set_color_mode(ColorMode.Multiply)
		sprite:set_color(POOF_COLOR)
	end

	return poof
end

function card_init(user)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())

	local field = user:field()
	local tracked_entities = {}
	local component
	local defense_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)
	local uninstalled = false

	local uninstall_all = function()
		if uninstalled then return end

		uninstalled = true

		user:remove_defense_rule(defense_rule)
		component:eject()

		for _, entity in pairs(tracked_entities) do
			if not entity:deleted() then
				entity:remove_aux_prop(entity._intercept_aux_prop)
			end
		end
	end

	---@param opponent Entity
	---@param opponent_action Action
	local function activate(opponent, opponent_action)
		local card = opponent_action:copy_card_properties()

		if card.recover <= 0 then
			return
		end

		-- create a new action to notify opponents about the trap
		local trap_action = Action.new(user, "PLAYER_IDLE")
		trap_action:set_lockout(ActionLockout.new_sequence())

		-- set display details
		local trap_action_props = CardProperties.new()
		trap_action_props.short_name = "AntiRecv"
		trap_action_props.time_freeze = true
		trap_action_props.prevent_time_freeze_counter = true
		trap_action:set_card_properties(trap_action_props)

		local i = 0
		local step = trap_action:create_step()
		local KEEP_FRAMES = 4
		local TOTAL = 16 * KEEP_FRAMES
		step.on_update_func = function()
			i = i + 1

			local tile = opponent:current_tile()

			if math.floor(i / KEEP_FRAMES) % 2 == 0 then
				tile:set_visible_state(TileState.Poison)

				if i >= TOTAL then
					step:complete_step()
					Resources.play_audio(PANEL_COMPLETE_SFX)
					tile:set_state(TileState.Poison)
				end
			else
				tile:set_visible_state(nil)
			end
		end

		trap_action.on_execute_func = function()
			local SAMPLE_RATE = 44100
			Resources.play_audio(PANEL_CHANGE_SFX, AudioBehavior.LoopSection(0, SAMPLE_RATE / 60 * 8))

			-- damage for the recovery amount and spawn artifact
			opponent:set_health(opponent:health() - card.recover)

			local poof_a = create_poof()
			local poof_b = create_poof()

			local tile = opponent:current_tile()

			poof_a:set_offset(-tile:width() * 0.5, 0)
			poof_b:set_offset(tile:width() * 0.5, 0)

			opponent:field():spawn(poof_a, tile)
			opponent:field():spawn(poof_b, tile)
		end

		trap_action.on_action_end_func = function()
			-- prevent the audio from looping forever
			Resources.play_audio(PANEL_CHANGE_SFX, AudioBehavior.EndLoop)
		end

		user:queue_action(trap_action)

		local alert_artifact = TrapAlert.new()
		local alert_sprite = alert_artifact:sprite()
		alert_sprite:set_never_flip(true)
		alert_sprite:set_offset(0, -opponent:height() / 2)
		alert_sprite:set_layer(-5)

		field:spawn(alert_artifact, opponent:current_tile())

		uninstall_all()
	end

	local track = function(opponent)
		if opponent:team() == user:team() then
			-- not an opponent
			return
		end

		if tracked_entities[opponent:id()] then
			return
		end

		local intercept_auxprop = AuxProp.new()
				:require_card_recover(Compare.GT, 0)
				:intercept_action(function(opponent_action)
					activate(opponent, opponent_action)
					return nil
				end)

		opponent:add_aux_prop(intercept_auxprop)
		opponent._intercept_aux_prop = intercept_auxprop

		tracked_entities[opponent:id()] = opponent
	end

	action.on_execute_func = function()
		component = user:create_component(Lifetime.Local)

		component.on_update_func = function()
			field:find_obstacles(track)
			field:find_characters(track)
		end

		defense_rule.on_replace_func = uninstall_all

		defense_rule.can_block_func = function(_, _, _, hit_props)
			if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
				uninstall_all()
			end
		end

		user:add_defense_rule(defense_rule)
	end

	return action
end

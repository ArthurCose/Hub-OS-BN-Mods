---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

function augment_init(augment)
	local player = augment:owner()

	-- Only works for players as only players can access the custom menu.
	if Player.from(player) == nil then return end

	local mood = 128

	local function create_mood_restoration_prop(action)
		local field = player:field()

		local list = field:find_characters(function(character)
			if Living.from(character) == nil then return false end
			if character:deleted() or character:will_erase_eof() then return false end
			if character:is_team(player:team()) then return false end
			if character:current_tile() == nil then return false end

			return true
		end)

		local hit_props = action:copy_card_properties()

		for _, character in ipairs(list) do
			local character_aux_prop = AuxProp.new()
				:require_hit_damage(Compare.EQ, hit_props.damage)
				:require_hit_flags(hit_props.hit_flags)
				:require_hit_element(hit_props.element)
				:once()
				:with_callback(function()
					mood = mood + 20
				end)

			character:add_aux_prop(character_aux_prop)
		end
	end

	-- Synchro Rings
	local synchro = EmotionsLib.new_synchro()
	synchro:set_ring_offset(0, -math.floor(player:height() / 2))
	synchro:implement(player)

	local synchro_state;
	local fear_state;
	local evil_state;
	for _, emotion in ipairs(player:emotions()) do
		if string.find(emotion, "SYNCHRO") then synchro_state = emotion end
		if string.find(emotion, "ANXIOUS") or string.find(emotion, "WORRIED") then fear_state = emotion end
		if string.find(emotion, "EVIL") or string.find(emotion, "DARK") then evil_state = emotion end
	end

	local become_evil = AuxProp.new()
		:require_action(ActionType.Card)
		:require_card_class(CardClass.Dark)
		:intercept_action(function(action)
			return action
		end)
		:with_callback(function()
			mood = 0
		end)
		:once()

	player:add_aux_prop(become_evil)

	local mood_damage = AuxProp.new()
		:require_hit_flags_absent(Hit.NoCounter)
		:require_hit_damage(Compare.GT, 0)
		:with_callback(function()
			if player:emotion() == evil_state then return end
			mood = math.max(1, mood - 10)
		end)

	player:add_aux_prop(mood_damage)

	local mood_damage_weak = AuxProp.new()
		:require_hit_flags(Hit.NoCounter)
		:require_hit_damage(Compare.GT, 0)
		:require_card_not_class(CardClass.Dark)
		:with_callback(function()
			if player:emotion() == evil_state then return end
			mood = math.max(1, mood - 3)
		end)

	player:add_aux_prop(mood_damage_weak)

	local mood_recovery = AuxProp.new()
		:require_card_recover(Compare.GT, 0)
		:require_action(ActionType.Card)
		:require_card_not_class(CardClass.Dark)
		:intercept_action(function(action)
			return action
		end)
		:with_callback(function()
			mood = math.min(254, mood + 30)
		end)

	player:add_aux_prop(mood_recovery)

	local mood_boost_card = AuxProp.new()
		:require_card_recover(Compare.EQ, 0)
		:require_action(ActionType.Card)
		:require_card_not_class(CardClass.Dark)
		:intercept_action(function(action)
			if player:emotion() == evil_state then return action end

			create_mood_restoration_prop(action)

			return action
		end)

	player:add_aux_prop(mood_boost_card)

	local karmic_tracker = player:create_component(Lifetime.Battle)
	karmic_tracker.on_update_func = function()
		if mood == 255 and synchro_state ~= nil then
			player:set_emotion(synchro_state)
		elseif mood > 0 and mood < 65 and fear_state ~= nil then
			player:set_emotion(fear_state)
		elseif mood <= 0 and evil_state ~= nil then
			player:set_emotion(evil_state)
		end
	end

	local chip_component = player:create_component(Lifetime.CardSelectOpen)

	local chip_list = {
		{ range = 0,  wound_range = 24, id = "BattleNetwork4.Class05.Dark.001.Cannon" },
		{ range = 12, wound_range = 27, id = "BattleNetwork4.Class05.Dark.002.Sword" },
		{ range = 24, wound_range = 30, id = "BattleNetwork4.Class05.Dark.003.Bomb" },
		{ range = 36, wound_range = 33, id = "BattleNetwork4.Class05.Dark.004.Vulcan" },
		{ range = 48, wound_range = 36, id = "BattleNetwork4.Class05.Dark.005.Lance" },
		{ range = 56, wound_range = 38, id = "BattleNetwork4.Class05.Dark.006.Spreader" },
		{ range = 64, wound_range = 40, id = "BattleNetwork4.Class05.Dark.007.Stage" },
		{ range = 0,  wound_range = 64, id = "BattleNetwork4.Class05.Dark.008.Recovery" },
	}

	local function get_random_chip(is_wounded)
		local number = math.random(1, 64)
		local chip;
		local range;

		for index, value in ipairs(chip_list) do
			if is_wounded then range = value.wound_range else range = value.range end
			if range == 0 then goto skip end
			if number <= range then
				chip = value.id
				break
			end
			::skip::
		end

		return chip
	end

	chip_component.on_update_func = function(self)
		if mood > 64 then return end

		local is_wounded = false
		if player:health() <= math.floor(player:max_health() / 2) then is_wounded = true end

		for i = 1, 2 do
			player:set_fixed_card(CardProperties.from_package(get_random_chip(is_wounded), " "), i)
		end
	end
end

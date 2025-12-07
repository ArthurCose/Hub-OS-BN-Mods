function augment_init(augment)
	local player = augment:owner()

	-- Only works for players as only players can access the custom menu.
	-- ...I don't remember why I added this check. Only players can install augments anyway.
	if Player.from(player) == nil then return end

	-- Set initial values
	player:remember("KARMA_VALUE", 128)

	local list = Field.find_characters(function(character)
		if Living.from(character) == nil then return false end
		if character:deleted() or character:will_erase_eof() then return false end
		if character:is_team(player:team()) then return false end
		if character:current_tile() == nil then return false end

		return true
	end)

	local karma_gain_props = {}

	local function create_mood_restore_prop(character)
		local character_aux_prop = AuxProp.new()
			:require_hit_damage(Compare.GT, 0)
			:require_hit_flags_absent(Hit.Drain)
			:intercept_action(function(action)
				local karma = player:recall("KARMA_VALUE")
				local props = action:copy_card_properties()
				local gain = math.max(1, math.floor(props.damage / 10))

				if player:recall("PAUSE_KARMA_GAIN") ~= true then player:remember("KARMA_VALUE", karma + gain) end

				return action
			end)

		character:add_aux_prop(character_aux_prop)

		return character_aux_prop
	end

	for _, character in ipairs(list) do
		karma_gain_props[character:id()] = create_mood_restore_prop(character)
	end

	-- Don't allow use of good-karma chips.
	local reject_good_embrace_evil = AuxProp.new()
		:require_card_tag("KARMA: GOOD")
		:require_action(ActionType.Card)
		:intercept_action(function(action)
			return nil
		end)

	local synchro_state;
	local fear_state;
	local evil_state;
	local normal_state;
	for _, emotion in ipairs(player:emotions()) do
		if string.find(emotion, "SYNCHRO") then synchro_state = emotion end
		if string.find(emotion, "ANXIOUS") or string.find(emotion, "WORRIED") then fear_state = emotion end
		if string.find(emotion, "EVIL") or string.find(emotion, "DARK") then evil_state = emotion end
		if string.find(emotion, "DEFAULT") or string.find(emotion, "NORMAL") then normal_state = emotion end
	end

	local become_evil = AuxProp.new()
		:require_action(ActionType.Card)
		:require_card_class(CardClass.Dark)
		:intercept_action(function(action)
			player:remember("KARMA_VALUE", 0)
			return action
		end)
		:once()

	local mood_damage = AuxProp.new()
		:require_hit_flags_absent(Hit.NoCounter)
		:require_hit_damage(Compare.GT, 0)
		:with_callback(function()
			if player:emotion() == evil_state then return end
			if player:recall("PAUSE_KARMA_LOSS") == true then return end
			local karma = player:recall("KARMA_VALUE")
			local new_karma = math.max(1, karma - 20)
			player:remember("KARMA_VALUE", math.max(0, new_karma))
		end)

	local synchro_karma_reset = AuxProp.new()
		:require_action(ActionType.Card)
		:require_emotion(synchro_state)
		:intercept_action(function(action)
			return action
		end)
		:with_callback(function()
			player:remember("KARMA_VALUE", 128)
		end)

	player:add_aux_prop(become_evil)
	player:add_aux_prop(reject_good_embrace_evil)
	player:add_aux_prop(mood_damage)
	player:add_aux_prop(synchro_karma_reset)

	local mood_recovery = AuxProp.new()
		:require_card_recover(Compare.GT, 0)
		:require_action(ActionType.Card)
		:require_card_not_class(CardClass.Dark)
		:intercept_action(function(action)
			if player:emotion() == evil_state then return action end
			if player:recall("PAUSE_KARMA_GAIN") == true then return action end
			local karma = player:recall("KARMA_VALUE")
			local gain = 0
			local props = action:copy_card_properties()

			if props.recover <= 30 then
				gain = 30
			elseif props.recover <= 80 then
				gain = 40
			elseif props.recover <= 300 then
				gain = 50
			else
				gain = 20
			end

			player:remember("KARMA_VALUE", math.min(255, karma + gain))
			return action
		end)

	player:add_aux_prop(mood_recovery)

	local karmic_tracker = player:create_component(Lifetime.Battle)
	karmic_tracker.on_update_func = function()
		local mood = player:recall("KARMA_VALUE")

		-- Exit fear/synchro as necesary
		if (fear_state ~= nil and mood > 64 and player:emotion() == fear_state) or (synchro_state ~= nil and mood < 255 and player:emotion() == synchro_state) then
			player:set_emotion(normal_state)
		end

		if mood == 255 and synchro_state ~= nil then
			-- Reset value to start
			player:remember("KARMA_VALUE", 128)

			-- Set synchro state
			player:set_emotion(synchro_state)
		elseif mood > 0 and mood < 65 and fear_state ~= nil then
			-- Set fear state
			player:set_emotion(fear_state)
		elseif mood == 0 and evil_state ~= nil then
			-- Permanent for rest of the fight.
			player:remember("PAUSE_KARMA_GAIN", 0)
			-- Set evil state
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

	local prior_chips = {}

	local function get_random_chip(is_wounded)
		local number = math.random(1, 64)
		local chip;
		local range;
		local attempts = 0

		-- Attempt to obey dark chip selection logic.
		while chip == nil and attempts < 10 do
			for index, value in ipairs(chip_list) do
				if is_wounded then range = value.wound_range else range = value.range end
				if range == 0 then goto skip end

				if #prior_chips > 0 then
					-- skip if it's one we just pulled within the last turn
					if value.id == prior_chips[1] or value.id == prior_chips[2] then goto skip end
				end

				if number <= range then chip = value.id end

				::skip::
			end

			number = math.random(1, 64)
			attempts = attempts + 1
		end

		-- If we failed to get a chip, then ignore previous logic and select a random one from the list.
		if chip == nil then chip = chip_list[math.random(#chip_list)].id end

		-- This check goes before the table.insert call because it would reset upon *reaching* two entries otherwise.
		-- By putting it here, it would happen on the *third* addition to the table - in other words, after you've gotten two.
		if #prior_chips == 2 then prior_chips = {} end
		table.insert(prior_chips, chip)

		return chip
	end

	chip_component.on_update_func = function(self)
		-- Temporarily disable dark chips in other mods.
		if player:recall("DISABLE_DARK_CHIP_SLOTS") == true then return end

		local mood = player:recall("KARMA_VALUE")
		if mood > 64 then return end

		local is_wounded = false
		if player:health() <= math.floor(player:max_health() / 2) then is_wounded = true end

		for i = 1, 2 do
			local id = nil
			while id == nil do
				id = get_random_chip(is_wounded)
			end

			player:set_fixed_card(CardProperties.from_package(id), i)
		end
	end

	augment.on_delete_func = function(self)
		-- Undo relevant values
		player:forget("KARMA_VALUE")
		player:forget("DISABLE_DARK_CHIP_SLOTS")
		player:forget("PAUSE_KARMA_GAIN")
		player:forget("PAUSE_KARMA_LOSS")

		-- Remove Components
		chip_component:eject()
		karmic_tracker:eject()

		-- Remove AuxProps
		player:remove_aux_prop(reject_good_embrace_evil)
		player:remove_aux_prop(mood_damage)
		player:remove_aux_prop(become_evil)
		player:remove_aux_prop(mood_recovery)
		player:remove_aux_prop(synchro_karma_reset)

		-- Remove feedback AuxProps from other entities
		for key, value in pairs(karma_gain_props) do
			local entity = Field.get_entity(key)

			if entity == nil then goto continue end
			if entity:deleted() or entity:will_erase_eof() then goto continue end

			entity:remove_aux_prop(value)

			::continue::
		end
	end
end

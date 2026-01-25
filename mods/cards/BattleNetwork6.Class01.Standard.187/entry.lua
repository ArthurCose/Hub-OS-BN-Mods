local bn_assets = require("BattleNetwork.Assets")
local explosion_texture = bn_assets.load_texture("bn6_hit_effects.png")
local explosion_animation_path = bn_assets.fetch_animation_path("bn6_hit_effects.animation")
-- local impact_audio = bn_assets.load_audio("hit_impact.ogg")
local aqua_audio = bn_assets.load_audio("bubbler.ogg")
local elec_audio = bn_assets.load_audio("elementman_thunder.ogg")
local fire_audio = bn_assets.load_audio("fireball.ogg")
local wood_audio = bn_assets.load_audio("grass.ogg")

function card_init(user, props)
	local action = Action.new(user)

	local field = user
	local component
	local defense_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)
	local uninstalled = false

	local uninstall_all = function()
		if uninstalled == true then return end

		uninstalled = true

		user:remove_defense_rule(defense_rule)
		component:eject()
	end

	defense_rule.defense_func = function(defense, _, _, hit_props)
		if defense:damage_blocked() then return end

		if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
			uninstall_all()
		end
	end

	local create_boom = function(user, element, secondary_element, is_first)
		local state
		local sound

		if element == Element.Fire or secondary_element == Element.Fire then
			state = "FIRE"
			sound = fire_audio
		elseif element == Element.Wood or secondary_element == Element.Wood then
			state = "WOOD"
			sound = wood_audio
		elseif element == Element.Elec or secondary_element == Element.Elec then
			state = "ELEC"
			sound = elec_audio
		elseif element == Element.Aqua or secondary_element == Element.Aqua then
			state = "AQUA"
			sound = aqua_audio
		else
			state = "PEASHOT"
			-- sound = impact_audio
		end

		local spell = Spell.new(user:team())

		spell:set_texture(explosion_texture)
		spell:set_facing(user:facing())

		if is_first == true then
			if state == "ELEC" then
				props.hit_flags = props.hit_flags & ~Hit.mutual_exclusions_for(Hit.Paralyze) | Hit.Paralyze
				props.status_durations[Hit.Paralyze] = 90
			elseif state == "WOOD" then
				props.hit_flags = props.hit_flags & ~Hit.mutual_exclusions_for(Hit.Confuse) | Hit.Confuse
				props.status_durations[Hit.Confuse] = Hit.duration_for(Hit.Confuse, 1)
			elseif state == "FIRE" or state == "AQUA" then
				props.hit_flags = props.hit_flags & ~Hit.mutual_exclusions_for(Hit.Flash) | Hit.Flash
			end

			spell:set_hit_props(
				HitProps.new(
					props.damage,
					props.hit_flags,
					element,
					secondary_element
				)
			)
		end

		spell.on_update_func = function(self)
			if is_first == true then
				local targets_list = Field.find_entities(function(target)
					-- Must meet these criteria:
					-- is "Living" type
					-- Hitbox is enabled
					-- Health > 0
					-- Is currently on the field
					-- Has not been deleted
					if not target:hittable() then return false end

					-- No friendly fire.
					if target:team() == user:team() then return false end

					-- Must be a character (virus, boss, player) or Obstacle (e.g. rock cube) to count
					return Character.from(target) ~= nil or Obstacle.from(target) ~= nil
				end)

				if #targets_list == 0 then return end

				for t = 1, #targets_list, 1 do
					self:attack_tile(targets_list[t]:current_tile())
				end
			end
		end

		local anim = spell:animation()
		anim:load(explosion_animation_path)
		anim:set_state(state)

		anim:on_complete(function()
			if not spell:deleted() then spell:delete() end
		end)

		spell.on_collision_func = function(self, other)
			if not spell:deleted() then spell:delete() end
		end

		spell.can_move_to_func = function(self)
			return true
		end

		spell.on_spawn_func = function()
			if is_first == false then return end
			Resources.play_audio(sound)
		end

		spell.on_delete_func = function(self)
			self:erase()
		end

		return spell
	end

	local find_spells = function()
		return Field.find_spells(
			function(entity)
				if entity:team() == user:team() then return false end

				local spell_props = entity:copy_hit_props()

				if spell_props.damage == 0 then return false end

				local element = spell_props.element
				local secondary_element = spell_props.secondary_element

				if element == Element.Fire or
						element == Element.Elec or
						element == Element.Aqua or
						element == Element.Wood or
						secondary_element == Element.Fire or
						secondary_element == Element.Elec or
						secondary_element == Element.Aqua or
						secondary_element == Element.Wood then
					return true
				end

				return false
			end
		)
	end

	local activate =
			function(found_entity, element, secondary_element)
				-- create a new action to notify opponents about ElemTrap
				local wrapped_action = Action.new(user, "CHARACTER_IDLE")

				-- never complete, force the generated_action to kick us out
				wrapped_action:set_lockout(ActionLockout.new_sequence())

				local wrapped_action_props = CardProperties.new()
				wrapped_action_props.short_name = "ElemTrap"
				wrapped_action_props.time_freeze = true
				wrapped_action_props.prevent_time_freeze_counter = true
				wrapped_action:set_card_properties(wrapped_action_props)

				wrapped_action.on_execute_func = function(self)
					local step1 = self:create_step()
					local tile_list = Field.find_tiles(function(tile)
						return not tile:is_edge()
					end)

					local shuffled = {}

					for i, v in ipairs(tile_list) do
						local pos = math.random(1, #shuffled + 1)
						table.insert(shuffled, pos, v)
					end

					local cooldown = 4

					local k = 1
					step1.on_update_func = function(self)
						cooldown = cooldown - 1

						if k >= #shuffled then
							self:complete_step()
							return
						end

						if cooldown == 0 then
							local explosion_tile = shuffled[k]

							Field.spawn(create_boom(user, element, secondary_element, k == 1), explosion_tile)

							cooldown = 4

							k = k + 1
						end
					end
				end

				user:queue_action(wrapped_action)

				local alert_artifact = TrapAlert.new()
				local alert_sprite = alert_artifact:sprite()
				alert_sprite:set_never_flip(true)

				alert_artifact:set_elevation(found_entity:height() / 2)

				alert_sprite:set_layer(-5)

				Field.spawn(alert_artifact, found_entity:current_tile())
			end

	action.on_execute_func = function()
		local attack_list = find_spells()

		-- Can't activate if it would trigger immediately.
		if #attack_list > 0 then return end

		component = user:create_component(Lifetime.ActiveBattle)

		component.on_update_func = function()
			attack_list = find_spells()

			if #attack_list > 0 then
				local copy_props = attack_list[1]:copy_hit_props()
				activate(attack_list[1], copy_props.element, copy_props.secondary_element)
				uninstall_all()
			end
		end

		defense_rule.on_replace_func = uninstall_all
		user:add_defense_rule(defense_rule)
	end

	return action
end

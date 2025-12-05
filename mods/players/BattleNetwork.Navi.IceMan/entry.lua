function player_init(player)
	player:set_name("IceMan")

	player:set_height(33.0)

	local base_texture = Resources.load_texture("battle.png")
	local base_animation_path = "battle.animation"
	local base_charge_color = Color.new(0, 200, 255, 255)

	player:load_animation(base_animation_path)
	player:set_texture(base_texture)
	player:set_fully_charged_color(base_charge_color)
	player:set_charge_position(0, -10)

	player.calculate_charge_time = function()
		local level = player:charge_level()
		return math.max(90, (140 - (level * 10)));
	end

	player.normal_attack_func = function(player)
		return Buster.new(player, false, player:attack_level())
	end

	player.charged_attack_func = function(self)
		local card_properties = CardProperties.from_package("dev.GladeWoodsgrove.Chips.FrostBomb")
		card_properties.damage = player:attack_level() * 10

		return Action.from_card(self, card_properties)
	end

	local snowman_spawned = false

	player.special_attack_func = function()
		if not snowman_spawned then
			local action = Action.new(player, "CHARACTER_SPECIAL")

			action.on_execute_func = function(self, user)
				local tile = user:get_tile(user:facing(), 1)

				local query = function(ent)
					return Character.from(ent) ~= nil and ent:hittable()
				end

				if tile and tile:is_walkable() and #tile:find_entities(query) <= 0 then
					local snowman = Obstacle.new(Team.Other)

					snowman:set_texture(base_texture)
					snowman:set_facing(user:facing())

					snowman:set_hit_props(
						HitProps.new(
							100,
							Hit.Flinch | Hit.Flash | Hit.Drag,
							Element.Aqua,
							user:context(),
							Drag.new(snowman:facing(), 1)
						)
					)

					local enemy_aux = StandardEnemyAux.new()

					snowman:add_aux_prop(enemy_aux)

					local snow_defense = DefenseRule.new(DefensePriority.Body, DefenseOrder.Always)

					snow_defense.filter_func = function(hit_props)
						hit_props.flags = hit_props.flags & ~Hit.Flinch
						hit_props.flags = hit_props.flags & ~Hit.Flash
						hit_props.flags = hit_props.flags & ~Hit.Freeze
						hit_props.flags = hit_props.flags & ~Hit.Paralyze
						hit_props.flags = hit_props.flags & ~Hit.Root
						hit_props.flags = hit_props.flags & ~Hit.Blind
						hit_props.flags = hit_props.flags & ~Hit.Confuse

						return hit_props
					end

					snowman:add_defense_rule(snow_defense)

					local animation = snowman:animation()
					animation:load(base_animation_path)
					animation:set_state("SNOWMAN_APPEAR")

					snowman:set_health(50)
					snowman:set_name("Snowman")

					animation:on_complete(function()
						animation:set_state("SNOWMAN_IDLE")
						animation:set_playback(Playback.Loop)
					end)

					snowman.on_spawn_func = function()
						snowman_spawned = true
					end

					snowman.on_update_func = function(self)
						local own_tile = self:current_tile()
						if not own_tile or own_tile and not own_tile:is_walkable() then
							self:delete()
							return
						end

						own_tile:attack_entities(self)
					end

					snowman.on_collision_func = function(self)
						self:delete()
					end

					snowman.on_delete_func = function(self)
						snowman_spawned = false
						self:default_character_delete()
					end

					snowman.can_move_to_func = function()
						return true
					end

					Field.spawn(snowman, tile)
				end
			end
			return action
		else
			local action = Action.new(player, "CHARACTER_KICK")
			action.on_execute_func = function(self, user)
				self:on_anim_frame(3, function()
					local hit_props = HitProps.new(
						10,
						Hit.Drag,
						Element.None,
						player:context(),
						Drag.new(user:facing(), 1)
					)

					local tile = user:get_tile(user:facing(), 1)
					self._spell = Spell.new(user:team())

					self._spell:set_hit_props(hit_props)

					self._spell._should_erase = false

					self._spell.on_update_func = function()
						if self._spell._should_erase == true then
							self._spell:erase()
						end

						self._spell:attack_tile(self._spell:current_tile())
					end

					self._spell.on_collision_func = function()
						self._spell:erase()
					end


					Field.spawn(self._spell, tile)
				end)

				action.on_animation_end_func = function()
					if self._spell ~= nil and not self._spell:deleted() then self._spell:erase() end
				end
			end
			return action
		end
	end
end

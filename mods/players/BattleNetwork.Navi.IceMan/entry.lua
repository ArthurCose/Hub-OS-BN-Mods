local bn_assets = require("BattleNetwork.Assets")
local snowman_texture = bn_assets.load_texture("snowman.png")
local navi_texture = bn_assets.load_texture("navi_iceman.png")

local snowman_anim_path = bn_assets.fetch_animation_path("snowman.animation")
local navi_animation_path = bn_assets.fetch_animation_path("navi_iceman.animation")

function player_init(player)
	player:set_name("IceMan")

	player:set_height(33.0)

	local base_charge_color = Color.new(0, 200, 255, 255)

	player:load_animation(navi_animation_path)
	player:set_texture(navi_texture)
	player:set_fully_charged_color(base_charge_color)
	player:set_charge_position(0, -10)

	local ice_panel_aux = AuxProp.new()
		:require_tile_state(TileState.Ice)
		:require_card_damage(Compare.GT, 0)
		:increase_card_damage(10)
		:with_callback(function()
			local tile = player:current_tile()
			local component = player:create_component(Lifetime.ActiveBattle)
			local timer = 5
			component.on_update_func = function(self)
				timer = timer - 1
				if timer > 0 then return end
				tile:set_state(TileState.Normal)
				self:eject()
			end
		end)

	local sea_panel_aux = AuxProp.new()
		:require_tile_state(TileState.Sea)
		:require_card_damage(Compare.GT, 0)
		:increase_card_damage(10)
		:with_callback(function()
			local tile = player:current_tile()
			local component = player:create_component(Lifetime.ActiveBattle)
			local timer = 5
			component.on_update_func = function(self)
				timer = timer - 1
				if timer > 0 then return end
				tile:set_state(TileState.Normal)
				self:eject()
			end
		end)

	player:add_aux_prop(ice_panel_aux)
	player:add_aux_prop(sea_panel_aux)

	player.normal_attack_func = function(player)
		return Buster.new(player, false, player:attack_level())
	end

	player.charged_attack_func = function(self)
		local props = CardProperties.from_package("NetworkTransmission.Chip052.IceSlasher")
		props.damage = (player:attack_level() * 20) + 20

		return Action.from_card(self, props)
	end

	player.calculate_card_charge_time_func = function(self, card_properties)
		if card_properties.time_freeze == true then return end
		if card_properties.element ~= Element.Aqua and card_properties.secondary_element ~= Element.Aqua then return end
		if card_properties.damage == 0 then return end

		return 100 - (2 * player:charge_level())
	end

	player.charged_card_func = function(self, card_properties)
		local props = CardProperties.from_package("BattleNetwork2.Chip.252.FreezBom")
		props.damage = math.min(100, math.ceil(card_properties.damage / 2))

		local start_tile = self:current_tile():get_tile(self:facing(), 3)
		local tiles = {
			start_tile
		}

		for x = -1, 1, 1 do
			for y = -1, 1, 1 do
				if math.abs(x) == math.abs(y) then goto continue end

				local tile = Field.tile_at(start_tile:x() + x, start_tile:y() + y)
				if tile == nil or tile:is_walkable() == false then goto continue end

				table.insert(tiles, tile)

				::continue::
			end
		end

		local action = Action.from_card(self, props)
		action:on_end(function()
			local component = player:create_component(Lifetime.ActiveBattle)
			local timer = 45
			component.on_update_func = function(self)
				timer = timer - 1
				if timer > 0 then return end
				for i = 1, #tiles, 1 do
					tiles[i]:set_state(TileState.Ice)
				end
				self:eject()
			end
		end)

		return action
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

					snowman:set_texture(snowman_texture)
					snowman:set_facing(user:facing())

					snowman:add_aux_prop(AuxProp.new():declare_immunity(~Hit.Drag))

					snowman:set_hit_props(
						HitProps.new(
							100,
							Hit.Flinch | Hit.Flash | Hit.Drag,
							Element.Aqua,
							user:context(),
							Drag.new(snowman:facing(), 1)
						)
					)

					local animation = snowman:animation()
					animation:load(snowman_anim_path)
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
						self:erase()
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

local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = Resources.load_texture("Anubis.png")

local LANDING_AUDIO = bn_assets.load_audio("gaia_hammer.ogg")

local DRAIN_RATE = 6


function card_init(actor, props)
	local action = Action.new(actor)
	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function(self, user)
		local spawn_tile = user:get_tile(user:facing(), 1)

		if not spawn_tile then
			action:end_action()
			return
		end

		local anubis = Obstacle.new(Team.Other)
		anubis:set_facing(user:facing())
		anubis:set_texture(TEXTURE)
		anubis:sprite():set_layer(-1)

		local anim = anubis:animation()
		anim:load("Anubis.animation")
		anim:set_state("ANUBIS")
		anim:set_playback(Playback.Loop)

		anubis:set_health(100)
		anubis:set_elevation(104)

		local anubis_aux = AuxProp:new():declare_immunity(~0)
		anubis:add_aux_prop(anubis_aux)

		local step = action:create_step()
		step.on_update_func = function()
			if anubis:elevation() > 0 then return end

			anubis:set_owner(user)

			step:complete_step()
		end

		-- define anubis collision hitprops
		local hit_props = HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)

		anubis:set_hit_props(hit_props)

		anubis.on_collision_func = function(self, other)
			other:apply_status(Hit.PoisonLDR, 1210)
			anubis:delete()
		end

		-- Can't move it, too heavy.
		anubis.can_move_to_func = function() return false end

		local shake = true
		local auxprop_array = {}
		local enemy_poisoned = {}

		local enemies = Field.find_characters(function(entity)
			if entity:team() ~= user:team() then
				auxprop_array[#auxprop_array + 1] = AuxProp.new()
					:drain_health(1)
					:require_interval(DRAIN_RATE)
				enemy_poisoned[#enemy_poisoned + 1] = false
				return true
			end
			return false
		end)

		local timer = 3000
		local smoke_spawned = false

		anubis.on_update_func = function(self)
			timer = timer - 1
			if timer <= 0 then
				anubis:delete()
				return
			end

			if self:elevation() > 0 then
				self:set_elevation(self:elevation() - 8)
				return
			end

			local current_tile = anubis:current_tile()
			if not current_tile then
				anubis:delete()
				return
			end
			if not current_tile:is_walkable() then
				anubis:delete()
				return
			end

			current_tile:attack_entities(anubis)

			local poisoned_tiles = {}

			for i = 0, Field.width() - 1, 1 do
				for j = 0, Field.height() - 1, 1 do
					local tile = Field.tile_at(i, j)

					if tile and tile:team() ~= user:team() and tile:is_edge() == false then
						poisoned_tiles[#poisoned_tiles + 1] = tile
					end
				end
			end

			Field.find_characters(function(entity)
				if entity:team() ~= user:team() then
					for _, enemy in ipairs(enemies) do
						if entity:id() == enemy:id() then
							return false
						end
					end
					auxprop_array[#auxprop_array + 1] = AuxProp.new()
						:drain_health(1)
						:require_interval(DRAIN_RATE)
					enemy_poisoned[#enemy_poisoned + 1] = false
					enemies[#enemies + 1] = entity
				end

				return false
			end)

			for i = #enemies, 1, -1 do
				local enemy = enemies[i]

				if enemy:deleted() then
					table.remove(enemies, i)
					table.remove(auxprop_array, i)
					table.remove(enemy_poisoned, i)
					goto continue
				end

				if enemy:current_tile():team() ~= user:team() and not enemy_poisoned[i] then
					enemy:add_aux_prop(auxprop_array[i])
					enemy_poisoned[i] = true
				else
					if enemy_poisoned[i] and enemy:current_tile():team() == user:team() then
						enemy_poisoned[i] = false
						enemy:remove_aux_prop(auxprop_array[i])
					end
				end

				::continue::
			end

			if smoke_spawned == false then
				local smoke = Poof.new(user:team())
				local smoke_sprite = smoke:sprite()
				local smoke_animation = smoke:animation()
				smoke_sprite:set_texture(Resources.load_texture("AnubisSmoke.png"))
				smoke_animation:load("AnubisSmoke.animation")
				smoke_animation:set_state("SMOKE")
				smoke_animation:set_playback(Playback.Once)

				smoke_animation:on_complete(function()
					smoke:erase()
					smoke_spawned = false
				end)

				local enemy_tiles = {}

				for x = 0, Field.width() - 1, 1 do
					for y = 0, Field.height() - 1, 1 do
						local tile = Field.tile_at(x, y)

						if tile and tile:team() ~= user:team() and not tile:is_edge() and
							tile ~= self:current_tile() then
							enemy_tiles[#enemy_tiles + 1] = tile
						end
					end
				end

				local random_index = math.random(1, #enemy_tiles)
				Field.spawn(smoke, enemy_tiles[random_index])
				smoke_spawned = true
			end

			if shake then
				Field.shake(8, 30)
				Resources.play_audio(LANDING_AUDIO)

				shake = false
			end
		end

		anubis.on_delete_func = function(self)
			for i, enemy in ipairs(enemies) do
				if not enemy:deleted() then
					enemy:remove_aux_prop(auxprop_array[i])
				end
			end

			local fx = Explosion.new()

			local fx_anim = fx:animation()

			fx_anim:on_complete(function()
				fx:erase()
			end)

			fx:sprite():set_layer(-2)
			Field.spawn(fx, self:current_tile())

			anubis:erase()
		end

		Field.spawn(anubis, spawn_tile)
	end

	return action
end

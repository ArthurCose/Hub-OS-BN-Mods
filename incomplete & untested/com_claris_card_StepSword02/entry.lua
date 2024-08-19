function card_init(actor, props)
	local alt_action = Action.new(actor, "PLAYER_IDLE")
	--Override the alternate idle action to be very fast so the user can keep playing on a failed chip use.
	alt_action:override_animation_frames({ { 1, 1 } })
	local original_tile = actor:current_tile()
	local desired_tile = actor:get_tile(actor:facing(), 2)
	local original_team = actor:team()
	local temp_super_armor = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
	temp_super_armor.filter_func = function(statuses)
		statuses.flags = statuses.flags & ~Hit.Flinch
		return statuses
	end
	local entity_check = function(e)
		if e and not e:hittable() then return false end
		return Obstacle.from(e) ~= nil or Character.from(e) ~= nil or Player.from(e) ~= nil
	end
	if desired_tile and not desired_tile:is_edge() and desired_tile:is_walkable() then
		alt_action.on_execute_func = function(self, user)
			if desired_tile and not desired_tile:is_edge() and desired_tile:is_walkable() then
				actor:add_defense_rule(temp_super_armor)
				desired_tile:reserve_for_id(user:id())
				user:set_team(Team.Other)
			end
		end
		alt_action.on_animation_end_func = function(self)
			actor:teleport(desired_tile, function()
				local action = Action.new(actor, "PLAYER_SWORD")
				action:set_lockout(ActionLockout.new_animation())
				local SLASH_TEXTURE = Resources.load_texture("spell_sword_slashes.png")
				local BLADE_TEXTURE = Resources.load_texture("spell_sword_blades.png")
				action.on_action_end_func = function(self)
					actor:remove_defense_rule(temp_super_armor)
					actor:teleport(original_tile, nil)
				end
				action.on_execute_func = function(self, user)
					actor:set_team(original_team)
					self:add_anim_action(2, function()
						local hilt = self:create_attachment("HILT")
						local hilt_sprite = hilt:sprite()
						hilt_sprite:set_texture(actor:texture())
						hilt_sprite:set_layer(-2)
						hilt_sprite:use_root_shader(true)

						local hilt_anim = hilt:animation()
						hilt_anim:copy_from(actor:animation())
						hilt_anim:set_state("HILT")

						local blade = hilt:create_attachment("ENDPOINT")
						local blade_sprite = blade:sprite()
						blade_sprite:set_texture(BLADE_TEXTURE)
						blade_sprite:set_layer(-1)

						local blade_anim = blade:animation()
						blade_anim:load("spell_sword_blades.animation")
						blade_anim:set_state("DEFAULT")
					end)

					local field = user:field()
					self:add_anim_action(3, function()
						local sword = create_slash(user, props)
						local tile = user:get_tile(user:facing(), 1)
						local fx = Artifact.new()
						fx:set_facing(sword:facing())
						local anim = fx:animation()
						fx:set_texture(SLASH_TEXTURE, true)
						anim:load("spell_sword_slashes.animation")
						anim:set_state("CROSS")
						anim:on_complete(function()
							fx:erase()
							if not sword:deleted() then sword:delete() end
						end)
						field:spawn(sword, tile)
						field:spawn(fx, tile)
					end)
				end
				actor:queue_action(action)
			end)
		end
	end
	return alt_action
end

function create_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)
	local attack_once = true
	local field = user:field()
	local facing = user:facing()
	local facing_away = user:facing_away()
	spell.on_update_func = function(self)
		local tile = spell:current_tile()
		local tile_next = tile:get_tile(Direction.join(facing, Direction.Up), 1)
		local tile_next_two = tile:get_tile(Direction.join(facing, Direction.Down), 1)
		local tile_back = tile:get_tile(Direction.join(facing_away, Direction.Up), 1)
		local tile_back_two = tile:get_tile(Direction.join(facing_away, Direction.Down), 1)
		if tile_next and not tile_next:is_edge() then
			tile_next:set_highlight(Highlight.Flash)
		end
		if tile_next_two and not tile_next_two:is_edge() then
			tile_next_two:set_highlight(Highlight.Flash)
		end
		if tile_back and not tile_back:is_edge() then
			tile_back:set_highlight(Highlight.Flash)
		end
		if tile_back_two and not tile_back_two:is_edge() then
			tile_back_two:set_highlight(Highlight.Flash)
		end
		if attack_once then
			if tile and not tile:is_edge() then
				local hitbox_c = SharedHitbox.new(self, 12)
				hitbox_c:set_hit_props(self:copy_hit_props())
				field:spawn(hitbox_c, tile)
			end
			if tile_next and not tile_next:is_edge() then
				local hitbox_r = SharedHitbox.new(self, 12)
				hitbox_r:set_hit_props(self:copy_hit_props())
				field:spawn(hitbox_r, tile_next)
			end
			if tile_next_two and not tile_next_two:is_edge() then
				local hitbox_l = SharedHitbox.new(self, 12)
				hitbox_l:set_hit_props(self:copy_hit_props())
				field:spawn(hitbox_l, tile_next_two)
			end
			if tile_back and not tile_back:is_edge() then
				local hitbox_u = SharedHitbox.new(self, 12)
				hitbox_u:set_hit_props(self:copy_hit_props())
				field:spawn(hitbox_u, tile_back)
			end
			if tile_back_two and not tile_back_two:is_edge() then
				local hitbox_d = SharedHitbox.new(self, 12)
				hitbox_d:set_hit_props(self:copy_hit_props())
				field:spawn(hitbox_d, tile_back_two)
			end
			attack_once = false
		end
		tile:attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end
	local AUDIO = Resources.load_audio("sfx.ogg")
	Resources.play_audio(AUDIO)

	return spell
end

function card_init(actor, props)
	local TEXTURE = Resources.load_texture("elecpulse.png")
	local FRAMES = { { 1, 1.032 } }
	local audio = Resources.load_audio("sfx.ogg")
	local action = Action.new(actor, "PLAYER_SHOOTING")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())

	local pulse = create_pulse(actor, props, audio)
	action.animate_component = nil
	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(TEXTURE, true)
		buster_sprite:set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:load("elecpulse.animation")
		buster_anim:set_state("WAIT")
		buster_anim:apply(buster_sprite)
		buster_anim:on_complete(function()
			buster_anim:set_state("DISH")
			buster_anim:set_playback(Playback.Loop)
		end)

		local pulse_visual = buster_sprite:create_node()
		pulse_visual:set_texture(TEXTURE)
		pulse_visual:set_layer(-2)
		local pulse_anim = Animation.new("elecpulse.animation")
		pulse_anim:set_state("PULSE 3")
		pulse_anim:apply(pulse_visual)
		pulse_anim:set_playback(Playback.Loop)
		self.animate_component = user:create_component(Lifetime.Battle)
		self.animate_component.count = 0
		local ref = self
		self.animate_component.on_update_func = function(self)
			self.count = self.count + 1
			if self.count >= 1.032 then
				ref.animate_component = nil
				self:eject()
				return
			end
			pulse_anim:update(pulse_visual)
		end
		local tile = user:get_tile(user:facing(), 1)
		actor:field():spawn(pulse, tile)
	end
	action.on_action_end_func = function(self)
		if self.animate_component ~= nil then self.animate_component:eject() end
	end
	return action
end

function create_pulse(user, props, audio)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	local direction = user:facing()
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceInvis,
			props.element,
			user:context(),
			Drag.new(Direction.reverse(direction), 1)
		)
	)
	local tile, tile1, tile2, tile3
	local function define_tiles(spell, tile, tile1, tile2, tile3)
		tile = spell:current_tile()
		tile1 = tile:get_tile(direction, 1)
		tile2 = tile1:get_tile(Direction.Up, 1)
		tile3 = tile1:get_tile(Direction.Down, 1)
		return tile, tile1, tile2, tile3
	end
	local field = user:field()
	local spell_time = 60 -- Lifetime. of the hitboxes in frames
	local attacking = true
	local start_delay = 1
	local delayed_loop
	local spawn_hitboxes = true
	local hitbox_1 = SharedHitbox.new(spell, 1)
	hitbox_1:set_hit_props(spell:copy_hit_props())
	local hitbox_2 = SharedHitbox.new(spell, 1)
	hitbox_2:set_hit_props(spell:copy_hit_props())
	local hitbox_3 = SharedHitbox.new(spell, 1)
	hitbox_3:set_hit_props(spell:copy_hit_props())
	spell.on_update_func = function(self)
		if start_delay then
			start_delay = start_delay - 1
			if start_delay < 0 then
				delayed_loop = true
				start_delay = nil
				tile, tile1, tile2, tile3 = define_tiles(spell, tile, tile1, tile2, tile3)
			end
		end
		if delayed_loop then
			if tile and attacking then
				tile:attack_entities(self)
				tile:set_highlight(Highlight.Solid)
			end
			if tile1 and attacking then
				tile1:set_highlight(Highlight.Solid)
			end
			if tile2 and attacking then
				tile2:set_highlight(Highlight.Solid)
			end
			if tile3 and attacking then
				tile3:set_highlight(Highlight.Solid)
			end
			if spawn_hitboxes then
				if tile1 then
					field:spawn(hitbox_1, tile1)
				end
				if tile2 then
					field:spawn(hitbox_2, tile2)
				end
				if tile3 then
					field:spawn(hitbox_3, tile3)
				end
				spawn_hitboxes = false
			end
			spell_time = spell_time - 1
			if spell_time <= 0 then
				self:delete()
			end
		end
	end
	local function turn_off_hitboxes(spell1)
		attacking = false
		if not spell1:deleted() then spell1:erase() end
	end
	spell.on_collision_func = function(self, other)
		turn_off_hitboxes(self)
	end
	spell.on_attack_func = function(self, other)
		turn_off_hitboxes(self)
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end
	Resources.play_audio(AUDIO)
	return spell
end

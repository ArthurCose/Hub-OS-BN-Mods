local TEXTURE = Resources.load_texture("Moonblade.png")
local AUDIO = Resources.load_audio("sfx.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SWING")

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local tile = user:current_tile()
		local slash = nil

		self:add_anim_action(3,
			function()
				local hilt = self:create_attachment("HILT")
				local hilt_sprite = hilt:sprite()
				hilt_sprite:set_texture(actor:texture())
				hilt_sprite:set_layer(-2)
				hilt_sprite:use_root_shader(true)

				local hilt_anim = hilt:animation()
				hilt_anim:copy_from(actor:animation())
				hilt_anim:set_state("HAND")
			end
		)

		if slash == nil then
			self:add_anim_action(3,
				function()
					slash = create_slash("DEFAULT", user, props)
					actor:field():spawn(slash, tile)
				end
			)
		end
	end
	return action
end

function create_slash(animation_state, user, props)
	local spell = Spell.new(user:team())
	spell:set_texture(TEXTURE, true)
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Sword,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	anim:load("Moonblade.animation")
	anim:set_state(animation_state)
	spell:animation():on_complete(
		function()
			spell:erase()
		end
	)
	spell.on_update_func = function(self)
		if self:current_tile():get_tile(Direction.UpLeft, 1) then
			self:current_tile():get_tile(Direction.UpLeft, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.UpLeft, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.Up, 1) then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.UpRight, 1) then
			self:current_tile():get_tile(Direction.UpRight, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.UpRight, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.Right, 1) then
			self:current_tile():get_tile(Direction.Right, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Right, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.Left, 1) then
			self:current_tile():get_tile(Direction.Left, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Left, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.DownLeft, 1) then
			self:current_tile():get_tile(Direction.DownLeft, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.DownLeft, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.Down, 1) then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		if self:current_tile():get_tile(Direction.DownRight, 1) then
			self:current_tile():get_tile(Direction.DownRight, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.DownRight, 1):attack_entities(self)
		end
	end
	spell.on_collision_func = function(self, other)
	end
	spell.on_attack_func = function(self, other)
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

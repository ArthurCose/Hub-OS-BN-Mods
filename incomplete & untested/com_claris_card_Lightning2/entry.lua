local TEXTURE = Resources.load_texture("Lightning Cross.png")

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_HIT")
	local FRAME1 = { 2, 45 }
	local long_frame = { FRAME1 }
	action:override_animation_frames(long_frame)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local field = user:field()
		local targets = field:find_obstacles(function(found)
			if found ~= nil and user:team() ~= found:team() then
				return true
			end
		end)
		local tile = nil
		local spell = nil
		for i = 1, #targets, 1 do
			tile = targets[i]:current_tile()
			spell = create_bolt(user, props)
			field:spawn(spell, tile)
		end
	end
	return action
end

function create_bolt(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Solid)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	spell:set_texture(TEXTURE, true)
	anim:load("Lightning Cross.animation")
	anim:set_state("DEFAULT")
	anim:apply(spell:sprite())
	anim:on_complete(function()
		spell:erase()
	end)
	local do_once = true
	spell.on_update_func = function(self)
		self:get_tile(Direction.Up, 1):set_highlight(Highlight.Solid)
		self:get_tile(Direction.Left, 1):set_highlight(Highlight.Solid)
		self:get_tile(Direction.Right, 1):set_highlight(Highlight.Solid)
		self:get_tile(Direction.Down, 1):set_highlight(Highlight.Solid)
		if do_once then
			self:get_tile(Direction.Up, 1):attack_entities(self)
			self:get_tile(Direction.Left, 1):attack_entities(self)
			self:get_tile(Direction.Right, 1):attack_entities(self)
			self:get_tile(Direction.Down, 1):attack_entities(self)
			self:current_tile():attack_entities(self)
			do_once = false
		end
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	-- Engine.play_audio(AUDIO)

	return spell
end

local BUSTER_TEXTURE = Resources.load_texture("spread_buster.png")
local BURST_TEXTURE = Resources.load_texture("spread_impact.png")
local AUDIO = Resources.load_audio("sfx.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_SHOOTING")

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE, true)
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:load("spread_buster.animation")
		buster_anim:set_state("DEFAULT")

		local cannonshot = create_attack(user, props)
		local tile = user:get_tile(user:facing(), 1)
		actor:field():spawn(cannonshot, tile)
	end
	return action
end

function create_attack(user, props)
	local spell = Spell.new(user:team())
	spell.slide_started = false
	local direction = user:facing()
	local field = user:field()
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)
	)
	spell.on_update_func = function(self)
		local spell_tile = spell:current_tile()
		spell_tile:attack_entities(self)
		if self:is_sliding() == false then
			if spell_tile:is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(direction, 1)
			local ref = self
			self:slide(dest, 1, function() ref.slide_started = true end)
		end
	end
	spell.on_collision_func = function(self, other)
		local fx = Artifact.new()
		fx:set_texture(BURST_TEXTURE, true)
		fx:animation():load("spread_impact.animation")
		fx:animation():set_state("DEFAULT")
		fx:animation():on_complete(function()
			fx:erase()
		end)
		fx:set_height(-16.0)
		local tile = self:current_tile():get_tile(direction, 1)
		if tile and not tile:is_edge() then
			field:spawn(fx, tile)
			tile:attack_entities(self)
		end

		local fx2 = Artifact.new()
		fx2:set_texture(BURST_TEXTURE, true)
		fx2:animation():load("spread_impact.animation")
		fx2:animation():set_state("DEFAULT")
		fx2:animation():on_complete(function()
			fx2:erase()
		end)
		fx2:set_height(-16.0)

		local tile2 = self:current_tile():get_tile(direction, 1)
		if tile2 and not tile2:is_edge() then
			field:spawn(fx2, tile2)
			tile2:attack_entities(self)
		end
		self:delete()
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

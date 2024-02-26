nonce = function() end

local DAMAGE = 20
local TEXTURE = Resources.load_texture("spell_tornado.png")
local BUSTER_TEXTURE = Resources.load_texture("buster_fan.png")
local AUDIO = Resources.load_audio("sfx.ogg")

local FRAME1 = { 1, 6 }
local FRAME2 = { 2, 3 }
local FRAME3 = { 3, 3 }
local FRAMES = { FRAME1, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME1, FRAME3,
	FRAME2, FRAME3, FRAME2 }

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_SHOOTING")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE, true)
		buster:sprite():set_layer(-1)
		self:add_anim_action(1, function()
			user:set_counterable(true)
		end)
		local buster_anim = buster:animation()
		buster_anim:load("buster_fan.animation")
		buster_anim:set_state("DEFAULT")
		buster_anim:apply(buster:sprite())
		buster_anim:set_playback(Playback.Loop)
		self:add_anim_action(4, function()
			user:set_counterable(false)
			local cannonshot = create_attack(user, props)
			local tile = user:get_tile(user:facing(), 2)
			actor:field():spawn(cannonshot, tile)
		end)
	end
	return action
end

function create_attack(user, props)
	local spell = Spell.new(user:team())
	spell.hits = 8
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Solid)
	spell:set_texture(TEXTURE, true)
	spell:sprite():set_layer(-1)
	local direction = user:facing()
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			props.element,
			user:context(),
			Drag.None
		)
	)
	local do_once = true
	spell.on_update_func = function(self)
		if do_once then
			local anim = spell:animation()
			anim:load("spell_tornado.animation")
			local spare_props = spell:copy_hit_props()
			local cur_tile = spell:current_tile()
			if cur_tile and cur_tile:state() == TileState.Grass then
				spare_props.element = Element.Wood
				anim:set_state("WOOD")
				spell:set_hit_props(spare_props)
			elseif cur_tile and cur_tile:state() == TileState.Lava then
				spare_props.element = Element.Fire
				anim:set_state("FIRE")
				spell:set_hit_props(spare_props)
				cur_tile:set_state(TileState.Normal)
			else
				anim:set_state("DEFAULT")
			end
			anim:apply(spell:sprite())
			anim:on_complete(function()
				if spell.hits > 1 then
					anim:set_playback(Playback.Loop)
					spell.hits = spell.hits - 1
					local hitbox = Hitbox.new(spell:team())
					hitbox:set_hit_props(spell:copy_hit_props())
					spell:field():spawn(hitbox, spell:current_tile())
				else
					spell:erase()
				end
			end)
			do_once = false
		end
		self:current_tile():attack_entities(self)
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

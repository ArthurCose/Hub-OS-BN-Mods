nonce = function() end

local DAMAGE = 0
local SLASH_TEXTURE = Resources.load_texture("spell_sword_slashes.png")
local BLADE_TEXTURE = Resources.load_texture("spell_sword_blades.png")
local AUDIO = Resources.load_audio("sfx.ogg")



function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SWING")
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		self:add_anim_action(2,
			function()
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
			end
		)

		self:add_anim_action(3,
			function()
				local sword = create_slash(actor)
				local tile = user:get_tile(user:facing(), 1)
				local sharebox1 = SharedHitbox.new(sword, 9)
				sharebox1:set_hit_props(sword:copy_hit_props())
				actor:field():spawn(sword, tile)
				actor:field():spawn(sharebox1, tile:get_tile(user:facing(), 1))
				local fx = Artifact.new()
				fx:set_facing(sword:facing())
				local anim = fx:animation()
				fx:set_texture(SLASH_TEXTURE, true)
				anim:load("spell_sword_slashes.animation")
				anim:set_state("LONG")
				anim:on_complete(
					function()
						fx:erase()
						sword:erase()
					end
				)
				actor:field():spawn(fx, tile)
			end
		)
	end
	return action
end

function create_slash(user)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	DAMAGE = user:max_health() - user:health()

	if DAMAGE > 500 then
		DAMAGE = 500
	end
	spell:set_hit_props(
		HitProps.new(
			DAMAGE,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			Element.Sword,
			user:context(),
			Drag.None
		)
	)
	spell.on_update_func = function(self)
		spell:set_tile_highlight(Highlight.Flash)
		if not self:current_tile():get_tile(user:facing(), 1):is_edge() then
			self:current_tile():get_tile(user:facing(), 1):set_highlight(Highlight.Flash)
		end
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

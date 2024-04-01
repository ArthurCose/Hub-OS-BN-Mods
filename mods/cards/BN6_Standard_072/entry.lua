local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local SLASH_TEXTURE = bn_helpers.load_texture("sword_slashes.png")
local BLADE_TEXTURE = bn_helpers.load_texture("sword_blades.png")

local SLASH_ANIM_PATH = bn_helpers.fetch_animation_path("sword_slashes.animation")
local BLADES_ANIM_PATH = bn_helpers.fetch_animation_path("sword_blades.animation")

local AUDIO = bn_helpers.load_audio("sword.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
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
				blade_anim:load(BLADES_ANIM_PATH)
				blade_anim:set_state("DEFAULT")
			end
		)
		local field = user:field()
		self:add_anim_action(3, function()
			local sword = create_slash(user, props)
			local tile = user:get_tile(user:facing(), 1)
			local fx = Artifact.new()
			fx:set_facing(sword:facing())
			local anim = fx:animation()
			fx:set_texture(SLASH_TEXTURE)
			anim:load(SLASH_ANIM_PATH)
			anim:set_state("LONG")
			anim:on_complete(function()
				fx:erase()
				if not sword:deleted() then sword:delete() end
			end)
			field:spawn(sword, tile)
			field:spawn(fx, tile)
		end)
	end
	return action
end

function create_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			props.secondary_element,
			user:context(),
			Drag.None
		)
	)
	local attack_once = true
	local field = user:field()
	spell.on_update_func = function(self)
		local tile = spell:current_tile()
		local tile_next = tile:get_tile(spell:facing(), 1)
		if tile_next and not tile_next:is_edge() then
			tile_next:set_highlight(Highlight.Flash)
		end
		if attack_once then
			if tile_next and not tile_next:is_edge() then
				local hitbox_r = SharedHitbox.new(self, 12)
				hitbox_r:set_hit_props(self:copy_hit_props())
				field:spawn(hitbox_r, tile_next)
			end
			attack_once = false
		end
		tile:attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

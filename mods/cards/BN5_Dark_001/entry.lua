local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("lifesword.ogg")

function card_mutate(user, card_index)
	local movement_component = user:create_component(Lifetime.ActiveBattle)
	movement_component._wait_timer = 7
	movement_component._count = 0

	movement_component.on_update_func = function(self)
		local owner = self:owner()
		self._count = self._count + 1
		if self._count % self._wait_timer == 0 and Living.from(owner) ~= nil then
			if owner:is_inactionable() or owner:is_immobile() or owner:is_moving() then return end
			local movement = Movement.new_teleport(owner:get_tile(owner:facing(), 1))

			owner:queue_movement(movement)
		end
	end
end

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		local spells = {}
		spawn_artifact(spells, user, "DARK")

		-- Attack in a two deep, three tall formation
		create_spell(spells, user, props, 1, -1)
		create_spell(spells, user, props, 1, 0)
		create_spell(spells, user, props, 1, 2)
		create_spell(spells, user, props, 2, -1)
		create_spell(spells, user, props, 2, 0)
		create_spell(spells, user, props, 2, 1)

		Resources.play_audio(AUDIO)
	end)
end

---@param user Entity
function create_spell(spells, user, props, x_offset, y_offset)
	local field = user:field()
	local h_tile = user:get_tile(user:facing(), x_offset)
	local tile = h_tile:get_tile(Direction.Down, y_offset)

	if not tile then
		return
	end

	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
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

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	field:spawn(spell, tile)

	spells[#spells + 1] = spell
end

---@param user Entity
function spawn_artifact(spells, user, state)
	local fx = Artifact.new()
	fx:set_facing(user:facing())
	local anim = fx:animation()
	fx:set_texture(SLASH_TEXTURE)
	anim:load(SLASH_ANIM_PATH)
	anim:set_state(state)
	anim:on_complete(function()
		fx:erase()

		for _, spell in ipairs(spells) do
			spell:delete()
		end
	end)

	local field = user:field()
	field:spawn(fx, user:get_tile(user:facing(), 1))
end

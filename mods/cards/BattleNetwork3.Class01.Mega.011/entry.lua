local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))
sword:set_blade_animation_state("WOOD")

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("sword.ogg")

function card_mutate(player, index)
	local card = player:field_card(index);

	local list = player:field_cards()

	if index == #list then return end

	local next_card = player:field_card(index + 1)

	if next_card.damage == 0 then return end

	card.damage = card.damage + next_card.damage
	card.boosted_damage = card.boosted_damage + next_card.damage

	player:remove_field_card(index + 1)

	player:set_field_card(index, card)
end

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		local spells = {}
		spawn_artifact(spells, user, "WOOD_LONG")
		create_spell(spells, user, props, 1, 0)
		create_spell(spells, user, props, 2, 0)

		Resources.play_audio(AUDIO)
	end)
end

---@param spells table
---@param user Entity
---@param props CardProperties
---@param x_offset number
---@param y_offset number
function create_spell(spells, user, props, x_offset, y_offset)
	local h_tile = user:get_tile(user:facing(), x_offset)
	if not h_tile then return end
	local tile = h_tile:get_tile(Direction.Down, y_offset)

	if not tile then
		return
	end

	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	Field.spawn(spell, tile)

	spells[#spells + 1] = spell
end

---@param spells table
---@param user Entity
---@param state string
function spawn_artifact(spells, user, state)
	local tile = user:get_tile(user:facing(), 1)
	if not tile then return end

	-- using spell to avoid weird time freeze quirks
	local fx = Spell.new()
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

	Field.spawn(fx, tile)
end

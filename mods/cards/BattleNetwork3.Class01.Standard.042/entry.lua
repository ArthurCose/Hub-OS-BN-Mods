local function debug_print(...)
	print(...)
end

local bn_assets = require("BattleNetwork.Assets")
---@type PanelStepLib
local PanelStepLib = require("dev.konstinople.library.panel_step")
---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("cross_slash.ogg")

local panel_step = PanelStepLib.new_panel_step()
panel_step:set_return_frame(26)

---@param user Entity
function card_init(user, props)
	return panel_step:create_action(user, function(action)
		sword:create_action_step(action, function()
			local spells = {}
			spawn_artifact(spells, user, "CROSS")
			-- Attack the centre tile twice
			create_spell(spells, user, props, 1, 0)
			create_spell(spells, user, props, 1, 0)
			-- Attack two tiles forward, one tile up
			create_spell(spells, user, props, 2, -1)
			-- Attack two tiles forward, one tile down
			create_spell(spells, user, props, 2, 1)
			-- Attack the tile above you
			create_spell(spells, user, props, 0, -1)
			-- Attack the tile below you
			create_spell(spells, user, props, 0, 1)

			Resources.play_audio(AUDIO)
		end)
	end)
end

---@param user Entity
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

---@param user Entity
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

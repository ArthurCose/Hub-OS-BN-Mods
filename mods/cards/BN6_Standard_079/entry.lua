---@type BattleNetworkAssetsLib
local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_blade_texture(bn_assets.load_texture("windrack.png"))
sword:set_blade_animation_path(bn_assets.fetch_animation_path("windrack.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("wind_slash.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("wind_slash.animation")
local AUDIO = bn_assets.load_audio("windrack.ogg")

local function create_gust(team, direction)
	local spell = Spell.new(team)
	spell:set_hit_props(HitProps.new(0, Hit.Drag, Element.None, nil, Drag.new(direction, 1)))

	local first_frame = true

	spell.on_update_func = function()
		local tile = spell:current_tile()

		local has_obstacles = false
		tile:find_obstacles(function()
			has_obstacles = true
			return false
		end)

		if has_obstacles then
			if first_frame then
				tile:attack_entities(spell)
			end

			spell:erase()
			return
		end

		tile:attack_entities(spell)
		first_frame = false

		if spell:is_moving() then
			return
		end

		local next_tile = tile:get_tile(direction, 1)

		if not next_tile then
			spell:erase()
			return
		end

		spell:slide(next_tile, 4)
	end

	return spell
end

---@param user Entity
local function create_spell(spells, user, props, x_offset, y_offset)
	local field = user:field()
	local h_tile = user:get_tile(user:facing(), x_offset)

	if not h_tile then
		return
	end

	local tile = h_tile:get_tile(Direction.Down, y_offset)

	if not tile then
		return
	end

	local team = user:team()

	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	spell.on_spawn_func = function(self)
		field:spawn(create_gust(team, self:facing()), self:current_tile())
	end

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	field:spawn(spell, tile)

	spells[#spells + 1] = spell
end

---@param user Entity
local function spawn_artifact(spells, user, state)
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
	local tile = user:get_tile(user:facing(), 1)

	if tile then
		field:spawn(fx, tile)
	end
end

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		local spells = {}
		spawn_artifact(spells, user, "DEFAULT")
		create_spell(spells, user, props, 1, -1)
		create_spell(spells, user, props, 1, 0)
		create_spell(spells, user, props, 1, 1)

		Resources.play_audio(AUDIO)
	end)
end

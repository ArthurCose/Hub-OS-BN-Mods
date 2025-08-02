---@type BattleNetwork.Assets
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
	spell:set_hit_props(HitProps.new(0, 0, Element.Wind))

	local i = 0
	spell.on_update_func = function()
		local tile = spell:current_tile()
		spell:attack_tile()

		i = i + 1

		local has_obstacles = false
		tile:find_obstacles(function()
			has_obstacles = true
			return false
		end)

		if has_obstacles then
			spell:erase()
			return
		end

		if spell:is_moving() then
			return
		end

		local next_tile = tile:get_tile(direction, 1)

		if not next_tile or next_tile:is_edge() then
			spell:erase()
			return
		end

		tile:find_characters(function(character)
			if character:team() ~= team then
				character:slide(next_tile, 4)
			end
			return false
		end)

		spell:slide(next_tile, 4)
	end

	return spell
end

---@param user Entity
local function create_slash(user, hit_props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(hit_props)
	spell:set_texture(SLASH_TEXTURE)

	local anim = spell:animation()
	anim:load(SLASH_ANIM_PATH)
	anim:set_state("DEFAULT")
	anim:on_complete(function()
		spell:delete()
	end)

	local attack_existing_tile = function(tile)
		if tile then spell:attack_tile(tile) end
	end

	spell.on_update_func = function()
		spell:attack_tile()
		attack_existing_tile(spell:get_tile(Direction.Up, 1))
		attack_existing_tile(spell:get_tile(Direction.Down, 1))
	end

	return spell
end

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		local forward_tile = user:get_tile(user:facing(), 1)

		if not forward_tile then
			return
		end

		local hit_props = HitProps.from_card(
			props,
			user:context(),
			Drag.new(user:facing(), Field.width())
		)

		Field.spawn(create_slash(user, hit_props), forward_tile)

		local team = user:team()
		local x = forward_tile:x()

		for y = 0, Field.height() - 1 do
			Field.spawn(create_gust(team, user:facing()), x, y)
		end

		Resources.play_audio(AUDIO)
	end)
end

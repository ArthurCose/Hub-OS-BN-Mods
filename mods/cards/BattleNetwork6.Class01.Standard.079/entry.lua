---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

---@type BattleNetwork.WindGust
local WindGustLib = require("BattleNetwork.WindGust")

local wind_gust_builder = WindGustLib.new_wind_gust()
wind_gust_builder:set_sync_movements()

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_blade_texture(bn_assets.load_texture("windrack.png"))
sword:set_blade_animation_path(bn_assets.fetch_animation_path("windrack.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("wind_slash.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("wind_slash.animation")
local AUDIO = bn_assets.load_audio("windrack.ogg")

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

		Resources.play_audio(AUDIO)

		-- spawn slash
		local hit_props = HitProps.from_card(
			props,
			user:context(),
			Drag.new(user:facing(), Field.width())
		)

		Field.spawn(create_slash(user, hit_props), forward_tile)

		-- spawning gusts with a delay
		local team = user:team()
		local facing = user:facing()

		local delayed_spawner = Spell.new()
		delayed_spawner.on_spawn_func = function()
			local x = forward_tile:x()

			for y = 0, Field.height() - 1 do
				local gust = wind_gust_builder:create_spell(team, facing)
				Field.spawn(gust, x, y)
			end

			delayed_spawner:delete()
		end

		Field.spawn(delayed_spawner, 0, 0)
	end)
end

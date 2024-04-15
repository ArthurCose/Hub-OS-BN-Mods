local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_animation_state("BEETANK")
bomb:set_bomb_held_animation_state("BEETANK_HELD")
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local EXPLOSION_TEXTURE = bn_assets.load_texture("crakbom_explosion.png")
local EXPLOSION_ANIMATION_PATH = bn_assets.load_texture("crakbom_explosion.animation")

---@param team Team
---@param tile? Tile
local function spawn_explosion(team, hit_props, field, tile)
	if not tile or tile:state() == TileState.Hidden then
		return
	end

	-- crack or break tile
	if tile:state() == TileState.Cracked then
		tile:set_state(TileState.Broken)
	else
		tile:set_state(TileState.Cracked)
	end

	-- create spell
	local spell = Spell.new(team)
	spell:set_hit_props(hit_props)
	spell:set_texture(EXPLOSION_TEXTURE)

	local spell_animation = spell:animation()
	spell_animation:load(EXPLOSION_ANIMATION_PATH)
	spell_animation:set_state("DEFAULT")
	spell_animation:on_complete(function() spell:erase() end)

	tile:attack_entities(spell)
	field:spawn(spell, tile)
end

---@param user Entity
function card_init(user, props)
	local field = user:field()
	local team = user:team()

	return bomb:create_action(user, function(tile)
		if not tile or not tile:is_walkable() then
			return
		end

		-- spawn explosions
		local hit_props = HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)

		spawn_explosion(team, hit_props, field, tile:get_tile(Direction.Up, 1))
		spawn_explosion(team, hit_props, field, tile)
		spawn_explosion(team, hit_props, field, tile:get_tile(Direction.Down, 1))
	end)
end

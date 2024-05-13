local bn_assets = require("BattleNetwork.Assets")

---@type SeedBombLib
local SeedBombLib = require("dev.konstinople.library.seed_bomb")

local seed_bomb = SeedBombLib.new_seed_bomb()
local bomb = seed_bomb:bomb()
bomb:set_bomb_texture(Resources.load_texture("seedbomb.png"))
bomb:set_bomb_animation_path(_folder_path .. "seedbomb.animation")
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_bomb_held_animation_state("HELD")
bomb:set_bomb_animation_state("AIR")
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

seed_bomb:set_tile_change_texture(bn_assets.load_texture("panelgrab.png"))
seed_bomb:set_tile_change_animation_path(bn_assets.fetch_animation_path("panelgrab.animation"))
seed_bomb:set_tile_change_animation_state("GRAB")
seed_bomb:set_tile_change_sfx(bn_assets.load_audio("break.ogg"))
seed_bomb:set_tile_state(TileState.Poison)

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	return seed_bomb:create_action(user, props)
end

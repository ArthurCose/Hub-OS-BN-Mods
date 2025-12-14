local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_animation_state("DEFAULT")
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local FREEZE_SFX = bn_assets.load_audio("freeze.ogg")
local ICE_SPIKE_TEXTURE = bn_assets.load_texture("ice_spike.png")
local ICE_SPIKE_ANIM_PATH = bn_assets.fetch_animation_path("ice_spike.animation")

---@param team Team
---@param tile? Tile
local function spawn_explosion(team, hit_props, tile)
	if not tile or tile:state() == TileState.Void then
		return
	end

	-- create spell
	local spell = Spell.new(team)
	spell:set_hit_props(hit_props)
	spell:set_texture(ICE_SPIKE_TEXTURE)

	local spell_animation = spell:animation()
	spell_animation:load(ICE_SPIKE_ANIM_PATH)
	spell_animation:set_state("SPAWN")
	spell_animation:on_complete(function()
        -- flash (disappear/reappear) before cleanup
        local component = spell:create_component(Lifetime.Scene)
        local t = 0
        component.on_update_func = function()
          local sprite = spell:sprite()
          sprite:set_visible(math.floor(t / 2) % 2 == 0)
          t = t + 1
            if t >= 24 then 
		      spell:erase() 
		    end
		end
	end)

	tile:attack_entities(spell)
	Field.spawn(spell, tile)
end

---@param user Entity
function card_init(user, props)
	local team = user:team()

	return bomb:create_action(user, function(tile)
		if not tile or not tile:is_walkable() then
			return
		end

		Resources.play_audio(FREEZE_SFX)

		-- spawn explosions
		local hit_props = HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)

		spawn_explosion(team, hit_props, tile:get_tile(Direction.Up, 1))
		spawn_explosion(team, hit_props, tile)
		spawn_explosion(team, hit_props, tile:get_tile(Direction.Down, 1))
		spawn_explosion(team, hit_props, tile:get_tile(Direction.Left, 1))
		spawn_explosion(team, hit_props, tile:get_tile(Direction.Right, 1))
	end)
end

local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("sword.ogg")

---@param user Entity
function card_init(user, props)
		
	return sword:create_action(user, function()
		spawn_cut(user, props)
		Resources.play_audio(AUDIO)
	end)
	
end

function spawn_cut(user, props)
    local spawn_tile

    spawn_tile = targeting(user)
	
    if not spawn_tile then
      return
    end
	
	local cut = Spell.new(user:team())
	cut:set_facing(user:facing())
	cut:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

    cut:set_texture(SLASH_TEXTURE)
    
    local cut_anim = cut:animation()
    cut_anim:load(SLASH_ANIM_PATH)
    cut_anim:set_state("WIDE")
    
    cut_anim:on_complete(function()
        cut:delete()
    end)

    -- attack on the first frame
    cut.on_spawn_func = function()
        cut:attack_tile()
        cut:attack_tile(cut:get_tile(Direction.Up, 1))
        cut:attack_tile(cut:get_tile(Direction.Down, 1))
    end
	
	cut.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end
    
    -- spawn the cut
    Field.spawn(cut, spawn_tile)
end

function targeting(user)
    local tile

    local enemy_filter = function(character)
        return character:team() ~= user:team() and character:hittable() and (character:current_tile():state() == TileState.Grass or character:current_tile():state() == TileState.Ice or character:current_tile():state() == TileState.Sea or character:current_tile():state() == TileState.Volcano)
    end

    local enemy_list = nil
    enemy_list = Field.find_nearest_characters(user, enemy_filter)
    if #enemy_list > 0 then tile = enemy_list[1]:current_tile() else tile = nil end

    if not tile then
        return nil
    end

    return tile
end
local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local ice_tower_texture = bn_assets.load_texture("ice_spike.png")
local ice_animation_path = bn_assets.fetch_animation_path("ice_spike.animation")

local PANEL_SFX = bn_assets.load_audio("physical_object_land.ogg")

---@param user Entity
function card_init(user, props)
    return bomb:create_action(user, function(tile)
        if not tile or not tile:is_walkable() then
            return
        end

        if not tile:is_reserved() then
            tile:set_state(TileState.Ice)
        end

        Resources.play_audio(PANEL_SFX)

        local spell = Spell.new(user:team())

        spell:set_facing(user:facing())

        spell:set_texture(ice_tower_texture)

        local spell_anim = spell:animation()
        spell_anim:load(ice_animation_path)

        spell_anim:set_state("SPAWN")

        spell_anim:on_complete(function()
            spell_anim:set_state("LOOP")
        end)

        spell:set_hit_props(
            HitProps.from_card(
                props,
                user:context(),
                Drag.None
            )
        )

        local timer = 80

        spell.on_update_func = function(self)
            timer = timer - 1
            if timer == 0 then
                spell_anim:set_state("SPAWN")
                spell_anim:set_playback(Playback.Reverse)
                spell_anim:on_complete(function()
                    spell:erase()
                end)
                return
            end

            self:current_tile():attack_entities(self)
        end

        Field.spawn(spell, tile)
    end)
end

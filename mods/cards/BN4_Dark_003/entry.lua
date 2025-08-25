local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local explosion_audio = bn_assets.load_audio("explosion_defeatedmob.ogg")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_animation_state("DARK")
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

function card_mutate(user, card_index)
    if Player.from(user) then
        user:boost_augment("BattleNetwork4.Bugs.BackwardMovement", 1)
    end
end

---@param user Entity
function card_init(user, props)
    return bomb:create_action(user, function(tile)
        if not tile or not tile:is_walkable() then
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
            for x = -1, 1, 1 do
                for y = -1, 1, 1 do
                    local own_tile = self:current_tile()
                    local attack_tile = Field.tile_at(own_tile:x() + x, own_tile:y() + y)
                    if attack_tile ~= nil then
                        -- spawn explosion
                        local dark_explosion = Artifact.new()
                        dark_explosion:set_texture(bn_assets.load_texture("bn4_spell_explosion.png"))

                        local dark_explosion_anim = dark_explosion:animation()
                        dark_explosion_anim:load(bn_assets.fetch_animation_path("bn4_spell_explosion.animation"))
                        dark_explosion_anim:set_state("DARK_QUICK")

                        dark_explosion.on_spawn_func = function()
                            Resources.play_audio(explosion_audio)
                        end

                        dark_explosion_anim:on_complete(function()
                            dark_explosion:erase()
                        end)

                        Field.spawn(dark_explosion, attack_tile)

                        self:attack_tile(attack_tile)
                    end
                end
            end
            self:erase()
        end

        Field.spawn(spell, tile)
    end)
end

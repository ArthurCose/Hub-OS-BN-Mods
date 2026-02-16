local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")

function debug_print(...)
    print(...)
end

local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("bn6_rush.png")
local ANIM_PATH = bn_assets.fetch_animation_path("bn6_rush.animation")

local SHADOW_TEXTURE = bn_assets.load_texture("bomb_shadow.png")

local APPEAR_AUDIO = bn_assets.load_audio("BlackWing_Appear.ogg")
local BITE_AUDIO = bn_assets.load_audio("rush_bite.ogg")

---@param entity Entity
---@param aug_owner Entity
---@param aux_prop_list table<EntityId, AuxProp>
local function track(entity, aug_owner, aux_prop_list)
    local rush_prop = AuxProp.new()
        :require_action(ActionType.Card)
        :require_card_tag("APPLY_RUSH")
        :intercept_action(function(action)
            if TurnGauge.frozen() == true then return action end

            local action_owner = action:owner()
            local rush_action = Action.new(aug_owner)

            local rush_card_props = CardProperties.new()

            rush_card_props.time_freeze = true
            rush_card_props.short_name = "Rush"
            rush_card_props.prevent_time_freeze_counter = true

            rush_action:set_card_properties(rush_card_props)

            rush_action:set_lockout(ActionLockout.new_sequence())

            local step = rush_action:create_step()

            local time = 0
            step.on_update_func = function()
                time = time + 1
            end

            aux_prop_list[action_owner:id()] = nil

            rush_action.on_execute_func = function()
                for key, value in pairs(aux_prop_list) do
                    if value == nil then goto continue end
                    local remove_target = Field.get_entity(key)

                    if remove_target then
                        remove_target:remove_aux_prop(value)
                    end

                    ::continue::
                end

                ChipNaviLib.exit(aug_owner, function()
                    ChipNaviLib.delay_for_swap(function()
                        local rush_artifact = Artifact.new()
                        local rush_sprite = rush_artifact:sprite()
                        local rush_anim = rush_artifact:animation()

                        rush_artifact:set_facing(aug_owner:facing())

                        rush_artifact:show_shadow(false)

                        rush_artifact.on_spawn_func = function()
                            Resources.play_audio(APPEAR_AUDIO)
                        end

                        local bite_loops = 7

                        rush_sprite:set_texture(TEXTURE)
                        rush_artifact:set_shadow(SHADOW_TEXTURE)

                        rush_anim:load(ANIM_PATH)
                        rush_anim:set_state("SPAWN")
                        rush_anim:set_playback(Playback.Once)
                        rush_anim:on_complete(function()
                            rush_anim:set_state("SNIFF")
                            rush_anim:set_playback(Playback.Once)
                            rush_anim:on_complete(function()
                                rush_artifact:teleport(action_owner:current_tile())
                                rush_anim:set_state("JUMP")
                                rush_anim:set_playback(Playback.Once)
                                rush_anim:on_complete(function()
                                    rush_anim:set_state("BITE")
                                    rush_anim:set_playback(Playback.Loop)
                                    rush_anim:on_complete(function()
                                        if bite_loops == 0 then
                                            rush_action:end_action()
                                            return
                                        end

                                        Resources.play_audio(BITE_AUDIO)
                                        bite_loops = bite_loops - 1
                                    end)
                                end)
                            end)
                        end)

                        rush_artifact.can_move_to_func = function()
                            return true
                        end

                        rush_action.on_action_end_func = function()
                            ChipNaviLib.enter(aug_owner, function() end)

                            rush_artifact:erase()

                            local props = HitProps.new(
                                0,
                                Hit.Paralyze | Hit.PierceInvis,
                                Element.None,
                                aug_owner:context(),
                                Drag.None
                            )

                            props.status_durations[Hit.Paralyze] = 150

                            local hitbox = Spell.new(aug_owner:team())
                            hitbox:set_hit_props(props)

                            hitbox.on_update_func = function(self)
                                self:attack_tile()
                                self:erase()
                            end

                            Field.spawn(hitbox, action_owner:current_tile())
                        end

                        Field.spawn(rush_artifact, aug_owner:current_tile())
                    end)
                end)
            end

            aug_owner:queue_action(rush_action)

            return nil
        end)
        :once()

    entity:add_aux_prop(rush_prop)
    aux_prop_list[entity:id()] = rush_prop
end

---@param augment Augment
function augment_init(augment)
    local owner = augment:owner()

    -- If we've bugged this program, it won't activate, so do nothing.
    if owner:get_augment("BattleNetwork6.Bugs.RushDisabled") ~= nil then return end

    local search_component = owner:create_component(Lifetime.ActiveBattle)
    local aug_timer = 0
    local aux_prop_list = {}
    search_component.on_update_func = function(self)
        aug_timer = aug_timer + 1

        if aug_timer < 1 then return end

        local enemy_team_list = Field.find_characters(function(entity)
            return not owner:is_team(entity:team()) and entity:id() ~= owner:id()
        end)

        for i = 1, #enemy_team_list, 1 do
            track(enemy_team_list[i], owner, aux_prop_list)
        end

        self:eject()
    end
end

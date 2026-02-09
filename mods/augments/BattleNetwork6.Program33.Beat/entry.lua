local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")

function debug_print(...)
    print(...)
end

local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("bn6_beat.png")
local ANIM_PATH = bn_assets.fetch_animation_path("bn6_beat.animation")

local SHADOW_TEXTURE = bn_assets.load_texture("bomb_shadow.png")

local DIVE_AUDIO = bn_assets.load_audio("beat_dive.ogg")
local GRAB_AUDIO = bn_assets.load_audio("beat_snatch.ogg")

local aux_prop_list = {}

local function track(entity, aug_owner)
    local beat_prop = AuxProp.new()
        :require_card_not_class(CardClass.Standard)
        :require_card_not_class(CardClass.Recipe)
        :require_card_not_class(CardClass.Dark)
        :intercept_action(function(action)
            if TurnGauge.frozen() then return action end

            local action_owner = action:owner()
            local beat_action = Action.new(aug_owner)

            local beat_card_props = CardProperties.new()

            beat_card_props.time_freeze = true
            beat_card_props.short_name = "Beat"
            beat_card_props.prevent_time_freeze_counter = true

            beat_action:set_card_properties(beat_card_props)

            beat_action:set_lockout(ActionLockout.new_sequence())

            local step = beat_action:create_step()

            local time = 0
            step.on_update_func = function()
                time = time + 1
            end

            aux_prop_list[action_owner:id()] = nil

            for key, value in pairs(aux_prop_list) do
                local remove_target = Field.get_entity(key)

                if remove_target then
                    remove_target:remove_aux_prop(value)
                end
            end

            beat_action.on_execute_func = function()
                ChipNaviLib.exit(aug_owner, function()
                    ChipNaviLib.delay_for_swap(function()
                        local beat_artifact = Artifact.new()
                        local beat_sprite = beat_artifact:sprite()
                        local beat_anim = beat_artifact:animation()

                        beat_artifact:set_facing(action_owner:facing_away())

                        beat_artifact:show_shadow(false)

                        beat_artifact.on_spawn_func = function()
                            Resources.play_audio(DIVE_AUDIO)
                        end

                        local loop_timer = 0
                        local spawn_loops = 8
                        local escape_elevation = 256
                        local goal_elevation = action_owner:height() + 12

                        beat_artifact:set_elevation(128)

                        local hovering = false
                        local begin_dive = false
                        local begin_hover = false
                        local begin_ascent = false
                        local start_loop_timer = false

                        local target_tile = action_owner:current_tile()
                        local beat_spawn_tile = Field.tile_at(0, target_tile:y())
                        if aug_owner:current_tile():x() > target_tile:x() then
                            beat_spawn_tile = Field.tile_at(Field.width() - 1, target_tile:y())
                        end

                        beat_sprite:set_texture(TEXTURE)
                        beat_artifact:set_shadow(SHADOW_TEXTURE)

                        beat_anim:load(ANIM_PATH)
                        beat_anim:set_state("SPAWN")
                        beat_anim:set_playback(Playback.Loop)
                        beat_anim:on_complete(function()
                            if spawn_loops == 0 then
                                beat_anim:set_state("DIVE")
                                beat_anim:set_playback(Playback.Once)
                                beat_artifact:teleport(beat_spawn_tile)
                                beat_artifact:set_elevation(128)
                                begin_dive = true
                                beat_artifact:show_shadow(true)
                            else
                                spawn_loops = spawn_loops - 1
                            end
                        end)

                        beat_artifact.on_update_func = function(self)
                            if start_loop_timer == true then loop_timer = loop_timer + 1 end

                            if begin_dive == false then return end

                            if self:elevation() > goal_elevation then
                                self:set_elevation(math.max(goal_elevation, self:elevation() - 4))
                            end

                            if begin_ascent == true then
                                if beat_anim:state() ~= "ESCAPE" then return end
                                if self:elevation() < escape_elevation then
                                    self:set_elevation(self:elevation() + 8)
                                else
                                    self:erase()
                                    beat_action:end_action()
                                end
                                return
                            end

                            if hovering == true then
                                if loop_timer < 60 then return end

                                hovering = false
                                begin_ascent = true

                                beat_anim:set_state("TAKEOFF")
                                beat_anim:on_complete(function()
                                    beat_anim:set_state("ESCAPE")
                                    beat_anim:set_playback(Playback.Loop)
                                end)
                                return
                            end

                            if self:current_tile() ~= target_tile then
                                if not self:is_sliding() then self:slide(self:get_tile(self:facing(), 1), 4) end
                                return
                            else
                                if hovering == false and begin_hover == false then
                                    begin_hover = true
                                end
                            end

                            if begin_hover == false then return end

                            begin_hover = false
                            hovering = true

                            Resources.play_audio(GRAB_AUDIO)

                            beat_anim:set_state("HOVER")
                            beat_anim:set_playback(Playback.Loop)
                            beat_anim:on_complete(function()
                                start_loop_timer = true
                            end)
                        end

                        beat_artifact.can_move_to_func = function()
                            return true
                        end

                        beat_action.on_action_end_func = function()
                            ChipNaviLib.enter(aug_owner, function() end)
                        end

                        Field.spawn(beat_artifact, aug_owner:current_tile())
                    end)
                end)
            end


            aug_owner:queue_action(beat_action)
            return nil
        end)
        :once()

    entity:add_aux_prop(beat_prop)
    aux_prop_list[entity:id()] = beat_prop
end

---@param augment Augment
function augment_init(augment)
    local owner = augment:owner()

    -- If we've bugged this program, it won't activate, so do nothing.
    if owner:get_augment("BattleNetwork6.Bugs.BeatDisabled") ~= nil then return end

    local search_component = owner:create_component(Lifetime.ActiveBattle)
    local aug_timer = 0
    search_component.on_update_func = function(self)
        aug_timer = aug_timer + 1

        if aug_timer < 1 then return end

        -- Only for pvp. Needs at least one player of the enemy team
        local enemy_team_list = Field.find_characters(function(entity)
            return owner:team() ~= entity:team()
        end)

        -- If enemy players are not found, then do nothing
        if #enemy_team_list == 0 then return end

        for i = 1, #enemy_team_list, 1 do
            track(enemy_team_list[i], owner)
        end

        self:eject()
    end
end

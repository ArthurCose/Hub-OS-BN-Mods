function debug_print(...)
    print(...)
end

local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("bn6_tango.png")
local ANIM_PATH = bn_assets.fetch_animation_path("bn6_tango.animation")
local ORB_TEXTURE = bn_assets.load_texture("bn6_tango_orb.png")
local ORB_ANIM_PATH = bn_assets.fetch_animation_path("bn6_tango_orb.animation")

local BARRIER_TEXTURE = bn_assets.load_texture("bn6_barriers.png")
local BARRIER_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_barriers.animation")
local BARRIER_UP_SOUND = bn_assets.load_audio("barrier.ogg")

local RECOVER_TEXTURE = bn_assets.load_texture("recover.png")
local RECOVER_ANIMATION = bn_assets.fetch_animation_path("recover.animation")
local RECOVER_AUDIO = bn_assets.load_audio("recover.ogg")

local function create_recov(user)
    local artifact = Artifact.new()
    artifact:set_texture(RECOVER_TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load(RECOVER_ANIMATION)
    anim:set_state("DEFAULT")
    anim:on_complete(function()
        artifact:erase()
    end)

    Resources.play_audio(RECOVER_AUDIO)

    return artifact
end


local function heal_and_create_barrier(user)
    local recov = create_recov(user)
    Field.spawn(recov, user:current_tile())
    user:set_health(user:health() + 300)

    local HP = 100

    Resources.play_audio(BARRIER_UP_SOUND)

    local fading = false
    local isWind = false
    local remove_barrier = false

    local barrier = user:create_node()
    barrier:set_layer(3)
    barrier:set_texture(BARRIER_TEXTURE)

    local barrier_animation = Animation.new(BARRIER_ANIMATION_PATH)
    barrier_animation:set_state("BARR100")
    barrier_animation:apply(barrier)

    barrier_animation:set_playback(Playback.Loop)

    local barrier_defense_rule = DefenseRule.new(DefensePriority.Barrier, DefenseOrder.Always)
    barrier_defense_rule.defense_func = function(defense, attacker, defender)
        local attacker_hit_props = attacker:copy_hit_props()
        HP = HP - attacker_hit_props.damage

        defense:block_damage()

        if attacker_hit_props.element == Element.Wind then isWind = true end
    end

    local aura_animate_component = user:create_component(Lifetime.ActiveBattle)

    aura_animate_component.on_update_func = function(self)
        barrier_animation:apply(barrier)
        barrier_animation:update()
    end

    local aura_destroy_component = user:create_component(Lifetime.Battle)

    local destroy_aura = false

    aura_destroy_component.on_update_func = function(self)
        if (isWind or HP <= 0 or destroy_aura) then
            remove_barrier = true
        end

        if remove_barrier and not fading then
            fading = true
            user:remove_defense_rule(barrier_defense_rule)

            barrier_animation:on_complete(function()
                user:sprite():remove_node(barrier)
                aura_animate_component:eject()
                aura_destroy_component:eject()
            end)

            if isWind then
                local initialX = barrier:offset().x
                local initialY = barrier:offset().y
                local facing_check = 1
                if user:facing() == Direction.Left then
                    facing_check = -1
                end

                barrier_animation:on_frame(1, function()
                    barrier:set_offset(facing_check * (-25 - initialX) * 0.5, -20 + initialY * 0.5)
                end)

                barrier_animation:on_frame(2, function()
                    barrier:set_offset(facing_check * (-50 - initialX) * 0.5, -40 + initialY * 0.5)
                end)

                barrier_animation:on_frame(3, function()
                    barrier:set_offset(facing_check * (-75 - initialX) * 0.5, -60 + initialY * 0.5)
                end)
            end
        end
    end

    barrier_defense_rule.on_replace_func = function()
        aura_animate_component:eject()
        aura_destroy_component:eject()
        user:remove_node(barrier)
    end

    user:add_defense_rule(barrier_defense_rule)
end

---@param owner Entity
local function create_action(owner)
    local action = Action.new(owner)

    local props = CardProperties.new()
    props.time_freeze = true
    props.short_name = "Tango"
    props.prevent_time_freeze_counter = true

    action:set_card_properties(props)

    action:set_lockout(ActionLockout.new_sequence())

    local executed = false

    action.on_execute_func = function()
        executed = true

        local step = action:create_step()
        local tango_artifact = Artifact.new(owner:team())
        tango_artifact:set_texture(TEXTURE)

        tango_artifact:set_shadow(Shadow.Small)

        tango_artifact:set_facing(owner:facing())

        tango_artifact:set_elevation(76)

        local tango_anim = tango_artifact:animation()
        tango_anim:load(ANIM_PATH)

        local has_given_buff = false
        tango_anim:set_state("SPAWN")

        local increment = 4

        step.on_update_func = function()
            local elevation = tango_artifact:elevation()

            if elevation > 0 and has_given_buff == false then
                tango_artifact:set_elevation(elevation - increment)
            elseif has_given_buff == true and tango_anim:state() == "SPAWN" then
                tango_artifact:set_elevation(elevation + increment)
                if tango_artifact:elevation() >= 76 then
                    tango_artifact:erase()
                    action:end_action()
                end
            end
        end

        tango_anim:on_complete(function()
            tango_anim:set_state("STAND")
            tango_anim:on_complete(function()
                tango_anim:set_state("BOX")
                tango_anim:on_frame(4, function()
                    has_given_buff = true
                    local orb_artifact = Artifact.new(owner:team())
                    orb_artifact:set_texture(ORB_TEXTURE)

                    local orb_anim = orb_artifact:animation()
                    orb_anim:load(ORB_ANIM_PATH)

                    orb_anim:set_state("SPAWN")

                    orb_anim:on_complete(function()
                        orb_anim:set_state("LOOP")
                        orb_anim:set_playback(Playback.Loop)
                    end)

                    local tango_do_once = true
                    orb_artifact.on_update_func = function(artifact_self)
                        if tango_do_once == true then
                            artifact_self:queue_movement(Movement.new_jump(owner:current_tile(), 20, 8))
                            tango_do_once = false
                        else
                            if artifact_self:is_jumping() == false then
                                heal_and_create_barrier(owner)
                                artifact_self:erase()
                            end
                        end
                    end

                    Field.spawn(orb_artifact, tango_artifact:current_tile())
                end)

                tango_anim:on_complete(function()
                    tango_anim:set_state("CLOSE")
                    tango_anim:on_complete(function()
                        tango_anim:set_state("SPAWN")
                        tango_anim:set_playback(Playback.Reverse)
                        tango_anim:on_complete(function()
                            -- action:end_action()
                            -- tango_artifact:erase()
                        end)
                    end)
                end)
            end)
        end)

        Field.spawn(tango_artifact, owner:get_tile(owner:facing(), 1) or owner:current_tile())
    end

    action.on_action_end_func = function()
        if not executed then
            -- keep trying to execute
            owner:queue_action(create_action(owner))
        end
    end

    return action
end

---@param augment Augment
function augment_init(augment)
    local owner = augment:owner()

    -- If we've bugged this program, it won't activate, so do nothing.
    if owner:get_augment("BattleNetwork6.Bugs.TangoDisabled") ~= nil then return end

    -- We're in pvp, and we aren't bugged! So let's activate this bad boy!
    local component = owner:create_component(Lifetime.ActiveBattle)

    component.on_update_func = function(self)
        if owner:health() > math.floor(owner:max_health() / 4) or owner:is_inactionable() or owner:is_immobile() then
            return
        end

        -- Only for pvp. Needs at least one player of the enemy team
        local find_func = function(entity) return not owner:is_team(entity:team()) end

        -- If enemy players are not found, then do nothing
        if #Field.find_players(find_func) == 0 then return end

        owner:queue_action(create_action(owner))
        self:eject()
    end
end

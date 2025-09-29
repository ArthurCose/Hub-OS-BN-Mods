---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local texture = bn_assets.load_texture("guardian.png")
local anim_path = bn_assets.fetch_animation_path("guardian.animation")
local GUARDIAN_HEIGHT = 31

local thunder_texture = bn_assets.load_texture("bn3_lightning.png")
local thunder_anim_path = bn_assets.fetch_animation_path("bn3_lightning.animation")

local audio = bn_assets.load_audio("elementman_thunder.ogg")

local function punish(user, team)
    local action = Action.new(user, "ATTACK")

    action:set_lockout(ActionLockout.new_sequence())

    local props = CardProperties.new()

    props.short_name = "Punishment"
    props.damage = 200
    props.time_freeze = true
    props.prevent_time_freeze_counter = true

    action:set_card_properties(props)

    local step = action:create_step()

    local time = 0

    action:add_anim_action(4, function()
        local enemy_list = Field.find_characters(function(ch)
            if ch:team() == team then return true end
            return false
        end)

        for i = 1, #enemy_list, 1 do
            local spell = Spell.new(Team.Other)
            spell:set_hit_props(
                HitProps.new(
                    200,
                    Hit.PierceInvis | Hit.Flash,
                    Element.None,
                    user:context(),
                    Drag.None
                )
            )

            spell:set_texture(thunder_texture)

            local spell_anim = spell:animation()
            spell_anim:load(thunder_anim_path)

            spell_anim:set_state("DEFAULT")
            spell_anim:on_complete(function()
                spell:erase()
            end)

            spell.on_update_func = function()
                spell:attack_tile()
            end

            Field.spawn(spell, enemy_list[i]:current_tile())
        end

        Field.shake(5, 60)

        Resources.play_audio(audio)
    end)

    action.on_animation_end_func = function()
        local artifact = bn_assets.MobMove.new("MEDIUM_END")
        artifact:set_offset(0, -GUARDIAN_HEIGHT // 2)

        local i = 0
        artifact.on_update_func = function()
            i = i + 1

            if i == 2 then
                user:hide()
            end
        end

        Field.spawn(artifact, user:current_tile())
    end

    step.on_update_func = function()
        time = time + 1

        if time == 60 then
            step:complete_step()
            return
        end
    end

    action.on_action_end_func = function()
        user:erase()
    end

    user:queue_action(action)
end

---@param user Entity
function card_init(user)
    local action = Action.new(user)

    action:set_lockout(ActionLockout.new_sequence())

    action.on_execute_func = function()
        local tile = user:get_tile(user:facing(), 1)
        if not tile then return end

        local artifact = bn_assets.MobMove.new("MEDIUM_START")
        artifact:set_offset(0, -GUARDIAN_HEIGHT // 2)

        artifact.on_spawn_func = function()
            if not tile:is_walkable() then return end

            local guardian = Obstacle.new(Team.Other)
            guardian:set_health(2048)
            guardian:set_height(GUARDIAN_HEIGHT)
            guardian:set_owner(user:team())
            guardian:add_aux_prop(AuxProp.new():declare_immunity(~Hit.Impact))
            guardian:set_texture(texture)

            local guardian_anim = guardian:animation()
            guardian_anim:load(anim_path)
            guardian_anim:set_state("IDLE")

            local activated = false
            local punishment_defense = DefenseRule.new(DefensePriority.Body, DefenseOrder.Always)

            punishment_defense.defense_func = function(defense, attacker, defender, hit_props)
                if hit_props.flags & Hit.Drain ~= 0 then return end
                if hit_props.damage == 0 then return end

                if activated then
                    return
                end

                punish(guardian, attacker:team())
                activated = true
            end

            punishment_defense.filter_func = function(hit_props)
                hit_props.damage = 1
                return hit_props
            end

            guardian:add_defense_rule(punishment_defense)

            Field.spawn(guardian, tile)
        end

        Field.spawn(artifact, tile)
    end

    return action
end

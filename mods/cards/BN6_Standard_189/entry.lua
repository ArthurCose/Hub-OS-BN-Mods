local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("antidmg.ogg")
local SHURIKEN_TEXTURE = Resources.load_texture("shuriken.png")
local SHURIKEN_ANIMATON_PATH = "shuriken.animation"

function card_init(user, props)
    local action = Action.new(user)

    action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
    action.on_execute_func = function()
        local antidamage_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)

        local has_blocked = false

        antidamage_rule.defense_func = function(defense, attacker, defender)
            local hit_props = attacker:copy_hit_props()

            --Simulate cursor removing traps
            if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
                defender:remove_defense_rule(antidamage_rule)
                return
            end

            if hit_props.damage >= 10 then
                defense:block_damage()
                if not has_blocked then
                    Player.from(defender):queue_action(poof_user(user, props))
                    defender:remove_defense_rule(antidamage_rule)
                end
            end
        end

        user:add_defense_rule(antidamage_rule)
    end

    return action
end

function poof_user(user, props)
    local action = Action.new(user)
    local field = user:field()
    local tile = targeting(user, field)

    if tile == nil then
        return action
    end

    action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
    action.on_execute_func = function(self, user)
        Resources.play_audio(AUDIO, AudioBehavior.Default)

        -- hide the player and disable hitbox
        user:hide()
        user:enable_hitbox(false)

        -- spawn poof
        local poof = bn_assets.ParticlePoof.new()
        local poof_position = user:movement_offset()
        poof_position.y = poof_position.y - user:height() / 2
        poof:set_offset(poof_position.x, poof_position.y)
        field:spawn(poof, user:current_tile())

        -- spawn shuriken
        local spell = create_shuriken_spell(user, props)
        field:spawn(spell, tile)

        local cooldown = 60
        local step1 = self:create_step()
        step1.on_update_func = function(self)
            if cooldown <= 0 then
                self:complete_step()
            else
                cooldown = cooldown - 1
            end
        end
    end

    action.on_action_end_func = function()
        user:reveal()
        user:enable_hitbox(true)
    end

    return action
end

function create_shuriken_spell(user, props)
    local spell = Spell.new(user:team())
    spell:set_facing(user:facing())
    spell:sprite():set_layer(-5)
    spell:set_texture(SHURIKEN_TEXTURE)
    local spell_anim = spell:animation()
    spell_anim:load(SHURIKEN_ANIMATON_PATH)
    spell_anim:set_state("FLY")

    spell:set_hit_props(
        HitProps.new(
            props.damage,
            Hit.Impact | Hit.Flinch,
            props.element,
            props.secondary_element,
            user:context(),
            Drag.None
        )
    )

    spell:set_tile_highlight(Highlight.Solid)

    local total_frames = 20
    local increment_x = 4
    local increment_y = 8

    if spell:facing() == Direction.Left then
        increment_x = -increment_x
    end

    local x = total_frames * -increment_x
    local y = total_frames * -increment_y


    spell.on_update_func = function()
        x = x + increment_x
        y = y + increment_y

        if y >= 0 then
            local tile = spell:current_tile()
            spell:set_tile_highlight(Highlight.None)

            if not tile:is_walkable() then
                spell:erase()
            else
                tile:attack_entities(spell)

                spell.on_update_func = nil

                spell_anim:set_state("SHINE")
                spell_anim:on_frame(5, function()
                    spell:hide()
                end)
                spell_anim:on_frame(7, function()
                    spell:reveal()
                end)
                spell_anim:on_frame(9, function()
                    spell:hide()
                end)
                spell_anim:on_frame(11, function()
                    spell:reveal()
                end)
                spell_anim:on_complete(function()
                    spell:erase()
                end)
            end

            x = 0
            y = 0
        end

        spell:set_offset(x, y)
    end

    return spell
end

function targeting(user, field)
    local tile;

    local enemy_filter = function(character)
        return character:team() ~= user:team()
    end

    local enemy_list = nil
    enemy_list = field:find_nearest_characters(user, enemy_filter)
    if #enemy_list > 0 then tile = enemy_list[1]:current_tile() else tile = nil end

    if not tile then
        return nil
    end

    return tile
end

local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")
local AUDIO = bn_helpers.load_audio("antidmg.ogg")

function card_init(user, props)
    local action = Action.new(user, "PLAYER_IDLE")
    local new_props = action:copy_card_properties()
    new_props.short_name = "????"
    action:set_card_properties(new_props)
    action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
    action.on_execute_func = function(self, user)
        local step1 = self:create_step()
        local antidamage_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly) -- Keristero's Guard is 0
        local field = user:field()

        antidamage_rule.has_blocked = false

        antidamage_rule.can_block_func = function(judge, attacker, defender)
            local hit_props = attacker:copy_hit_props()

            --Simulate cursor removing traps
            if hit_props.element == Element.Cursor then
                defender:remove_defense_rule(antidamage_rule)
                return
            end

            if hit_props.damage >= 10 then
                judge:block_damage()
                if not antidamage_rule.has_blocked then
                    Player.from(defender):queue_action(poof_user(user, props))
                    defender:remove_defense_rule(antidamage_rule)
                end
            end
        end
        step1.on_update_func = function(self)
            user:add_defense_rule(antidamage_rule)
            self:complete_step()
        end
    end
    return action
end

function poof_user(user, props)
    if user:deleted() then return nil end

    local action = Action.new(user, "PLAYER_IDLE")
    local spell_texture = Resources.load_texture("shuriken.png")
    local field = user:field()
    local tile = targeting(user, field)

    if tile == nil then
        return action
    end

    local spell = create_shuriken_spell(user, spell_texture, props, tile)
    action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
    action.on_execute_func = function(self, user)
        Resources.play_audio(AUDIO, AudioBehavior.Default)
        local step1 = self:create_step()
        local fx = bn_helpers.ParticlePoof.new()
        user:hide()
        user:enable_hitbox(false)
        field:spawn(fx, user:current_tile())
        field:spawn(spell, tile)
        local cooldown = 60
        step1.on_update_func = function(self)
            if cooldown > 0 then
                cooldown = cooldown - 1
                return
            end
            user:reveal()
            user:enable_hitbox(true)
            self:complete_step()
        end
    end

    action.on_end_func = function()
        user:reveal()
        user:enable_hitbox(true)
    end
    return action
end

function create_shuriken_spell(user, texture, props, desired_tile)
    if user:deleted() then return Spell.new(Team.Other) end

    local spell = Spell.new(user:team())
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

    desired_tile:set_highlight(Highlight.Flash)

    local y = 192

    spell.increment_y = 8

    local field = user:field()
    spell:set_offset(spell:offset().x * 0.5, spell:offset().y - y * 0.5)
    spell.animate_once = true
    spell.dest = desired_tile
    spell.can_move_to_func = function(tile)
        return true
    end
    spell.on_update_func = function(self)
        if math.ceil(y / 2) <= 0 then
            local tile = self:current_tile()
            if tile == self.dest and self.dest:is_walkable() then
                self:current_tile():attack_entities(self)
                if self.animate_once then
                    self.animate_once = false
                    local fx = Spell.new(self:team())
                    fx:set_texture(texture)
                    local fx_anim = fx:animation()
                    fx_anim:load("shuriken.animation")
                    fx_anim:set_state("SHINE")
                    fx_anim:on_frame(5, function()
                        fx:hide()
                    end)
                    fx_anim:on_frame(7, function()
                        fx:reveal()
                    end)
                    fx_anim:on_frame(9, function()
                        fx:hide()
                    end)
                    fx_anim:on_frame(11, function()
                        fx:reveal()
                    end)
                    fx_anim:on_complete(function()
                        fx:erase()
                        if spell and not spell:deleted() then spell:erase() end
                    end)
                    field:spawn(fx, self.dest)
                end
            end
        else
            y = y - self.increment_y
        end
    end

    spell.on_collision_func = function(self, other)
        self:erase()
    end

    return spell
end

function targeting(user, field)
    local tile, target;

    local enemy_filter = function(character)
        return character:team() ~= user:team()
    end

    local enemy_list = nil
    enemy_list = field:find_nearest_characters(user, enemy_filter)
    if #enemy_list > 0 then tile = enemy_list[1]:current_tile() else tile = nil end

    -- else
    --     tile = target:current_tile()
    -- end

    if not tile then
        return nil
    end

    return tile
end

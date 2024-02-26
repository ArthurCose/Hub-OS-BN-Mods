function card_init(user, props)
    local action = Action.new(user, "PLAYER_IDLE")
    local new_props = action:copy_card_properties()
    new_props.short_name = "????"
    action:set_card_properties(new_props)
    action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
    action.on_execute_func = function(self, user)
        local step1 = self:create_step()
        local antidamage_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly) -- Keristero's Guard is 0
        antidamage_rule.has_blocked = false
        local field = user:field()
        antidamage_rule.can_block_func = function(judge, attacker, defender)
            local hit_props = attacker:copy_hit_props()
            local temp_action = poof_user(user, field:get_entity(hit_props.aggressor), props)
            if temp_action ~= nil then antidamage_rule.second_action = temp_action else return end
            if hit_props.element == Element.Cursor then
                defender:remove_defense_rule(antidamage_rule)
                return
            end --Simulate cursor removing traps
            if hit_props.damage >= 10 then
                judge:block_damage()
                if not antidamage_rule.has_blocked then
                    Player.from(defender):queue_action(antidamage_rule.second_action)
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

function poof_user(user, aggressor, props)
    if user:deleted() or aggressor == nil then return nil end
    local action = Action.new(user, "PLAYER_IDLE")
    local spell_texture = Resources.load_texture("shuriken.png")
    local field = user:field()
    local tile = targeting(user, aggressor, field)
    if tile == nil then
        return action
    end
    local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")
    local spell = create_shuriken_spell(user, spell_texture, props, tile)
    action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
    action.on_execute_func = function(self, user)
        local step1 = self:create_step()
        local fx = bn_helpers.ParticlePoof.new()
        user:hide()
        user:enable_hitbox(false)
        field:spawn(fx, user:current_tile())
        field:spawn(spell, user:current_tile())
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
    return action
end

function create_shuriken_spell(user, texture, props, desired_tile)
    if user:deleted() then return Spell.new(Team.Other) end
    local spell = Spell.new(user:team())
    spell:set_hit_props(
        HitProps.new(
            props.damage,
            Hit.Impact | Hit.Flinch,
            Element.Sword, --Change to props.element later and set secondary element.
            user:context(),
            Drag.None
        )
    )
    desired_tile:set_highlight(Highlight.Flash)
    spell.slide_rate = 8
    local y = 192
    local user_tile = user:current_tile()
    local distance = math.abs((user_tile:x() + user_tile:y()) - (desired_tile:x() + desired_tile:y())) * 8
    print(distance)
    spell.increment_y = math.floor(y / distance)
    print(spell.increment_y)
    local field = user:field()
    spell:set_offset(spell:offset().x * 0.5, spell:offset().y - y * 0.5)
    spell.animate_once = true
    spell.dest = desired_tile
    spell.can_move_to_func = function(tile)
        return true
    end
    spell.on_update_func = function(self)
        if not self:is_sliding() then
            local ref = self
            self:slide(self.dest, (self.slide_rate), (0), nil)
        end
        if self:current_tile() == self.dest and self.dest:is_walkable() then
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
                end)
                field:spawn(fx, self.dest)
            end
            self:erase()
        end
    end
    return spell
end

function targeting(user, target, field)
    local tile
    if not target or target and target:deleted() then
        local enemy_filter = function(character)
            return character:team() ~= user:team()
        end

        local enemy_list = nil
        enemy_list = field:find_nearest_characters(user, enemy_filter)
        if #enemy_list > 0 then tile = enemy_list[1]:current_tile() else tile = nil end
    else
        tile = target:current_tile()
    end
    if not tile then
        return nil
    end
    return tile
end

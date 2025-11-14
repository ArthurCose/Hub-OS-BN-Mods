function card_init(user)
    local action = Action.new(user)

    local tracked_entities = {}
    local component
    local defense_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)
    local uninstalled = false

    local uninstall_all = function()
        if uninstalled then return end

        uninstalled = true

        user:remove_defense_rule(defense_rule)
        component:eject()

        for _, entity in pairs(tracked_entities) do
            if not entity:deleted() then
                entity:remove_aux_prop(entity._intercept_aux_prop)
                entity:remove_aux_prop(entity._interrupt_aux_prop)
            end
        end
    end

    local activate =
        function(opponent, opponent_action)
            local card = opponent_action:copy_card_properties()
            local generated_action = Action.from_card(user, card)

            if not generated_action then
                return
            end

            -- create a new action to notify opponents about AntiNavi
            local wrapped_action = Action.new(user, "CHARACTER_IDLE")

            -- never complete, force the generated_action to kick us out
            wrapped_action:set_lockout(ActionLockout.new_sequence())

            local wrapped_action_props = CardProperties.new()
            wrapped_action_props.short_name = "AntiNavi"
            wrapped_action_props.time_freeze = true
            wrapped_action_props.prevent_time_freeze_counter = true
            wrapped_action:set_card_properties(wrapped_action_props)

            wrapped_action.on_execute_func = function()
                -- use the stolen action
                user:queue_action(generated_action)
            end

            user:queue_action(wrapped_action)

            local alert_artifact = TrapAlert.new()
            local alert_sprite = alert_artifact:sprite()
            alert_sprite:set_never_flip(true)
            alert_sprite:set_offset(0, -opponent:height() / 2)
            alert_sprite:set_layer(-5)

            Field.spawn(alert_artifact, opponent:current_tile())

            uninstall_all()
        end

    local track = function(opponent)
        if opponent:team() == user:team() then
            -- not an opponent
            return
        end

        if tracked_entities[opponent:id()] then
            return
        end

        local intercept_auxprop = AuxProp.new()
            :require_card_tag("NAVI")
            :require_card_not_class(CardClass.Giga)
            :require_card_not_class(CardClass.Recipe)
            :intercept_action(function(opponent_action)
                activate(opponent, opponent_action)
                return nil
            end)

        local interrupt_auxprop = AuxProp.new()
            :require_card_tag("NAVI")
            :require_card_not_class(CardClass.Giga)
            :require_card_not_class(CardClass.Recipe)
            :interrupt_action(function(opponent_action)
                activate(opponent, opponent_action)
            end)

        opponent:add_aux_prop(intercept_auxprop)
        opponent:add_aux_prop(interrupt_auxprop)
        opponent._intercept_aux_prop = intercept_auxprop
        opponent._interrupt_aux_prop = interrupt_auxprop

        tracked_entities[opponent:id()] = opponent
    end

    action.on_execute_func = function()
        component = user:create_component(Lifetime.Local)

        component.on_update_func = function()
            Field.find_obstacles(track)
            Field.find_characters(track)
        end

        defense_rule.on_replace_func = uninstall_all

        defense_rule.defense_func = function(defense, _, _, hit_props)
            if defense:damage_blocked() then return end

            if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
                uninstall_all()
            end
        end

        user:add_defense_rule(defense_rule)
    end

    return action
end

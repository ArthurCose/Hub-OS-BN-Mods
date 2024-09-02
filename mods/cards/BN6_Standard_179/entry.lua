function card_init(player)
    local action = Action.new(player, "CHARACTER_IDLE");
    action.on_execute_func = function(self, user)
        local intangible_rule = IntangibleRule.new();
        -- 6 seconds at 60 frames per second.
        intangible_rule.duration = 360;
        -- This is the default weakness, but this is to show you how to set it.
        intangible_rule.hit_weaknesses = Hit.PierceInvis;

        -- Create a rule to cause sprite flickering
        local component = user:create_component(Lifetime.Scene)

        -- Create a timer that ticks down.
        local timer = 2
        local visible = false
        local sprite = user:sprite()

        -- Use an update function to tick this forward.
        component.on_update_func = function()
            if visible then
                local color = sprite:color()
                color.a = 0
                sprite:set_color(color)
            end

            -- update timer
            timer = timer - 1
            if timer > 0 then return end
            timer = 2

            -- flip visibility
            visible = not visible
        end

        intangible_rule.on_deactivate_func = function()
            component:eject()
        end

        -- Add the rule. Use false to remove a rule, and don't pass a rule in to use a default intangibility.
        user:set_intangible(true, intangible_rule);

        -- Resources.play_audio(AudioType.Invisible)
    end
    return action
end

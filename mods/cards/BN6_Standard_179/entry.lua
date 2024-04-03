function card_init(player)
    local action = Action.new(player, "PLAYER_IDLE");
    action.on_execute_func = function(self, user)
        local intangible_rule = IntangibleRule.new();
        -- 6 seconds at 60 frames per second.
        intangible_rule.duration = 360;
        -- This is the default weakness, but this is to show you how to set it.
        intangible_rule.hit_weaknesses = Hit.PierceInvis;

        -- Create a rule to cause sprite flickering
        intangible_rule.flicker = user:create_component(Lifetimes.Scene)

        -- Create a timer that ticks down.
        intangible_rule.flicker.timer = 2

        -- Use an update function to tick this forward.
        intangible_rule.flicker.on_update_func = function(flicker)
            local owner = flicker:owner()
            if owner:deleted() then return end
            flicker.timer = flicker.timer - 1
            if flicker.timer > 0 then return end
            local sprite = owner:sprite()
            sprite:set_visible(not sprite:visible())
            flicker.timer = 2
        end

        intangible_rule.on_deactivate_func = function()
            intangible_rule.flicker:eject()
            user:reveal()
        end

        -- Add the rule. Use false to remove a rule, and don't pass a rule in to use a default intangibility.
        user:set_intangible(true, intangible_rule);


        user:hide()

        -- Resources.play_audio(AudioType.Invisible)
    end
    return action
end

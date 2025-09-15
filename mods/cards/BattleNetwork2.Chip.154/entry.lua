function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_IDLE");
    local frames = { { 1, 30 } }

    action:override_animation_frames(frames);

    action.on_execute_func = function(self, user)
        user:apply_status(Hit.StoneBody, 1800)
    end

    return action;
end

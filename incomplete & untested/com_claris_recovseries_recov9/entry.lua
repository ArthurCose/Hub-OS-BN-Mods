function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_IDLE")
    action:set_lockout(ActionLockout.new_sequence())
    action.on_execute_func = function(self, user)
        local step1 = self:create_step()
        step1.on_update_func = function(self)
            local recov = create_recov("DEFAULT", user)
            actor:field():spawn(recov, actor:current_tile())
            self:complete_step()
        end
    end
    return action
end

function create_recov(animation_state, user)
    local spell = Spell.new(Team.Other)

    spell:set_texture(Resources.load_texture("spell_heal.png"), true)
    spell:set_facing(user:facing())
    spell:set_hit_props(
        HitProps.new(
            0,
            Hit.None,
            Element.None,
            user:context(),
            Drag.None
        )
    )
    spell:sprite():set_layer(-1)
    local anim = spell:animation()
    anim:load("spell_heal.animation")
    anim:set_state(animation_state)
    spell:animation():on_complete(
        function()
            spell:erase()
        end
    )

    spell.on_delete_func = function(self)
        self:erase()
    end

    spell.can_move_to_func = function(tile)
        return true
    end

    Resources.play_audio(Resources.load_audio("sfx.ogg"))

    return spell
end

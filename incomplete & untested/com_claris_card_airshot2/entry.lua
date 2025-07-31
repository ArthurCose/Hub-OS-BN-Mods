nonce = function() end

local DAMAGE = 30
local BUSTER_TEXTURE = Resources.load_texture("AirShot.png")
local AUDIO = Resources.load_audio("sfx.ogg")



function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_SHOOT")

    action:set_lockout(ActionLockout.new_animation())

    action.on_execute_func = function(self, user)
        local buster = self:create_attachment("BUSTER")
        buster:sprite():set_texture(BUSTER_TEXTURE, true)
        buster:sprite():set_layer(-1)

        local buster_anim = buster:animation()
        buster_anim:load("airshot.animation")
        buster_anim:set_state("DEFAULT")

        local tile = user:get_tile(user:facing(), 1)
        if tile then
            local cannonshot = create_attack(user, props)
            Field.spawn(cannonshot, tile)
        end
    end
    return action
end

function create_attack(user, props)
    local spell = Spell.new(user:team())
    spell:set_facing(user:facing())
    spell.slide_started = false
    local direction = spell:facing()
    spell:set_hit_props(
        HitProps.new(
            props.damage,
            Hit.Impact | Hit.Drag | Hit.Flinch,
            Element.Wind,
            user:context(),
            Drag.new(direction, 1)
        )
    )
    spell.on_update_func = function(self)
        self:current_tile():attack_entities(self)
        if self:is_sliding() == false then
            if self:current_tile():is_edge() and self.slide_started then
                self:delete()
            end

            local dest = self:get_tile(direction, 1)
            local ref = self
            self:slide(dest, (0), (0),
                function()
                    ref.slide_started = true
                end
            )
        end
    end

    spell.on_collision_func = function(self, other)
        self:delete()
    end
    spell.on_attack_func = function(self, other)
    end

    spell.on_delete_func = function(self)
        self:erase()
    end

    spell.can_move_to_func = function(tile)
        return true
    end

    Resources.play_audio(AUDIO)
    return spell
end

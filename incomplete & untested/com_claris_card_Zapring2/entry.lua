nonce = function() end

local DAMAGE = 40
local TEXTURE = Resources.load_texture("spell_zapring.png")
local BUSTER_TEXTURE = Resources.load_texture("buster_zapring.png")
local AUDIO = Resources.load_audio("fwish.ogg")



--[[
    1. megaman loads buster
    2. zapring flies out
--]]

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_SHOOT")

    action:set_lockout(ActionLockout.new_animation())

    action.on_execute_func = function(self, user)
        local buster = self:create_attachment("BUSTER")
        buster:sprite():set_texture(BUSTER_TEXTURE, true)
        buster:sprite():set_layer(-1)

        local buster_anim = buster:animation()
        buster_anim:load("buster_zapring.animation")
        buster_anim:set_state("DEFAULT")

        local cannonshot = create_zap("DEFAULT", user, props)
        local tile = user:get_tile(user:facing(), 1)
        actor:field():spawn(cannonshot, tile)
    end
    return action
end

function create_zap(animation_state, user, props)
    local spell = Spell.new(user:team())
    spell:set_texture(TEXTURE, true)
    spell:set_tile_highlight(Highlight.Solid)
    spell:set_height(16.0)
    local direction = user:facing()
    spell.slide_started = false

    spell:set_hit_props(
        HitProps.new(
            props.damage,
            Hit.Impact | Hit.Paralyze | Hit.Flinch,
            Element.Elec,
            user:context(),
            Drag.None
        )
    )

    local anim = spell:animation()
    anim:load("spell_zapring.animation")
    anim:set_state(animation_state)

    spell.on_update_func = function(self)
        self:current_tile():attack_entities(self)

        if self:is_sliding() == false then
            if self:current_tile():is_edge() and self.slide_started then
                self:delete()
            end

            local dest = self:get_tile(direction, 1)
            local ref = self
            self:slide(dest, (4), (0),
                function()
                    ref.slide_started = true
                end
            )
        end
    end

    spell.on_attack_func = function(self, other)
        -- nothing
    end

    spell.on_collision_func = function(self, other)
        self:erase()
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

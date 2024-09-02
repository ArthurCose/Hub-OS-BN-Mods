local arrow_texture = Resources.load_texture("roll_arrow.png")
local bow_texture = Resources.load_texture("bow.png")

function card_init(player, props)
    local action = Action.new(player, "CHARACTER_SHOOT")
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local facing = user:facing()
        local do_attack = function()
            local spell = Spell.new(user:team())
            spell:set_facing(facing)
            spell:set_offset(-30.0 * 0.5, -82.0 * 0.5)
            spell:set_texture(arrow_texture)
            spell.slide_started = false
            local direction = facing
            spell:set_hit_props(
                HitProps.from_card(
                    props,
                    user:context(),
                    Drag.None
                )
            )

            spell.on_update_func = function(self)
                local tile = self:current_tile()
                tile:attack_entities(self)
                if not self:is_sliding() then
                    if tile:is_edge() and self.slide_started then
                        self:erase()
                    end

                    local dest = self:get_tile(direction, 1)
                    local ref = self
                    self:slide(dest, 6, function() ref.slide_started = true end)
                end
            end

            spell.on_attack_func = function(self, other)
                local to_remove = other:field_card(1)
                if to_remove then
                    other:remove_field_card(1)
                end
            end

            spell.on_collision_func = function(self, other)
                self:erase();
            end

            spell:set_tile_highlight(Highlight.Solid)

            spell.can_move_to_func = function(tile)
                return true
            end

            user:field():spawn(spell, user:get_tile(facing, 1))
        end
        self:add_anim_action(2, do_attack)
        self:add_anim_action(1, function()
            local buster = self:create_attachment("BUSTER")
            buster:sprite():set_texture(bow_texture)
            buster:sprite():set_layer(-1)

            local buster_anim = buster:animation()
            buster_anim:load("bow.animation")
            buster_anim:set_state("FIRE")
        end)
    end
    return action
end

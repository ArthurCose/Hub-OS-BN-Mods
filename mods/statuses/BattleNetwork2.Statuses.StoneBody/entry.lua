function status_init(status)
    local owner = status:owner()

    owner:sprite():set_shader_effect(SpriteShaderEffect.Grayscale)

    local stone_defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)

    stone_defense_rule.can_block_func = function(judge, attacker, defender, hit_props)
        -- Only block if the damage isn't guard piercing.
        if hit_props.flags & Hit.PierceGuard ~= Hit.PierceGuard then
            local stone_bod_aux_prop = AuxProp.new()
                :decrease_hit_damage("DAMAGE - 1")

            -- Eject after 1 frame so as only to block while the damage is incoming.
            stone_bod_aux_prop:immediate()

            -- Add the property to the player.
            defender:add_aux_prop(stone_bod_aux_prop)
        end
    end

    owner:add_defense_rule(stone_defense_rule)

    status.on_delete_func = function(self)
        owner:remove_defense_rule(stone_defense_rule)
        owner:sprite():set_shader_effect(SpriteShaderEffect.Grayscale)
    end
end

local bn_assets = require("BattleNetwork.Assets")

local BARRIER_TEXTURE = bn_assets.load_texture("bn6_barriers.png")
local BARRIER_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_barriers.animation")
local BARRIER_UP_SOUND = bn_assets.load_audio("barrier.ogg")

local function create_barrier(user)
    Resources.play_audio(BARRIER_UP_SOUND)

    local HP = 10

    local fading = false
    local blown_away = false
    local remove_barrier = false

    local barrier = user:create_node()
    barrier:set_layer(3)
    barrier:set_texture(BARRIER_TEXTURE)

    local barrier_animation = Animation.new(BARRIER_ANIMATION_PATH)
    barrier_animation:set_state("BARRIER")
    barrier_animation:apply(barrier)

    barrier_animation:set_playback(Playback.Loop)

    local barrier_defense_rule = DefenseRule.new(DefensePriority.Barrier, DefenseOrder.Always)
    barrier_defense_rule.defense_func = function(defense, attacker, defender, hit_props)
        if hit_props.element == Element.Wind or hit_props.secondary_element == Element.Wind then blown_away = true end

        if hit_props.flags & Hit.Drain ~= 0 then return end

        HP = HP - hit_props.damage

        defense:block_damage()
    end

    local aura_animate_component = user:create_component(Lifetime.ActiveBattle)

    aura_animate_component.on_update_func = function(self)
        barrier_animation:apply(barrier)
        barrier_animation:update()
    end

    local aura_destroy_component = user:create_component(Lifetime.Battle)

    local destroy_aura = false

    barrier_defense_rule.on_replace_func = function()
        aura_animate_component:eject()
        aura_destroy_component:eject()
        user:sprite():remove_node(barrier)
    end

    aura_destroy_component.on_update_func = function(self)
        if (blown_away or HP <= 0 or destroy_aura) then
            remove_barrier = true
        end

        if remove_barrier and not fading then
            fading = true
            user:remove_defense_rule(barrier_defense_rule)

            barrier_animation:on_complete(function()
                user:sprite():remove_node(barrier)
                aura_animate_component:eject()
                aura_destroy_component:eject()
            end)

            if blown_away then
                local initialX = barrier:offset().x
                local initialY = barrier:offset().y
                local facing_check = 1
                if user:facing() == Direction.Left then
                    facing_check = -1
                end

                barrier_animation:on_frame(1, function()
                    barrier:set_offset(facing_check * (-25 - initialX) * 0.5, -20 + initialY * 0.5)
                end)

                barrier_animation:on_frame(2, function()
                    barrier:set_offset(facing_check * (-50 - initialX) * 0.5, -40 + initialY * 0.5)
                end)

                barrier_animation:on_frame(3, function()
                    barrier:set_offset(facing_check * (-75 - initialX) * 0.5, -60 + initialY * 0.5)
                end)
            end
        end
    end

    user:add_defense_rule(barrier_defense_rule)
end

---@param augment Augment
function augment_init(augment)
    local player = augment:owner()

    local first_barrier_component = player:create_component(Lifetime.Scene)

    local delay = 1
    first_barrier_component.on_update_func = function(self)
        if delay > 0 then
            delay = delay - 1
        else
            create_barrier(player)
            self:eject()
        end
    end
end

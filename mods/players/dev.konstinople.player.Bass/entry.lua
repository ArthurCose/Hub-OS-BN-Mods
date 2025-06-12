---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")
local buster_shooting = require("attacks/buster_shooting.lua")
local helz_rolling = require("attacks/helz_rolling.lua")

---@param player Entity
function player_init(player)
    player:set_height(62)
    player:load_animation("battle.animation")
    player:set_texture(Resources.load_texture("battle.png"))
    player:set_fully_charged_color(Color.new(120, 63, 152))
    player:set_charge_position(10, -35)

    -- create cape
    local cape_sync_node = player:create_sync_node()
    cape_sync_node:animation():load("cape.animation")
    local cape_sprite = cape_sync_node:sprite()
    cape_sprite:set_texture(Resources.load_texture("cape.png"))
    cape_sprite:use_root_shader(true)

    -- emotions
    local synchro = EmotionsLib.new_synchro()
    synchro:set_ring_offset(3, -35)
    synchro:implement(player)

    player.on_counter_func = function()
        player:set_emotion("SYNCHRO")
    end

    -- attacks
    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        return buster_shooting(player)
    end

    player.calculate_card_charge_time_func = function(self, card)
        local can_charge =
            not card.time_freeze
            and card.element == Element.None
            and card.secondary_element == Element.None

        if can_charge then
            return 100
        end
    end

    player.charged_card_func = function()
        return helz_rolling(player)
    end

    -- intro
    player.intro_func = function()
        local action = Action.new(player, "CHARACTER_SUMMON_START")
        action:set_lockout(ActionLockout.new_sequence())
        action:override_animation_frames({ { 1, 4 }, { 2, 4 }, { 3, 18 } })

        local animation = player:animation()
        local sync_node

        local start_step = action:create_step()

        action.on_execute_func = function()
            animation:on_complete(function()
                start_step:complete_step()
            end)
        end

        local loop_step = action:create_step()
        loop_step.on_update_func = function()
            loop_step.on_update_func = nil

            animation:set_state("CHARACTER_SUMMON_LOOP")
            animation:set_playback(Playback.Loop)

            sync_node = player:create_sync_node()
            sync_node:sprite():set_texture(player:texture())
            local sync_anim = sync_node:animation()
            sync_anim:load("summon_hand.animation")

            local i = 0
            animation:on_complete(function()
                i = i + 1

                if i >= 6 then
                    loop_step:complete_step()
                end
            end)
        end

        local pause_step = action:create_step()
        pause_step.on_update_func = function()
            pause_step.on_update_func = nil

            player:remove_sync_node(sync_node)
            sync_node = nil

            animation:set_state("CHARACTER_SUMMON_START", { { 3, 6 } })
            animation:on_complete(function()
                pause_step:complete_step()
            end)
        end

        local final_step = action:create_step()
        final_step.on_update_func = function()
            final_step.on_update_func = nil

            animation:set_state("CHARACTER_BUSTER_SHOOTING_END", { { 2, 4 }, { 3, 4 } })
            animation:on_complete(function()
                final_step:complete_step()
            end)
        end

        action.on_action_end_func = function()
            if sync_node then
                player:remove_sync_node(sync_node)
            end
        end

        return action
    end
end

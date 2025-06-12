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
end

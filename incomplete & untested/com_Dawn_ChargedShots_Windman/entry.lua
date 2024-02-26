


function player_init(player)
    player:set_name("Windman")
    player:set_health(1000)
    player:set_element(Element.Wind)
    player:set_height(70.0)
    player:set_shadow(Shadow.Small)
    player:show_shadow(true)

    local WindRack = require("Chips/WindRack/entry.lua")
    local AirShot = require("Chips/AirShot/entry.lua")

    local base_texture = Resources.load_texture("windman_EXE4.5.png")
    local base_animation_path = "windman.animation"
    local base_charge_color = Color.new(255, 0, 255, 0)

    player:load_animation(base_animation_path)
    player:set_texture(base_texture, true)
    player:set_fully_charged_color(base_charge_color)
    player:set_charge_position(4, -35)

    player.normal_attack_func = function(player)
        local props = CardProperties:new()
        props.damage = 10 + (player:attack_level()*5)
        return AirShot.card_init(player, props)
    end

    player.charged_attack_func = function(player)
        local props = CardProperties:new()
        props.damage = 90 + (player:attack_level() * 10)
        return WindRack.card_init(player, props)
    end
end

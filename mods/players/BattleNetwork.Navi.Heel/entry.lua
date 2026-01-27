---@param player Entity
function player_init(player)
    player:set_height(39.0)
    player:set_texture(Resources.load_texture("battle.png"))
    player:load_animation("battle.animation")
    player:set_fully_charged_color(Color.new(57, 198, 243, 255))
    player:set_charge_position(0, -20)

    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        local card_props = CardProperties.from_package("BattleNetwork6.Class01.Standard.058")
        card_props.damage = player:attack_level() * 10

        return Action.from_card(player, card_props)
    end

    player.special_attack_func = function()
        return Action.new(player, "CHEER")
    end
end

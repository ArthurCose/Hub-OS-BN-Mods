---@param player Entity
function player_init(player)
    player:set_height(70.0)
    player:load_animation("battle.animation")
    player:set_texture(Resources.load_texture("battle.png"))
    player:set_fully_charged_color(Color.new(255, 200, 200, 255))
    player:set_charge_position(4, -34)

    player.normal_attack_func = function(self)
        return Buster.new(self, false, player:attack_level())
    end

    player.charged_attack_func = function(self)
        local card_properties = CardProperties.from_package("BattleNetwork4.Class05.Secret.001")
        card_properties.damage = player:attack_level() * 10
        return Action.from_card(self, card_properties)
    end
end

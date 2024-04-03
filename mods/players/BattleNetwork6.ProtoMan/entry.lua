function player_init(player)
    player:set_height(47.0)
    player:load_animation("battle.animation")
    player:set_texture(Resources.load_texture("battle.png"))

    player.normal_attack_func = function(self)
        return Buster.new(self, false, player:attack_level())
    end

    player.charged_attack_func = function(self)
        local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.071")
        card_properties.damage = 30 + player:attack_level() * 10
        return Action.from_card(self, card_properties)
    end
end

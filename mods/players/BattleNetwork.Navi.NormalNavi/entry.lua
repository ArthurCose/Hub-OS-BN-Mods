function player_init(player)
    player:set_height(40)
    player:load_animation("battle.animation")
    player:set_texture("battle.png")

    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        return Buster.new(player, true, player:attack_level() * 10)
    end
end

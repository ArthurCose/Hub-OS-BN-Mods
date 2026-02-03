---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

---@param player Entity
function player_init(player)
    player:set_height(39.0)
    player:set_texture(Resources.load_texture("battle.png"))
    player:load_animation("battle.animation")
    player:set_fully_charged_color(Color.new(57, 198, 243, 255))
    player:set_charge_position(0, -20)
    player:set_emotions_texture(Resources.load_texture("emotions.png"))
    player:load_emotions_animation("emotions.animation")
    player:set_emotion("DEFAULT")

    --- emotions
    EmotionsLib.implement_supported_full(player)

    local cheered = false

    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        local card_props = CardProperties.from_package("BattleNetwork2.Class01.Standard.017.LittleBomb")
        card_props.damage = 15 + player:attack_level() * 15

        return Action.from_card(player, card_props)
    end

    player:create_component(Lifetime.CardSelectOpen).on_update_func = function()
        cheered = false
    end

    player.special_attack_func = function()
        if not cheered then
            local cheer_boost = AuxProp.new()
                :require_card_damage(Compare.GE, 1)
                :require_card_time_freeze(false)
                :increase_card_damage(10)
                :once()
            player:add_aux_prop(cheer_boost)
            cheered = true
        end
        return Action.new(player, "CHEER")
    end
end

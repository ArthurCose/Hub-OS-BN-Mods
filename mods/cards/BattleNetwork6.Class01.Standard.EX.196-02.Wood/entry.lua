local bn_assets = require("BattleNetwork.Assets")

function card_mutate(player, index)
    local left_card = player:field_card(index - 1)

    if left_card and left_card.can_boost then
        if left_card.element == Element.Wood or left_card.secondary_element == Element.Wood then
            -- update the left_card
            left_card.damage = left_card.damage + 20
            left_card.boosted_damage = left_card.boosted_damage + 20
            player:set_field_card(index - 1, left_card)

            -- remove attack booster
            player:remove_field_card(index)
        end
    end
end

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_IDLE")
    action.on_execute_func = function(self, user)
        local fx = bn_assets.ParticlePoof.new()
        fx:set_elevation(user:height() + 20)
        Field.spawn(fx, actor:current_tile())
    end
    return action
end

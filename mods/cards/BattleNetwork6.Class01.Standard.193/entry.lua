function card_mutate(player, index)
    local left_card = player:field_card(index - 1)

    if left_card and left_card.can_boost and not left_card.time_freeze then
        -- update the left_card
        left_card.hit_flags = left_card.hit_flags | Hit.Uninstall
        player:set_field_card(index - 1, left_card)

        -- remove self
        player:remove_field_card(index)
    end
end

function card_init()
    return nil
end

function card_mutate(player, index)
    local left_card = player:field_card(index - 1)

    if left_card and left_card.can_boost then
        -- update the left_card
        left_card.hit_flags = left_card.hit_flags & ~Hit.mutual_exclusions_for(Hit.Paralyze) | Hit.Paralyze
        player:set_field_card(index - 1, left_card)

        -- remove this card
        player:remove_field_card(index)
    end
end

function card_init()
    return nil
end

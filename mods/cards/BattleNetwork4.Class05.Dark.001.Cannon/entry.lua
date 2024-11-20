local track_health;

function card_mutate(entity, card_index)
    if Player.from(entity) ~= nil then
        entity:boost_attack_level(-entity:attack_level())
        entity:boost_charge_level(-entity:charge_level())
        entity:boost_rapid_level(-entity:rapid_level())
    end

    if track_health == nil then
        track_health = entity:create_component(Lifetime.ActiveBattle)
        track_health._stored_value = 0
        track_health._is_update_value = true
        track_health.on_update_func = function(self)
            local owner = self:owner()
            local card = owner:field_card(1)

            if card ~= nil and self._is_update_value == true then
                for index, value in ipairs(card.tags) do
                    if value == "DAMAGE_EQUALS_POWER" then
                        self._stored_value = owner:health()
                        card.damage = math.min(999, owner:max_health() - owner:health())
                        entity:set_field_card(1, card)
                        self._is_update_value = false
                    end
                end
            end

            self._is_update_value = self._stored_value ~= owner:health()
        end
    end
end

function card_init(actor, props)
    props.package_id = "dev.GladeWoodsgrove.ZeroDamageCannon"

    return Action.from_card(actor, props);
end

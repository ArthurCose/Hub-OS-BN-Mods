---@param user Entity
function card_mutate(user, index)
  local card = user:field_card(index)
  local target_recover = card.damage * 3

  if target_recover ~= card.recover then
    card.recover = target_recover
    user:set_field_card(index, card)
  end
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  props.package_id = "BattleNetwork6.Class02.Mega.001.Roll"
  return Action.from_card(user, props)
end

---@param augment Augment
function min_turn(augment)
  local level = augment:level()
  if level == 1 then
    return 4
  elseif level == 2 then
    return 3
  else
    return 2
  end
end

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local component = player:create_component(Lifetime.CardSelectOpen)
  local turn = 0

  component.on_update_func = function()
    turn = turn + 1

    if turn >= min_turn(augment) then
      player:boost_augment("BattleNetwork6.Bugs.Custom-", 1)
    end
  end
end

---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()

  local backward_augment = owner:get_augment("BattleNetwork4.Bugs.BackwardMovement")

  if backward_augment then
    owner:boost_augment(backward_augment:id(), -backward_augment:level())
  end

  local component = owner:create_component(Lifetime.ActiveBattle)
  local frequency = 7
  local time = 0

  component.on_update_func = function()
    time = time + 1

    if time % frequency ~= 0 then return end
    if owner:is_moving() or owner:has_actions() then return end

    -- avoid moving the player if they are fighting the movement
    if owner:input_has(Input.Held.Left) or
        owner:input_has(Input.Held.Right) or
        owner:input_has(Input.Held.Up) or
        owner:input_has(Input.Held.Down)
    then
      return
    end

    local tile = owner:get_tile(owner:facing(), 1)

    if tile and owner:can_move_to(tile) then
      owner:queue_default_player_movement(tile)
    end
  end

  owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
    component:eject()
  end
end

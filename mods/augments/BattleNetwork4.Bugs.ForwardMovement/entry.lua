---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()

  local backward_augment = owner:get_augment("BattleNetwork4.Bugs.BackwardMovement")

  if backward_augment then
    owner:boost_augment(backward_augment:id(), -backward_augment:level())
  end

  local frequency = 7
  local time = 0

  augment.movement_input_func = function()
    time = time + 1

    if time % frequency ~= 0 then return end

    -- avoid moving the player if they are fighting the movement
    if owner:input_has(Input.Held.Left) or
        owner:input_has(Input.Held.Right) or
        owner:input_has(Input.Held.Up) or
        owner:input_has(Input.Held.Down)
    then
      return
    end

    return owner:facing()
  end

  owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
  end
end

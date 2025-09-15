---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()

  local foreward_augment = owner:get_augment("BattleNetwork4.Bugs.ForwardMovement")

  if foreward_augment then
    owner:boost_augment(foreward_augment:id(), -foreward_augment:level())
  end

  local component = owner:create_component(Lifetime.ActiveBattle)
  local frequency = 7
  local time = 0

  component.on_update_func = function()
    time = time + 1

    if time % frequency ~= 0 then return end
    if owner:is_moving() or owner:has_actions() then return end

    -- whether this player is facing the default facing direction
    local facing_flipped = owner:facing() ~= Direction.Right

    if owner:team() == Team.Blue then
      facing_flipped = not facing_flipped
    end

    -- avoid moving the player if they are fighting the movement
    if facing_flipped then
      if owner:input_has(Input.Held.Left) then
        return
      end
    elseif owner:input_has(Input.Held.Right) then
      return
    end

    local tile = owner:get_tile(owner:facing_away(), 1)

    if tile and owner:can_move_to(tile) then
      owner:queue_default_player_movement(tile)
    end
  end

  augment.on_delete_func = function()
    component:eject()
  end
end

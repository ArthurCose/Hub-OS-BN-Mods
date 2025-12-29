local TIMING = { 6, 4, 3 }

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  local open = false
  local open_component = player:create_component(Lifetime.CardSelectOpen)
  open_component.on_update_func = function()
    open = true
  end

  local close_component = player:create_component(Lifetime.CardSelectClose)
  close_component.on_update_func = function()
    open = false
  end

  local component = player:create_component(Lifetime.Scene)
  local time = 0

  component.on_update_func = function()
    if not open then
      time = 0
      return
    end

    if player:health() <= 1 then return end

    time = time + 1

    local rate = TIMING[augment:level()] or TIMING[#TIMING]

    if time % rate ~= 0 then
      return
    end

    -- setting health directly, as auxprops would wait for ActiveBattle
    player:set_health(player:health() - 1)
  end

  player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)

    open_component:eject()
    close_component:eject()
    component:eject()
  end
end

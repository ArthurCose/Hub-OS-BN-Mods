local MOVE_START_FRAMES = { { 1, 1 }, { 2, 1 }, { 3, 1 } }
local MOVE_END_FRAMES = { { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 1 } }

---@class BattleNetwork6.Libraries.ChipNavi
local Lib = {}

---Reveals a navi then plays the CHARACTER_MOVE state
---@param navi Entity navi to hide
---@param callback fun() called as soon as the animation completes
function Lib.enter(navi, callback)
  navi:reveal()

  local animation = navi:animation()
  animation:set_state("CHARACTER_MOVE", MOVE_END_FRAMES)
  animation:on_complete(callback)
end

---Hides a navi after playing the CHARACTER_MOVE state
---@param navi Entity navi to hide
---@param callback fun() called after the animation completes
function Lib.exit(navi, callback)
  -- animate and hide navi_out
  local animation = navi:animation()
  animation:set_state("CHARACTER_MOVE", MOVE_START_FRAMES)
  animation:on_complete(function()
    navi:hide()
    callback()
  end)
end

---@param callback fun() called after the delay
function Lib.delay(duration, callback)
  local artifact = Artifact.new()
  Field.spawn(artifact, 0, 0)

  local time = duration

  local component = artifact:create_component(Lifetime.Scene)
  component.on_update_func = function()
    time = time - 1

    if time > 0 then
      return
    end

    artifact:delete()

    callback()
  end
end

---@param callback fun() called after the delay
function Lib.delay_for_swap(callback)
  Lib.delay(30, callback)
end

---Swaps a navi in using the CHARACTER_MOVE state on both navis
---@param navi_in Entity navi to reveal
---@param navi_out Entity navi to hide
---@param callback fun()
function Lib.swap_in(navi_in, navi_out, callback)
  -- make sure this character is hidden
  navi_in:hide()

  Lib.exit(navi_out, function()
    Lib.delay_for_swap(function()
      Lib.enter(navi_in, callback)
    end)
  end)
end

---@param action Action
---@param navi Entity
function Lib.create_enter_step(action, navi)
  local step = action:create_step()
  step.on_update_func = function()
    step.on_update_func = nil
    Lib.enter(navi, function() step:complete_step() end)
  end
end

---@param action Action
---@param delay number
function Lib.create_delay_step(action, delay)
  local step = action:create_step()
  step.on_update_func = function()
    delay = delay - 1
    if delay <= 0 then
      step:complete_step()
    end
  end
end

---@param action Action
---@param navi Entity
function Lib.create_exit_step(action, navi)
  local step = action:create_step()
  step.on_update_func = function()
    step.on_update_func = nil
    Lib.exit(navi, function() step:complete_step() end)
  end
end

return Lib

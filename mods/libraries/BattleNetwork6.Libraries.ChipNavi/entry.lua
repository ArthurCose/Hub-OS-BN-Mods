local MOVE_START_FRAMES = { { 1, 1 }, { 2, 1 }, { 3, 1 } }
local MOVE_END_FRAMES = { { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 1 } }

---@class BattleNetwork6.Libraries.ChipNavi
local Lib = {}

---Swaps a navi in using the CHARACTER_MOVE state on both navis
---@param navi_in Entity navi to reveal
---@param navi_out Entity navi to hide
---@param callback fun()
function Lib.swap_in(navi_in, navi_out, callback)
  -- make sure this character is hidden
  navi_in:hide()

  -- animate and hide navi_out
  local out_anim = navi_out:animation()
  out_anim:set_state("CHARACTER_MOVE", MOVE_START_FRAMES)
  out_anim:on_complete(function()
    navi_out:hide()
  end)

  local time = 30 + #MOVE_START_FRAMES

  local component = navi_in:create_component(Lifetime.Scene)
  component.on_update_func = function()
    time = time - 1

    if time > 0 then
      return
    end

    component:eject()

    -- reveal and animate navi_in
    navi_in:reveal()
    local in_anim = navi_in:animation()
    in_anim:set_state("CHARACTER_MOVE", MOVE_END_FRAMES)
    in_anim:on_complete(callback)
  end
end

---@param action Action
---@param navi Entity
function Lib.create_enter_step(action, navi)
  local step = action:create_step()
  step.on_update_func = function()
    step.on_update_func = nil
    Lib.swap_in(navi, action:owner(), function() step:complete_step() end)
  end
end

---@param action Action
---@param navi Entity
function Lib.create_exit_step(action, navi)
  local step = action:create_step()
  step.on_update_func = function()
    step.on_update_func = nil
    Lib.swap_in(action:owner(), navi, function() step:complete_step() end)
  end
end

return Lib

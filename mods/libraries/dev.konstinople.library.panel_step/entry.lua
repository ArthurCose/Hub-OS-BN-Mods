local function debug_print(...)
  -- print(...)
end

local function can_move_to_func()
  return false
end

---@param user Entity
---@param tile Tile
local function test_dest_tile(user, tile)
  if user:current_tile() == tile then
    return true
  end

  return tile and not tile:is_edge() and not tile:is_reserved()
end

---@class PanelStep
local PanelStep = {}
PanelStep.__index = PanelStep

---@param return_frame number the amount of frames after the action start to return the user to the original tile. (26 by default)
function PanelStep:set_return_frame(return_frame)
  self._return_frame = return_frame
end

---Called when an action executes to resolve a destination
---@param callback fun(user: Entity): Tile?, Direction?
function PanelStep:set_dest_func(callback)
  self._dest_func = callback
end

---@param color Color
function PanelStep:set_ghost_color(color)
  self._ghost_color = color
end

---@param user Entity
---@param color Color
local function create_ghost(user, color)
  local ghost = Artifact.new()
  ghost:set_facing(user:facing())

  local queue = { { user:sprite(), ghost:sprite() } }
  while #queue > 0 do
    local item = queue[1]

    -- swap remove to avoid shifting
    queue[1] = queue[#queue]
    queue[#queue] = nil

    -- process
    local user_sprite = item[1]
    local ghost_sprite = item[2]

    ghost_sprite:copy_from(user_sprite)
    ghost_sprite:set_shader_effect(SpriteShaderEffect.Grayscale)
    ghost_sprite:set_color_mode(ColorMode.Multiply)
    ghost_sprite:set_color(color)

    for _, user_child_sprite in ipairs(user_sprite:children()) do
      queue[#queue + 1] = { user_child_sprite, ghost_sprite:create_node() }
    end
  end

  local component = ghost:create_component(Lifetime.ActiveBattle)
  local sprite = ghost:sprite()
  component.on_update_func = function()
    sprite:set_color_mode(ColorMode.Multiply)
    sprite:set_color(color)
  end

  return ghost
end

---@param user Entity
---@param color Color
local function create_lagging_ghost(user, color)
  local spawner = Artifact.new()

  local i = 0
  spawner.on_update_func = function()
    i = i + 1

    if i % 4 ~= 1 then
      return
    end

    if user:deleted() then
      spawner:erase()
    end

    local ghost = create_ghost(user, color)

    local ghost_i = 0
    ghost.on_update_func = function()
      ghost_i = ghost_i + 1

      if ghost_i == 2 then
        ghost:erase()
      end
    end

    local tile = spawner:current_tile()
    Field.spawn(ghost, tile)
  end

  return spawner
end

---@param user Entity
---@param color Color
local function create_static_blinking_ghost(user, color)
  local ghost = create_ghost(user, color)
  local ghost_sprite = ghost:sprite()

  local i = 0
  ghost.on_update_func = function()
    ghost_sprite:set_visible(math.floor(i / 2) % 2 == 0)

    i = i + 1
  end

  return ghost
end

---@param wrapped_action Action
function PanelStep:wrap_action(wrapped_action)
  local user = wrapped_action:owner()

  local start_action = Action.new(user)
  start_action:set_lockout(ActionLockout.new_sequence())

  local dest_tile, dest_facing, lagging_ghost, static_ghost
  local return_frame = self._return_frame

  start_action.can_move_to_func = can_move_to_func

  start_action.on_execute_func = function()
    -- resolve tiles on execute, in case the user moved before the action exited queue
    local original_tile = user:current_tile()
    local original_facing = user:facing()

    if self._dest_func then
      dest_tile, dest_facing = self._dest_func(user)
    else
      dest_tile = user:get_tile(user:facing(), 2)
    end

    dest_facing = dest_facing or original_facing

    if not dest_tile or not test_dest_tile(user, dest_tile) then
      -- invalid dest, return early
      dest_tile = nil
      start_action:end_action()
      return
    end

    -- reserve our destination
    dest_tile:reserve_for(user)
    -- reserve our return tile
    original_tile:reserve_for(user)

    -- queue our wrapped action to run next
    user:queue_action(wrapped_action)

    -- queue an action, that will queue a clean up action
    -- allows our wrapped action to queue actions that run before we return to the original tile
    local queue_action = Action.new(user)
    local executed_queue_action = false
    local returned = false

    local cleanup = function()
      -- just in case we never landed on it
      if dest_tile then
        dest_tile:remove_reservation_for(user)
      end

      if lagging_ghost then
        lagging_ghost:erase()
      end

      if not returned then
        user:current_tile():remove_entity(user)
        original_tile:add_entity(user)
        original_tile:remove_reservation_for(user)
        user:set_facing(original_facing)
        debug_print("default returned")
      end
    end

    queue_action.on_execute_func = function()
      local end_action = Action.new(user)
      end_action:set_lockout(ActionLockout.new_sequence())
      end_action.on_action_end_func = cleanup
      user:queue_action(end_action)

      executed_queue_action = true
    end

    queue_action.on_action_end_func = function()
      if not executed_queue_action then
        cleanup()
      end
    end

    user:queue_action(queue_action)

    -- create ghosts
    lagging_ghost = create_lagging_ghost(user, self._ghost_color)
    static_ghost = create_static_blinking_ghost(user, self._ghost_color)

    -- handles return + ghosts in the middle of the following steps
    local component = user:create_component(Lifetime.Local)
    local i = 1

    local function eject_component()
      component:eject()

      if not static_ghost:deleted() then
        static_ghost:erase()
      end
    end

    component.on_update_func = function()
      if lagging_ghost:deleted() then
        eject_component()
        return
      end

      i = i + 1

      debug_print(i)

      if i == 2 then
        -- takes 1 frame to spawn, will appear on frame 3
        Field.spawn(static_ghost, original_tile)
      elseif i == 8 then
        -- takes 1 frame to spawn the base entity
        -- and another to spawn the artifact
        -- will appear on frame 10
        Field.spawn(lagging_ghost, dest_tile)
      elseif i == 20 then
        static_ghost:erase()
      elseif not return_frame and i > 21 then
        eject_component()
      elseif i == return_frame then
        eject_component()
        user:current_tile():remove_entity(user)
        original_tile:add_entity(user)
        original_tile:remove_reservation_for(user)
        user:set_facing(original_facing)
        debug_print("returned")
        returned = true
      end
    end
  end

  -- jump forward step
  local jump_forward_step = start_action:create_step()

  jump_forward_step.on_update_func = function()
    debug_print("step update")

    -- step forward
    user:current_tile():remove_entity(user)
    dest_tile:add_entity(user)
    user:set_facing(dest_facing)

    -- wait one frame after stepping forward to complete step
    jump_forward_step.on_update_func = function()
      jump_forward_step:complete_step()
    end
  end

  return start_action
end

---@param user Entity
---@param create_action_steps fun(Action)
function PanelStep:create_action(user, create_action_steps)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local original_tile, original_facing, dest_tile, dest_facing, lagging_ghost, static_ghost
  local return_frame = self._return_frame
  local returned = false

  action.can_move_to_func = can_move_to_func

  action.on_execute_func = function()
    original_tile = user:current_tile()
    original_facing = user:facing()

    if self._dest_func then
      dest_tile, dest_facing = self._dest_func(user)
    else
      dest_tile = user:get_tile(user:facing(), 2)
    end

    dest_facing = dest_facing or original_facing

    if not dest_tile or not test_dest_tile(user, dest_tile) then
      dest_tile = nil
      returned = true
      action:end_action()
      return
    end

    -- reserve our destination
    dest_tile:reserve_for(user)
    -- reserve our return tile
    original_tile:reserve_for(user)

    -- create ghosts
    lagging_ghost = create_lagging_ghost(user, self._ghost_color)
    static_ghost = create_static_blinking_ghost(user, self._ghost_color)

    -- handles return in the middle of the following steps
    local component = user:create_component(Lifetime.Local)
    local i = 1

    local function eject_component()
      component:eject()

      if not static_ghost:deleted() then
        static_ghost:erase()
      end
    end

    component.on_update_func = function()
      i = i + 1

      debug_print(i)

      if i == 2 then
        -- takes 1 frame to spawn, will appear on frame 3
        Field.spawn(static_ghost, original_tile)
      elseif i == 8 then
        -- takes 1 frame to spawn the base entity
        -- and another to spawn the artifact
        -- will appear on frame 10
        Field.spawn(lagging_ghost, dest_tile)
      elseif i == 20 then
        static_ghost:erase()
      elseif not return_frame and i > 21 then
        eject_component()
      elseif i == return_frame then
        eject_component()
        user:current_tile():remove_entity(user)
        original_tile:add_entity(user)
        original_tile:remove_reservation_for(user)
        user:set_facing(original_facing)
        debug_print("returned")
        returned = true
      end
    end
  end

  -- jump forward step
  local jump_forward_step = action:create_step()

  jump_forward_step.on_update_func = function()
    debug_print("step update")

    -- step forward
    user:current_tile():remove_entity(user)
    dest_tile:add_entity(user)
    user:set_facing(dest_facing)

    -- wait one frame after stepping forward to complete step
    jump_forward_step.on_update_func = function()
      jump_forward_step:complete_step()
    end
  end

  create_action_steps(action)

  -- clean up
  action.on_action_end_func = function()
    -- just in case we never landed on it
    if dest_tile then
      dest_tile:remove_reservation_for(user)
    end

    if lagging_ghost then
      lagging_ghost:erase()
    end

    if not returned and original_tile then
      user:current_tile():remove_entity(user)
      original_tile:add_entity(user)
      original_tile:remove_reservation_for(user)
      user:set_facing(original_facing)
      debug_print("default returned")
    end
  end

  return action
end

---@class PanelStepLib
local PanelStepLib = {}

---@alias dev.konstinople.library.panel_step PanelStepLib

---@return PanelStep
function PanelStepLib.new_panel_step()
  local panel_step = {
    _ghost_color = Color.new(255, 0, 0)
  }
  setmetatable(panel_step, PanelStep)

  return panel_step
end

return PanelStepLib

---@type dev.konstinople.library.iterator
local IteratorLib = require("dev.konstinople.library.iterator")

---A function that returns a new Action on every call, or nil to signify the end
---@alias ActionIterator fun(): Action?

---@class AiPlan
---@field private _weight number
---@field private _usable_after number
---@field private _action_iter_factory fun(): ActionIterator
local AiPlan = {}
AiPlan.__index = AiPlan

---@return AiPlan
function AiPlan.new()
  local plan = {}
  setmetatable(plan, AiPlan)
  return plan
end

---Automatically calls AiPlan:set_action_iter_factory()
---@param action_factory fun(): Action
function AiPlan.new_single_action(action_factory)
  local plan = AiPlan.new()

  plan:set_action_iter_factory(function()
    return IteratorLib.take(1, action_factory)
  end)

  return plan
end

function AiPlan:set_weight(weight)
  self._weight = weight
end

function AiPlan:weight()
  return self._weight or 1
end

---Unlocks the plan to be usable after `roll` rolls
---@param roll number
function AiPlan:set_usable_after(roll)
  self._usable_after = roll
end

function AiPlan:usable_after()
  return self._usable_after or 0
end

---@param iter_factory fun(): ActionIterator a factory function, that returns an ActionIterator
---@see ActionIterator
function AiPlan:set_action_iter_factory(iter_factory)
  self._action_iter_factory = iter_factory
end

function AiPlan:action_iter_factory()
  return self._action_iter_factory
end

---@class Ai
---@field private _entity Entity
---@field private _plans AiPlan[]
---@field private _rolls number
---@field private _action_iter? ActionIterator
---@field private _component Component
local Ai = {}
Ai.__index = Ai

---@param plans AiPlan[]
local function pick_plan(rolls, plans)
  -- resolve total weight
  local combined_weight = 0

  for _, plan in ipairs(plans) do
    if plan:usable_after() <= rolls then
      combined_weight = combined_weight + plan:weight()
    end
  end

  local roll = math.random() * combined_weight

  -- resolve roll
  for _, plan in ipairs(plans) do
    if plan:usable_after() <= rolls then
      roll = roll - plan:weight()

      if roll < 0 then
        return plan
      end
    end
  end

  return plans[#plans]
end

---@return Ai
---@param entity Entity
function Ai.new(entity)
  local ai = {
    _entity = entity,
    _plans = {},
    _rolls = 0
  }
  setmetatable(ai, Ai)

  ai:_create_component()

  return ai
end

function Ai:create_plan()
  local plan = AiPlan.new()
  self._plans[#self._plans + 1] = plan
  return plan
end

function Ai:cancel_plan()
  self._action_iter = nil
end

function Ai:eject()
  self._component:eject()
end

---@private
function Ai:_create_component()
  self._component = self._entity:create_component(Lifetime.Local)

  self._component.on_update_func = function()
    if self._entity:has_actions() then
      return
    end

    local action
    local attempts = 0

    while true do
      while not self._action_iter do
        local plan = pick_plan(self._rolls, self._plans)
        self._rolls = self._rolls + 1

        if not plan then
          -- no plans
          return
        end

        local iter_factory = plan:action_iter_factory()

        if not iter_factory then
          -- no factory
          error("An AiPlan is missing action_iter_factory")
        end

        self._action_iter = iter_factory()

        if not self._action_iter then
          error("An AiPlan's action_iter_factory returned nil")
        end

        attempts = attempts + 1

        if attempts >= 5 then
          error("AI failed to find an action after 5 attempts.")
        end
      end


      action = self._action_iter()

      if action then
        break
      end

      self._action_iter = nil
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    self._entity:queue_action(action)
  end
end

---@class dev.konstinople.library.ai
local Lib = {
  new_ai = Ai.new,
  new_plan = AiPlan.new,
  new_single_action_plan = AiPlan.new_single_action,
  Ai = Ai,
  AiPlan = AiPlan,
  IteratorLib = IteratorLib,
}

---@param entity Entity
---@param card_props CardProperties
function Lib.create_card_action_factory(entity, card_props)
  return function()
    return Action.from_card(entity, card_props)
  end
end

---@param entity Entity
---@param min_duration number
---@param max_duration number
---@param think_callback? fun(entity: Entity): boolean Return true to end the action early, actions should be queued here to make the most of it.
function Lib.create_idle_action_factory(entity, min_duration, max_duration, think_callback)
  return function()
    local action = Action.new(entity)
    action:set_lockout(ActionLockout.new_sequence())

    local step = action:create_step()

    local duration = math.random(min_duration, max_duration)

    action.on_execute_func = function()
      local component = entity:create_component(Lifetime.Local)

      component.on_update_func = function()
        duration = duration - 1

        local complete_early = false

        if think_callback and not entity:is_inactionable() and not entity:is_immobile() then
          complete_early = think_callback(entity)
        end

        if complete_early or duration <= 0 then
          step:complete_step()
        end
      end

      action.on_action_end_func = function()
        component:eject()
      end
    end

    return action
  end
end

---Used to find good tiles to teleport to before an attack.
---@param entity Entity
---@param tile_suggester fun(entity: Entity, suggest: fun(tile: Tile?)) `suggest()` can be called multiple times to suggest multiple tiles
---@param tile_filter? fun(tile: Tile): boolean If no tile_filter is passed in, it will default to test if the tile passes `entity:can_move_to()`
---@param entity_filter? fun(entity: Entity): boolean If no entity_filter is passed in, it will default to test if the entity is a non team Character
---@return Tile[]
function Lib.find_setup_tiles(entity, tile_suggester, tile_filter, entity_filter)
  local tiles = {}

  if not entity_filter then
    entity_filter = function(other)
      return other:team() ~= entity:team() and Character.from(other) ~= nil and other:hittable()
    end
  end

  if not tile_filter then
    tile_filter = function(tile)
      return entity:can_move_to(tile)
    end
  end

  local suggest = function(tile)
    if tile and tile_filter(tile) then
      tiles[#tiles + 1] = tile
    end
  end

  local find_entity_callback = function(other)
    if entity_filter(other) then
      tile_suggester(other, suggest)
    end

    return false
  end

  Field.find_characters(find_entity_callback)
  Field.find_obstacles(find_entity_callback)

  return tiles
end

---Picks a random tile for movement on the same row as an enemy
---@param entity Entity
---@param min_dist number? starts at 1
---@param max_dist number? defaults to the field width
function Lib.pick_same_row_tile(entity, min_dist, max_dist)
  local team = entity:team()
  local enemies = Field.find_nearest_characters(entity, function(e)
    return not e:deleted() and e:team() ~= team
  end)

  if #enemies == 0 then
    return
  end

  min_dist = math.max(1, min_dist or 1)
  max_dist = max_dist or Field.width()

  ---@type Tile[]
  local possible_tiles = {}

  for _, enemy in ipairs(enemies) do
    local enemy_tile = enemy:current_tile()

    local enemy_x = enemy_tile:x()
    local y = enemy_tile:y()

    for x = 1, Field.width() - 1 do
      local tile = Field.tile_at(x, y)
      local dist = math.abs(x - enemy_x)

      if not tile or dist < min_dist or dist > max_dist or not entity:can_move_to(tile) then
        goto continue
      end

      local facing_correctly

      if tile:facing() == Direction.Right then
        facing_correctly = x < enemy_x
      else
        facing_correctly = x > enemy_x
      end

      if facing_correctly then
        possible_tiles[#possible_tiles + 1] = tile
      end

      ::continue::
    end
  end

  if #possible_tiles == 0 then
    return
  end

  return possible_tiles[math.random(#possible_tiles)]
end

---Finds the furthest tile away from each enemy in both directions for movement, returns one of them
---@param entity Entity
function Lib.pick_far_same_row_tile(entity)
  local team = entity:team()
  local enemies = Field.find_nearest_characters(entity, function(e)
    return not e:deleted() and e:team() ~= team
  end)

  if #enemies == 0 then
    return
  end

  ---@type Tile[]
  local possible_tiles = {}
  local current_tile = entity:current_tile()

  for _, enemy in ipairs(enemies) do
    local enemy_tile = enemy:current_tile()

    local enemy_x = enemy_tile:x()
    local y = enemy_tile:y()

    local furthest_tile

    -- find the furthest tile on the right

    for x = Field.width() - 1, enemy_x + 1, -1 do
      local tile = Field.tile_at(x, y)

      if not tile or not entity:can_move_to(tile) then
        goto continue
      end

      if tile:facing() == Direction.Left then
        furthest_tile = tile
        break
      end

      ::continue::
    end

    if furthest_tile and furthest_tile ~= current_tile then
      possible_tiles[#possible_tiles + 1] = furthest_tile
    end

    -- find the furthest tile on the left

    for x = 1, enemy_x - 1 do
      local tile = Field.tile_at(x, y)

      if not tile or not entity:can_move_to(tile) then
        goto continue
      end

      if tile:facing() == Direction.Left then
        furthest_tile = tile
        break
      end

      ::continue::
    end

    if furthest_tile and furthest_tile ~= current_tile then
      possible_tiles[#possible_tiles + 1] = furthest_tile
    end
  end

  if #possible_tiles == 0 then
    return
  end

  return possible_tiles[math.random(#possible_tiles)]
end

---Finds the tiles closest to the edge in both directions, returns one of them
---@param entity Entity
function Lib.pick_far_tile(entity)
  local x_start = 1

  local facing = entity:facing()
  if facing == Direction.Left then
    x_start = Field.width() - 2
  end

  ---@type Tile[]
  local possible_tiles = {}
  local current_tile = entity:current_tile()

  for y = 1, Field.height() - 2 do
    local tile = Field.tile_at(x_start, y)

    while tile do
      if entity:can_move_to(tile) and tile ~= current_tile then
        possible_tiles[#possible_tiles + 1] = tile
        break
      end

      tile = tile:get_tile(facing, 1)
    end
  end

  if #possible_tiles == 0 then
    return
  end

  return possible_tiles[math.random(#possible_tiles)]
end

---Finds a random tile with a matching team for movement
---@param entity Entity
function Lib.pick_same_team_tile(entity)
  local current_tile = entity:current_tile()

  local tiles = Field.find_tiles(function(tile)
    return entity:can_move_to(tile) and current_tile ~= tile
  end)

  if #tiles == 0 then
    return nil
  end

  return tiles[math.random(#tiles)]
end

return Lib

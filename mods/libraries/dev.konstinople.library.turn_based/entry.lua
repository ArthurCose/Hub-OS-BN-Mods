---@class dev.konstinople.library.turn_based
local TurnBasedLib = {}

---Turn tracker that cycles between multiple entities
---@class dev.konstinople.library.turn_based.TurnTracker
---@field package entities Entity[]
---@field package current_turn number
local TurnTracker = {}
TurnTracker.__index = TurnTracker

---@param entity Entity
function TurnTracker:add_entity(entity)
  self.entities[#self.entities + 1] = entity
end

---@param entity Entity
function TurnTracker:remove_entity(entity)
  local entity_id = entity:id()

  for i = 1, #self.entities do
    local existing_entity = self.entities[i]

    if existing_entity:id() ~= entity_id then
      goto continue
    end

    table.remove(self.entities, i)

    if self.current_turn > i then
      -- shift to maintain the current entity's turn and avoid out of bounds index
      self.current_turn = math.max(self.current_turn - 1, 1)
    elseif self.current_turn == i then
      if self.current_turn > #self.entities then
        -- avoid out of bounds index
        self.current_turn = 1
      end
    end

    break

    ::continue::
  end
end

---@param entity Entity
function TurnTracker:request_turn(entity)
  -- loop to filter out deleted entities
  while true do
    local current_entity = self.entities[self.current_turn]

    if not current_entity then
      return false
    end

    if not current_entity:deleted() then
      return current_entity:id() == entity:id()
    end

    self:remove_entity(current_entity)
  end
end

---@param entity Entity
function TurnTracker:end_turn(entity)
  local current_entity = self.entities[self.current_turn]

  if current_entity and current_entity:id() == entity:id() then
    -- advance
    self.current_turn = self.current_turn % #self.entities + 1
  end
end

---@param comp fun(a: Entity, b: Entity): boolean Should return true if `a` should come before `b`, passed directly to `table.sort()`
function TurnTracker:sort_turn_order(comp)
  table.sort(self.entities, comp)

  -- todo: maybe track if a turn being taken and update the turn index to match
end

---Turn tracker for a single direction
---@class _dev.konstinople.library.turn_based.SingleDirectionTurnTracker: dev.konstinople.library.turn_based.TurnTracker
---@field package root dev.konstinople.library.turn_based.DirectionalTurnTracker
local SingleDirectionTurnTracker = {}
SingleDirectionTurnTracker.__index = SingleDirectionTurnTracker
setmetatable(SingleDirectionTurnTracker, TurnTracker)

---@param entity Entity
function SingleDirectionTurnTracker:remove_entity(entity)
  self.root.facing_directions[entity:id()] = nil
  TurnTracker.remove_entity(self, entity)
end

---Turn tracker that allows entities with differing facing directions to take turns at the same time
---@class dev.konstinople.library.turn_based.DirectionalTurnTracker
---@field package facing_directions table<EntityId, Direction>
---@field package turn_trackers table<Direction, _dev.konstinople.library.turn_based.SingleDirectionTurnTracker>
local DirectionalTurnTracker = {}
DirectionalTurnTracker.__index = DirectionalTurnTracker

---@param entity Entity
function DirectionalTurnTracker:add_entity(entity)
  if entity:deleted() then
    return
  end

  if self.facing_directions[entity:id()] then
    self:remove_entity(entity)
  end

  local facing = entity:facing()
  local tracker = self.turn_trackers[facing]

  if not tracker then
    tracker = {
      entities = {},
      current_turn = 1,
      root = self
    }
    setmetatable(tracker, SingleDirectionTurnTracker)

    self.turn_trackers[facing] = tracker
  end

  tracker:add_entity(entity)
  self.facing_directions[entity:id()] = facing
end

---@param entity Entity
function DirectionalTurnTracker:remove_entity(entity)
  local last_facing = self.facing_directions[entity:id()]

  if not last_facing then
    return
  end

  local tracker = self.turn_trackers[last_facing]
  -- this will also remove this entity from facing_directions
  tracker:remove_entity(entity)
end

---@param entity Entity
function DirectionalTurnTracker:request_turn(entity)
  local last_facing = self.facing_directions[entity:id()]

  if not last_facing then
    return false
  end

  local tracker = self.turn_trackers[last_facing]
  return tracker:request_turn(entity)
end

---@param entity Entity
function DirectionalTurnTracker:end_turn(entity)
  local last_facing = self.facing_directions[entity:id()]

  if not last_facing then
    return false
  end

  local tracker = self.turn_trackers[last_facing]

  if entity:deleted() then
    -- this will also remove this entity from facing_directions
    tracker:remove_entity(entity)
    return
  end

  if last_facing ~= entity:facing() then
    -- re-add to update the facing direction
    tracker:remove_entity(entity)
    self:add_entity(entity)
    return
  end

  tracker:end_turn(entity)
end

---@param comp fun(a: Entity, b: Entity): boolean Should return true if `a` should come before `b`, passed directly to `table.sort()`
function DirectionalTurnTracker:sort_turn_order(comp)
  for _, tracker in pairs(self.turn_trackers) do
    tracker:sort_turn_order(comp)
  end
end

---First ready entity claims control
---@class dev.konstinople.library.turn_based.Lock
---@field package entity? Entity
local Lock = {}
Lock.__index = Lock

---@param entity Entity
function Lock:request_lock(entity)
  if self.entity and not self.entity:deleted() and self.entity:id() ~= entity:id() then
    return false
  end

  self.entity = entity
  return true
end

---@param entity Entity
function Lock:unlock(entity)
  if self:request_lock(entity) then
    self.entity = nil
  end
end

---Alias for request_lock
---@param entity Entity
function Lock:request_turn(entity)
  return self:request_lock(entity)
end

---Alias for unlock
---@param entity Entity
function Lock:end_turn(entity)
  return self:unlock(entity)
end

---First ready entity claims control
---@class dev.konstinople.library.turn_based.PerTeamLock
---@field package locks table<Team, dev.konstinople.library.turn_based.Lock>
---@field package entity_teams table<EntityId, Team>
local PerTeamLock = {}
PerTeamLock.__index = PerTeamLock

---@param entity Entity
function PerTeamLock:request_lock(entity)
  if entity:deleted() then
    return false
  end

  local team = entity:team()
  local lock = self.locks[team]

  if not lock then
    lock = TurnBasedLib.new_lock()
    self.locks[team] = lock
  end

  if lock.entity then
    if lock.entity:id() == entity:id() then
      return true
    end

    if not lock.entity:deleted() and lock.entity:team() == team then
      return false
    end

    -- clean up
    self.entity_teams[lock.entity:id()] = nil
  end

  -- update lock
  lock.entity = entity
  self.entity_teams[entity:id()] = team

  return true
end

---@param entity Entity
function PerTeamLock:unlock(entity)
  local team = self.entity_teams[entity:id()]

  if not team then
    return
  end

  self.entity_teams[entity:id()] = nil

  local lock = self.locks[team]
  lock:unlock(entity)
end

---Alias for request_lock
---@param entity Entity
function PerTeamLock:request_turn(entity)
  return self:request_lock(entity)
end

---Alias for unlock
---@param entity Entity
function PerTeamLock:end_turn(entity)
  return self:unlock(entity)
end

---Turn tracker that cycles between multiple entities
---@return dev.konstinople.library.turn_based.TurnTracker
function TurnBasedLib.new_tracker()
  local o = {
    entities = {},
    current_turn = 1
  }
  setmetatable(o, TurnTracker)

  return o
end

---Turn tracker that allows entities with differing facing directions to take turns at the same time
---@return dev.konstinople.library.turn_based.DirectionalTurnTracker
function TurnBasedLib.new_directional_tracker()
  local o = {
    facing_directions = {},
    turn_trackers = {}
  }
  setmetatable(o, DirectionalTurnTracker)

  return o
end

---@return dev.konstinople.library.turn_based.Lock
function TurnBasedLib.new_lock()
  local o = {}
  setmetatable(o, Lock)

  return o
end

---@return dev.konstinople.library.turn_based.PerTeamLock
function TurnBasedLib.new_per_team_lock()
  local o = {
    locks = {},
    entity_teams = {},
  }
  setmetatable(o, PerTeamLock)

  return o
end

return TurnBasedLib

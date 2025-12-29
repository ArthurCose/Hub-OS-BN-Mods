---@class TrackedData
---@field augment? Augment

---@type table<any, TrackedData>
local tracking = {}

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local entity_id = player:id()

  player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  -- handle removal
  augment.on_delete_func = function()
    player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
    tracking[entity_id].augment = nil
  end

  -- see if we're already tracking this entity
  local data = tracking[entity_id]

  if data then
    -- data exists, update it
    data.augment = augment
    return
  end

  -- start tracking
  data = {
    augment = augment
  }
  tracking[entity_id] = data

  -- register callbacks
  local boost_hp_bug = function()
    if not data.augment then
      -- not installed
      return
    end

    player:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 1)
  end

  player:register_status_callback(Hit.Flinch, boost_hp_bug)
  player:register_status_callback(Hit.Drag, boost_hp_bug)
end

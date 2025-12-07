---@class BattleNetwork.Emotions
local Lib = {}

---@return SynchroEmotion
function Lib.new_synchro()
  local synchro = {}
  setmetatable(synchro, require("synchro.lua"))
  return synchro
end

---@return AngerEmotion
function Lib.new_anger()
  local anger = {}
  setmetatable(anger, require("anger.lua"))
  return anger
end

---Implements supported emotions
---@param player Entity
function Lib.implement_supported(player)
  local synchro = Lib.new_synchro()
  synchro:implement(player)

  local anger = Lib.new_anger()
  anger:implement(player)
end

---Implements supported emotions and sets listeners for activation
---
---This will overwrite player.on_countered_func
---@param player Entity
function Lib.implement_supported_full(player)
  local synchro = Lib.new_synchro()
  synchro:implement(player)
  synchro:implement_activation(player)

  local anger = Lib.new_anger()
  anger:implement(player)
  anger:implement_activation(player)

  return {
    synchro = synchro,
    anger = anger
  }
end

return Lib

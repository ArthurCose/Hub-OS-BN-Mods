local shared_init = require("../shared/entry.lua")

---@type table<Rank, _BattleNetwork6.CraggerProps>
local props_by_rank = {
  [Rank.V1] = {
    name = "Cragger",
    health = 120,
    attack = 50,
    disable_movement = true
  },
  [Rank.V2] = {
    name = "MetlCrgr",
    health = 160,
    attack = 120
  },
  [Rank.V3] = {
    name = "BigCrggr",
    health = 200,
    attack = 200
  },
  [Rank.SP] = {
    name = "Cragger",
    health = 240,
    attack = 220
  },
  [Rank.Rare1] = {
    name = "RarCrggr",
    health = 200,
    attack = 150,
    deletes_chips = true
  },
  [Rank.Rare2] = {
    name = "RarCrgr2",
    health = 240,
    attack = 220,
    deletes_chips = true
  },
}

local palettes_by_rank = {
  [Rank.V1] = "v1.palette.png",
  [Rank.V2] = "v2.palette.png",
  [Rank.V3] = "v3.palette.png",
  [Rank.SP] = "sp.palette.png",
  [Rank.Rare1] = "rare1.palette.png",
  [Rank.Rare2] = "rare2.palette.png",
}

---@param character Entity
function character_init(character)
  character:set_name("Cragger")
  character:set_palette(palettes_by_rank[character:rank()] or palettes_by_rank[Rank.V1])
  shared_init(character, props_by_rank[character:rank()] or props_by_rank[Rank.V1])
end

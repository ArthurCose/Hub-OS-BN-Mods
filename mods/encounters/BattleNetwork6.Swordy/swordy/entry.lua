local shared_init = require("../shared/entry.lua")

---@type table<Rank, _BattleNetwork6.SwordyProps>
local props_by_rank = {
  [Rank.V1] = {
    name = "Swordy",
    element = Element.None,
    health = 90,
    ai = "V1",
    attack = 30,
    attack_delay = 64,
    attack_endlag = 80,
    movement_time = 72,
  },
  [Rank.V2] = {
    name = "Swordy",
    element = Element.Fire,
    health = 140,
    ai = "V1",
    attack = 60,
    attack_delay = 24,
    attack_endlag = 16,
    movement_time = 48,
  },
  [Rank.V3] = {
    name = "Swordy",
    element = Element.Aqua,
    health = 200,
    ai = "AQUA",
    attack = 200,
    attack_delay = 40,
    attack_endlag = 40,
    movement_time = 64,
  },
  -- [Rank.SP] = {
  --   name = "Swordy",
  --   element = Element.None,
  --   health = 200,
  --   attack = 120,
  -- },
  [Rank.Rare1] = {
    name = "RarSwrdy",
    element = Element.Fire,
    health = 160,
    ai = "RARE",
    attack = 80,
    attack_delay = 16,
    attack_endlag = 0, -- holds the animation, but instantly backs off
    movement_time = 42,
  },
  [Rank.Rare2] = {
    name = "RarSwrd2", -- bn formats this as RarSwrdy2, but we don't render text the same way
    element = Element.Aqua,
    health = 220,
    ai = "AQUA",
    attack = 150,
    attack_delay = 24,
    attack_endlag = 24,
    movement_time = 64,
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
  character:set_palette(palettes_by_rank[character:rank()] or palettes_by_rank[Rank.V1])
  shared_init(character, props_by_rank[character:rank()] or props_by_rank[Rank.V1])
end

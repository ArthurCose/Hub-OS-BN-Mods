local shared_init = require("../shared/entry.lua")

local props_by_rank = {
  [Rank.V1] = {
    health = 140,
    attack = 60,
    idle_steps = 0,
    gape_duration = 38,
    cursor_frames_per_tile = 22
  },
  [Rank.V2] = {
    health = 210,
    attack = 100,
    idle_steps = 0,
    gape_duration = 32,
    cursor_frames_per_tile = 21
  },
}

local palettes_by_rank = {
  [Rank.V1] = "v1.palette.png",
  [Rank.V2] = "v2.palette.png",
}

---@param character Entity
function character_init(character)
  character:set_name("RarePira")
  character:set_palette(palettes_by_rank[character:rank()] or palettes_by_rank[Rank.V1])
  shared_init(character, props_by_rank[character:rank()] or props_by_rank[Rank.V1])
end

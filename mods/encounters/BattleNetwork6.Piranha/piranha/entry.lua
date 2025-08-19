local shared_init = require("../shared/entry.lua")

local props_by_rank = {
  [Rank.V1] = {
    health = 70,
    attack = 20,
    idle_steps = 1,
    gape_duration = 62,
    cursor_frames_per_tile = 25
  },
  [Rank.V2] = {
    health = 120,
    attack = 40,
    idle_steps = 0,
    gape_duration = 56,
    cursor_frames_per_tile = 24
  },
  [Rank.V3] = {
    health = 150,
    attack = 60,
    idle_steps = 0,
    gape_duration = 50,
    cursor_frames_per_tile = 23
  },
  [Rank.SP] = {
    health = 180,
    attack = 80,
    idle_steps = 0,
    gape_duration = 44,
    cursor_frames_per_tile = 22
  },
  [Rank.Rare1] = {
    health = 140,
    attack = 60,
    idle_steps = 0,
    gape_duration = 38,
    cursor_frames_per_tile = 22
  },
  [Rank.Rare2] = {
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
  [Rank.V3] = "v3.palette.png",
  [Rank.SP] = "sp.palette.png",
  [Rank.Rare1] = "rare1.palette.png",
  [Rank.Rare2] = "rare2.palette.png",
}

---@param character Entity
function character_init(character)
  local rank = character:rank()

  if rank == Rank.Rare1 then
    character:set_name("RarePira1")
  elseif rank == Rank.Rare2 then
    character:set_name("RarePira2")
  else
    character:set_name("Piranha")
  end

  character:set_palette(palettes_by_rank[rank] or palettes_by_rank[Rank.V1])
  shared_init(character, props_by_rank[rank] or props_by_rank[Rank.V1])
end

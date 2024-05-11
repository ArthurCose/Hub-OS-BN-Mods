local shared_character_init = require("../shared/entry.lua")

function character_init(character)
  shared_character_init(character)

  if character:rank() == Rank.EX then
    character:set_name("Cactkl")
    character:set_health(110)
    character._damage = 40
    character:set_palette(Resources.load_texture("" .. "cactikilEX.palette.png"))
  else
    character:set_name("Cactikil")
    character:set_health(70)
    character._damage = 20
    character:set_palette(Resources.load_texture("" .. "cactikil.palette.png"))
  end
end

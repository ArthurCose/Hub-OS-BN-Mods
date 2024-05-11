local shared_character_init = require("../shared/entry.lua")

function character_init(character)
  shared_character_init(character)
  character:set_name("Cacter")

  if character:rank() == Rank.EX then
    character:set_health(270)
    character._damage = 200
    character:set_palette(Resources.load_texture("" .. "cacterEX.palette.png"))
  else
    character:set_health(230)
    character._damage = 150
    character:set_palette(Resources.load_texture("" .. "cacter.palette.png"))
  end
end

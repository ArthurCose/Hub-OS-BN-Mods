local shared_character_init = require("../shared/entry.lua")

function character_init(character)
  shared_character_init(character)

  if character:rank() == Rank.EX then
    character:set_name("Cactrl")
    character:set_health(190)
    character._damage = 100
    character:set_palette(Resources.load_texture("" .. "cactrollEX.palette.png"))
  else
    character:set_name("Cactroll")
    character:set_health(150)
    character._damage = 70
    character:set_palette(Resources.load_texture("" .. "cactroll.palette.png"))
  end
end

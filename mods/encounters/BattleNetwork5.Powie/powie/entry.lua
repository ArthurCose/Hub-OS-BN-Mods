local shared_entry = require("../shared/shared_entry.lua")

function character_init(character)
  shared_entry(character)
  character:set_name("Powie")

  if character:rank() == Rank.EX then
    character:set_palette(Resources.load_texture("powieEX.palette.png"))
    character:set_health(100)
    character._damage = 40
    character._shock_shape = "column"
  else
    character:set_palette(Resources.load_texture("powie.palette.png"))
    character:set_health(60)
    character._damage = 20
  end
end

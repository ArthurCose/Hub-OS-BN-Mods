local shared_entry = require("../shared/shared_entry.lua")

function character_init(character)
  shared_entry(character)
  character:set_name("Powie2")
  character._shock_shape = "column"

  if character:rank() == Rank.EX then
    character:set_palette(Resources.load_texture("powie2EX.palette.png"))
    character:set_health(180)
    character._damage = 110
  else
    character:set_palette(Resources.load_texture("powie2.palette.png"))
    character:set_health(140)
    character._damage = 70
  end
end

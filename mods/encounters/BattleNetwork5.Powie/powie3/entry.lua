local shared_entry = require("../shared/shared_entry.lua")

function character_init(character)
  shared_entry(character)
  character:set_name("Powie3")
  character._shock_shape = "cross"

  if character:rank() == Rank.EX then
    character:set_palette(Resources.load_texture("powie3EX.palette.png"))
    character:set_health(260)
    character._damage = 190
  else
    character:set_palette(Resources.load_texture("powie3.palette.png"))
    character:set_health(240)
    character._damage = 150
  end
end

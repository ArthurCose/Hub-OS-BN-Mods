local shared_character_init = require("../shared/entry.lua")

function character_init(character)
  shared_character_init(character)
  character:set_name("Shademan")
  character:set_health(1200)
end

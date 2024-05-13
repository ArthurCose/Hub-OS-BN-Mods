local bn_assets = require("BattleNetwork.Assets")

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local function try_hit(entity)
  if not entity:hittable() or entity:intangible() or entity:ignoring_negative_tile_effects() or entity:element() == Element.Fire then
    return
  end

  entity:hit(HitProps.new(50, Hit.Flinch | Hit.Impact, Element.Fire))

  local tile = entity:current_tile()
  tile:set_state(TileState.Normal)

  local artifact = Artifact.new()
  artifact:set_texture(HIT_TEXTURE)
  artifact:sprite():set_layer(-5)

  local animation = artifact:animation()
  animation:load(HIT_ANIMATION_PATH)
  animation:set_state("FIRE")
  animation:on_complete(function()
    artifact:erase()
  end)

  entity:field():spawn(artifact, tile)
end

---@param custom_state CustomTileState
function tile_state_init(custom_state)
  custom_state.on_update_func = function(self, tile)
    tile:find_characters(function(entity)
      try_hit(entity)
      return false
    end)

    tile:find_obstacles(function(entity)
      try_hit(entity)
      return false
    end)
  end
end

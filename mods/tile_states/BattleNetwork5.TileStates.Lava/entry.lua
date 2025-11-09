local bn_assets = require("BattleNetwork.Assets")

---@param entity Entity
local function try_hit(entity)
  if not entity:hittable() then return end
  if entity:intangible() then return end
  if entity:ignoring_negative_tile_effects() then return end
  if entity:element() == Element.Fire then return end

  local props = HitProps.new(50, Hit.Flinch, Element.Fire)
  entity:hit(props)

  local tile = entity:current_tile()

  local hit_fx = bn_assets.HitParticle.new("FIRE", math.random(-10, 10), math.random(-10, 10))
  Field.spawn(hit_fx, tile)

  tile:set_state(TileState.Normal)
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

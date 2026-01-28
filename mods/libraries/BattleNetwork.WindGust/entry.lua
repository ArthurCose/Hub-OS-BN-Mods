---@class BattleNetwork.WindGust
local WindGustLib = {}

---@class BattleNetwork.WindGust.Builder
---@field package _sync_movements boolean?
local WindGustBuilder = {}
WindGustBuilder.__index = WindGustBuilder

---@return BattleNetwork.WindGust.Builder
function WindGustLib.new_wind_gust()
  local builder = {}
  setmetatable(builder, WindGustBuilder)

  return builder
end

---Moves characters at specific intervals to sync movements in the same column.
---`false` when unset
---@param sync boolean?
function WindGustBuilder:set_sync_movements(sync)
  self._sync_movements = sync or true
end

---`false` when unset
---@param despawn boolean?
function WindGustBuilder:set_despawn_on_team_tile(despawn)
  self._despawn_on_team = despawn or true
end

---@param team Team
---@param direction Direction
---@param tile Tile
local function create_gust_hitbox(team, direction, tile)
  local spell = Spell.new(team)
  spell:set_hit_props(HitProps.new(0, Hit.Drain, Element.Wind))

  spell.on_spawn_func = function()
    spell:delete()
  end

  spell.on_attack_func = function(_, other)
    if not Character.from(other) then
      return
    end

    local next_tile = spell:get_tile(direction, 1)

    if next_tile then
      other:slide(next_tile, 4)
    end
  end

  Field.spawn(spell, tile)
  spell:attack_tile()
end

---@param team Team
---@param direction Direction
function WindGustBuilder:create_spell(team, direction)
  local spell = Spell.new(team)
  spell:set_hit_props(HitProps.new(0, Hit.Drain, Element.Wind))

  local i = 0
  spell.on_update_func = function()
    local tile = spell:current_tile()
    spell:attack_tile()

    if self._despawn_on_team and tile:team() == team then
      spell:delete()
      return
    end

    if not self._sync_movements then
      create_gust_hitbox(team, direction, tile)
    end

    i = i + 1

    local has_neutral_obstacle = false
    tile:find_obstacles(function(o)
      if o:team() == Team.Other then
        has_neutral_obstacle = true
      end

      return false
    end)

    if has_neutral_obstacle then
      spell:delete()
      return
    end

    if spell:is_moving() then
      return
    end

    if self._sync_movements then
      create_gust_hitbox(team, direction, tile)
    end

    local next_tile = tile:get_tile(direction, 1)

    if not next_tile then
      spell:delete()
      return
    end

    spell:slide(next_tile, 4)
  end

  return spell
end

return WindGustLib

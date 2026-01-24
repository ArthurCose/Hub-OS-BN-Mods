---@class dev.konstinople.library.liberation
local Lib = {}

---@param encounter Encounter
---@param terrain Liberation.TerrainString
function Lib.apply_spawn_positions_for_terrain(encounter, terrain)
  local spawn_positions

  if terrain == "advantage" then
    spawn_positions = {
      { 2, 2 },
      { 3, 3 },
      { 3, 1 },
      { 1, 1 },
      { 1, 3 },
      { 4, 2 },
      { 4, 1 },
      { 4, 3 },
      { 2, 1 },
      { 2, 3 },
      { 3, 2 },
      { 1, 2 },
    }
  elseif terrain == "disadvantage" then
    spawn_positions = {
      { 1, 2 },
      { 2, 3 },
      { 2, 1 },
      { 1, 1 },
      { 1, 3 },
      { 2, 2 },
    }
  elseif terrain == "surrounded" then
    spawn_positions = {
      { 3, 2 },
      { 4, 2 },
      { 3, 1 },
      { 4, 3 },
      { 3, 3 },
      { 4, 1 },
    }
  else
    spawn_positions = {
      { 2, 2 },
      { 1, 3 },
      { 1, 1 },
      { 3, 3 },
      { 3, 1 },
      { 1, 2 },
      { 3, 2 },
      { 2, 1 },
      { 2, 3 },
    }
  end

  for i = 0, encounter:player_count() - 1 do
    local position = spawn_positions[i % #spawn_positions + 1]
    encounter:spawn_player(i, position[1], position[2])
  end
end

local function apply_basic_terrain(red_end_x)
  for y = 0, Field.height() - 1 do
    for x = 0, red_end_x do
      Field.tile_at(x, y):set_team(Team.Red, Direction.Right)
    end

    for x = red_end_x + 1, Field.width() - 1 do
      Field.tile_at(x, y):set_team(Team.Blue, Direction.Left)
    end
  end
end

---Sets teams on tiles
---@param terrain Liberation.TerrainString
function Lib.apply_terrain(terrain)
  if terrain == "advantage" then
    apply_basic_terrain(4)
  elseif terrain == "disadvantage" then
    apply_basic_terrain(2)
  elseif terrain == "surrounded" then
    for y = 0, Field.height() - 1 do
      for x = 0, 2 do
        Field.tile_at(x, y):set_team(Team.Blue, Direction.Right)
      end

      Field.tile_at(3, y):set_team(Team.Red, Direction.Left)
      Field.tile_at(4, y):set_team(Team.Red, Direction.Right)

      for x = Field.width() - 3, Field.width() - 1 do
        Field.tile_at(x, y):set_team(Team.Blue, Direction.Left)
      end
    end
  else
    apply_basic_terrain(3)
  end
end

---@param encounter Encounter
---@param data Liberation.EncounterData
function Lib.resolve_spectators(encounter, data)
  for i = 0, encounter:player_count() - 1 do
    if data.spectators[i] then
      encounter:mark_spectator(i)
    end
  end
end

---@param data Liberation.EncounterData
function Lib.apply_statuses(data)
  if not data.start_invincible then
    return
  end

  local artifact = Artifact.new()
  artifact.on_battle_start_func = function()
    Field.find_players(function(player)
      player:apply_status(Hit.Invincible, 512)
      return false
    end)

    artifact:delete()
  end
end

---Restores health from data,
---and sends the final health back to the server when battle ends.
---@param entity Entity
---@param encounter Encounter
---@param data Liberation.EncounterData
function Lib.sync_enemy_health(entity, encounter, data)
  if data.health then
    entity:set_health(data.health)
  end

  encounter:on_battle_end(function()
    local health = 0

    if not entity:deleted() then
      health = entity:health()
    end

    encounter:send_to_server({ health = health })
  end)
end

---@param encounter Encounter
---@param data Liberation.EncounterData
function Lib.init(encounter, data)
  Lib.resolve_spectators(encounter, data)
  Lib.apply_spawn_positions_for_terrain(encounter, data.terrain)
  Lib.apply_terrain(data.terrain)
  Lib.apply_statuses(data)
  encounter:enable_automatic_turn_end(true)
  encounter:set_turn_limit(3)
end

return Lib

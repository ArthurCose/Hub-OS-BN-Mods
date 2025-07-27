---@class BattleNetwork.FallingRock
local Lib = {}

local ROCK_SFX = Resources.load_audio("rock_shatter.ogg")
local TEXTURE = Resources.load_texture("rock.png")
local ANIMATION_PATH = _folder_path .. "rock.animation"
local BIG_SHADOW = Resources.load_texture("shadow_big.png")
local SMALL_SHADOW = Resources.load_texture("shadow_small.png")

local function calculate_elevation_after(frame, acc, vel_y)
  return frame * ((frame + 1) / 2 * acc + vel_y)
end

local HIT_HEIGHT = Tile:height()
local ROCK_ACC = 0.07
local FALL_TIME = 5 / ROCK_ACC -- must hit a vel of 5, before it hits the ground
local ROCK_INITIAL_HEIGHT = calculate_elevation_after(FALL_TIME, ROCK_ACC, 0)
local PARTICLE_ACC = 0.15

---Spawns up to `count` falling rocks, aims for enemy characters
---@param field Field
---@param team Team the team of the attacker, tiles on this team will not be cracked
---@param count number
function Lib.crack_tiles(field, team, count)
  -- find enemy tiles
  local enemy_tiles = field:find_tiles(function(tile)
    local tile_team = tile:team()
    return (tile_team ~= team or tile_team == Team.Other) and not tile:is_edge()
  end)

  -- randomly crack tiles
  for _ = 1, math.min(#enemy_tiles, count) do
    local tile = table.remove(enemy_tiles, math.random(#enemy_tiles))

    if tile:state() == TileState.Cracked then
      tile:set_state(TileState.Broken)
    else
      tile:set_state(TileState.Cracked)
    end
  end
end

---Spawns up to `count` falling rocks, aims for enemy characters
---@param field Field
---@param team Team the team of the attacker
---@param count number
---@param hit_props HitProps
function Lib.spawn_falling_rocks(field, team, count, hit_props)
  -- find enemy tiles
  local enemy_tiles = field:find_tiles(function(tile)
    local tile_team = tile:team()
    return (tile_team ~= team or tile_team == Team.Other) and not tile:is_edge()
  end)

  -- resolve which of the tiles have enemies
  local tiles_with_enemy = {}

  for i, tile in ipairs(enemy_tiles) do
    local contains_enemy = false

    tile:find_characters(function(character)
      if character:hittable() and character:team() ~= team then
        contains_enemy = true
      end
      return false
    end)

    if contains_enemy then
      tiles_with_enemy[#tiles_with_enemy + 1] = i
    end
  end

  -- aim for enemies
  while #tiles_with_enemy > 0 and count > 0 do
    local i = table.remove(tiles_with_enemy, math.random(#tiles_with_enemy))
    local tile = table.remove(enemy_tiles, i)

    local rock = Lib.create_falling_rock(team, hit_props)
    field:spawn(rock, tile)

    count = count - 1
  end

  -- randomly drop remaining rocks
  for _ = 1, math.min(#enemy_tiles, count) do
    local tile = table.remove(enemy_tiles, math.random(#enemy_tiles))

    local rock = Lib.create_falling_rock(team, hit_props)
    field:spawn(rock, tile)
  end
end

---@param team Team
---@param hit_props HitProps
function Lib.create_falling_rock(team, hit_props)
  local spell = Spell.new(team)
  spell:set_hit_props(hit_props)
  spell:set_texture(TEXTURE)
  spell:set_shadow(BIG_SHADOW)
  spell:show_shadow(true)
  spell:set_never_flip(true)

  local animation = spell:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state("BIG")

  local sprite = spell:sprite()
  sprite:set_layer(-4)

  local spawn_particles = function()
    local tile = spell:current_tile()
    local elevation = spell:elevation()

    local particle_a = Lib.create_smashed_particle(-0.5, -3)
    particle_a:set_elevation(elevation)
    spell:field():spawn(particle_a, tile)

    local particle_b = Lib.create_smashed_particle(0.5, -2.5)
    particle_b:set_elevation(elevation)
    spell:field():spawn(particle_b, tile)
  end

  local vel = 0

  spell:set_elevation(ROCK_INITIAL_HEIGHT)

  spell.on_update_func = function()
    vel = vel + ROCK_ACC

    local elevation = spell:elevation()
    spell:set_elevation(elevation - vel)

    if elevation < HIT_HEIGHT then
      spell:current_tile():attack_entities(spell)
    end

    if elevation <= 0 then
      if spell:current_tile():is_walkable() then
        spawn_particles()
        Resources.play_audio(ROCK_SFX, AudioBehavior.NoOverlap)
      end

      spell:erase()
    end
  end

  spell.on_collision_func = function()
    spawn_particles()
    Resources.play_audio(ROCK_SFX, AudioBehavior.NoOverlap)
    spell:erase()
  end

  return spell
end

---@param vel_x number
---@param vel_y number
function Lib.create_smashed_particle(vel_x, vel_y)
  local artifact = Artifact.new()
  artifact:set_texture(TEXTURE)
  artifact:set_shadow(SMALL_SHADOW)
  artifact:set_never_flip(true)
  artifact:show_shadow(true)

  local animation = artifact:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state("SMALL")

  local sprite = artifact:sprite()
  sprite:set_layer(-5)

  local ground_time = 0

  artifact.on_update_func = function()
    vel_y = vel_y + PARTICLE_ACC

    local elevation = artifact:elevation() - vel_y

    if elevation <= 0 then
      elevation = 0

      sprite:set_visible((ground_time / 2) % 2 == 0)
      ground_time = ground_time + 1
    else
      local offset = artifact:offset()
      artifact:set_offset(offset.x + vel_x, offset.y)
    end

    if ground_time > 11 then
      artifact:erase()
    end

    artifact:set_elevation(elevation)
  end

  return artifact
end

return Lib

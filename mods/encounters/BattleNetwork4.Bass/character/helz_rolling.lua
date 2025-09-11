---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local ROLLING_TEXTURE = bn_assets.load_texture("hells_rolling.png")
local ROLLING_ANIMATION = bn_assets.fetch_animation_path("hells_rolling.animation")
local SFX = Resources.load_audio("helz_rolling.ogg")

---@param tile Tile?
---@param team Team
local function has_enemies(tile, team)
  if not tile then return end

  local has_enemy = false

  tile:find_characters(function(character)
    if character:team() ~= team and character:hittable() then
      has_enemy = true
    end

    return false
  end)

  return has_enemy
end

---@param spell Entity
---@param direction_priority Direction
local function next_helz_tile(spell, direction_priority)
  local team = spell:team()
  local direction = spell:facing()

  local forward_tile = spell:get_tile(direction, 1)

  if has_enemies(forward_tile, team) then
    return forward_tile
  end

  local test_tile = spell:get_tile(Direction.join(direction, direction_priority), 1)

  if has_enemies(test_tile, team) then
    return test_tile
  end

  test_tile = spell:get_tile(Direction.join(direction, Direction.reverse(direction_priority)), 1)

  if has_enemies(test_tile, team) then
    return test_tile
  end

  return forward_tile
end

---@param user Entity
---@param hit_props HitProps
---@param direction_priority Direction
local function create_helz_rolling(user, hit_props, direction_priority)
  local spell = Spell.new(user:team())
  local direction = user:facing()

  spell:set_hit_props(hit_props)
  spell:set_facing(direction)
  spell:set_texture(ROLLING_TEXTURE)

  local animation = spell:animation()
  animation:load(ROLLING_ANIMATION)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  local function normal_update()
    spell:attack_tile()

    if not spell:current_tile():is_walkable() then
      animation:set_state("DESPAWN")
      animation:on_complete(function()
        spell:erase()
      end)

      local offset = spell:movement_offset()
      spell:set_offset(offset.x, offset.y)
      spell:set_movement_offset(0, 0)
      spell:cancel_movement()

      spell.on_update_func = nil
      return
    end

    if spell:is_moving() then
      return
    end

    spell:slide(next_helz_tile(spell, direction_priority), 10)
  end

  -- spawn animation
  local time = 0
  local max_time = 32
  local start_angle = -math.pi * 0.25
  local end_angle = math.pi * 0.5

  spell.on_update_func = function()
    time = time + 1

    local angle = (end_angle - start_angle) * time / max_time + start_angle
    local x = math.cos(angle) * Tile:width()
    local y = -math.sin(angle) * Tile:height() * 0.5

    y = y + Tile:height() * 0.5

    if spell:facing() == Direction.Right then
      x = -x
    end

    if direction_priority == Direction.Up then
      y = -y
    end

    spell:set_movement_offset(x, y)

    if time == max_time then
      spell.on_update_func = normal_update
    end
  end

  spell.on_spawn_func = function()
    Resources.play_audio(SFX)
  end

  return spell
end

return create_helz_rolling

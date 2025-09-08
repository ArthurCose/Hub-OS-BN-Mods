---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local ROLLING_TEXTURE = bn_assets.load_texture("hells_rolling.png")
local ROLLING_ANIMATION = bn_assets.fetch_animation_path("hells_rolling.animation")
local SWING_SFX = bn_assets.load_audio("hells_rolling.ogg")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:use_hand()

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
  spell:set_tile_highlight(Highlight.Solid)
  spell:set_texture(ROLLING_TEXTURE)

  local animation = spell:animation()
  animation:load(ROLLING_ANIMATION)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  local function normal_update()
    spell:attack_tile()

    if spell:is_moving() then
      return
    end

    if not spell:current_tile():is_walkable() then
      local artifact = bn_assets.MobMove.new("BIG_START")
      local spell_sprite = spell:sprite()
      artifact:set_elevation(spell_sprite:origin().y // 2)

      Field.spawn(artifact, spell:current_tile())
      spell:erase()
      return
    end

    -- normally has duration 9, it's sped up for pvp
    spell:slide(next_helz_tile(spell, direction_priority), 7)
  end

  -- spawn animation
  local x_inc = 5
  local elevation_inc = -8

  if direction == Direction.Left then
    x_inc = -x_inc
  end

  local x_offset = 20 * -x_inc
  local elevation = 20 * -elevation_inc

  spell.on_update_func = function()
    x_offset = x_offset + x_inc
    elevation = elevation + elevation_inc

    spell:set_elevation(elevation)
    spell:set_offset(x_offset, 0)

    if elevation == 0 then
      spell.on_update_func = normal_update
    end
  end

  return spell
end

---@param user Entity
return function(user)
  local hit_props = HitProps.new(
    50 + user:attack_level() * 10,
    Hit.Flinch | Hit.Flash,
    Element.None,
    user:context()
  )

  local action = Action.new(user, "CHARACTER_HELZ_ROLLING_START")
  action:set_lockout(ActionLockout.new_sequence())

  ---@type ActionStep
  local start_step = action:create_step()

  local animation = user:animation()

  action.on_execute_func = function()
    animation:on_complete(function()
      start_step:complete_step()
    end)
  end

  sword:create_action_step(action, function()
    Resources.play_audio(SWING_SFX)

    local top_tile = user:get_tile(Direction.Up, 1)
    local bottom_tile = user:get_tile(Direction.Down, 1)

    if top_tile then
      local rolling = create_helz_rolling(user, hit_props, Direction.Down)
      Field.spawn(rolling, top_tile)
    end

    if bottom_tile then
      local rolling = create_helz_rolling(user, hit_props, Direction.Up)
      Field.spawn(rolling, bottom_tile)
    end
  end)

  return action
end

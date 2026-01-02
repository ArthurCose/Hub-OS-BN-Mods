local spawn_state = "SPAWN"
local flash_state = "FLASH"
local idle_state = "IDLE_YELLOW"

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("cursor_circgun.png")
local ANIMATION_PATH = bn_assets.fetch_animation_path("cursor_circgun.animation")

local AUDIO = bn_assets.load_audio("magnum_cursor.ogg")
local LOCKON_AUDIO = bn_assets.load_audio("cursor_lockon.ogg")
local SHOOT_AUDIO = bn_assets.load_audio("vulcan.ogg")

local HIT_TEXTURE = bn_assets.load_texture("buster_charged_impact.png")
local HIT_ANIM_PATH = bn_assets.fetch_animation_path("buster_charged_impact.animation")


local create_hit_effect = function(tile)
  local hit_effect = Artifact.new()
  local hit_anim = hit_effect:animation()

  hit_effect:set_texture(HIT_TEXTURE)
  hit_anim:load(HIT_ANIM_PATH)

  hit_effect.on_spawn_func = function()
    Resources.play_audio(SHOOT_AUDIO)
  end

  hit_anim:set_state("DEFAULT")
  hit_anim:on_complete(function()
    hit_effect:erase()
  end)

  Field.spawn(hit_effect, tile)
end

---@param user Entity
local function attack(user, props, tile, count)
  local spell = Spell.new(user:team())

  local facing = user:facing()

  spell:set_facing(facing)

  spell:set_hit_props(
    HitProps.from_card(
      props,
      user:context(),
      Drag.None
    )
  )

  local can_start = false

  spell:set_texture(TEXTURE)

  local spell_anim = spell:animation()
  spell_anim:load(ANIMATION_PATH)
  spell_anim:set_state(flash_state)
  spell_anim:on_complete(function()
    spell_anim:set_state(idle_state)
    spell_anim:on_complete(function()
      can_start = true
    end)
  end)

  spell.on_spawn_func = function()
    Resources.play_audio(LOCKON_AUDIO)
  end

  local timer = 20
  spell.on_update_func = function(self)
    if can_start == false then return end

    timer = timer - 1

    if timer == 0 then
      if tile:is_walkable() then
        self:attack_tile()
      end

      create_hit_effect(tile)

      self:erase()
    end
  end

  Field.spawn(spell, tile)
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)

  local main_step = action:create_step()

  action:set_lockout(ActionLockout.new_sequence())

  local cursor_count = 3
  local is_dark = props.card_class == CardClass.Dark
  if is_dark then
    cursor_count = 6
    spawn_state = "SPAWN_DARK"
    flash_state = "FLASH_DARK"
    idle_state = "IDLE_DARK"
  end

  local timer = 360
  local end_timer = 80

  if is_dark == true then end_timer = end_timer + 20 end

  local has_attacked = false

  local start_x;
  if user:team() == Team.Blue then
    start_x = 1
  else
    start_x = Field.width() - 2
  end

  local is_blue = user:team() == Team.Blue

  -- Always at the top of a column
  local start_tile = Field.tile_at(start_x, 1);

  local function bad(tile, direction)
    if direction == nil then
      return true
    end

    local new_tile = tile:get_tile(direction, 1)

    if not new_tile then
      return true
    end

    if new_tile:is_edge() then
      return true
    end

    if (is_blue == false and (new_tile:x() < tile:x())) or (is_blue == true and (new_tile:x() >= tile:x())) then
      local y = 1
      local x = new_tile:x()
      local non_team_count = 0
      while y < Field.height() - 1 and non_team_count == 0 do
        local test_tile = Field.tile_at(x, y)
        if test_tile == nil then goto continue end
        if test_tile:is_edge() then goto continue end

        if test_tile:team() ~= user:team() then non_team_count = non_team_count + 1 end

        ::continue::

        y = y + 1
      end

      if non_team_count ~= 0 then
        return false
      else
        return true
      end
    end
    return false
  end

  local list = {}
  local index = 1
  local move_timer = 4
  local previous_direction = Direction.Right


  list[Direction.Up] = { Direction.Right, Direction.Down, Direction.Left }
  list[Direction.Down] = { Direction.Left, Direction.Up, Direction.Right }
  list[Direction.Left] = { Direction.Up, Direction.Right, Direction.Down }
  list[Direction.Right] = { Direction.Down, Direction.Left, Direction.Up }

  local function reverse(dir, i)
    if list[dir][i] == Direction.Right or list[dir][i] == Direction.Left then
      list[dir][i] = Direction.reverse(list[dir][i])
    end
  end

  if is_blue == true then
    previous_direction = Direction.Left

    for i = 1, 3, 1 do
      reverse(Direction.Up, i)
      reverse(Direction.Down, i)
      reverse(Direction.Left, i)
      reverse(Direction.Right, i)
    end
  end

  local function check_and_set_next_tile(tile)
    local direction_list;
    local next_tile;
    if bad(tile, previous_direction) == true then
      direction_list = list[previous_direction]

      while next_tile == nil and index <= #direction_list do
        if bad(tile, direction_list[index]) then
          index = index + 1
        else
          previous_direction = direction_list[index]
          next_tile = tile:get_tile(direction_list[index], 1)
          break
        end
      end
    else
      next_tile = tile:get_tile(previous_direction, 1)
    end

    index = 1

    return next_tile
  end

  local cursor = Artifact.new(user:team())
  cursor:set_texture(TEXTURE)

  local cursor_anim = cursor:animation()
  cursor_anim:load(ANIMATION_PATH)
  cursor_anim:set_state(spawn_state)

  local cursor_can_move = false

  cursor.on_spawn_func = function()
    cursor_anim:set_state(spawn_state)
    cursor_anim:on_complete(function()
      cursor_can_move = true
      cursor_anim:set_state(idle_state)
    end)
  end

  action.on_execute_func = function()
    Field.spawn(cursor, start_tile)
  end

  main_step.on_update_func = function(self)
    if cursor:spawned() == false then return end
    if cursor_can_move == false then return end

    if has_attacked == true then
      end_timer = end_timer - 1

      if end_timer % 4 == 0 and cursor_count > 0 then
        local tile = check_and_set_next_tile(cursor:current_tile());

        if tile ~= nil then
          attack(user, props, tile)
          tile:add_entity(cursor)
        else
          cursor_count = 0
        end

        cursor_count = cursor_count - 1
      end

      if end_timer == 0 then self:complete_step() end

      return
    end

    move_timer = move_timer - 1

    if move_timer == 0 then
      local tile = cursor:current_tile()

      local next_tile = check_and_set_next_tile(tile);

      if next_tile == nil then
        cursor:erase()
        action:end_action()
        return
      end

      move_timer = 4
      cursor:teleport(next_tile, function() Resources.play_audio(AUDIO) end)
    end

    timer = timer - 1

    if user:input_has(Input.Pressed.Use) or timer == 0 then
      has_attacked = true

      cursor:hide()

      local tile = cursor:current_tile()
      attack(user, props, tile)
    end
  end

  return action
end

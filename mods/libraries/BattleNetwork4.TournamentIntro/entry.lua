---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local FINISH_SFX = bn_assets.load_audio("flashbomb.ogg")

---@class BattleNetwork4.TournamentIntro
local Lib = {
  BG_COLOR = Color.new(0, 0, 0),
  LINE_COLOR = Color.new(0, 255, 0),
  LINE_SPEED = 16
}

local WHITE_TEXTURE = Resources.load_texture("pixel.png")

local SCREEN_W = 240
local SCREEN_H = 160

local function create_background()
  local background = Artifact.new()
  background:set_texture(WHITE_TEXTURE)

  local sprite = background:sprite()

  -- try to cover the whole field
  -- would be nice to use math for this, but trying to write this fast
  sprite:set_offset(-1000, -1000)
  sprite:set_scale(3000, 3000)

  background:create_component(Lifetime.Scene).on_update_func = function()
    sprite:set_color_mode(ColorMode.Multiply)
    sprite:set_color(Lib.BG_COLOR)
  end

  Field.spawn(background, 0, 0)

  return background
end

---@param user Entity
---@param color Color
local function create_ghost(user, color)
  local ghost = Artifact.new()
  ghost:set_facing(user:facing())

  local queue = { { user:sprite(), ghost:sprite() } }
  while #queue > 0 do
    local item = queue[1]

    -- swap remove to avoid shifting
    queue[1] = queue[#queue]
    queue[#queue] = nil

    -- process
    local user_sprite = item[1]
    local ghost_sprite = item[2]

    ghost_sprite:copy_from(user_sprite)
    ghost_sprite:set_color_mode(ColorMode.Adopt)
    ghost_sprite:set_color(color)

    for _, user_child_sprite in ipairs(user_sprite:children()) do
      queue[#queue + 1] = { user_child_sprite, ghost_sprite:create_node() }
    end
  end

  local component = ghost:create_component(Lifetime.ActiveBattle)
  local sprite = ghost:sprite()
  component.on_update_func = function()
    sprite:set_color_mode(ColorMode.Adopt)
    sprite:set_color(color)
  end

  return ghost
end


local plain_intro_func = function(c)
  return Action.new(c)
end

local function create_pixel(color)
  local sprite = Hud:create_node()
  sprite:set_texture(WHITE_TEXTURE)
  sprite:set_color_mode(ColorMode.Multiply)
  sprite:set_color(color)

  -- avoid stitching issues
  sprite:set_width(1.01)
  sprite:set_height(1.01)

  return sprite
end

---@param action Action
---@param delay number
---@param callback fun()?
local function create_delay_step(action, delay, callback)
  local step = action:create_step()
  step.on_update_func = function()
    delay = delay - 1

    if delay > 0 then
      return
    end

    step:complete_step()

    if callback then
      callback()
    end
  end
end

---@param action Action
local function create_horizontal_lines_step(action)
  ---@type Sprite[]
  local black_lines = {}

  for y = 0, SCREEN_H - 1 do
    local sprite = create_pixel(Lib.BG_COLOR)
    sprite:set_offset(0, y)
    sprite:set_width(SCREEN_W)
    black_lines[#black_lines + 1] = sprite
  end

  ---@type [Sprite, Sprite, number][]
  local green_lines = {}

  ---@param speed number
  local function create_green_line(speed)
    ---@type Sprite
    local black_line = table.remove(black_lines, math.random(#black_lines))
    local y = black_line:offset().y

    local sprite = create_pixel(Lib.LINE_COLOR)

    local width = math.random(16, 120)
    sprite:set_width(width)

    if speed > 0 then
      sprite:set_offset(-width, y)
    else
      sprite:set_offset(SCREEN_W + width, y)
    end

    green_lines[#green_lines + 1] = { sprite, black_line, speed }
  end

  local step = action:create_step()
  step.on_update_func = function()
    for i = #green_lines, 1, -1 do
      local data = green_lines[i]
      local green_line, black_line, speed = data[1], data[2], data[3]

      -- move line
      local offset = green_line:offset()
      offset.x = offset.x + speed
      green_line:set_offset(offset.x, offset.y)

      local width = green_line:width()
      local delete = false

      if speed > 0 then
        -- moving right
        if offset.x > SCREEN_W then
          delete = true
        end

        black_line:set_offset(offset.x, offset.y)
      else
        -- moving left
        local right = offset.x + width

        if right < 0 then
          delete = true
        end

        black_line:set_width(right)
      end

      if delete then
        Hud:remove_node(black_line)
        Hud:remove_node(green_line)

        -- swap remove <3
        green_lines[i] = green_lines[#green_lines]
        green_lines[#green_lines] = nil
      end
    end

    if #black_lines > 0 then
      create_green_line(Lib.LINE_SPEED)
      create_green_line(-Lib.LINE_SPEED)
    end

    if #green_lines == 0 then
      -- finished animating our lines
      step:complete_step()
    end
  end
end

---@param action Action
---@param grid_lines Entity[]
local function create_vertical_grid_lines_step(action, grid_lines)
  local TILE_W = Tile:width()
  local TILE_H = Tile:height()

  local pending = 0
  local visible_field_height = Field.height() - 2
  local max_y = TILE_H // 2

  local offsets = {
    -TILE_H * 4,
    0,
    -TILE_H * 3,
    -TILE_H * 6,
    -TILE_H * 2,
  }

  local step = action:create_step()
  step.on_update_func = function()
    -- spawn grid lines
    for x = 2, Field.width() - 2 do
      local tile = Field.tile_at(x, 0)

      if tile then
        pending = pending + 1

        local line = Artifact.new()
        line:set_facing(Direction.Right)

        local sprite = line:sprite()
        sprite:set_texture(WHITE_TEXTURE)
        sprite:set_height(visible_field_height * TILE_H)

        local x_offset = -TILE_W // 2

        if x == Field.width() - 1 then
          x_offset = x_offset - 1
        end

        local y_offset = max_y - visible_field_height * TILE_H * 2 + offsets[(x - 1) % #offsets + 1]

        sprite:set_offset(x_offset, y_offset)

        local is_pending = true
        line:create_component(Lifetime.Scene).on_update_func = function()
          sprite:set_color(Lib.LINE_COLOR)
          sprite:set_color_mode(ColorMode.Multiply)

          sprite:set_offset(x_offset, y_offset)
          y_offset = math.min(y_offset + TILE_H // 2, max_y)

          if is_pending and y_offset == max_y then
            is_pending = false
            pending = pending - 1
          end
        end

        Field.spawn(line, tile)

        grid_lines[#grid_lines + 1] = line
      end
    end

    step.on_update_func = function()
      if pending <= 0 then
        step:complete_step()
      end
    end
  end
end

local intro_func = function(character)
  local action = Action.new(character)
  action:set_lockout(ActionLockout.new_sequence())

  local background = create_background()

  ---@type Entity[]
  local grid_lines = {}
  ---@type Entity[]
  local ghosts = {}
  ---@type Entity[]
  local removed_entities = {}

  -- track removed entities and prevent the background from being removed
  local removed_entity_map = { [background:id()] = true }

  local ghost_component = character:create_component(Lifetime.Scene)
  ghost_component.on_update_func = function()
    Field.find_entities(function(e)
      if not removed_entity_map[e:id()] then
        local tile = e:current_tile()
        tile:remove_entity(e)

        removed_entities[#removed_entities + 1] = e
        removed_entity_map[e:id()] = true
      end

      return false
    end)
  end

  local function return_entities()
    -- return entities to the field
    for _, e in ipairs(removed_entities) do
      if not e:deleted() then
        e:current_tile():add_entity(e)
      end
    end

    -- delete ghosts
    for _, ghost in ipairs(ghosts) do
      ghost:delete()
    end
  end

  action.on_execute_func = function()
    ghost_component:eject()

    for _, e in ipairs(removed_entities) do
      local ghost = create_ghost(e, Lib.LINE_COLOR)
      ghosts[#ghosts + 1] = ghost

      Field.spawn(ghost, e:current_tile())
    end

    for y = 1, Field.height() - 1 do
      local tile = Field.tile_at(0, 0)

      if tile then
        local h_line = Artifact.new()
        h_line:set_facing(Direction.Right)
        local sprite = h_line:sprite()
        sprite:set_texture(WHITE_TEXTURE)
        sprite:set_width(Field.width() * Tile:width())
        sprite:set_offset(0, Tile:height() * y - Tile:height() // 2)

        h_line:create_component(Lifetime.Scene).on_update_func = function()
          sprite:set_color(Lib.LINE_COLOR)
          sprite:set_color_mode(ColorMode.Multiply)
        end

        Field.spawn(h_line, tile)
        grid_lines[#grid_lines + 1] = h_line
      end
    end

    -- steps
    create_delay_step(action, 16)
    create_horizontal_lines_step(action)
    create_vertical_grid_lines_step(action, grid_lines)
    create_delay_step(action, 12, function()
      return_entities()
      background:delete()

      Resources.play_audio(FINISH_SFX)
    end)
    create_delay_step(action, 16)
  end

  action.on_action_end_func = function()
    ghost_component:eject()
    return_entities()

    for _, line in ipairs(grid_lines) do
      line:delete()
    end

    -- delete artifacts
    background:delete()
  end

  return action
end

function Lib.init()
  local artifact = Artifact.new()

  local is_first_character = true

  artifact.on_spawn_func = function()
    Field.find_characters(function(c)
      if is_first_character then
        c.intro_func = intro_func
        is_first_character = false
      else
        c.intro_func = plain_intro_func
      end

      return false
    end)
  end

  Field.spawn(artifact, 0, 0)
end

return Lib

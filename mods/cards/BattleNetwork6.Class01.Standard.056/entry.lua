---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local BUSTER_TEXTURE = bn_assets.load_texture("machgun.png")
local BUSTER_ANIMATION = bn_assets.fetch_animation_path("machgun.animation")
local CURSOR_TEXTURE = bn_assets.load_texture("gunner_cursor.png")
local CURSOR_ANIMATION = bn_assets.fetch_animation_path("gunner_cursor.animation")
local SHOT_TEXTURE = bn_assets.load_texture("gunner_shot_burst.png")
local SHOT_ANIMATION = bn_assets.fetch_animation_path("gunner_shot_burst.animation")
local SHOT_SFX = bn_assets.load_audio("gunner_shot.ogg")

local frame_data = { { 1, 4 } }

for i = 2, 32 do
  if i % 2 == 0 then
    frame_data[i] = { 2, 2 }
  else
    frame_data[i] = { 1, 3 }
  end
end

---@param user Entity
---@param hit_props HitProps
local function create_shot(user, hit_props)
  local spell = Spell.new(user:team())
  spell:set_texture(SHOT_TEXTURE)
  spell:set_facing(user:facing())
  spell:set_hit_props(hit_props)
  spell:sprite():set_layer(-3)

  local animation = spell:animation()
  animation:load(SHOT_ANIMATION)
  animation:set_state("DEFAULT")

  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
    Resources.play_audio(SHOT_SFX)
  end

  return spell
end

---@param user Entity
local function resolve_target_column(user)
  local direction = user:facing()
  local start_x = user:current_tile():x()

  local filter = function(entity)
    if not entity:hittable() or entity:team() == user:team() then
      return false
    end

    if direction == Direction.Right then
      return entity:current_tile():x() > start_x
    else
      return entity:current_tile():x() < start_x
    end
  end

  local target = Field.find_nearest_players(user, filter)[1]

  if not target then
    target = Field.find_nearest_characters(user, filter)[1]
  end

  if not target then
    return nil
  end

  return target:current_tile():x()
end

---@param user Entity
---@param props CardProperties
local function create_cursor(user, props)
  local hit_props = HitProps.from_card(props, user:context())

  local cursor = Spell.new(user:team())
  cursor:set_texture(CURSOR_TEXTURE)
  cursor:sprite():set_layer(-3)

  local animation = cursor:animation()
  animation:load(CURSOR_ANIMATION)
  animation:set_state("SEEK")

  local time = 0
  local movements = 0
  local direction = Direction.Up

  cursor.on_update_func = function()
    time = time + 1

    if time == 1 then
      cursor:reveal()
    end

    if time >= 5 and time <= 7 then
      cursor:current_tile():set_highlight(Highlight.Solid)
    end

    if time == 6 then
      Field.spawn(
        create_shot(user, hit_props),
        cursor:current_tile()
      )
    end

    if time == 7 then
      cursor:hide()
    end

    if time < 9 then
      return
    end

    if movements >= 9 then
      cursor:delete()
      return
    end

    movements = movements + 1

    -- reset time
    time = 0

    -- resolve the tile to move to
    local next_tile = cursor:get_tile(direction, 1)

    if not next_tile or next_tile:is_edge() then
      -- flip direction
      direction = Direction.reverse(direction)

      -- try to move to the target column
      local x = cursor:current_tile():x()
      local target_x = resolve_target_column(user) or x

      if target_x > x then
        next_tile = cursor:get_tile(Direction.Right, 1)
      elseif target_x < x then
        next_tile = cursor:get_tile(Direction.Left, 1)
      end

      -- move in the same column
      if not next_tile or next_tile:is_edge() then
        next_tile = cursor:get_tile(direction, 1)
      end
    end

    if next_tile then
      cursor:teleport(next_tile)
    end
  end

  return cursor
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "CHARACTER_SHOOT")
  action:override_animation_frames(frame_data)

  local cursor

  action.on_execute_func = function()
    -- create machgun
    local attachment = action:create_attachment("BUSTER")

    local sprite = attachment:sprite()
    sprite:set_texture(BUSTER_TEXTURE)
    sprite:use_root_shader()

    local animation = attachment:animation()
    animation:load(BUSTER_ANIMATION)
    animation:set_state("0")
    animation:on_complete(function()
      animation:set_state("1")
      animation:set_playback(Playback.Loop)
    end)

    -- create and spawn cursor
    cursor = create_cursor(user, props)
    local spawn_x = resolve_target_column(user)

    if not spawn_x then
      if user:facing() == Direction.Right then
        spawn_x = Field.width() - 2
      else
        spawn_x = 1
      end
    end

    Field.spawn(cursor, spawn_x, Field.height() - 2)
  end

  action.on_action_end_func = function()
    if cursor then
      cursor:delete()
    end
  end

  return action
end

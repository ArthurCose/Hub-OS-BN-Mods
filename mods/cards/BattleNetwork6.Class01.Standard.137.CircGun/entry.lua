---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("cursor_circgun.png")
local ANIMATION_PATH = bn_assets.fetch_animation_path("cursor_circgun.animation")

local AUDIO = bn_assets.load_audio("magnum_cursor.ogg")
local LOCKON_AUDIO = bn_assets.load_audio("cursor_lockon.ogg")
local SHOOT_AUDIO = bn_assets.load_audio("vulcan.ogg")

local HIT_TEXTURE = bn_assets.load_texture("buster_charged_impact.png")
local HIT_ANIM_PATH = bn_assets.fetch_animation_path("buster_charged_impact.animation")

local CLOCKWISE = {
  [Direction.Down] = Direction.Left,
  [Direction.Left] = Direction.Up,
  [Direction.Up] = Direction.Right,
  [Direction.Right] = Direction.Down,
}

local COUNTER_CLOCKWISE = {
  [Direction.Down] = Direction.Right,
  [Direction.Right] = Direction.Up,
  [Direction.Up] = Direction.Left,
  [Direction.Left] = Direction.Down,
}

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
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local timer = 360
  local end_timer = 80
  local move_timer = 4
  local cursor_count = 3

  local idle_state = "IDLE_YELLOW"

  if props.card_class == CardClass.Dark then
    end_timer = end_timer + 20
    cursor_count = 6
    idle_state = "IDLE_DARK"
  end

  local hit_props = HitProps.from_card(
    props,
    user:context(),
    Drag.None
  )

  local function attack(tile)
    local spell = Spell.new(user:team())
    spell:set_hit_props(hit_props)
    spell:set_facing(user:facing())
    spell:set_texture(TEXTURE)

    local spell_anim = spell:animation()
    spell_anim:load(ANIMATION_PATH)
    spell_anim:set_state(idle_state)

    spell.on_spawn_func = function()
      Resources.play_audio(LOCKON_AUDIO)
    end

    local attack_delay = 35
    spell.on_update_func = function(self)
      attack_delay = attack_delay - 1

      if attack_delay == 0 then
        if tile:is_walkable() then
          self:attack_tile()
        end

        create_hit_effect(tile)

        self:erase()
      end
    end

    Field.spawn(spell, tile)
  end

  local cursor = Artifact.new(user:team())
  cursor:set_texture(TEXTURE)

  local cursor_anim = cursor:animation()
  cursor_anim:load(ANIMATION_PATH)
  cursor_anim:set_state(idle_state)

  local min_x = 0
  local max_x = 0
  local direction = Direction.Down
  local rotation_map = CLOCKWISE

  action.on_execute_func = function()
    -- find a seed tile for resolving enemy field bounds
    -- we handle it this way to account for liberation missions
    ---@type Tile?
    local seed_tile = user:current_tile()

    while seed_tile do
      if not user:is_team(seed_tile:team()) then
        break
      end

      seed_tile = seed_tile:get_tile(user:facing(), 1)
    end

    if not seed_tile then
      action:end_action()
      return
    end

    -- init bounds using the seed tile
    min_x = seed_tile:x()
    max_x = min_x

    -- resolve min_x
    while true do
      local x = min_x - 1

      for y = 1, Field.height() - 2 do
        local tile = Field.tile_at(x, y)

        if not tile or tile:is_edge() then
          break
        end

        if not user:is_team(tile:team()) then
          min_x = x
          break
        end
      end

      if x ~= min_x then
        break
      end
    end

    -- resolve max_x
    while true do
      local x = max_x + 1

      for y = 1, Field.height() - 2 do
        local tile = Field.tile_at(x, y)

        if not tile or tile:is_edge() then
          break
        end

        if not user:is_team(tile:team()) then
          max_x = x
          break
        end
      end

      if x ~= max_x then
        break
      end
    end

    -- resolve the cursor's start tile
    local start_x = max_x

    if user:facing() == Direction.Left then
      start_x = min_x
      rotation_map = COUNTER_CLOCKWISE
    end

    -- Always at the top of a column
    local start_tile = Field.tile_at(start_x, 1) --[[@as Tile]]

    Field.spawn(cursor, start_tile)
  end

  ---@param tile Tile
  local function in_bounds(tile)
    local x, y = tile:x(), tile:y()

    return
        x >= min_x and
        x <= max_x and
        y >= 1 and
        y <= Field.height() - 2
  end

  local function resolve_next_tile()
    local attempts = 0

    while true do
      local tile = cursor:get_tile(direction, 1)

      if attempts >= 4 then
        -- full circle, give up
        return nil
      end

      attempts = attempts + 1

      if tile and in_bounds(tile) then
        return tile
      end

      direction = rotation_map[direction]
    end
  end

  -- steps

  local aim_step = action:create_step()
  local odd = false
  aim_step.on_update_func = function()
    if cursor:spawned() == false then return end

    move_timer = move_timer - 1

    if move_timer == 0 then
      local next_tile = resolve_next_tile()

      if next_tile == nil then
        cursor:erase()
        action:end_action()
        return
      end

      if odd then
        move_timer = 4
      else
        move_timer = 3
      end

      odd = not odd

      next_tile:add_entity(cursor)
      Resources.play_audio(AUDIO)
    end

    timer = timer - 1

    if user:input_has(Input.Pressed.Use) or timer == 0 then
      aim_step:complete_step()

      cursor:hide()

      attack(cursor:current_tile())
    end
  end

  local attack_step = action:create_step()
  attack_step.on_update_func = function()
    end_timer = end_timer - 1

    if end_timer % 4 == 0 and cursor_count > 0 then
      local tile = resolve_next_tile()

      if tile ~= nil then
        attack(tile)
        tile:add_entity(cursor)
      else
        cursor_count = 0
      end

      cursor_count = cursor_count - 1
    end

    if end_timer == 0 then
      attack_step:complete_step()
    end
  end

  action.on_action_end_func = function()
    cursor:delete()
  end

  return action
end

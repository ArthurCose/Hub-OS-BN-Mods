---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local SPAWN_SFX = bn_assets.load_audio("dragon1.ogg")
local HIT_SFX = bn_assets.load_audio("hit_impact.ogg")
local TEXTURE = Resources.load_texture("dragon.png")
local ANIMATION_PATH = _folder_path .. "dragon.animation"
local HIT_EFFECT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_EFFECT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")
local HIT_EFFECT_STATE = "AQUA"
local TILE_STATE = TileState.Ice

local Sword = SwordLib.new_sword()
Sword:use_hand()
Sword:set_spell_frame_index(1)

local WAIT = Sword:frame_data()[1][2] - 2

---@param entity Entity
---@param direction_bias Direction
---@param turn_callback fun(direction?: Direction)
local function create_movement_updater(entity, direction_bias, turn_callback)
  local direction = Direction.Down

  return function()
    if entity:is_moving() then
      return
    end

    local next_tile = entity:get_tile(direction, 1)

    if direction ~= Direction.Up then
      -- handle turning
      local turn_direction = nil

      if not next_tile or next_tile:is_edge() then
        turn_direction = direction_bias
        next_tile = entity:get_tile(turn_direction, 1)
        direction = Direction.Up
      end

      if not next_tile or next_tile:is_edge() then
        turn_direction = Direction.reverse(direction_bias)
        next_tile = entity:get_tile(turn_direction, 1)
      end

      if turn_direction and turn_callback then
        turn_callback(turn_direction)
      end
    elseif not next_tile then
      turn_callback()
    end

    entity:slide(next_tile, 7)
  end
end

---@param user Entity
---@param props CardProperties
local function create_dragon(user, props)
  local field = user:field()

  local spell = Spell.new(user:team())
  spell:set_hit_props(HitProps.from_card(props))
  spell:set_facing(Direction.Right)

  -- we'll reveal after some initial movement
  spell:hide()

  spell:set_texture(TEXTURE)
  local spell_animation = spell:animation()
  spell_animation:load(ANIMATION_PATH)
  spell_animation:set_state("DOWN")

  local direction_bias = user:facing()

  local movement_updater = create_movement_updater(spell, direction_bias, function(turn_direction)
    if turn_direction then
      spell:set_facing(turn_direction)
      spell_animation:set_state("TURN_RIGHT")
      spell_animation:on_complete(function()
        spell_animation:set_state("UP")
      end)
    else
      field:spawn(bn_assets.ParticlePoof.new(), spell:current_tile())
      spell:delete()
    end
  end)

  ---@type Entity[]
  local tail_segments = {}
  local MAX_SEGMENTS = 4

  local time = 0
  local initial_tile, last_tile, tile_pending_change
  local can_attack = true

  spell.on_collision_func = function()
    can_attack = false

    local artifact = Artifact.new()
    artifact:set_texture(HIT_EFFECT_TEXTURE)
    artifact:sprite():set_layer(-5)

    local animation = artifact:animation()
    animation:load(HIT_EFFECT_ANIMATION_PATH)
    animation:set_state(HIT_EFFECT_STATE)
    animation:on_complete(function()
      artifact:erase()
    end)

    field:spawn(artifact, spell:current_tile())
    Resources.play_audio(HIT_SFX)
  end

  spell.on_update_func = function()
    time = time + 1

    if time < WAIT then
      -- manually waiting for the hand
      return
    end

    if time == WAIT + 1 then
      spell:reveal()
      Resources.play_audio(SPAWN_SFX)
    end

    local current_tile = spell:current_tile()

    -- initialize initial tile
    if not initial_tile then
      initial_tile = current_tile
      last_tile = current_tile
    end

    if tile_pending_change and TILE_STATE then
      last_tile:set_state(TILE_STATE)
    end

    if last_tile ~= current_tile then
      can_attack = true
      tile_pending_change = last_tile
      last_tile = current_tile
    end

    -- attack tile
    if can_attack then
      spell:attack_tile()
      current_tile:set_highlight(Highlight.Solid)
    end

    -- spawn new segments
    if #tail_segments < MAX_SEGMENTS and (time - WAIT + 1) % 3 == 0 and time - WAIT > 0 then
      local segment = Artifact.new()
      segment:set_texture(TEXTURE)

      local animation = segment:animation()
      animation:load(ANIMATION_PATH)
      animation:set_state("FLAME")
      animation:set_playback(Playback.Loop)

      segment.on_update_func = create_movement_updater(segment, direction_bias, function(turn_direction)
        if not turn_direction then
          field:spawn(bn_assets.ParticlePoof.new(), segment:current_tile())
          segment:delete()
        end
      end)

      field:spawn(segment, initial_tile)
      table.insert(tail_segments, segment)

      field:spawn(bn_assets.ParticlePoof.new(), initial_tile)
    end

    -- movement
    movement_updater()
  end

  return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  return Sword:create_action(user, function()
    local dragon = create_dragon(user, props)

    local field = user:field()

    local targets = field:find_nearest_characters(user, function(character)
      return character:team() ~= user:team() and character:hittable()
    end)

    local target = targets[1]
    local target_tile

    if target then
      target_tile = field:tile_at(target:current_tile():x(), 0)
    else
      local tile = user:get_tile(user:facing(), 1)

      if tile then
        target_tile = field:tile_at(tile:x(), 0)
      end
    end

    if not target_tile then
      if user:facing() == Direction.Right then
        target_tile = field:tile_at(field:width() - 1, 0) --[[@as Tile]]
      else
        target_tile = field:tile_at(1, 0) --[[@as Tile]]
      end
    end

    field:spawn(dragon, target_tile)
  end)
end

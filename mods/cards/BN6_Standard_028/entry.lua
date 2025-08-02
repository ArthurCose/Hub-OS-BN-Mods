---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = Resources.load_texture("star.png")
local ANIMATION_PATH = _folder_path .. "star.animation"
local LAUNCH_SFX = bn_assets.load_audio("bubblestar.ogg")
local HIT_EFFECT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_EFFECT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")
local HIT_EFFECT_STATE = "AQUA"
local COLUMN_AVERAGE = 12.5 -- the average time spent in a full column

local Sword = SwordLib.new_sword()
Sword:set_frame_data({ { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 15 } })
Sword:use_hand()

---@param user Entity
local function create_star(user, hit_props)
  local spell = Spell.new(user:team())
  spell:set_texture(TEXTURE)
  spell:set_facing(user:facing())
  spell:set_hit_props(hit_props)

  local animation = spell:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  spell.on_spawn_func = function()
    Resources.play_audio(LAUNCH_SFX)
  end

  ---@type Entity[]
  local obstacles_hit = {}
  local can_attack = true

  -- disable attack + track obstacles + hit artifact
  spell.on_collision_func = function(_, other)
    can_attack = false

    -- track obstacles
    if other and Obstacle.from(other) then
      table.insert(obstacles_hit, other)
    end

    local artifact = Artifact.new()
    artifact:set_texture(HIT_EFFECT_TEXTURE)
    artifact:sprite():set_layer(-1)

    local artifact_anim = artifact:animation()
    artifact_anim:load(HIT_EFFECT_ANIMATION_PATH)
    artifact_anim:set_state(HIT_EFFECT_STATE)
    artifact_anim:on_complete(function()
      artifact:erase()
    end)

    local offset = spell:movement_offset()
    artifact:set_offset(offset.x, offset.y)

    Field.spawn(artifact, spell:current_tile())
  end

  -- movement and attack
  local tile_width = Tile:width()
  local tile_height = Tile:height()
  local speed = tile_width / COLUMN_AVERAGE

  if user:facing() ~= Direction.Right then
    speed = -speed
  end

  local initial_tile
  local x = Tile:width() / 2
  local a = math.pi
  local a_speed = math.pi / COLUMN_AVERAGE

  spell.on_update_func = function()
    local current_tile = spell:current_tile()

    if not initial_tile then
      initial_tile = current_tile
    else
      for i, obstacle in ipairs(obstacles_hit) do
        if not obstacle:deleted() then
          spell:erase()
          return
        end

        obstacles_hit[i] = nil
      end
    end

    -- move forward
    x = x + speed

    -- resolve tile_x and x_offset
    local tile_x = initial_tile:x() + math.floor(x / tile_width)
    local x_offset = x - (tile_x - initial_tile:x() + 0.5) * tile_width

    -- advance angle
    a = a + a_speed

    -- resolve y values
    local sine = math.sin(a)
    local y = sine * tile_height
    local tile_y = initial_tile:y()

    if sine >= 0.5 then
      tile_y = tile_y + 1
    elseif sine <= -0.5 then
      tile_y = tile_y - 1
    end

    local y_offset = y - (tile_y - initial_tile:y()) * tile_height

    -- update offset
    spell:set_movement_offset(x_offset, y_offset)

    -- updating tile
    local tile = Field.tile_at(tile_x, tile_y)

    if not tile then
      spell:erase()
      return
    end

    -- update tile
    if current_tile ~= tile then
      can_attack = true
      current_tile:remove_entity(spell)
      tile:add_entity(spell)
    end

    if can_attack then
      tile:set_highlight(Highlight.Solid)
      spell:attack_tile()
    end
  end

  return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  return Sword:create_action(user, function()
    local tile = user:get_tile(user:facing(), 1)

    if tile then
      local hit_props = HitProps.from_card(props, user:context())
      local star = create_star(user, hit_props)

      Field.spawn(star, tile)
    end
  end)
end

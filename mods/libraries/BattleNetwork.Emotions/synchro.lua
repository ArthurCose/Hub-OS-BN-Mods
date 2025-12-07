---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("shared")

local EMOTION_NAME = "SYNCHRO"
local SYNCHRO_TEXTURE = bn_assets.load_texture("synchro_rings.png")
local SYNCHRO_ANIMATION_PATH = bn_assets.fetch_animation_path("synchro_rings.animation")
local BODY_COLOR = Color.new(32, 32, 128)
local COUNTERABLE_COLOR = Color.new(0, 0, 255)

---@class SynchroEmotion
---@field package ring_animation_state string
---@field package ring_offset [number, number]
local Synchro = {}
Synchro.__index = Synchro

function Synchro:set_ring_animation_state(state)
  self.ring_animation_state = state
end

function Synchro:set_ring_offset(x, y)
  self.ring_offset = { x, y }
end

---@param self SynchroEmotion
---@param player Entity
---@param ring_sprite Sprite
---@param ring_anim Animation
local function animate_ring(self, player, ring_sprite, ring_anim)
  local state = self.ring_animation_state or "DEFAULT"

  if ring_anim:state() ~= state then
    ring_anim:set_state(state)
  end

  if self.ring_offset then
    ring_sprite:set_offset(self.ring_offset[1], self.ring_offset[2])
  else
    local offset = player:charge_position()
    ring_sprite:set_offset(offset.x, offset.y)
  end

  ring_anim:apply(ring_sprite)
  ring_anim:update()
end

---@param player Entity
---@param player_sprite Sprite
---@param counterable_tracking table<number, number>
local color_entities = function(player, player_sprite, counterable_tracking)
  if shared.is_sprite_color_unmodified(player_sprite) then
    player_sprite:set_color(BODY_COLOR)
  end

  if not player:is_local() then
    return
  end

  local current_counterable = {}

  Field.find_characters(function(character)
    if character:team() == player:team() or not character:counterable() then
      return false
    end

    local id = character:id()

    current_counterable[id] = true

    local elapsed = counterable_tracking[id] or 0
    counterable_tracking[id] = elapsed + 1

    if math.floor(elapsed / 2) % 2 ~= 0 then
      return false
    end

    local sprite = character:sprite()

    if sprite:color_mode() == ColorMode.Additive then
      sprite:set_color(COUNTERABLE_COLOR)
    end

    return false
  end)

  for key, _ in pairs(counterable_tracking) do
    if not current_counterable[key] then
      counterable_tracking[key] = nil
    end
  end
end

-- used to avoid running every frame
-- avoids excessive VM snapshots
---@param self SynchroEmotion
---@param player Entity
---@param ring_sprite Sprite
---@param ring_anim Animation
local function handle_activated(self, player, ring_sprite, ring_anim)
  local cleanup

  local remove_end_detection = shared.detect_end_once(player, EMOTION_NAME, function()
    cleanup()
  end)

  -- aux props
  local increase_damage_aux_prop = AuxProp.new()
      :require_emotion(EMOTION_NAME)
      :require_card_damage(Compare.GT, 0)
      :increase_card_multiplier(1)
      :with_callback(function()
        player:set_emotion("DEFAULT")
        cleanup()
      end)

  player:add_aux_prop(increase_damage_aux_prop)

  local hit_aux_prop = AuxProp.new()
      :require_emotion(EMOTION_NAME)
      :require_hit_flags_absent(Hit.Drain)
      :require_hit_damage(Compare.GT, 0)
      :with_callback(function()
        player:set_emotion("DEFAULT")
        cleanup()
      end)

  player:add_aux_prop(hit_aux_prop)

  -- animate
  ring_sprite:set_visible(true)

  local animate_func = function()
    animate_ring(self, player, ring_sprite, ring_anim)
  end

  local animate_component = player:create_component(Lifetime.ActiveBattle)
  animate_component.on_update_func = animate_func
  animate_func()

  -- colors
  local counterable_tracking = {}
  local color_func = function()
    color_entities(player, player:sprite(), counterable_tracking)
  end

  local color_component = player:create_component(Lifetime.Scene)
  color_component.on_update_func = color_func
  color_func()

  cleanup = function()
    remove_end_detection()

    shared.detect_once(player, EMOTION_NAME, function()
      handle_activated(self, player, ring_sprite, ring_anim)
    end)

    player:remove_aux_prop(increase_damage_aux_prop)
    player:remove_aux_prop(hit_aux_prop)
    animate_component:eject()
    color_component:eject()
    ring_sprite:set_visible(false)
  end
end

---Implements the SYNCHRO emotion. Does not implement activation.
---@param player Entity
function Synchro:implement(player)
  local player_sprite = player:sprite()

  -- rings
  local ring_sprite = player_sprite:create_node()
  ring_sprite:set_layer(-1)
  ring_sprite:set_texture(SYNCHRO_TEXTURE)
  ring_sprite:set_visible(false)

  local ring_anim = Animation.new(SYNCHRO_ANIMATION_PATH)
  ring_anim:set_state(self.ring_animation_state or "DEFAULT")
  ring_anim:set_playback(Playback.Loop)
  ring_anim:apply(ring_sprite)

  shared.detect_once(player, EMOTION_NAME, function()
    handle_activated(self, player, ring_sprite, ring_anim)
  end)
end

---Overwrites player.on_counter_func to apply the SYNCHRO emotion
---@param player Entity
function Synchro:implement_activation(player)
  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end
end

return Synchro

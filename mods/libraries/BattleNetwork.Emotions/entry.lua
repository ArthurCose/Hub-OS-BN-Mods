---@type BattleNetworkAssetsLib
local bn_assets = require("BattleNetwork.Assets")

local SYNCHRO_TEXTURE = bn_assets.load_texture("synchro_rings.png")
local SYNCHRO_ANIMATION_PATH = bn_assets.fetch_animation_path("synchro_rings.animation")

---@class SynchroEmotion
---@field private ring_animation_state string
---@field private ring_offset [number, number]
local Synchro = {}
Synchro.__index = Synchro

function Synchro:set_ring_animation_state(state)
  self.ring_animation_state = state
end

function Synchro:set_ring_offset(x, y)
  self.ring_offset = { x, y }
end

---Implements the SYNCHRO emotion. Does not implement activation.
---
---For a standard activation, set the emotion in `on_counter_func`:
---
---```lua
---player.on_counter_func = function()
---   player:set_emotion("SYNCHRO")
---end
---```
---@param player Entity
function Synchro:implement(player)
  local EMOTION_NAME = "SYNCHRO"

  local player_sprite = player:sprite()

  local increase_damage_aux_prop = AuxProp.new()
      :require_emotion(EMOTION_NAME)
      :require_card_damage(Compare.GT, 0)
      :increase_card_multiplier(1)
      :with_callback(function()
        player:set_emotion("DEFAULT")
      end)

  player:add_aux_prop(increase_damage_aux_prop)

  local hit_aux_prop = AuxProp.new()
      :require_emotion(EMOTION_NAME)
      :require_hit_flag(Hit.Impact)
      :require_hit_damage(Compare.GT, 0)
      :with_callback(function()
        player:set_emotion("DEFAULT")
      end)

  player:add_aux_prop(hit_aux_prop)

  -- rings
  local ring_sprite = player_sprite:create_node()
  ring_sprite:set_layer(-1)
  ring_sprite:set_texture(SYNCHRO_TEXTURE)

  if self.ring_offset then
    ring_sprite:set_offset(self.ring_offset[1], self.ring_offset[2])
  else
    ring_sprite:set_offset(0, -math.floor(player:height() / 2))
  end

  local animation = Animation.new(SYNCHRO_ANIMATION_PATH)
  animation:set_state(self.ring_animation_state or "DEFAULT")
  animation:set_playback(Playback.Loop)
  animation:apply(ring_sprite)

  local component = player:create_component(Lifetime.Battle)

  component.on_update_func = function()
    ring_sprite:set_visible(player:emotion() == EMOTION_NAME)
    animation:apply(ring_sprite)
    animation:update()
  end

  -- colors
  local color_component = player:create_component(Lifetime.Scene)

  local function is_black(color)
    return color.r == 0 and color.g == 0 and color.b == 0
  end

  local counterable_tracking = {}

  color_component.on_update_func = function()
    if player:emotion() ~= EMOTION_NAME then
      return
    end

    if player_sprite:color_mode() == ColorMode.Additive and is_black(player_sprite:color()) then
      player_sprite:set_color(Color.new(32, 32, 128, 255))
    end

    if not player:is_local() then
      return
    end

    local current_counterable = {}

    player:field():find_characters(function(character)
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
        sprite:set_color(Color.new(0, 0, 255, 255))
      end

      return false
    end)

    for key, _ in pairs(counterable_tracking) do
      if not current_counterable[key] then
        counterable_tracking[key] = nil
      end
    end
  end
end

---@class BattleNetwork.Emotions
local Lib = {
  ---@return SynchroEmotion
  new_synchro = function()
    local synchro = {}
    setmetatable(synchro, Synchro)
    return synchro
  end
}

return Lib

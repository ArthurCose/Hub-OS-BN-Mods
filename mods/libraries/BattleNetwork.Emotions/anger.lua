local shared = require("shared")

local EMOTION_NAME = "ANGER"
local BODY_COLOR = Color.new(160, 0, 0)
local DEFAULT_DURATION = 600

---@class AngerEmotion
---@field package color? Color
local Anger = {}
Anger.__index = Anger

---@param color Color
function Anger:set_color(color)
  self.color = color
end

---@param self AngerEmotion
---@param player Entity
local function handle_activated(self, player)
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

  -- colors
  local player_sprite = player:sprite()

  local color_func = function()
    if shared.is_sprite_color_unmodified(player_sprite) then
      player_sprite:set_color(self.color or BODY_COLOR)
    end
  end

  local color_component = player:create_component(Lifetime.Scene)
  color_component.on_update_func = color_func
  color_func()

  -- timer
  local remaining_time = DEFAULT_DURATION
  local timer_component = player:create_component(Lifetime.Local)
  timer_component.on_update_func = function()
    remaining_time = remaining_time - 1

    if remaining_time <= 0 then
      player:set_emotion("DEFAULT")
      cleanup()
    end
  end

  cleanup = function()
    remove_end_detection()

    shared.detect_once(player, EMOTION_NAME, function()
      handle_activated(self, player)
    end)

    player:remove_aux_prop(increase_damage_aux_prop)
    color_component:eject()
    timer_component:eject()
  end
end

---Implements the ANGER emotion. Does not implement activation.
---@param player Entity
function Anger:implement(player)
  shared.detect_once(player, EMOTION_NAME, function()
    handle_activated(self, player)
  end)
end

---Adds AuxProps to apply the ANGER emotion
---@param player Entity
function Anger:implement_activation(player)
  player:add_aux_prop(AuxProp.new()
    :require_hit_damage(Compare.GT, 300)
    :with_callback(function()
      player:set_emotion("ANGER")
    end))

  -- stunlocked for 120f causes anger
  local flinch_remaining_time = 0
  ---@type Component?
  local timer_component

  local function create_timer()
    if timer_component or player:emotion() == EMOTION_NAME then
      return
    end

    local function eject()
      if timer_component then
        timer_component:eject()
        timer_component = nil
        flinch_remaining_time = 0
      end
    end

    local time = 0

    timer_component = player:create_component(Lifetime.ActiveBattle)
    timer_component.on_update_func = function()
      if flinch_remaining_time <= 0 and player:remaining_status_time(Hit.Paralyze) <= 0 then
        eject()
        return
      end

      time = time + 1

      if flinch_remaining_time > 0 then
        flinch_remaining_time = flinch_remaining_time - 1
      end

      if time >= 120 then
        eject()
        player:set_emotion("ANGER")
      end
    end
  end

  player:register_status_callback(Hit.Flinch, function()
    flinch_remaining_time = 22 -- assuming we'll flinch for a full 22 frames
    create_timer()
  end)
  player:register_status_callback(Hit.Paralyze, create_timer)
end

return Anger

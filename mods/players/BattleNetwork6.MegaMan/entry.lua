---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")
local implement_heat_form = require("forms/heat.lua")

local BASE_TEXTURE = Resources.load_texture("battle.png")
local BASE_ANIMATION_PATH = "battle.animation"

---@param player Entity
function player_init(player)
  player:set_height(38.0)
  player:load_animation(BASE_ANIMATION_PATH)
  player:set_texture(BASE_TEXTURE)

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.charged_attack_func = function(self)
    return Buster.new(self, true, player:attack_level() * 10)
  end

  -- emotions
  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  local synchro = EmotionsLib.new_synchro()
  synchro:set_ring_offset(0, -math.floor(player:height() / 2))
  synchro:implement(player)

  -- forms
  local heat_form = player:create_form()
  implement_heat_form(player, heat_form, BASE_TEXTURE, BASE_ANIMATION_PATH)
end

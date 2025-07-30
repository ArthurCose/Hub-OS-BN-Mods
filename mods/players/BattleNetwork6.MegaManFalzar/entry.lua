---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local implement_spout_form = require("forms/spout/spout.lua")
local implement_thawk_form = require("forms/thawk/thawk.lua")
local implement_tengu_form = require("forms/tengu/tengu.lua")
local implement_grnd_form = require("forms/grnd/grnd.lua")
local implement_dust_form = require("forms/dust/dust.lua")

local BASE_TEXTURE = Resources.load_texture("battle.png")
local BASE_ANIMATION_PATH = _folder_path .. "battle.animation"

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
  local spout_form = player:create_form()
  implement_spout_form(player, spout_form, BASE_ANIMATION_PATH)

  local thawk_form = player:create_form()
  implement_thawk_form(player, thawk_form, BASE_ANIMATION_PATH)

  local tengu_form = player:create_form()
  implement_tengu_form(player, tengu_form, BASE_ANIMATION_PATH)

  local grnd_form = player:create_form()
  implement_grnd_form(player, grnd_form, BASE_ANIMATION_PATH)

  local dust_form = player:create_form()
  implement_dust_form(player, dust_form, BASE_ANIMATION_PATH)
end

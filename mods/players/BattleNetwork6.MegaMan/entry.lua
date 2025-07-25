---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

-- gregar
local implement_heat_form = require("forms/heat/heat.lua")
local implement_elec_form = require("forms/elec/elec.lua")
local implement_slash_form = require("forms/slash/slash.lua")
local implement_erase_form = require("forms/erase/erase.lua")
local implement_charge_form = require("forms/charge/charge.lua")

-- falzar
local implement_spout_form = require("forms/spout/spout.lua")
local implement_thawk_form = require("forms/thawk/thawk.lua")

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
  local gregar_button = player:create_form()
  gregar_button:set_mugshot_texture("gregar.png")
  gregar_button:set_close_on_select(false)

  local falzar_button = player:create_form()
  falzar_button:set_mugshot_texture("falzar.png")
  falzar_button:set_close_on_select(false)

  gregar_button.on_select_func = function()
    falzar_button:deactivate()
    gregar_button:deactivate()

    local heat_form = player:create_form()
    implement_heat_form(player, heat_form, BASE_ANIMATION_PATH)

    local elec_form = player:create_form()
    implement_elec_form(player, elec_form, BASE_ANIMATION_PATH)

    local slash_form = player:create_form()
    implement_slash_form(player, slash_form, BASE_ANIMATION_PATH)

    local erase_form = player:create_form()
    implement_erase_form(player, erase_form, BASE_ANIMATION_PATH)

    local charge_form = player:create_form()
    implement_charge_form(player, charge_form, BASE_ANIMATION_PATH)
  end

  falzar_button.on_select_func = function()
    falzar_button:deactivate()
    gregar_button:deactivate()

    local spout_form = player:create_form()
    implement_spout_form(player, spout_form, BASE_ANIMATION_PATH)

    local thawk_form = player:create_form()
    implement_thawk_form(player, thawk_form, BASE_ANIMATION_PATH)
  end
end

---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

---@param player Entity
function player_init(player)
  player:set_height(38.0)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))

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
end

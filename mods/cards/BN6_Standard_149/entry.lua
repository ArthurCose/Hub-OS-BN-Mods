---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = Resources.load_texture("trumpy.png")
local APPEAR_SFX = bn_assets.load_audio("appear.ogg")
local HIT_SFX = bn_assets.load_audio("hit_obstacle.ogg")
local MUSIC_SFX = bn_assets.load_audio("fanfare.ogg")
local MUSIC_INTERVAL = 64
local IDLE_DURATION = 140 -- acts as 170f cooldown, warn animation is 30f
local PLAY_DURATION = 170
local EFFECT = Hit.Invincible
local AFFECTS_TEAM = true

local function apply_effect(field, team)
  field:find_characters(function(character)
    if character:team() == team then
      if not AFFECTS_TEAM then
        return false
      end
    elseif AFFECTS_TEAM then
      return false
    end

    local aux_prop = AuxProp.new():apply_status(EFFECT, 2):once()
    character:add_aux_prop(aux_prop)

    return false
  end)
end

---@param user Entity
local function create_trumpy(user)
  local field = user:field()
  local team = user:team()

  local trumpy = Obstacle.new(team)
  trumpy:set_owner(user)
  trumpy:set_facing(user:facing())
  trumpy:set_texture(TEXTURE)
  trumpy:set_health(60)

  local animation = trumpy:animation()
  animation:load("trumpy.animation")
  animation:set_state("IDLE")

  trumpy:register_status_callback(Hit.Impact, function()
    Resources.play_audio(HIT_SFX)
  end)

  trumpy.on_delete_func = function()
    trumpy:erase()
    field:spawn(Explosion.new(), trumpy:current_tile())
  end

  trumpy.can_move_to_func = function(tile)
    return tile:is_walkable() and tile:team() == team and not tile:is_reserved()
  end

  local time = 0
  local state_remaining_time = 0
  local music_time = 0

  trumpy.on_update_func = function()
    if TurnGauge.frozen() then
      return
    end

    time = time + 1
    music_time = music_time + 1

    if time > 2400 then
      trumpy:delete()
      return
    end

    if state_remaining_time > 0 then
      state_remaining_time = state_remaining_time - 1
    end

    local state = animation:state()

    if state == "IDLE" then
      if state_remaining_time == 0 then
        animation:set_state("WARN")
        animation:on_complete(function()
          animation:set_state("PLAY")
          animation:set_playback(Playback.Loop)

          state_remaining_time = PLAY_DURATION
          music_time = 0
          Resources.play_audio(MUSIC_SFX)
        end)
      end
    elseif state == "PLAY" then
      if state_remaining_time > 0 then
        apply_effect(field, team)
      else
        animation:set_state("IDLE")
        state_remaining_time = IDLE_DURATION
      end

      if music_time % MUSIC_INTERVAL == 0 then
        Resources.play_audio(MUSIC_SFX)
      end
    end
  end

  return trumpy
end

---@param user Entity
function card_init(user)
  local action = Action.new(user)

  action.on_execute_func = function()
    local tile = user:get_tile(user:facing(), 1)

    if tile and not tile:is_reserved() and tile:is_walkable() then
      user:field():spawn(create_trumpy(user), tile)
      Resources.play_audio(APPEAR_SFX)
    end
  end

  return action
end

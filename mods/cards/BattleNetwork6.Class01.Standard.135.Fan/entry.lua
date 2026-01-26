---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = Resources.load_texture("unit.png")
local ANIM_PATH = "unit.animation"
local APPEAR_SFX = bn_assets.load_audio("appear.ogg")

local GUST_TEXTURE = bn_assets.load_texture("wind_puff.png")
local GUST_ANIMATION_PATH = bn_assets.fetch_animation_path("wind_puff.animation")
local WIND_SFX = bn_assets.load_audio("wind_burst.ogg")

---@type BattleNetwork.WindGust
local WindGustLib = require("BattleNetwork.WindGust")

local gust_builder = WindGustLib.new_wind_gust()
gust_builder:set_despawn_on_team_tile(true)

local function resolve_gust_x(team, direction, y)
  local start_x = Field.width() - 1
  local end_x = 0
  local inc_x = -1

  if direction == Direction.Left then
    end_x, start_x = start_x, end_x
    inc_x = -inc_x
  end

  if team == Team.Other then
    return start_x + inc_x
  end

  local gust_x = start_x

  for x = start_x, end_x, inc_x do
    local tile = Field.tile_at(x, y)

    if not tile then
      break
    end

    if tile:team() ~= team then
      return x
    end
  end

  return gust_x
end

---@param user Entity
function card_init(user)
  local action = Action.new(user, "CHARACTER_IDLE")
  action:set_lockout(ActionLockout.new_sequence())

  action.on_execute_func = function()
    local desired_tile = user:get_tile(user:facing(), 1)

    if not desired_tile or desired_tile:is_reserved() or not desired_tile:is_walkable() then
      return
    end

    Resources.play_audio(APPEAR_SFX)

    local unit = Obstacle.new(user:team())
    unit:set_owner(user)
    unit:set_facing(user:facing())
    unit:set_texture(TEXTURE)
    unit:set_health(40)

    local anim = unit:animation()
    anim:load(ANIM_PATH)
    anim:set_state("DEFAULT")
    anim:set_playback(Playback.Loop)

    local gust_y = Field.height() // 2
    local gust

    local time = 0

    local function normal_update()
      time = time + 1

      if time >= 1500 then
        unit:delete()
        return
      end

      if gust and not gust:deleted() then
        return
      end

      local team = unit:team()
      local direction = unit:facing()
      local gust_x = resolve_gust_x(team, direction, gust_y)

      -- spawn gust
      local gust_direction = Direction.reverse(direction)
      gust = gust_builder:create_spell(team, gust_direction)
      gust:set_texture(GUST_TEXTURE)
      gust:set_facing(gust_direction)

      local animation = gust:animation()
      animation:load(GUST_ANIMATION_PATH)
      animation:set_state("GREEN")

      if direction == Direction.Right then
        gust:set_offset(-8, 0)
      else
        gust:set_offset(8, 0)
      end

      Field.spawn(gust, gust_x, gust_y)

      -- resolve next y position
      if gust_y == 1 then
        gust_y = Field.height() - 2
      else
        gust_y = gust_y - 1
      end
    end

    -- need to pause the anim since we were spawned in time freeze
    anim:pause()

    unit.on_update_func = function()
      if TurnGauge.frozen() then
        return
      end

      anim:resume()

      Resources.play_audio(WIND_SFX)

      unit.on_update_func = normal_update
      normal_update()
    end

    unit:add_aux_prop(AuxProp.new():declare_immunity(~Hit.Drag))

    unit.can_move_to_func = function(tile)
      return unit:is_dragged() and (tile:team() == unit:team() or tile:team() == Team.Other)
    end

    unit.on_delete_func = function()
      Field.spawn(Explosion.new(), unit:current_tile())
      unit:erase()
    end

    Field.spawn(unit, desired_tile)
  end

  return action
end

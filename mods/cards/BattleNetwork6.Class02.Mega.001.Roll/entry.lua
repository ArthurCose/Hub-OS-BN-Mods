---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("navi_roll.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_roll.animation")

local SPARKLE_TEXTURE = bn_assets.load_texture("battle_shine.png")
local SPARKLE_ANIM_PATH = bn_assets.fetch_animation_path("battle_shine.animation")

local APPEAR_SFX = bn_assets.load_audio("appear.ogg")
local TELEPORT_SFX = bn_assets.load_audio("roll_teleport.ogg")
local ATTACK_SFX = bn_assets.load_audio("whip_attack.ogg")

local RECOVER_TEXTURE = bn_assets.load_texture("recover.png")
local RECOVER_ANIMATION = bn_assets.fetch_animation_path("recover.animation")
local RECOVER_SFX = bn_assets.load_audio("recover.ogg")

local function create_sparkle()
  local artifact = Artifact.new()
  artifact:set_layer(-5)
  artifact:set_texture(SPARKLE_TEXTURE)

  local animation = artifact:animation()
  animation:load(SPARKLE_ANIM_PATH)
  animation:set_state("SHINE")
  animation:on_complete(function()
    artifact:delete()
  end)

  return artifact
end

---@param step ActionStep
---@param roll Entity
local function implement_sparkle_rise_step(step, roll)
  local time = 0
  step.on_update_func = function()
    time = time + 1

    if time == 4 then
      local sparkle = create_sparkle()
      sparkle:set_offset(math.random(-8, 8), math.random(-8, 8) - 32)
      Field.spawn(sparkle, roll:current_tile())
    elseif time == 9 then
      local sparkle = create_sparkle()
      sparkle:set_offset(math.random(-8, 8), math.random(-8, 8) - 96)
      Field.spawn(sparkle, roll:current_tile())
    end

    if time == 12 then
      step:complete_step()
    end
  end
end

---@param step ActionStep
---@param roll Entity
local function implement_sparkle_fall_step(step, roll)
  local time = 0
  step.on_update_func = function()
    time = time + 1

    if time == 4 then
      local sparkle = create_sparkle()
      sparkle:set_offset(math.random(-8, 8), math.random(-8, 8) - 96)
      Field.spawn(sparkle, roll:current_tile())
    elseif time == 9 then
      local sparkle = create_sparkle()
      sparkle:set_offset(math.random(-8, 8), math.random(-8, 8) - 32)
      Field.spawn(sparkle, roll:current_tile())
    end

    if time == 12 then
      step:complete_step()
    end
  end
end

---@param user Entity
function card_mutate(user, index)
  local card = user:field_card(index)
  local target_recover = card.damage * 3

  if target_recover ~= card.recover then
    card.recover = target_recover
    user:set_field_card(index, card)
  end
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local roll
  local previously_visible

  action.on_execute_func = function()
    previously_visible = user:sprite():visible()

    roll = Spell.new(user:team())
    roll:set_facing(user:facing())
    roll:set_hit_props(HitProps.from_card(props, user:context()))
    roll:hide()
    roll:set_texture(NAVI_TEXTURE)

    local roll_animation = roll:animation()
    roll_animation:load(NAVI_ANIM_PATH)
    roll_animation:set_state("CHARACTER_IDLE")
    roll_animation:set_playback(Playback.Loop)

    roll:set_height(roll:sprite():origin().y)

    Field.spawn(roll, user:current_tile())

    -- must create steps in execute func, so they have access to roll

    local swap_in_step = action:create_step()
    swap_in_step.on_update_func = function()
      swap_in_step.on_update_func = nil

      ChipNaviLib.exit(user, function()
        ChipNaviLib.delay_for_swap(function()
          Resources.play_audio(APPEAR_SFX)

          local sparkle = create_sparkle()
          sparkle:set_facing(user:facing())
          sparkle:set_offset(math.random(-8, 8), math.random(-8, 8) - roll:height() // 2)
          Field.spawn(sparkle, roll:current_tile())

          swap_in_step:complete_step()
        end)
      end)
    end

    local max_flicker_time = 16
    local flicker_time = 0
    local color = Color.new(0, 0, 0)
    local flicker_roll_step = action:create_step()
    flicker_roll_step.on_update_func = function()
      if flicker_time % 2 == 0 then
        local v = (1 - flicker_time / max_flicker_time) * 255
        color.r = v
        color.g = v
        color.b = v
        roll:set_color(color)
        roll:reveal()
      else
        roll:hide()
      end

      flicker_time = flicker_time + 1

      if flicker_time >= max_flicker_time then
        roll:reveal()
        flicker_roll_step:complete_step()
      end
    end

    ChipNaviLib.create_delay_step(action, 20)

    ---@type Tile?
    local target_tile
    local reservation_exclusion = { user:id() }

    local exit_to_enemy_step = action:create_step()
    exit_to_enemy_step.on_update_func = function()
      exit_to_enemy_step.on_update_func = nil

      -- find nearest free enemy
      local user_x = user:current_tile():x()
      local nearest = Field.find_nearest_characters(user, function(e)
        if e:team() == user:team() then
          return false
        end

        -- needs a free tile to stand on
        local tile_ahead = e:get_tile(user:facing_away(), 1)

        if not tile_ahead or tile_ahead:is_reserved(reservation_exclusion) then
          return false
        end

        -- must be ahead of us
        local enemy_x = e:current_tile():x()

        if user:facing() == Direction.Right then
          return enemy_x > user_x
        else
          return enemy_x < user_x
        end
      end)

      if #nearest > 0 then
        target_tile = nearest[1]:current_tile()
      end

      if not target_tile then
        exit_to_enemy_step:complete_step()
        return
      end

      Resources.play_audio(TELEPORT_SFX)

      ChipNaviLib.exit(roll, function()
        exit_to_enemy_step:complete_step()
      end)
    end

    local sparkle_rise_step = action:create_step()
    sparkle_rise_step.on_update_func = function()
      if not target_tile then
        sparkle_rise_step:complete_step()
        return
      end

      implement_sparkle_rise_step(sparkle_rise_step, roll)
    end

    local appear_at_enemy_step = action:create_step()
    appear_at_enemy_step.on_update_func = function()
      appear_at_enemy_step:complete_step()

      if target_tile then
        target_tile:get_tile(user:facing_away(), 1):add_entity(roll)
      end
    end

    local sparkle_fall_step = action:create_step()
    sparkle_fall_step.on_update_func = function()
      if not target_tile then
        sparkle_fall_step:complete_step()
        return
      end

      implement_sparkle_fall_step(sparkle_fall_step, roll)
    end

    ChipNaviLib.create_enter_step(action, roll)

    local attack_step = action:create_step()
    attack_step.on_update_func = function()
      attack_step.on_update_func = nil

      if not target_tile then
        attack_step:complete_step()
        return
      end

      local roll_anim = roll:animation()
      roll_anim:set_state("ATTACK")
      roll_anim:on_complete(function()
        local spell = Spell.new(user:team())
        spell:set_facing(user:facing())
        spell:set_layer(-1)
        spell:set_texture(NAVI_TEXTURE)

        local spell_anim = spell:animation()
        spell_anim:load(NAVI_ANIM_PATH)
        spell_anim:set_state("WHIP")
        spell_anim:set_playback(Playback.Loop)

        local strikes = 0
        spell_anim:on_frame(1, function()
          strikes = strikes + 1

          if strikes == 4 then
            spell:delete()
            attack_step:complete_step()
            return
          end

          roll:attack_tile(target_tile)
        end)

        spell.on_update_func = function()
          Resources.play_audio(ATTACK_SFX, AudioBehavior.NoOverlap)
        end

        Field.spawn(spell, roll:current_tile())
      end)
    end

    local attack_idle_step = action:create_step()
    attack_idle_step.on_update_func = function()
      attack_idle_step.on_update_func = nil

      local roll_anim = roll:animation()
      roll_anim:set_state("CHARACTER_IDLE")
      roll_anim:on_frame(3, function()
        attack_idle_step:complete_step()
      end)
    end

    local final_exit_step = action:create_step()
    final_exit_step.on_update_func = function()
      final_exit_step.on_update_func = nil

      Resources.play_audio(TELEPORT_SFX)

      ChipNaviLib.exit(roll, function()
        final_exit_step:complete_step()
      end)
    end

    implement_sparkle_rise_step(action:create_step(), roll)
    ChipNaviLib.create_delay_step(action, 12)
    ChipNaviLib.create_enter_step(action, user)

    local heart_fall_step = action:create_step()
    heart_fall_step.on_update_func = function()
      heart_fall_step.on_update_func = nil

      local heart = Artifact.new()
      heart:set_layer(-10)
      heart:set_texture(NAVI_TEXTURE)

      local heart_anim = heart:animation()
      heart_anim:load(NAVI_ANIM_PATH)
      heart_anim:set_state("HEART")

      local heart_fall_time = 50
      heart.on_update_func = function()
        local elevation = heart_fall_time * 3
        heart:set_elevation(elevation)

        if heart_fall_time % 10 == 5 then
          local sparkle = create_sparkle()
          sparkle:set_offset(math.random(-8, 8), -elevation)
          Field.spawn(sparkle, user:current_tile())
        end

        if heart_fall_time == 0 then
          heart:delete()
          heart_fall_step:complete_step()
          return
        end

        heart_fall_time = heart_fall_time - 1
      end

      Field.spawn(heart, user:current_tile())
    end

    local recover_step = action:create_step()
    recover_step.on_update_func = function()
      recover_step.on_update_func = nil

      user:set_health(user:health() + props.recover)

      Resources.play_audio(RECOVER_SFX)

      local recov = Artifact.new()
      recov:set_layer(-1)
      recov:set_facing(user:facing())
      recov:set_texture(RECOVER_TEXTURE)

      local recov_anim = recov:animation()
      recov_anim:load(RECOVER_ANIMATION)
      recov_anim:set_state("DEFAULT")
      recov_anim:on_complete(function()
        recov:delete()
        recover_step:complete_step()
      end)

      Field.spawn(recov, user:current_tile())
    end
  end

  action.on_action_end_func = function()
    if previously_visible ~= nil then
      if previously_visible then
        user:reveal()
      else
        user:hide()
      end
    end

    if roll then
      roll:delete()
    end
  end

  return action
end

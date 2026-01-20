local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.004.Gregar"

local CURSOR_TEXTURE = Resources.load_texture("erase_cursor.png")
local CURSOR_ANIM_PATH = "erase_cursor.animation"

local SLASH_TEXTURE = Resources.load_texture("slash.png")
local SLASH_ANIM_PATH = "slash.animation"
local SLASH_SFX = bn_assets.load_audio("sword.ogg")

local CHARGE_TIMING = { 110, 100, 90, 85, 80 }

---@param player Entity
function player_init(player)
  player:set_height(55.0)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))
  player:set_charge_position(5, -27)

  EmotionsLib.implement_supported_full(player)

  -- +30 cursor chips
  player:add_aux_prop(
    AuxProp.new():require_card_element(Element.Cursor):increase_card_damage(30)
  )

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "HEX_SICKLE_START")
    action:set_lockout(ActionLockout.new_sequence())

    local cursor = Artifact.new()
    cursor:set_layer(-10)
    cursor:set_texture(CURSOR_TEXTURE)
    cursor:load_animation(CURSOR_ANIM_PATH)
    local cursor_anim = cursor:animation()
    cursor_anim:set_state("DEFAULT")
    cursor_anim:set_playback(Playback.Loop)

    ---@type Tile
    local original_tile

    action.on_execute_func = function()
      player:set_counterable(true)
      Field.spawn(cursor, player:current_tile())

      original_tile = player:current_tile()
      original_tile:reserve_for(player)
    end

    -- targetting step
    local cursor_step = action:create_step()
    cursor_step.on_update_func = function()
      if player:input_has(Input.Pressed.Use) or player:input_has(Input.Pressed.Shoot) then
        local tile = cursor:current_tile()
        cursor:cancel_movement()
        tile:add_entity(cursor)

        cursor_anim:set_state("LOCKED")
        cursor_step:complete_step()
        return
      end

      if cursor:is_moving() then
        return
      end

      local next_tile = cursor:get_tile(player:facing(), 1)

      if not next_tile then
        local target_tile = player:get_tile(player:facing(), 2)

        if target_tile then
          target_tile:add_entity(cursor)
        end

        cursor_anim:set_state("LOCKED")
        cursor_step:complete_step()
        return
      end

      cursor:slide(next_tile, 5)
    end

    -- warp step
    local warp_step = action:create_step()
    warp_step.on_update_func = function()
      local tile = cursor:get_tile(player:facing_away(), 2)
      local should_jump = false

      if not tile or player:is_immobile() or (not tile:is_walkable() and not player:ignoring_hole_tiles()) then
        tile = player:current_tile()
      end

      if player:facing() == Direction.Right then
        should_jump = tile:x() > player:current_tile():x()
      else
        should_jump = tile:x() < player:current_tile():x()
      end

      should_jump = should_jump and not tile:is_reserved({ player:id() })

      if should_jump then
        tile:add_entity(player)
        -- todo: create ghost
      end

      warp_step:complete_step()
    end

    -- attack
    local attack_step = action:create_step()
    attack_step.on_update_func = function()
      attack_step.on_update_func = nil

      player:set_counterable(false)

      local animation = player:animation()
      animation:set_state("HEX_SICKLE")

      animation:on_complete(function()
        attack_step:complete_step()
      end)

      animation:on_frame(3, function()
        Resources.play_audio(SLASH_SFX)

        local facing = player:facing()
        local tile = player:get_tile(facing, 2)

        if tile then
          local spell = Spell.new(player:team())
          spell:set_facing(facing)
          spell:set_texture(SLASH_TEXTURE)

          local spell_anim = spell:animation()
          spell_anim:load(SLASH_ANIM_PATH)
          spell_anim:set_state("DEFAULT")
          spell_anim:set_playback(Playback.Once)
          spell_anim:on_complete(function()
            spell:delete()
          end)

          spell:set_hit_props(HitProps.new(
            50 + 20 * player:attack_level(),
            Hit.Flinch,
            Element.Cursor,
            player:context()
          ))

          spell.on_spawn_func = function()
            local center = spell:current_tile()

            spell:attack_tile(center)

            local up = center:get_tile(Direction.Up, 1)
            if up then spell:attack_tile(up) end

            local down = center:get_tile(Direction.Down, 1)
            if down then spell:attack_tile(down) end
          end

          Field.spawn(spell, tile)
        end
      end)
    end

    local remaining_end_lag = 24
    local end_lag_step = action:create_step()
    end_lag_step.on_update_func = function()
      remaining_end_lag = remaining_end_lag - 1

      if remaining_end_lag <= 0 then
        end_lag_step:complete_step()
      end
    end

    action.on_action_end_func = function()
      player:set_counterable(false)

      if original_tile then
        original_tile:remove_reservation_for(player)
        original_tile:add_entity(player)
      end

      cursor:delete()
    end

    return action
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "K")
  player:set_fixed_card(card)
end

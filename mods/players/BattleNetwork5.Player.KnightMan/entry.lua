---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local MACE_TEXTURE = bn_assets.load_texture("navi_knightman_mace.png")
local MACE_ANIM_PATH = bn_assets.fetch_animation_path("navi_knightman_mace.animation")
local MACE_OVERLAY_ANIM_PATH = bn_assets.fetch_animation_path("navi_knightman_mace_overlay.animation")

-- not sure where to find this
local MACE_SFX = bn_assets.load_audio("dust_chute2.ogg")

local FIXED_CARD_ID = "BattleNetwork5.Class06.Fixed.005.Colonel"

local CHARGE_TIMING = { 120, 110, 100, 95, 90 }

---@param player Entity
function player_init(player)
  player:set_height(64.0)
  player:set_texture(Resources.load_texture("battle.png"))
  player:load_animation("battle.animation")
  player:set_charge_position(2, -34)
  player:set_shadow(Resources.load_texture("shadow.png"), "shadow.animation")

  local super_armor = AuxProp.new():declare_immunity(Hit.Flinch)
  player:add_aux_prop(super_armor)

  local mace_overlay = player:create_sync_node()
  local mace_overlay_sprite = mace_overlay:sprite()
  mace_overlay_sprite:set_texture(MACE_TEXTURE)
  mace_overlay_sprite:use_root_shader()
  mace_overlay:animation():load(MACE_OVERLAY_ANIM_PATH)

  -- emotions
  local emotions = EmotionsLib.implement_supported_full(player)
  emotions.synchro:set_ring_animation_state("BIG")

  -- attacks
  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "ROYAL_WRECKING_BALL")

    local spell = Spell.new(player:team())
    spell:set_facing(player:facing())
    spell:set_elevation(16)
    spell:set_hit_props(HitProps.new(
      70 + player:attack_level() * 10,
      Hit.Flinch | Hit.Flash | Hit.PierceGuard,
      Element.Break,
      player:context()
    ))

    spell:set_texture(MACE_TEXTURE)
    local spell_anim = spell:animation()
    spell_anim:load(MACE_ANIM_PATH)
    spell_anim:set_state("DEFAULT")

    local time = 0
    local max_spell_time = 22
    local radius_x = 40
    local radius_y = 24

    spell.on_update_func = function()
      local angle_vel = -math.pi * 2 / max_spell_time
      local angle = math.pi + angle_vel * time

      local offset_x = math.cos(angle) * radius_x
      local offset_y = math.sin(angle) * radius_y

      if spell:facing() == Direction.Left then
        offset_x = -offset_x
      end

      spell:set_movement_offset(offset_x, offset_y)

      -- resolve the tile to attack based on visual position
      local attack_direction = Direction.None

      if offset_x < -radius_x // 2 then
        attack_direction = Direction.Left
      elseif offset_x > radius_x // 2 then
        attack_direction = Direction.Right
      end

      if offset_y < -radius_y // 2 then
        attack_direction = Direction.join(attack_direction, Direction.Up)
      elseif offset_y > radius_y // 2 then
        attack_direction = Direction.join(attack_direction, Direction.Down)
      end

      local tile = spell:get_tile(attack_direction, 1)

      if tile then
        spell:attack_tile(tile)
        tile:set_highlight(Highlight.Solid)
      end

      -- update time and try to delete
      time = time + 1

      if time == max_spell_time then
        spell:delete()
      end
    end

    action.on_execute_func = function()
      Resources.play_audio(MACE_SFX)
      Field.spawn(spell, player:current_tile())
    end

    action.on_action_end_func = function()
      spell:delete()
    end

    return action
  end

  local animation = player:animation()
  player.movement_func = function(_, direction)
    local horizontal, vertical = Direction.split(direction)

    if vertical == Direction.None then
      direction = horizontal
    else
      direction = vertical
    end

    local tile = player:get_tile(direction, 1)

    if not tile or not player:can_move_to(tile) then
      return
    end

    local movement = Movement.new_teleport(tile)
    movement.delay = 4
    movement.endlag = 15

    tile:reserve_for(player)
    movement.on_end_func = function()
      tile:remove_reservation_for(player)
    end

    player:queue_movement(movement)

    animation:set_state("CHARACTER_MOVE", { { 1, 1 }, { 2, 1 }, { 3, 1 } })
    animation:on_complete(function()
      animation:set_state("CHARACTER_MOVE_END")
    end)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "K")
  player:set_fixed_card(card)
end

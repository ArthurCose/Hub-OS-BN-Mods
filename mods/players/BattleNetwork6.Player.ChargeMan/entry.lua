---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.005.Gregar"

local CAR_TEXTURE = Resources.load_texture("train_car.png")
local CAR_ANIM_PATH = "train_car.animation"
-- is this correct?
local CRAZY_LOCO_SFX = bn_assets.load_audio("dragon1.ogg")


---@param player Entity
function player_init(player)
  player:set_height(47.0)
  player:set_texture(Resources.load_texture("battle.png"))
  player:load_animation("battle.animation")
  player:set_charge_position(2, -18)

  local emotions = EmotionsLib.implement_supported_full(player)
  emotions.synchro:set_ring_animation_state("BIG")

  -- handle boosting chip charge
  ---@type AuxProp?
  local charge_boost_aux_prop
  local charging_chip = false
  local chip_charge_time = 0

  local detect_charge_aux_prop = AuxProp.new()
      :require_card_charge_time(Compare.GT, 0)
      :with_callback(function()
        charging_chip = true
      end)
  player:add_aux_prop(detect_charge_aux_prop)

  player.on_update_func = function()
    if not charging_chip then
      chip_charge_time = 0

      if charge_boost_aux_prop then
        player:remove_aux_prop(charge_boost_aux_prop)
        charge_boost_aux_prop = nil
      end

      return
    end

    charging_chip = false

    if chip_charge_time >= 500 then
      -- already reached max charge
      return
    end

    chip_charge_time = chip_charge_time + 1

    if chip_charge_time % 5 ~= 0 then
      -- return early if a change isn't necessary
      return
    end

    if charge_boost_aux_prop then
      player:remove_aux_prop(charge_boost_aux_prop)
      charge_boost_aux_prop = nil
    end

    charge_boost_aux_prop = AuxProp.new()
        :require_card_primary_element(Element.Fire)
        :require_card_time_freeze(false)
        :increase_card_damage(math.min(chip_charge_time // 5, 100))

    player:add_aux_prop(charge_boost_aux_prop)
  end

  player.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.Fire and not card_properties.time_freeze and card_properties.can_boost then
      return 500
    end
  end

  player.charged_card_func = function(self, card_properties)
    -- already boosted by auxprops
    return Action.from_card(player, card_properties)
  end

  -- attacks
  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  local charge_timing = { 90, 80, 70, 65, 60 }
  player.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or charge_timing[#charge_timing]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "CRAZY_LOCOMOTIVE")
    action:set_lockout(ActionLockout.new_sequence())

    ---@type Tile
    local original_tile
    ---@type Entity
    local attack_spell
    local hit_props = HitProps.new(
      20 * player:attack_level() + 10,
      Hit.Flinch | Hit.PierceGuard,
      Element.None,
      player:context()
    )

    local on_attack_func = function(_, other)
      local offset = other:movement_offset()
      local hit_particle = bn_assets.HitParticle.new("BREAK")

      hit_particle:set_offset(
        offset.x + math.random(-16, 16),
        offset.y + math.random(-32, 0)
      )

      Field.spawn(hit_particle, other:current_tile())
    end

    action.on_execute_func = function()
      original_tile = player:current_tile()
      original_tile:reserve_for(player)

      attack_spell = Spell.new(player:team())
      attack_spell:set_hit_props(hit_props)
      attack_spell.on_attack_func = on_attack_func
      Field.spawn(attack_spell, original_tile)

      local animation = player:animation()
      animation:set_playback(Playback.Loop)

      Resources.play_audio(CRAZY_LOCO_SFX)
    end

    local attack_step = action:create_step()
    local fall_step = action:create_step()

    ---@param tile Tile
    local can_move_to = function(tile)
      return (tile:is_walkable() or player:ignoring_hole_tiles()) and not tile:is_edge()
    end

    action.can_move_to_func = function(tile)
      return player:get_tile(player:facing(), 1) == tile
    end

    local cars_spawned = 0
    local fell = false

    attack_step.on_update_func = function()
      player:apply_status(Hit.Invincible, 2)

      -- copy player position and attack the current tile
      local current_tile = player:current_tile()

      current_tile:add_entity(attack_spell)
      local player_offset = player:movement_offset()
      attack_spell:set_movement_offset(player_offset.x, player_offset.y)
      attack_spell:attack_tile()

      if not player:ignoring_hole_tiles() and not current_tile:is_walkable() and not current_tile:is_edge() then
        attack_step:complete_step()
        -- signal to the cars
        fell = true
        return
      end

      if player:is_moving() then
        return
      end

      -- spawn cars
      if cars_spawned < 2 and current_tile ~= original_tile then
        cars_spawned = cars_spawned + 1

        local car = Obstacle.new(player:team())
        car:set_hit_props(hit_props)
        car:set_facing(player:facing())
        car:set_layer(1)
        car:set_texture(CAR_TEXTURE)
        car:set_height(27.0)
        car:set_health(9999)

        local animation = car:animation()
        animation:load(CAR_ANIM_PATH)
        animation:set_state("METAL")
        animation:set_playback(Playback.Loop)

        car.can_move_to_func = function() return true end
        car.on_attack_func = on_attack_func

        local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
        defense_rule.defense_func = function(defense)
          defense:block_damage()
        end
        car:add_defense_rule(defense_rule)

        car.on_update_func = function()
          local car_tile = car:current_tile()

          if fell or player:deleted() or (not car_tile:is_walkable() and not car_tile:is_edge()) then
            car:delete()
            return
          end

          car:attack_tile()

          if car:is_moving() then
            return
          end

          local next_tile = car:get_tile(car:facing(), 1)

          if not next_tile or car_tile:is_edge() then
            car:erase()
            return
          end

          car:slide(next_tile, 7)
        end

        car.on_delete_func = function()
          local movement_offset = car:movement_offset()
          local poof = bn_assets.MobMove.new("BIG_END")
          poof:set_offset(movement_offset.x, movement_offset.y - car:height() // 2)
          Field.spawn(poof, car:current_tile())
          car:erase()
        end


        Field.spawn(car, original_tile)
      end

      -- player movement
      local next_tile = player:get_tile(player:facing(), 1)

      if not next_tile or not can_move_to(player:current_tile()) then
        attack_step:complete_step()
        fall_step:complete_step()
        return
      end

      player:slide(next_tile, 7)
    end

    fall_step.on_update_func = function()
      fall_step.on_update_func = nil

      player:apply_status(Hit.Invincible, 2)

      local movement_offset = player:movement_offset()
      local tile = player:current_tile()

      player:cancel_movement()

      tile:add_entity(player)
      player:set_movement_offset(0, 0)
      player:set_offset(movement_offset.x, movement_offset.y)

      local animation = player:animation()

      animation:set_state("CHARACTER_MOVE", { { 1, 1 }, { 2, 2 }, { 4, 2 } })
      animation:on_complete(function()
        player:set_offset(0, 0)
        fall_step:complete_step()
      end)
    end

    local return_step = action:create_step()
    return_step.on_update_func = function()
      original_tile:add_entity(player)

      local animation = player:animation()
      animation:set_state("CHARACTER_MOVE", { { 4, 1 }, { 2, 2 }, { 1, 11 }, { 2, 10 }, { 1, 10 } })
      animation:on_complete(function()
        return_step:complete_step()
      end)

      return_step.on_update_func = nil
    end

    action.on_action_end_func = function(self)
      if original_tile then
        original_tile:add_entity(player)
        original_tile:remove_reservation_for(player)
      end

      if attack_spell then
        attack_spell:delete()
      end

      player:set_offset(0, 0)
    end

    return action
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "C")
  player:set_fixed_card(card)
end

-- todo: main menu art

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.001.Gregar"

local CHARGE_TIMING = { 80, 70, 60, 55, 50 }

local FIRE_TEXTURE = bn_assets.load_texture("fire_tower.png")
local FIRE_ANIMATION_PATH = bn_assets.fetch_animation_path("fire_tower.animation")
-- not sure if it's this, but it sounds closer than fireburn.ogg
local FIRE_SFX = bn_assets.load_audio("dragon1.ogg")

---@param team Team
---@param hit_props HitProps
---@param tile Tile?
local function spawn_single_tower(team, hit_props, tile)
  if not tile or not tile:is_walkable() then return end

  local spell = Spell.new(team)
  spell:set_hit_props(hit_props)

  local sprite = spell:sprite()
  sprite:set_texture(FIRE_TEXTURE)
  sprite:set_layer(-1)

  local anim = spell:animation()
  anim:load(FIRE_ANIMATION_PATH)
  anim:set_state("SPAWN")

  anim:on_complete(function()
    anim:set_state("LOOP")

    local loops = 0

    anim:set_playback(Playback.Loop)
    anim:on_complete(function()
      loops = loops + 1

      if loops < 4 then
        return
      end

      anim:set_state("DESPAWN")
      anim:on_complete(function()
        -- disable attack
        spell.on_update_func = nil
        spell:delete()
      end)
    end)
  end)

  spell.on_update_func = function()
    spell:attack_tile()
  end

  spell.on_attack_func = function(_, other)
    local particle = bn_assets.HitParticle.new("FIRE")
    local movement_offset = other:movement_offset()
    particle:set_offset(
      movement_offset.x + math.random(-16, 16),
      movement_offset.y + math.random(-16, 16)
    )
    Field.spawn(particle, spell:current_tile())
  end

  Field.spawn(spell, tile)
end

---@param player Entity
function player_init(player)
  player:set_height(43)
  player:set_texture(Resources.load_texture("battle.png"))
  player:load_animation("battle.animation")
  player:set_charge_position(2, -26)

  local sync_node = player:create_sync_node()
  local overlay_sprite = sync_node:sprite()
  overlay_sprite:set_texture(Resources.load_texture("overlay.png"))
  overlay_sprite:use_root_shader()
  sync_node:animation():load("overlay.animation")

  player:set_shadow(Resources.load_texture("shadow.png"), "shadow.animation")

  -- float shoes
  player:ignore_negative_tile_effects()

  -- fire +50
  player:add_aux_prop(
    AuxProp.new()
    :require_card_primary_element(Element.Fire)
    :increase_card_damage(50)
  )

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  -- heat arm
  player.charged_attack_func = function()
    local action = Action.new(player, "HEAT_WAVE_START")
    action:set_lockout(ActionLockout.new_sequence())

    local startup_step = action:create_step()

    local wait_time = 0
    local wait_step = action:create_step()
    wait_step.on_update_func = function()
      wait_time = wait_time + 1

      if wait_time >= 30 then
        wait_step:complete_step()
      end
    end

    local animation = player:animation()

    action.on_execute_func = function()
      animation:on_complete(function()
        Resources.play_audio(FIRE_SFX)

        local team = player:team()
        local hit_props = HitProps.new(
          20 + player:attack_level() * 20,
          Hit.Flinch | Hit.Flash,
          Element.Fire,
          player:context()
        )

        local facing = player:facing()
        local initial_tile = player:get_tile(facing, 1)
        spawn_single_tower(team, hit_props, initial_tile)

        -- heat arm fails if the initial tile can't be used
        if initial_tile and initial_tile:is_walkable() then
          local two_ahead = player:get_tile(facing, 2)
          spawn_single_tower(team, hit_props, two_ahead)

          if two_ahead then
            spawn_single_tower(team, hit_props, two_ahead:get_tile(Direction.Up, 1))
            spawn_single_tower(team, hit_props, two_ahead:get_tile(Direction.Down, 1))
          end
        end

        startup_step:complete_step()

        animation:set_state("HEAT_WAVE_LOOP")
        animation:set_playback(Playback.Loop)
      end)
    end

    return action
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "H")
  player:set_fixed_card(card)

  -- emotions
  EmotionsLib.implement_supported_full(player)
end

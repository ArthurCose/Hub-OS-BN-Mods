---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local CIRCLE_TEXTURE = Resources.load_texture("magic_summon.png")
local CIRCLE_ANIM = "magic_summon.animation"

local SHINE_TEXTURE = Resources.load_texture("shine.png")
local SHINE_ANIM = "shine.animation"

local FIRE_TEXTURE = Resources.load_texture("magic_fire.png")
local FIRE_ANIM = "magic_fire.animation"

local MAGIC_FIRE_START_SFX = Resources.load_audio("attack_start.ogg")
local MAGIC_FIRE_SFX = bn_assets.load_audio("magic_fire.ogg")

local function create_magic_fire(team, direction, hit_props)
  local spell = Spell.new(team)
  spell:set_facing(direction)
  spell:set_elevation(14)
  spell:set_hit_props(hit_props)
  spell:set_texture(FIRE_TEXTURE)

  local anim = spell:animation()
  anim:load(FIRE_ANIM)
  anim:set_state("DEFAULT")

  anim:on_frame(9, function()
    local tile = spell:get_tile(spell:facing(), 1)

    if tile then
      Field.spawn(
        create_magic_fire(team, direction, hit_props),
        tile
      )
    end
  end)

  anim:on_complete(function()
    spell.on_update_func = nil

    anim:set_state("FIZZLE")
    anim:on_complete(function()
      spell:delete()
    end)
  end)

  spell.on_update_func = function()
    spell:attack_tile()
  end

  return spell
end

---@param player Entity
function player_init(player)
  player:set_height(59)
  player:set_texture(Resources.load_texture("battle.png"))
  local animation = player:animation()
  animation:load("battle.animation")

  local super_armor = AuxProp.new():declare_immunity(Hit.Flinch)
  player:add_aux_prop(super_armor)

  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  local charge_timing = { 120, 110, 100, 95, 90 }
  player.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or charge_timing[#charge_timing]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "ATTACK_START")
    action:set_lockout(ActionLockout.new_sequence())

    action:create_step()

    action.on_execute_func = function()
      Resources.play_audio(MAGIC_FIRE_START_SFX)

      animation:on_complete(function()
        animation:set_state("ATTACK_LOOP")

        local shine = action:create_attachment("ORIGIN")
        local shine_sprite = shine:sprite()
        shine_sprite:set_texture(SHINE_TEXTURE)
        shine_sprite:use_parent_shader()

        local shine_anim = shine:animation()
        shine_anim:load(SHINE_ANIM)
        shine_anim:set_state("DEFAULT")
        shine_anim:set_playback(Playback.Loop)

        animation:on_complete(function()
          animation:set_state("ATTACK_END")
          print("a")
          animation:on_complete(function()
            print("b")
            action:end_action()
          end)

          local tile = player:get_tile(player:facing(), 1)

          if tile then
            local hit_props = HitProps.new(
              50 + 10 * player:attack_level(),
              Hit.Flinch | Hit.Flash,
              Element.Fire,
              player:context()
            )

            Field.spawn(
              create_magic_fire(player:team(), player:facing(), hit_props),
              tile
            )

            Resources.play_audio(MAGIC_FIRE_SFX)
          end
        end)
      end)
    end

    return action
  end

  ---@type Entity
  local marker
  local marker_ready = false

  player.special_attack_func = function()
    if not marker or marker:deleted() then
      if player:current_tile():is_walkable() then
        marker = Spell.new(player:team())
        marker:set_texture(CIRCLE_TEXTURE)
        marker:set_layer(5)

        local marker_anim = marker:animation()
        marker_anim:load(CIRCLE_ANIM)
        marker_anim:set_state("DEFAULT")
        marker_anim:on_complete(function()
          marker_ready = true
        end)

        local tile = player:current_tile()
        local original_state = tile:state()

        marker.on_update_func = function()
          local current_tile = marker:current_tile()
          local current_state = current_tile:state()

          if not current_tile:is_walkable() or (current_state ~= original_state and current_state == TileState.Cracked) then
            marker:delete()
          end
        end

        Field.spawn(marker, tile)

        marker_ready = false
      end
      return
    end

    if not marker_ready then
      return
    end

    local action = Action.new(player)
    action:set_lockout(ActionLockout.new_sequence())
    action:create_step()

    action.on_execute_func = function()
      local marker_anim = marker:animation()
      marker_anim:set_state("GLOW")
      marker_anim:on_frame(4, function()
        player:queue_default_player_movement(marker:current_tile())
      end)
      marker_anim:on_complete(function()
        marker:delete()
        action:end_action()
      end)
      marker.on_delete_func = function()
        marker:erase()
      end
      marker_ready = false
    end

    return action
  end
end

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

local APPEAR_SFX = bn_assets.load_audio("appear.ogg")

---@param player Entity
---@param shine_created_callback fun(shine_animation: Animation)
local function create_attack_action(player, shine_created_callback)
  local action = Action.new(player, "ATTACK_START")
  action:set_lockout(ActionLockout.new_sequence())

  action:create_step()

  action.on_execute_func = function()
    Resources.play_audio(MAGIC_FIRE_START_SFX)

    local animation = player:animation()
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
        animation:on_complete(function()
          action:end_action()
        end)
      end)

      shine_created_callback(shine_anim)
    end)
  end

  return action
end

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

  player:set_charge_position(-1, -28)

  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  local charge_timing = { 120, 110, 100, 95, 90 }
  player.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or charge_timing[#charge_timing]
  end

  player.charged_attack_func = function()
    return create_attack_action(player, function(shine_anim)
      shine_anim:on_frame(4, function()
        local tile = player:get_tile(player:facing(), 1)

        if tile then
          local hit_props = HitProps.new(
            50 + 20 * player:attack_level(),
            Hit.Flinch | Hit.Flash | Hit.BurnLDR,
            Element.Fire,
            player:context()
          )

          Field.spawn(
            create_magic_fire(player:team(), player:facing(), hit_props),
            tile
          )

          Resources.play_audio(MAGIC_FIRE_SFX)
        end
      end, true)
    end)
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

  player.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.Summon or card_properties.secondary_element == Element.Summon then
      return 60 * 2.5
    end
  end

  local METTAUR_RANKS = { Rank.V1, Rank.V2, Rank.V3, Rank.SP }
  local TRANSPARENT = Color.new(0, 0, 0, 0)

  ---@param tile Tile
  ---@param team Team
  local function tile_is_livable(tile, team)
    return tile:is_walkable() and tile:team() == team and not tile:is_reserved()
  end

  player.charged_card_func = function()
    return create_attack_action(player, function(shine_anim)
      shine_anim:on_frame(4, function()
        -- resolve possible spawn tiles
        local candidate_tiles = {}

        local start_x = Field.width() - 2
        local end_x = 1
        local inc_x = -1

        if player:facing() == Direction.Left then
          start_x, end_x = end_x, start_x
          inc_x = -inc_x
        end

        local team = player:team()

        for y = 1, Field.height() - 2 do
          for x = start_x, end_x, inc_x do
            local tile = Field.tile_at(x, y)

            if tile and tile_is_livable(tile, team) then
              candidate_tiles[#candidate_tiles + 1] = tile
              break
            end
          end
        end

        -- no spawn tiles
        if #candidate_tiles == 0 then
          return
        end

        local spawn_tile = candidate_tiles[math.random(#candidate_tiles)]

        local rank = METTAUR_RANKS[math.min(#METTAUR_RANKS, player:attack_level())]
        local character = Character.from_package("BattleNetwork6.Mettaur.Enemy", team, rank)
        character:set_facing(player:facing())

        -- disable hitbox
        character:enable_hitbox(false)

        -- make this character's existence very fragile and flicker
        local existence_component = character:create_component(Lifetime.Scene)
        local time = 0
        existence_component.on_update_func = function()
          local tile = character:current_tile()

          -- prevent reservation
          tile:remove_reservation_for(character)

          -- try to self destruct if anything happens to us
          if player:deleted() or not tile_is_livable(tile, team) or character:health() ~= character:max_health() then
            character:delete()
          end

          -- flicker
          if time // 2 % 2 == 0 then
            character:set_color(TRANSPARENT)
          end
        end

        -- timing for flickering
        local timing_component = character:create_component(Lifetime.ActiveBattle)
        timing_component.on_update_func = function()
          time = time + 1
        end

        Field.spawn(character, spawn_tile)
        Resources.play_audio(APPEAR_SFX)
      end, true)
    end)
  end
end

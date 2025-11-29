---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local AQUA_HOSE_TEXTURE = Resources.load_texture("aqua_hose.png")
local AQUA_HOSE_ANIM = "aqua_hose.animation"
local BUBBLES_TEXTURE = bn_assets.load_texture("bn4_bubble_impact.png")
local BUBBLES_ANIMATION_PATH = bn_assets.fetch_animation_path("bn4_bubble_impact.animation")
local BUBBLES_SFX = bn_assets.load_audio("bubbler.ogg")
local SHOOT_SFX = bn_assets.load_audio("aqua_hose.ogg")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.001.Falzar"

---@param player Entity
function player_init(player)
  player:set_height(35.0)
  player:set_texture(Resources.load_texture("battle.png"))
  player:load_animation("battle.animation")
  player:set_fully_charged_color(Color.new(180, 237, 49, 255))
  player:set_charge_position(2, -14)

  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  local synchro = EmotionsLib.new_synchro()
  synchro:implement(player)

  player:add_aux_prop(
    AuxProp.new()
    :require_card_primary_element(Element.Aqua)
    :require_charged_card()
    :require_card_time_freeze(false)
    :increase_card_multiplier(1)
  )

  -- attacks
  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  local AQUA_HOSE_FRAMES = { { 1, 8 }, { 2, 4 }, { 3, 4 }, { 4, 24 } }
  player.charged_attack_func = function()
    local action = Action.new(player, "CHARACTER_SHOOT")
    action:override_animation_frames(AQUA_HOSE_FRAMES)

    action:set_lockout(ActionLockout.new_animation())

    local buster, buster_anim

    action.on_execute_func = function()
      player:set_counterable(true)

      buster = action:create_attachment("BUSTER")
      local buster_sprite = buster:sprite()
      buster_sprite:set_texture(player:texture())
      buster_sprite:set_layer(-1)
      buster_sprite:use_root_shader()

      buster_anim = buster:animation()
      buster_anim:copy_from(player:animation())
      buster_anim:set_state("BUSTER", AQUA_HOSE_FRAMES)
    end

    action:add_anim_action(2, function()
      Resources.play_audio(SHOOT_SFX)
      player:set_counterable(false)

      local flare = buster:create_attachment("ENDPOINT")
      local flare_sprite = flare:sprite()
      flare_sprite:set_texture(AQUA_HOSE_TEXTURE)
      flare_sprite:set_layer(-2)
      flare_sprite:use_root_shader()

      local flare_anim = flare:animation()
      flare_anim:load(AQUA_HOSE_ANIM)
      flare_anim:set_state("ATTACHMENT")

      -- immediately spawn the attack
      local spell = Spell.new(player:team())
      spell:set_facing(player:facing())
      spell:set_texture(AQUA_HOSE_TEXTURE)

      local spell_anim = spell:animation()
      spell_anim:load(AQUA_HOSE_ANIM)
      spell_anim:set_state("BLOB")

      local hit_props = HitProps.new(
        20 * player:attack_level() + 20,
        Hit.Flinch | Hit.Flash | Hit.PierceGround,
        Element.Aqua,
        player:context(),
        Drag.None
      )

      local direction = player:facing()

      local total_frames = 16

      local buster_point = player:animation():relative_point("BUSTER")
      local flare_point = buster_anim:relative_point("ENDPOINT")

      local x = buster_point.x + flare_point.x + spell:sprite():origin().x
      local y = buster_point.y + flare_point.y
      local vel_x = (Tile:width() * 2 - x) / total_frames
      local vel_y = -y / total_frames

      if direction == Direction.Left then
        x = -x
        vel_x = -vel_x
      end

      spell:set_offset(math.floor(x), math.floor(y))

      local function spawn_bubbles(tile, cracks)
        if not tile then
          return
        end

        local bubbles = Spell.new(spell:team())
        bubbles:set_facing(spell:facing())
        bubbles:set_hit_props(hit_props)
        bubbles:set_texture(BUBBLES_TEXTURE)

        bubbles.on_spawn_func = function()
          bubbles:attack_tile()
        end

        local bubbles_anim = bubbles:animation()
        bubbles_anim:load(BUBBLES_ANIMATION_PATH)
        bubbles_anim:set_state("BN6")
        bubbles_anim:on_complete(function()
          bubbles:delete()
        end)

        if cracks then
          bubbles.on_delete_func = function()
            if tile:state() == TileState.Cracked then
              tile:set_state(TileState.Broken)
            else
              tile:set_state(TileState.Cracked)
            end

            bubbles:erase()
          end
        end

        Field.spawn(bubbles, tile)
      end

      spell.on_update_func = function()
        spell:set_offset(math.floor(x), math.floor(y))
        x = x + vel_x
        y = y + vel_y

        if y < 0 then
          return
        end

        spell:delete()

        Resources.play_audio(BUBBLES_SFX)

        local first_tile = spell:get_tile(spell:facing(), 2)

        if not first_tile then
          return
        end

        if not first_tile:is_walkable() then
          local particle = bn_assets.MobMove.new("SMALL_END")
          Field.spawn(particle, first_tile)

          -- fallback test, spawn bubbles for direct hits
          local hit_test = Spell.new(spell:team())
          hit_test:attack_tile(first_tile)
          hit_test.on_spawn_func = function()
            hit_test:delete()
          end
          hit_test.on_collision_func = function()
            spawn_bubbles(first_tile, true)
            spawn_bubbles(spell:get_tile(spell:facing(), 3))
            particle:delete()
          end
          Field.spawn(hit_test, first_tile)
          return
        end

        spawn_bubbles(first_tile, true)
        spawn_bubbles(spell:get_tile(spell:facing(), 3))
      end

      Field.spawn(spell, player:current_tile())
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  player.calculate_card_charge_time_func = function(_, props)
    if not props.time_freeze and props.element == Element.Aqua then
      return 30
    end
  end

  player.charged_card_func = function(_, props)
    return Action.from_card(player, props)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "A")
  player:set_fixed_card(card)
end

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")
---@type dev.konstinople.library.bomb
local BombLib = require("dev.konstinople.library.bomb")

local THUNDERBOLT_TEXTURE = bn_assets.load_texture("thunderbolt.png")
local THUNDERBOLT_ANIMATION_PATH = bn_assets.fetch_animation_path("thunderbolt.animation")
local THUNDERBOLT_SFX = bn_assets.load_audio("dollthunder.ogg")

local ROD_TEXTURE = Resources.load_texture("elec_rod.png")
local ROD_ANIMATION_PATH = _folder_path .. "elec_rod.animation"
local ROD_SHADOW = bn_assets.load_texture("bomb_shadow.png")

local EXPLOSION_TEXTURE = bn_assets.load_texture("spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("spell_explosion.animation")
local EXPLOSION_SFX = bn_assets.load_audio("explosion_defeatedmob.ogg")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.002.Gregar"

local rod_bomb = BombLib.new_bomb()
rod_bomb:set_bomb_texture(ROD_TEXTURE)
rod_bomb:set_bomb_animation_path(ROD_ANIMATION_PATH)
rod_bomb:set_bomb_shadow(ROD_SHADOW)
rod_bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local function spawn_hit_artifact(entity)
  local movement_offset = entity:movement_offset()

  local particle = bn_assets.HitParticle.new("ELEC")

  particle:set_offset(
    movement_offset.x + math.random(-8, 8),
    movement_offset.y - entity:height() // 2 + math.random(-8, 8)
  )

  Field.spawn(particle, entity:current_tile())
end

---@param player Entity
local function spawn_h_thunderbolt(player)
  local tile = player:current_tile()
  local facing = player:facing()
  local spell_offset = player:animation():relative_point("POINTER")

  local spell = Spell.new(player:team())
  spell:set_facing(facing)
  spell:set_layer(1)
  spell:set_texture(THUNDERBOLT_TEXTURE)

  if facing == Direction.Right then
    spell:set_offset(spell_offset.x, spell_offset.y)
  else
    spell:set_offset(-spell_offset.x, spell_offset.y)
  end

  local spell_anim = spell:animation()
  spell_anim:load(THUNDERBOLT_ANIMATION_PATH)
  spell_anim:set_state("DEFAULT")
  spell_anim:set_playback(Playback.Loop)

  spell:set_hit_props(HitProps.new(
    20 * player:attack_level() + 40,
    Hit.Flinch | Hit.Flash,
    Element.Elec,
    player:context()
  ))

  local attack_list = { tile }

  for i = 1, 5 do
    local new_tile = tile:get_tile(facing, i)
    if new_tile then
      attack_list[#attack_list + 1] = new_tile
    end
  end

  local time = 0

  spell.on_update_func = function()
    for _, tile in ipairs(attack_list) do
      spell:attack_tile(tile)
    end

    time = time + 1

    if time >= 18 then
      spell:delete()
    end
  end

  spell.on_spawn_func = function()
    Resources.play_audio(THUNDERBOLT_SFX)
  end

  spell.on_attack_func = function(_, other)
    spawn_hit_artifact(other)
  end

  Field.spawn(spell, tile)
end

local function create_elec_rod()
  local rod = Obstacle.new(Team.Other)
  rod:set_health(40)
  rod:set_never_flip(true)
  rod:set_texture(ROD_TEXTURE)
  rod:set_shadow(ROD_SHADOW)

  rod:set_hit_props(
    HitProps.new(
      50,
      Hit.Paralyze | Hit.Flinch | Hit.Flash,
      Element.Elec
    )
  )

  rod:add_aux_prop(AuxProp.new():declare_immunity(~Hit.None))

  local animation = rod:animation()
  animation:load(ROD_ANIMATION_PATH)
  animation:set_state("DEFAULT")

  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.Always)
  local attacking = false

  defense_rule.defense_func = function(defense, _, _, hit_props)
    if hit_props.flags & Hit.Drain ~= 0 then
      return
    end

    if hit_props.element == Element.Break or hit_props.secondary_element == Element.Break or hit_props.flags & Hit.PierceGuard ~= 0 then
      rod:set_health(0)
      return
    end

    if hit_props.element ~= Element.Elec and hit_props.secondary_element ~= Element.Elec then
      return
    end

    defense:block_damage()

    if attacking then
      return
    end

    attacking = true

    animation:set_state("SHOCK")
    animation:on_complete(function()
      attacking = false
      animation:set_state("SPAWN")
    end)
  end

  rod:add_defense_rule(defense_rule)

  rod.on_update_func = function()
    if not attacking then
      -- attack only the current tile
      rod:attack_tile()
      return
    end

    local center_tile = rod:current_tile()
    local center_x = center_tile:x()
    local center_y = center_tile:y()

    for y = center_y - 2, center_y + 2 do
      rod:attack_tile(Field.tile_at(center_x, y))
    end
  end

  rod.on_collision_func = function()
    if not attacking then
      -- explode if we weren't trying to attack,
      -- as this was caused by an entity in the same tile as us
      rod:set_health(0)
    end
  end

  rod.on_attack_func = function(_, other)
    spawn_hit_artifact(other)
  end

  rod.on_delete_func = function()
    if rod:health() == 0 then
      rod:erase()

      local explosion = Artifact.new()
      explosion:set_texture(EXPLOSION_TEXTURE)

      local explosion_anim = explosion:animation()
      explosion_anim:load(EXPLOSION_ANIM_PATH)
      explosion_anim:set_state("DEFAULT")
      explosion_anim:on_complete(function()
        explosion:delete()
      end)

      Resources.play_audio(EXPLOSION_SFX)
      Field.spawn(explosion, rod:current_tile())
    else
      animation:set_state("SPAWN")
      animation:set_playback(Playback.Reverse)
      animation:on_complete(function()
        rod:erase()
      end)
    end
  end

  return rod
end

---@param player Entity
function player_init(player)
  player:set_height(60.0)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))
  player:ignore_negative_tile_effects()

  player:set_charge_position(2, -38)

  local synchro = EmotionsLib.new_synchro()
  synchro:implement(player)

  -- chip boost
  player:add_aux_prop(
    AuxProp.new()
    :require_card_time_freeze(false)
    :require_card_element(Element.Elec)
    :increase_card_damage(50)
  )

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  local charge_timing = { 90, 80, 70, 65, 60 }
  player.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or charge_timing[#charge_timing]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "H_THUNDERBOLT_START")
    action:set_lockout(ActionLockout.new_sequence())
    action:create_step()

    action.on_execute_func = function()
      local animation = player:animation()
      animation:set_playback(Playback.Loop)

      player:set_counterable(true)

      local i = 0

      animation:on_complete(function()
        i = i + 1

        if i < 3 then return end

        i = 0

        player:set_counterable(false)

        animation:set_state("H_THUNDERBOLT_LOOP")
        animation:set_playback(Playback.Loop)
        animation:on_complete(function()
          i = i + 1

          if i == 4 then
            action:end_action()
          end
        end)

        spawn_h_thunderbolt(player)
      end)
    end

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  ---@type Entity?
  local prev_rod
  local rod_cooldown = 0

  player:create_component(Lifetime.ActiveBattle).on_update_func = function()
    if rod_cooldown > 0 then
      rod_cooldown = rod_cooldown - 1
    end
  end

  player.special_attack_func = function()
    if rod_cooldown > 0 then
      return
    end

    rod_cooldown = 60 * 8

    if prev_rod and not prev_rod:deleted() then
      prev_rod:delete()
    end

    return rod_bomb:create_action(player, function(tile)
      if tile then
        local rod = create_elec_rod()
        rod:set_owner(player)
        Field.spawn(rod, tile)

        prev_rod = rod
      end
    end)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "E")
  card.damage = 40 + player:attack_level() * 20
  local button = player:set_fixed_card(card)

  local component = player:create_component(Lifetime.CardSelectOpen)

  local prev_attack_level = player:attack_level()
  component.on_update_func = function()
    if button:deleted() then
      component:eject()
      return
    end

    local attack_level = player:attack_level()

    if attack_level == prev_attack_level then
      return
    end

    button:delete()

    prev_attack_level = attack_level
    card.damage = 40 + player:attack_level() * 20
    button = player:set_fixed_card(card)
  end
end

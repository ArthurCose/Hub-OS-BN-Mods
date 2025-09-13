---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")
---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local FIXED_CARD_ID = "BattleNetwork5.Class06.Fixed.001.Colonel"
local CHARGE_TIMING = { 120, 110, 100, 95, 90 }
local BLIND_DURATION = 3 * 60
local BLIND_COOLDOWN = BLIND_DURATION * 2

local TEXTURE = Resources.load_texture("battle.png")
local ANIM_PATH = "battle.animation"

local DIVIDE_TEXTURE = bn_assets.load_texture("colonel_slashes.png")
local DIVIDE_ANIM_PATH = bn_assets.fetch_animation_path("colonel_slashes.animation")
local DIVIDE_SFX = bn_assets.load_audio("cross_slash.ogg")

local CAPE_SFX = bn_assets.load_audio("panel_throw.ogg")

local MISSILE_LAUNCH_SFX = bn_assets.load_audio("cannon.ogg") -- incorrect sfx
local MISSILE_LAND_SFX = bn_assets.load_audio("explosion_defeatedboss.ogg")
local EXPLOSION_TEXTURE = bn_assets.load_texture("spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("spell_explosion.animation")

local screen_divide = SwordLib.new_sword()

---@param player Entity
local function create_screen_divide_action(player)
  return screen_divide:create_action(player, function()
    Resources.play_audio(DIVIDE_SFX)

    local tile = player:current_tile()

    while tile do
      local has_hittable = false

      tile:find_entities(function(e)
        if e:hittable() and e:team() ~= player:team() then
          has_hittable = true
        end
        return false
      end)

      if has_hittable then
        break
      end

      local next_tile = tile:get_tile(player:facing(), 1)

      if not next_tile or next_tile:is_edge() then
        break
      end

      tile = next_tile
    end

    local spell = Spell.new(player:team())
    spell:set_facing(player:facing())
    spell:set_texture(DIVIDE_TEXTURE)

    local animation = spell:animation()
    animation:load(DIVIDE_ANIM_PATH)
    animation:set_state("SLASH_V")
    animation:on_complete(function()
      spell:delete()
    end)

    spell:set_hit_props(HitProps.new(
      45 + player:attack_level() * 5,
      Hit.Flinch | Hit.Flash,
      Element.Sword,
      player:context()
    ))

    spell.on_spawn_func = function()
      spell:attack_tile()
      spell:attack_tile(spell:get_tile(Direction.join(spell:facing_away(), Direction.Up), 1))
      spell:attack_tile(spell:get_tile(Direction.join(spell:facing_away(), Direction.Down), 1))
    end

    Field.spawn(spell, tile)
  end)
end

---@param player Entity
local function create_throw_cape_action(player)
  local action = Action.new(player, "CHARACTER_SWING_HAND_CAPELESS")
  action:set_lockout(ActionLockout.new_sequence())

  local step = action:create_step()

  action:add_anim_action(2, function()
    Resources.play_audio(CAPE_SFX)

    local spell = Spell.new(player:team())
    spell:set_facing(player:facing())
    spell:set_texture(TEXTURE)

    local spell_anim = spell:animation()
    spell_anim:load(ANIM_PATH)
    spell_anim:set_state("THROWN_CAPE")
    spell_anim:on_complete(function()
      spell:delete()
    end)

    if player:facing() == Direction.Right then
      spell:set_offset(Tile:width() // 2, 0)
    else
      spell:set_offset(-Tile:width() // 2, 0)
    end

    spell:set_elevation(20)

    local hit_props = HitProps.new(
      0,
      Hit.Drain | Hit.Blind,
      Element.None
    )
    hit_props.status_durations[Hit.Blind] = BLIND_DURATION
    spell:set_hit_props(hit_props)

    spell.on_collision_func = function()
      spell:delete()
    end

    spell.on_update_func = function()
      spell:attack_tile()

      if not spell:is_moving() then
        spell:slide(spell:get_tile(spell:facing(), 1), 6)
      end
    end

    Field.spawn(spell, player:current_tile())

    step.on_update_func = function()
      if spell:deleted() then
        step:complete_step()
      end
    end
  end)

  return action
end

---@param player Entity
---@param directly_targetted table<Tile, boolean>
local function spawn_missile(player, directly_targetted)
  local spell = Spell.new(player:team())
  spell:set_facing(player:facing())
  spell:set_texture(TEXTURE)

  local spell_anim = spell:animation()
  spell_anim:load(ANIM_PATH)

  spell:set_hit_props(
    HitProps.new(
      30 + player:attack_level() * 20,
      Hit.Flinch | Hit.Flash,
      Element.Fire,
      player:context()
    )
  )

  local remaining_fall_time = 12

  local function fall_update()
    remaining_fall_time = remaining_fall_time - 1

    local x_offset = (remaining_fall_time + 1) * 5
    local y_offset = (remaining_fall_time + 1) * 12

    if spell:facing() == Direction.Right then
      x_offset = -x_offset
    end

    spell:set_offset(x_offset, -y_offset)

    if remaining_fall_time > 0 then
      return
    end

    -- attack tiles and delete self
    spell:attack_tile()
    spell:delete()

    -- crack tiles
    local tile = spell:current_tile()
    if tile:state() == TileState.Cracked then
      tile:set_state(TileState.Broken)
    else
      tile:set_state(TileState.Cracked)
    end

    -- spawn an explosion
    local explosion = Artifact.new()
    explosion:set_layer(-1)
    explosion:set_texture(EXPLOSION_TEXTURE)
    local explosion_anim = explosion:animation()
    explosion_anim:load(EXPLOSION_ANIM_PATH)
    explosion_anim:set_state("DEFAULT")
    explosion_anim:on_complete(function()
      explosion:delete()
    end)

    Field.spawn(explosion, tile)
  end

  spell.on_collision_func = function()
    local particle = bn_assets.HitParticle.new("FIRE", math.random(-16, 16), math.random(-16, 0))
    Field.spawn(particle, spell:current_tile())
  end

  spell.on_delete_func = function()
    Resources.play_audio(MISSILE_LAND_SFX)
    spell:erase()
  end

  spell_anim:set_state("MISSILE_LAUNCH")
  spell_anim:on_complete(function()
    spell:set_tile_highlight(Highlight.Flash)
    spell_anim:set_state("MISSILE_FALL")

    spell.on_update_func = fall_update

    -- teleport to a tile to attack
    local opponents = Field.find_nearest_characters(spell, function(c)
      return c:team() ~= spell:team() and c:hittable()
    end)

    -- try directly targetting an opponent
    for _, opponent in ipairs(opponents) do
      local tile = opponent:current_tile()

      if not directly_targetted[tile] then
        directly_targetted[tile] = true
        tile:add_entity(spell)
        return
      end
    end

    -- attack randomly around opponents
    local tiles = {}

    for _, opponent in ipairs(opponents) do
      local current_tile = opponent:current_tile()
      local center_x = current_tile:x()
      local center_y = current_tile:y()

      for x = center_x - 1, center_x + 1 do
        for y = center_y - 1, center_y + 1 do
          local tile = Field.tile_at(x, y)

          if tile and tile:team() ~= spell:team() and not tile:is_edge() then
            tiles[#tiles + 1] = tile
          end
        end
      end
    end

    if #tiles == 0 then
      -- failed to find any tiles, try any random opponent tile
      tiles = Field.find_tiles(function(t)
        return t:team() ~= spell:team() and not t:is_edge()
      end)
    end

    if #tiles == 0 then
      spell:delete()
    end

    tiles[math.random(#tiles)]:add_entity(spell)
  end)

  Field.spawn(spell, player:current_tile())
  Resources.play_audio(MISSILE_LAUNCH_SFX)
end

---@param player Entity
local function create_induct_missile_action(player)
  local action = Action.new(player, "INDUCT_MISSILE_START")
  action:set_lockout(ActionLockout.new_sequence())

  local step = action:create_step()

  action.on_execute_func = function()
    local animation = player:animation()

    animation:on_complete(function()
      animation:set_state("INDUCT_MISSILE_LOOP")
      animation:set_playback(Playback.Loop)

      local loops = 0

      local directly_targetted = {}
      spawn_missile(player, directly_targetted)

      animation:on_complete(function()
        loops = loops + 1

        if loops >= 3 then
          step:complete_step()
          return
        end

        spawn_missile(player, directly_targetted)
      end)
    end)
  end

  return action
end

---@param player Entity
function player_init(player)
  player:set_height(47.0)
  player:set_texture(TEXTURE)
  player:load_animation(ANIM_PATH)

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  player.charged_attack_func = function()
    return create_screen_divide_action(player)
  end

  -- cape
  local cape_cooldown = 0

  player.on_update_func = function()
    if cape_cooldown > 0 then
      cape_cooldown = cape_cooldown - 1
    end
  end

  player.special_attack_func = function()
    if cape_cooldown > 0 then
      local action = Action.new(player)
      action:set_lockout(ActionLockout.new_sequence())
      return action
    end

    cape_cooldown = BLIND_COOLDOWN
    return create_throw_cape_action(player)
  end

  -- induct missile
  player.calculate_card_charge_time_func = function(self, card)
    local can_charge = not card.time_freeze and
        (card.element == Element.Fire or card.secondary_element == Element.Fire) and
        card.package_id ~= FIXED_CARD_ID

    if not can_charge then
      return
    end

    return 60
  end

  player.charged_card_func = function()
    return create_induct_missile_action(player)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "C")
  card.damage = 70 + player:attack_level() * 10
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
    card.damage = 70 + player:attack_level() * 10
    button = player:set_fixed_card(card)
  end

  -- intro
  player.intro_func = function()
    return Action.new(player, "INTRO")
  end

  -- emotions
  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  local synchro = EmotionsLib.new_synchro()
  synchro:set_ring_offset(0, -math.floor(player:height() / 2))
  synchro:implement(player)
end

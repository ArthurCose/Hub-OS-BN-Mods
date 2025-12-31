---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")
---@type dev.konstinople.library.bomb
local BombLib = require("dev.konstinople.library.bomb")

local TEXTURE = Resources.load_texture("battle.png")
local ANIM_PATH = "battle.animation"

local SHADOW_TEXTURE = Resources.load_texture("shadow.png")
local SHADOW_ANIM_PATH = "shadow.animation"

local UNDER_WATER_TEXTURE = Resources.load_texture("water_shadow.png")
local UNDER_WATER_ANIM_PATH = "water_shadow.animation"

local SPLASH_TEXTURE = Resources.load_texture("big_splash.png")
local SPLASH_ANIM_PATH = "big_splash.animation"

local DIVE_SFX = bn_assets.load_audio("dive.ogg")
local SURFACE_SFX = bn_assets.load_audio("feather.ogg")
-- no idea if this is correct
local FROG_SMACK_SFX = bn_assets.load_audio("dust_chute2.ogg")

local KERO_KERO_TEXTURE = Resources.load_texture("kero_kero_frog.png")
local KERO_KERO_SHADOW_TEXTURE = Resources.load_texture("kero_kero_frog_shadow.png")
local KERO_KERO_ANIM_PATH = _folder_path .. "kero_kero_frog.animation"
local KERO_KERO_SFX = bn_assets.load_audio("kero_kero_jump.ogg")

local kero_kero_bomb = BombLib.new_bomb()
kero_kero_bomb:set_bomb_texture(KERO_KERO_TEXTURE)
kero_kero_bomb:set_bomb_animation_path(KERO_KERO_ANIM_PATH)
kero_kero_bomb:set_bomb_animation_state("SPAWN")
kero_kero_bomb:set_bomb_shadow(KERO_KERO_SHADOW_TEXTURE)
kero_kero_bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local FIXED_CARD_ID = "BattleNetwork5.Class06.Fixed.006.Colonel"

local function spawn_splash(tile)
  local artifact = Artifact.new()
  artifact:set_texture(SPLASH_TEXTURE)

  artifact:set_layer(-1)

  local artifact_anim = artifact:animation()
  artifact_anim:load(SPLASH_ANIM_PATH)
  artifact_anim:set_state("DEFAULT")
  artifact_anim:on_complete(function()
    artifact:delete()
  end)

  Field.spawn(artifact, tile)
end

local function find_bomb_target_tile(team, x)
  local priority_tiles = {}
  local tiles = {}

  for y = 0, Field.height() - 1 do
    local test_tile = Field.tile_at(x, y)

    if not test_tile then
      goto continue
    end

    if test_tile:is_walkable() then
      tiles[#tiles + 1] = test_tile
    end

    local contains_opponent = false
    test_tile:find_characters(function(c)
      if c:hittable() and c:team() ~= team then
        contains_opponent = true
      end
      return false
    end)

    if contains_opponent then
      priority_tiles[#priority_tiles + 1] = test_tile
    end

    ::continue::
  end

  if #priority_tiles > 0 then
    return priority_tiles[math.random(#priority_tiles)]
  elseif #tiles > 0 then
    return tiles[math.random(#tiles)]
  end

  return nil
end

kero_kero_bomb.target_tile_func = function(user)
  local x_end, x_inc

  if user:facing() == Direction.Right then
    x_end = Field.width() - 1
    x_inc = 1
  else
    x_end = 0
    x_inc = -1
  end

  local x_start = user:current_tile():x() + x_inc
  local team = user:team()

  for x = x_start, x_end, x_inc do
    local has_opponent_tile = false

    for y = 0, Field.height() do
      local tile = Field.tile_at(x, y)

      if tile and tile:team() ~= team and not tile:is_edge() then
        has_opponent_tile = true
      end
    end

    if has_opponent_tile then
      local tile = find_bomb_target_tile(team, x)

      if tile then
        return tile
      end
    end
  end

  return nil
end

---@param player Entity
local function create_throw_kero_kero_action(player)
  local team = player:team()
  local direction = player:facing()
  local hit_props = HitProps.new(
    player:attack_level() * 20,
    Hit.Flinch | Hit.Flash,
    Element.Aqua
  )

  return kero_kero_bomb:create_action(player, function(tile)
    if not tile or not tile:is_walkable() then
      return
    end

    local spell = Spell.new(team)
    spell:set_facing(direction)
    spell:set_hit_props(hit_props)
    spell:set_texture(KERO_KERO_TEXTURE)
    spell:set_shadow(KERO_KERO_SHADOW_TEXTURE)

    local animation = spell:animation()
    animation:load(KERO_KERO_ANIM_PATH)

    local landing = false

    spell.on_update_func = function()
      if spell:is_moving() then return end

      spell:attack_tile()

      local current_tile = spell:current_tile()

      if not current_tile:is_walkable() then
        spell:delete()
      end

      if landing then
        return
      end

      landing = true
      spell:current_tile():set_state(TileState.Sea)

      animation:set_state("LAND")
      animation:on_complete(function()
        -- find the next tile to jump to
        local x = current_tile:x()

        if spell:facing() == Direction.Right then
          x = x + 1
        else
          x = x - 1
        end

        local next_tile = find_bomb_target_tile(spell:team(), x) or spell:get_tile(spell:facing(), 1)

        if not next_tile then
          spell:delete()
          return
        end

        spell:jump(next_tile, 24 * 3, 30)
        animation:set_state("JUMP")
        Resources.play_audio(KERO_KERO_SFX)
        landing = false
      end)
    end

    spell.on_delete_func = function()
      animation:set_state("DESPAWN")
      animation:on_complete(function()
        spell:erase()
      end)
    end

    Field.spawn(spell, tile)
  end)
end

---@param player Entity
---@param original_tile Tile
---@param find_fn fun(tile: Tile, callback: fun(entity: Entity): boolean)
local function find_frog_smack_dest_tile(player, original_tile, find_fn)
  local x_start = original_tile:x()
  local x_end
  local x_inc = 1

  if player:facing() == Direction.Right then
    x_start = x_start + 1
    x_end = Field.width() - 1
  else
    x_start = x_start - 1
    x_end = 0
    x_inc = -x_inc
  end

  local reservation_exclude_list = { player:id() }

  for x = x_start, x_end, x_inc do
    for y = 0, Field.height() - 1 do
      local tile = Field.tile_at(x, y)

      if not tile then
        goto continue
      end

      local can_hit = false

      find_fn(tile, function(entity)
        if entity:hittable() and entity:team() ~= player:team() then
          can_hit = true
        end

        return false
      end)

      if not can_hit then
        goto continue
      end

      local dest_tile = tile:get_tile(player:facing_away(), 1)
      if dest_tile and not dest_tile:is_reserved(reservation_exclude_list) and (dest_tile:is_walkable() or player:ignoring_hole_tiles()) then
        return dest_tile, player:facing()
      end

      dest_tile = tile:get_tile(player:facing(), 1)
      if dest_tile and not dest_tile:is_reserved(reservation_exclude_list) and (dest_tile:is_walkable() or player:ignoring_hole_tiles()) then
        return dest_tile, player:facing_away()
      end

      ::continue::
    end
  end

  return nil
end

---@param player Entity
local function create_frog_smack_action(player)
  local action = Action.new(player)
  action:set_lockout(ActionLockout.new_sequence())

  local animation = player:animation()
  local original_tile
  local original_facing

  local start_step = action:create_step()

  local delay = 30
  local delay_step = action:create_step()
  delay_step.on_update_func = function()
    if delay > 0 then
      delay = delay - 1
    else
      delay_step:complete_step()
    end
  end

  local attack_step = action:create_step()
  attack_step.on_update_func = function()
    attack_step.on_update_func = nil

    local dest_tile, dest_facing = find_frog_smack_dest_tile(player, original_tile, Tile.find_characters)

    if not dest_tile then
      dest_tile, dest_facing = find_frog_smack_dest_tile(player, original_tile, Tile.find_obstacles)
    end

    if not dest_tile or not dest_facing then
      dest_tile = original_tile
      dest_facing = original_facing
    end

    dest_tile:add_entity(player)
    player:set_facing(dest_facing)
    spawn_splash(player:current_tile())
    Resources.play_audio(SURFACE_SFX)

    animation:set_state("CHARACTER_PUNCH_START")
    animation:on_complete(function()
      Resources.play_audio(FROG_SMACK_SFX)

      animation:set_state("CHARACTER_PUNCH")
      animation:on_frame(4, function()
        local target_tile = player:get_tile(player:facing(), 1)

        if not target_tile then
          return
        end

        local spell = Spell.new(player:team())
        spell:set_hit_props(HitProps.new(
          player:attack_level() * 20,
          Hit.Flinch | Hit.Flash,
          Element.Aqua,
          player:context()
        ))
        spell.on_spawn_func = function()
          spell:attack_tile()
          spell:delete()
        end

        Field.spawn(spell, target_tile)
      end)
      animation:on_complete(function()
        player:queue_default_player_movement(original_tile)
        attack_step:complete_step()
      end)
    end)
  end

  local return_step = action:create_step()
  return_step.on_update_func = function()
    if player:current_tile() == original_tile then
      player:set_facing(original_facing)
      original_tile:remove_reservation_for(player)
      original_tile = nil
    end

    if not player:is_moving() then
      return_step:complete_step()
    end
  end

  action.on_execute_func = function()
    original_tile = player:current_tile()
    original_tile:reserve_for(player)
    original_facing = player:facing()

    animation:set_state("CHARACTER_MOVE")
    animation:on_complete(function()
      start_step:complete_step()
      player:current_tile():remove_entity(player)
      spawn_splash(player:current_tile())
      Resources.play_audio(DIVE_SFX)
    end)
  end

  action.on_action_end_func = function()
    if original_tile then
      original_tile:remove_reservation_for(player)
      original_tile:add_entity(player)
      player:set_facing(original_facing)
    end
  end

  return action
end

---@param player Entity
function player_init(player)
  player:set_height(36.0)
  player:set_texture(TEXTURE)
  player:load_animation(ANIM_PATH)
  player:set_charge_position(2, -14)

  player:set_shadow(SHADOW_TEXTURE, SHADOW_ANIM_PATH)

  -- emotions
  EmotionsLib.implement_supported_full(player)

  -- water logic
  local under_water = false

  local under_water_node = player:create_sync_node()
  local under_water_sprite = under_water_node:sprite()
  under_water_sprite:set_texture(UNDER_WATER_TEXTURE)
  under_water_sprite:hide()
  under_water_node:animation():load(UNDER_WATER_ANIM_PATH)

  local set_under_water = function(value)
    under_water = value

    if under_water then
      under_water_sprite:reveal()
    else
      under_water_sprite:hide()
    end
  end

  local component = player:create_component(Lifetime.Scene)
  local TRANSPARENT = Color.new(0, 0, 0, 0)
  component.on_update_func = function()
    if player:has_actions() then
      set_under_water(false)
      return
    end

    if under_water then
      player:set_color(TRANSPARENT)
    end
  end

  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.Always)
  defense_rule.defense_func = function(defense, _, _, hit_props)
    if not under_water then
      return
    end

    if hit_props.flags & Hit.PierceGround ~= 0 then
      set_under_water(false)
      return
    end

    if hit_props.element == Element.Elec or hit_props.secondary_element == Element.Elec then
      set_under_water(false)
      return
    end

    defense:block_damage()
  end
  player:add_defense_rule(defense_rule)

  player.on_update_func = function()
    local on_sea_panel = player:current_tile():state() == TileState.Sea

    if on_sea_panel and not under_water and not player:has_actions() then
      set_under_water(true)
    elseif not on_sea_panel and under_water then
      set_under_water(false)
    end
  end

  -- attacks
  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.charged_attack_func = function()
    return create_frog_smack_action(player)
  end

  -- custom chip charge: kero kero!
  player.calculate_card_charge_time_func = function(self, card)
    local can_charge = not card.time_freeze and
        (card.element == Element.Aqua or card.secondary_element == Element.Aqua) and
        card.package_id ~= FIXED_CARD_ID

    if not can_charge then
      return
    end

    return 60
  end

  player.charged_card_func = function()
    return create_throw_kero_kero_action(player)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "T")
  player:set_fixed_card(card)

  -- intro
  player.intro_func = function()
    local action = Action.new(player, "INTRO_JUMP")
    action:set_lockout(ActionLockout.new_sequence())

    player:hide()

    local elevation = 0
    local vel = 10
    local acc = -1

    local physics_step = action:create_step()
    physics_step.on_update_func = function()
      elevation = elevation + vel
      vel = vel + acc

      if elevation <= 0 then
        player:set_elevation(0)
        physics_step:complete_step()

        player:animation():set_state("CHARACTER_IDLE")
        return
      end

      player:set_elevation(elevation)
    end

    local wait_time = 16
    local wait_step = action:create_step()
    wait_step.on_update_func = function()
      wait_time = wait_time - 1
      if wait_time <= 0 then
        wait_step:complete_step()
      end
    end

    action.on_execute_func = function()
      spawn_splash(player:current_tile())
      Resources.play_audio(SURFACE_SFX)
      player:reveal()
    end

    return action
  end
end

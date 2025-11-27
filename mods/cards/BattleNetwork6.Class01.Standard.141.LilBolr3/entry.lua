---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local TEMP_STYLE = TextStyle.new_monospace("ENTITY_HP")
local TEMP_INC_STYLE = TextStyle.new_monospace("ENTITY_HP_RED")
TEMP_STYLE.letter_spacing = 0
TEMP_INC_STYLE.letter_spacing = 0

local EXPLOSION_TEXTURE = bn_assets.load_texture("spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("spell_explosion.animation")
local EXPLOSION_SFX = bn_assets.load_audio("explosion_defeatedmob.ogg")

local STEAM_TEXTURE = bn_assets.load_texture("kettle_steam.png")
local STEAM_ANIM_PATH = bn_assets.fetch_animation_path("kettle_steam.animation")

local TEXTURE = bn_assets.load_texture("kettle.grayscale.png")
local ANIM_PATH = bn_assets.fetch_animation_path("kettle.animation")
local SHADOW = bn_assets.load_texture("kettle_shadow.png")
local PALETTE = Resources.load_texture("palette.png")

local LAND_SFX = bn_assets.load_audio("golmhit2.ogg")
local SPLASH_SFX = bn_assets.load_audio("dust_chute2.ogg")
local ATTACK_SFX = bn_assets.load_audio("kettle.ogg")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))
bomb:set_air_duration(52)

local function spawn_explosion(tile)
  local explosion = Artifact.new()
  explosion:set_texture(EXPLOSION_TEXTURE)

  local animation = explosion:animation()
  animation:load(EXPLOSION_ANIM_PATH)
  animation:set_state("DEFAULT")

  animation:on_complete(function()
    explosion:delete()
  end)

  explosion.on_spawn_func = function()
    Resources.play_audio(EXPLOSION_SFX)
  end

  Field.spawn(explosion, tile)
end

---@param team Team
---@param hit_props HitProps
local function create_splash_attack(team, hit_props)
  local steam = Spell.new(team)
  steam:set_hit_props(hit_props)
  steam:set_texture(STEAM_TEXTURE)

  local animation = steam:animation()
  animation:load(STEAM_ANIM_PATH)
  animation:set_state("SPLASH")

  animation:on_complete(function()
    steam:delete()
  end)

  steam.on_spawn_func = function()
    steam:attack_tile()
  end

  return steam
end

---@param center_tile Tile
---@param callback fun(tile: Tile)
local function iterate_surrounding_tiles(center_tile, callback)
  local center_x = center_tile:x()
  local center_y = center_tile:y()

  for y = -1, 1 do
    for x = -1, 1 do
      local tile = Field.tile_at(center_x + x, center_y + y)

      if tile and not tile:is_edge() and not (x == 0 and y == 0) then
        callback(tile)
      end
    end
  end
end

---@param team Team
---@param hit_props HitProps
local function create_steam_burst(team, hit_props)
  local steam = Spell.new()
  steam:set_texture(STEAM_TEXTURE)

  local animation = steam:animation()
  animation:load(STEAM_ANIM_PATH)
  animation:set_state("ATTACK")

  animation:on_complete(function()
    steam:delete()

    local spawned_splash = false
    iterate_surrounding_tiles(steam:current_tile(), function(tile)
      local splash = create_splash_attack(team, hit_props)
      Field.spawn(splash, tile)
      spawned_splash = true
    end)

    if spawned_splash then
      Resources.play_audio(SPLASH_SFX)
    end
  end)

  steam.on_update_func = function()
    iterate_surrounding_tiles(steam:current_tile(), function(tile)
      tile:set_highlight(Highlight.Flash)
    end)
  end

  return steam
end

---@param parent_entity Entity
local function spawn_temperature_artifact(parent_entity)
  local artifact = Artifact.new()
  artifact:set_never_flip(true)

  local displayed_temp = 999 - parent_entity:health()

  local temp_node
  local function build_temp_node(text_style)
    if temp_node then
      artifact:remove_node(temp_node)
    end

    temp_node = artifact:sprite():create_text_node(text_style, " " .. displayed_temp)

    local children = temp_node:children()
    local last_child = children[#children]
    local text_width = last_child:offset().x + last_child:width()

    temp_node:set_offset(-text_width // 2, 2)
  end
  build_temp_node(TEMP_STYLE)

  local component = artifact:create_component(Lifetime.Scene)
  component.on_update_func = function()
    if parent_entity:deleted() then
      artifact:delete()
      return
    end

    -- update position
    local TILE_W = Tile:width()
    local TILE_H = Tile:height()
    local tile = parent_entity:current_tile()
    local offset = parent_entity:offset()
    local movement_offset = parent_entity:movement_offset()
    local elevation = parent_entity:elevation()

    local tile_offset_x = tile:x() * TILE_W
    local tile_offset_y = tile:y() * TILE_H - (Field.height() - 1) * TILE_H

    artifact:set_offset(
      tile_offset_x + offset.x + movement_offset.x,
      tile_offset_y + offset.y + movement_offset.y - elevation
    )

    -- updating health
    local target_temp = 999 - parent_entity:health()

    if target_temp == displayed_temp then
      -- no need to update
      return
    end

    local diff = target_temp - displayed_temp

    -- using math from the engine
    -- https://www.desmos.com/calculator/qwxqhthmuw
    -- "x = diff, y = change"
    local x = math.abs(diff)
    local y

    if x >= 4 then
      y = x // 8 + 4
    elseif x >= 2 then
      y = 2
    else
      y = 1
    end

    if diff < 0 then
      y = -y
    end

    local prev_temp = displayed_temp
    displayed_temp = prev_temp + y

    if displayed_temp ~= target_temp then
      build_temp_node(TEMP_INC_STYLE)
    else
      build_temp_node(TEMP_STYLE)
    end
  end

  Field.spawn(artifact, 0, Field.height() - 1)
end

bomb.swap_bomb_func = function(action)
  local owner = action:owner()
  local props = action:copy_card_properties()

  local team = owner:team()
  local steam_hit_props = HitProps.from_card(props, owner:context())
  steam_hit_props.element = Element.Aqua
  local direct_hit_props = HitProps.from_card(props, owner:context())
  direct_hit_props.element = Element.None
  direct_hit_props.damage = direct_hit_props.damage // 2

  local obstacle = Obstacle.new(Team.Other)
  obstacle:set_owner(owner)
  obstacle:set_facing(owner:facing())
  obstacle:set_texture(TEXTURE)
  obstacle:set_palette(PALETTE)
  obstacle:set_shadow(SHADOW)
  obstacle:set_hit_props(direct_hit_props)
  obstacle:set_health(999 - steam_hit_props.damage)

  local animation = obstacle:animation()
  animation:load(ANIM_PATH)
  animation:set_state("LITTLE_BOILER")
  animation:set_playback(Playback.Loop)

  -- display temp
  spawn_temperature_artifact(obstacle)

  -- immune to anything that isn't drag
  obstacle:add_aux_prop(AuxProp.new():declare_immunity(~Hit.Drag))

  -- track hits, avoid taking damage after 3 hits
  local hits = 0
  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
  defense_rule.defense_func = function(defense, _, _, hit_props)
    if hit_props.flags & Hit.PierceGuard ~= 0 then
      hits = 0
      obstacle:delete()
      return
    end

    if hits >= 3 then
      defense:block_damage()
      return
    end

    if hit_props.damage <= 0 then
      return
    end

    hits = hits + 1

    if hits == 3 then
      obstacle:delete()
    end
  end
  obstacle:add_defense_rule(defense_rule)

  -- update
  local time = 0
  obstacle.on_update_func = function()
    local elevation = obstacle:elevation()

    if elevation < 16 and elevation > 0 then
      obstacle:attack_tile()
      obstacle:enable_hitbox()
    end

    if elevation > 0 then
      return
    end

    time = time + 1

    if time == 2 then
      -- land
      obstacle:enable_hitbox()
      Field.shake(3, 16)
      Resources.play_audio(LAND_SFX)
    elseif time > 96 then
      -- set hits to 3 to attack
      hits = 3
      obstacle:delete()
    end
  end

  obstacle.on_collision_func = function()
    obstacle:delete()
  end

  obstacle.on_delete_func = function()
    if obstacle:health() > 0 and hits ~= 3 then
      spawn_explosion(obstacle:current_tile())
      obstacle:erase()
      return
    end

    Resources.play_audio(ATTACK_SFX)

    animation:set_state("ATTACK")
    animation:on_frame(2, function()
      steam_hit_props.damage = 999 - obstacle:health()
      Field.spawn(create_steam_burst(team, steam_hit_props), obstacle:current_tile())
    end)
    animation:on_complete(function()
      spawn_explosion(obstacle:current_tile())
      obstacle:erase()
    end)
  end

  local ignored_reservations = { obstacle:id() }
  obstacle.can_move_to_func = function(tile)
    return tile:is_walkable() and not tile:is_reserved(ignored_reservations)
  end

  obstacle:enable_hitbox(false)

  return obstacle
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  return bomb:create_action(user, function(tile, boiler)
    if not tile or not tile:is_walkable() then
      boiler:delete()
      return
    end
  end)
end

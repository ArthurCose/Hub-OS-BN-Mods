---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local sword = SwordLib.new_sword()
sword:set_blade_texture(Resources.load_texture("racket.png"))
sword:set_blade_animation_path(_folder_path .. "racket.animation")

local SLASH_TEXTURE = bn_assets.load_texture("wind_slash.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("wind_slash.animation")
local SLASH_SFX = bn_assets.load_audio("windrack.ogg")

local GUST_TEXTURE = bn_assets.load_texture("wind_puff.png")
local GUST_ANIMATION_PATH = bn_assets.fetch_animation_path("wind_puff.animation")
local WIND_SFX = bn_assets.load_audio("wind_burst.ogg")


local function create_gust(team, direction)
  local spell = Spell.new(team)
  spell:set_hit_props(HitProps.new(0, 0, Element.Wind))

  local i = 0
  spell.on_update_func = function()
    local tile = spell:current_tile()
    spell:attack_tile()

    i = i + 1

    local has_obstacles = false
    tile:find_obstacles(function()
      has_obstacles = true
      return false
    end)

    if has_obstacles then
      spell:erase()
      return
    end

    if spell:is_moving() then
      return
    end

    local next_tile = tile:get_tile(direction, 1)

    if not next_tile or next_tile:is_edge() then
      spell:erase()
      return
    end

    tile:find_characters(function(character)
      if character:team() ~= team then
        character:slide(next_tile, 4)
      end

      return false
    end)

    spell:slide(next_tile, 4)
  end

  return spell
end

---@param user Entity
local function create_slash(user, hit_props)
  local spell = Spell.new(user:team())
  spell:set_facing(user:facing())
  spell:set_hit_props(hit_props)
  spell:set_texture(SLASH_TEXTURE)

  local anim = spell:animation()
  anim:load(SLASH_ANIM_PATH)
  anim:set_state("DEFAULT")
  anim:on_complete(function()
    spell:delete()
  end)

  local attack_existing_tile = function(tile)
    if tile then spell:attack_tile(tile) end
  end

  spell.on_update_func = function()
    spell:attack_tile()
    attack_existing_tile(spell:get_tile(Direction.Up, 1))
    attack_existing_tile(spell:get_tile(Direction.Down, 1))
  end

  return spell
end

local function create_back_gust(team, direction)
  local spell = Spell.new(team)
  spell:set_facing(direction)
  spell:set_hit_props(HitProps.new(0, 0, Element.Wind))

  spell:set_texture(GUST_TEXTURE)
  local animation = spell:animation()
  animation:load(GUST_ANIMATION_PATH)
  animation:set_state("GREEN")

  if direction == Direction.Right then
    spell:set_offset(-8, 0)
  else
    spell:set_offset(8, 0)
  end

  local i = 0
  spell.on_update_func = function()
    local tile = spell:current_tile()
    spell:attack_tile()

    i = i + 1

    local has_obstacles = false
    tile:find_obstacles(function()
      has_obstacles = true
      return false
    end)

    if has_obstacles then
      spell:erase()
      return
    end

    local next_tile = tile:get_tile(direction, 1)

    if next_tile then
      -- back gusts push continuously, not only when centered on a tile
      tile:find_characters(function(character)
        if character:team() ~= team then
          character:slide(next_tile, 4)
        end

        return false
      end)
    end

    if spell:is_moving() then
      return
    end

    if tile:team() == spell:team() then
      spell:erase()
      return
    end

    if not next_tile or next_tile:is_edge() then
      spell:erase()
      return
    end

    spell:slide(next_tile, 4)
  end

  return spell
end

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Wind,
    charge_timing = { 100, 90, 80, 75, 70 },
    activate_callback = function()
      player:boost_augment("HubOS.Augments.IgnoreHoles", 1)
    end,
    deactivate_callback = function()
      player:boost_augment("HubOS.Augments.IgnoreHoles", -1)
    end
  })

  form:set_mugshot_texture(FORM_MUG)


  local special_cooldown = 0

  form.on_update_func = function()
    if special_cooldown > 0 then
      special_cooldown = special_cooldown - 1
    end
  end


  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  form.charged_attack_func = function()
    return sword:create_action(player, function()
      local forward_tile = player:get_tile(player:facing(), 1)

      if not forward_tile then
        return
      end

      local hit_props = HitProps.new(
        20 * player:attack_level() + 40,
        Hit.Impact | Hit.Flinch | Hit.Drag,
        Element.Wind,
        player:context(),
        Drag.new(player:facing(), Field.width())
      )

      Field.spawn(create_slash(player, hit_props), forward_tile)

      local team = player:team()
      local x = forward_tile:x()

      for y = 0, Field.height() - 1 do
        Field.spawn(create_gust(team, player:facing()), x, y)
      end

      Resources.play_audio(SLASH_SFX)
    end)
  end

  form.special_attack_func = function()
    if special_cooldown > 0 then
      return nil
    end

    special_cooldown = 60

    local action = Action.new(player, "PLAYER_IDLE")
    action:set_lockout(ActionLockout.new_sequence())

    local wait_step = action:create_step()
    local i = 0
    wait_step.on_update_func = function()
      i = i + 1

      if i == 10 then
        wait_step:complete_step()
      end
    end

    action.on_execute_func = function()
      Resources.play_audio(WIND_SFX)

      local team = player:team()
      local direction = player:facing_away()

      local x = 1

      if direction == Direction.Left then
        x = Field.width() - 2
      end

      for y = 1, Field.height() - 2 do
        Field.spawn(create_back_gust(team, direction), x, y)
      end
    end

    return action
  end
end

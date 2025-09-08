---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")
local implement_trash_chute = require("trash_chute/trash_chute")

local FORM_MUG = _folder_path .. "mug.png"

local VACUUM_TEXTURE = Resources.load_texture("vacuum.png")
local VACUUM_ANIMATION_PATH = _folder_path .. "vacuum.animation"
local VACUUM_SFX = bn_assets.load_audio("wind_burst.ogg")
local BUSTER_PEA_SHOT_SFX = bn_assets.load_audio("buster_pshot.ogg")

local SCRAP_REBORN_TEXTURE = Resources.load_texture("scrap_reborn.png")
local SCRAP_REBORN_ANIMATION_PATH = _folder_path .. "scrap_reborn.animation"
local SCRAP_REBORN_SHADOW_TEXTURE = Resources.load_texture("scrap_reborn_shadow.png")
local LAUNCH_SFX = bn_assets.load_audio("dust_launch.ogg")
local PUNCH_SFX = bn_assets.load_audio("golemhit.ogg")

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Break,
    charge_timing = { 80, 70, 60, 55, 50 }
  })

  form:set_mugshot_texture(FORM_MUG)
  implement_trash_chute(player, form)

  local special_cooldown = 0

  form.on_update_func = function()
    if special_cooldown > 0 then
      special_cooldown = special_cooldown - 1
    end
  end

  ---@type Entity[]
  local inhaled = {}
  player:on_delete(function()
    for _, entity in ipairs(inhaled) do
      entity:erase()
    end
  end)

  form.normal_attack_func = function()
    if #inhaled == 0 then
      -- normal buster
      return Buster.new(player, false, player:attack_level())
    end

    -- shoot an inhaled obstacle
    local action = Action.new(player, "CHARACTER_SHOOT")
    action:override_animation_frames({ { 1, 1 }, { 2, 2 }, { 3, 2 }, { 4, 11 }, { 4, 19 } })

    action.on_execute_func = function()
      local buster = action:create_attachment("BUSTER")
      buster:sprite():set_texture(player:texture())
      local buster_anim = buster:animation()
      buster_anim:copy_from(player:animation())
      buster_anim:set_state("BUSTER")
    end

    action:add_anim_action(2, function()
      Resources.play_audio(LAUNCH_SFX)
      Resources.play_audio(BUSTER_PEA_SHOT_SFX)

      local direction = player:facing()

      ---@type Entity
      local spell = table.remove(inhaled, 1)
      spell:set_tile_highlight(Highlight.Solid)
      spell:set_team(player:team())
      spell:set_hit_props(
        HitProps.new(
          200,
          Hit.Flinch | Hit.Flash | Hit.PierceGuard,
          Element.Break,
          player:context()
        )
      )

      local spell_sprite = spell:sprite()
      spell:set_offset(
        0,
        (spell_sprite:height() - spell_sprite:origin().y) // 2 - player:animation():get_point("BUSTER").y
      )

      spell.on_collision_func = function(_, other)
        shared.spawn_hit_artifact(
          other,
          "BREAKING",
          math.random(-Tile:width() // 2, Tile:width() // 2),
          0
        )
        spell:delete()
      end

      spell.on_update_func = function()
        spell:attack_tile()

        if spell:is_moving() then
          return
        end

        local next_tile = spell:get_tile(direction, 1)

        if not next_tile then
          spell:delete()
          return
        end

        spell:slide(next_tile, 4)
      end

      local spawn_tile = player:get_tile(direction, 1)

      if spawn_tile then
        spawn_tile:add_entity(spell)
      else
        spell:delete()
      end
    end)

    return action
  end

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARACTER_SHOOT")
    action:override_animation_frames({ { 1, 1 }, { 2, 2 }, { 3, 2 }, { 4, 11 }, { 4, 19 } })

    action.on_execute_func = function()
      Resources.play_audio(LAUNCH_SFX)
      player:set_counterable(true)

      local buster = action:create_attachment("BUSTER")
      buster:sprite():set_texture(player:texture())
      local buster_anim = buster:animation()
      buster_anim:copy_from(player:animation())
      buster_anim:set_state("BUSTER")

      local spawn_tile = player:get_tile(player:facing(), 1)

      if not spawn_tile then
        return
      end

      local spell = Spell.new(player:team())

      spell:set_hit_props(HitProps.new(
        10 * player:attack_level() + 50,
        Hit.Flinch | Hit.Flash | Hit.PierceGuard,
        Element.Break,
        player:context()
      ))

      spell:set_facing(player:facing())
      spell:set_shadow(SCRAP_REBORN_SHADOW_TEXTURE)
      spell:set_texture(SCRAP_REBORN_TEXTURE)

      local spell_anim = spell:animation()
      spell_anim:load(SCRAP_REBORN_ANIMATION_PATH)
      spell_anim:set_state("DEFAULT")

      local function stop_and_attack()
        spell.on_update_func = nil
        local offset = spell:movement_offset()
        spell:cancel_movement()
        spell:set_movement_offset(0, 0)
        spell:set_offset(offset.x, offset.y)

        spell_anim:set_state("PUNCH")

        spell_anim:on_frame(3, function()
          spell:attack_tile()

          local tile = spell:current_tile()

          if not tile:is_walkable() then
            return
          end

          Field.shake(3, 30)
          Resources.play_audio(PUNCH_SFX)

          if tile:state() == TileState.Cracked then
            tile:set_state(TileState.Broken)
          else
            tile:set_state(TileState.Cracked)
          end
        end)

        spell_anim:on_complete(function()
          spell:delete()
        end)
      end

      spell.on_collision_func = function(_, other)
        shared.spawn_hit_artifact(
          other,
          "BREAKING",
          math.random(-Tile:width() // 2, Tile:width() // 2),
          0
        )
      end

      spell.on_update_func = function()
        local tile = spell:current_tile()
        local contains_hittable = false
        tile:find_entities(function(e)
          if not contains_hittable then
            contains_hittable = Living.from(e) and e:hittable() and e:team() ~= spell:team()
          end
          return false
        end)

        if contains_hittable then
          stop_and_attack()
          return
        end

        local next_tile = spell:get_tile(spell:facing(), 1)

        if not next_tile or next_tile:is_edge() then
          stop_and_attack()
          return
        end

        if spell:is_moving() then
          return
        end

        spell:slide(next_tile, 8)
      end

      Field.spawn(spell, spawn_tile)
    end

    action:add_anim_action(5, function()
      player:set_counterable(false)
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  form.special_attack_func = function()
    if special_cooldown > 0 then
      return nil
    end

    special_cooldown = 30

    local action = Action.new(player, "SPECIAL_ATTACK")

    action.on_execute_func = function()
      local artifact = Artifact.new()
      artifact:set_facing(player:facing())
      artifact:set_texture(VACUUM_TEXTURE)
      local anim = artifact:animation()
      anim:load(VACUUM_ANIMATION_PATH)
      anim:set_state("DEFAULT")
      anim:on_complete(function()
        artifact:delete()
      end)

      Field.spawn(artifact, player:current_tile())
    end

    ---@type Entity[]
    local inhaling = {}

    action:add_anim_action(4, function()
      Resources.play_audio(VACUUM_SFX)

      Field.find_obstacles(function(e)
        if not e:hittable() or not e:owner() or #inhaled + #inhaling >= 8 then
          return false
        end

        -- create a spell with the appearance of the entity
        local spell = Spell.new(player:team())

        spell.on_spawn_func = function()
          if e:deleted() then
            spell:delete()
            return
          end

          spell:set_facing(e:facing())
          spell:set_texture(e:texture())
          e:animation():apply(spell:sprite())

          if e:height() > 0 then
            spell:set_height(e:height())
          else
            spell:set_height(spell:sprite():origin().y)
          end

          inhaling[#inhaling + 1] = spell
          e:erase()
        end

        -- animate the vacuum
        -- we'll do math using global offsets
        -- then convert these offsets to a tiles and local offset
        local TILE_W, TILE_H = Tile:width(), Tile:height()
        local spawn_tile = e:current_tile()
        local start_x = spawn_tile:x() * TILE_W + TILE_W // 2
        local start_y = spawn_tile:y() * TILE_H + TILE_H // 2

        local time = 0
        local DURATION = 10

        spell.on_update_func = function()
          time = time + 1

          spell:current_tile():remove_entity(spell)

          if time > DURATION then
            spell.on_update_func = nil
            return
          end

          local end_tile = player:current_tile()
          local movement_offset = player:movement_offset()

          local end_local_x = 0

          if player:facing() == Direction.Right then
            end_local_x = TILE_W
          end

          local end_x = end_tile:x() * TILE_W + end_local_x + movement_offset.x
          local end_y = end_tile:y() * TILE_H + TILE_H // 2 + movement_offset.y

          local progress = time / DURATION
          local global_x = (end_x - start_x) * progress + start_x
          local global_y = (end_y - start_y) * progress + start_y

          -- resolve tile
          local tile = Field.tile_at(
            global_x // TILE_W,
            global_y // TILE_H
          )

          -- resolve local offset
          local elevation = progress * (player:height() * 3 // 4 - spell:height() // 2)

          spell:set_offset(
            global_x % TILE_W - TILE_W // 2,
            global_y % TILE_H - TILE_H // 2 - elevation
          )

          if tile then
            tile:add_entity(spell)
          end
        end

        Field.spawn(spell, spawn_tile)

        return false
      end)
    end)

    action:add_anim_action(8, function()
      for _, entity in ipairs(inhaling) do
        if not entity:deleted() then
          inhaled[#inhaled + 1] = entity
        end
      end

      inhaling = {}
    end)

    action.on_action_end_func = function()
      for _, entity in ipairs(inhaling) do
        entity:erase()
      end
    end

    return action
  end
end

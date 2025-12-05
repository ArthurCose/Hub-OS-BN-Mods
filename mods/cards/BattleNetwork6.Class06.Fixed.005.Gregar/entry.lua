---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local COAL_TEXTURE = Resources.load_texture("coal.png")
local COAL_ANIM_PATH = "coal.animation"
local COAL_SFX = bn_assets.load_audio("fireball.ogg")
local COAL_SHADOW = bn_assets.load_texture("bomb_shadow.png")

local EXPLOSION_TEXTURE = bn_assets.load_texture("spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("spell_explosion.animation")
local EXPLOSION_SFX = bn_assets.load_audio("explosion_defeatedboss.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 30 + user:attack_level() * 10
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "CHARACTER_THROW")
  action:set_lockout(ActionLockout.new_animation())

  action.on_execute_func = function()
    user:set_counterable(true)
  end

  action:on_anim_frame(2, function()
    user:set_counterable(false)
  end)

  local time = 0
  local step = action:create_step()
  step.on_update_func = function()
    time = time + 1

    if time == 19 then
      Resources.play_audio(COAL_SFX)

      local primary_tiles = {}
      local secondary_tiles = {}
      local all_opposing_tiles = Field.find_tiles(function(tile)
        if tile:team() == user:team() or tile:is_edge() then
          return false
        end

        local has_enemy = false
        tile:find_characters(function(c)
          if c:hittable() and c:team() ~= user:team() then
            has_enemy = true
          end
          return false
        end)

        if has_enemy then
          primary_tiles[#primary_tiles + 1] = tile
        else
          secondary_tiles[#secondary_tiles + 1] = tile
        end

        return tile:team() ~= user:team()
      end)

      local hit_props = HitProps.from_card(props, user:context())

      for _ = 1, 5 do
        local spell = Spell.new(user:team())
        spell:set_hit_props(hit_props)
        spell:set_layer(-1)
        spell:set_shadow(COAL_SHADOW)
        spell:set_texture(COAL_TEXTURE)

        local animation = spell:animation()
        animation:load(COAL_ANIM_PATH)
        animation:set_state("DEFAULT")
        animation:set_playback(Playback.Loop)

        local MOVEMENT_TIME = 45
        local initial_x = 12
        local initial_y = -44

        if user:facing() == Direction.Left then
          initial_x = -initial_x
        end

        ---@type Tile
        local target_tile

        if #primary_tiles > 0 then
          target_tile = table.remove(primary_tiles, math.random(#primary_tiles))
        elseif #secondary_tiles > 0 then
          target_tile = table.remove(secondary_tiles, math.random(#secondary_tiles))
        elseif #all_opposing_tiles > 0 then
          target_tile = all_opposing_tiles[math.random(#all_opposing_tiles)]
        else
          target_tile = user:current_tile()
        end

        spell.on_spawn_func = function()
          spell:jump(target_tile, 64, MOVEMENT_TIME)
        end

        local time = 0
        local hit_something = false
        spell.on_update_func = function()
          target_tile:set_highlight(Highlight.Flash)

          time = time + 1

          -- try to move closer to 0 from the initial offset
          local offset_x = 0
          local offset_y = 0

          if time < MOVEMENT_TIME then
            local progress = time / MOVEMENT_TIME
            offset_x = math.floor(initial_x * (1 - progress))
            offset_y = math.floor(initial_y * (1 - progress))
          end

          spell:set_offset(offset_x, 0)
          spell:set_elevation(-offset_y)

          if time + 1 == MOVEMENT_TIME then
            spell:attack_tile(target_tile)
          end

          if spell:is_moving() then
            return
          end

          if not target_tile:is_walkable() and not hit_something then
            -- missed
            spell:delete()
            return
          end

          -- explode
          spell.on_update_func = nil

          spell:show_shadow(false)
          spell:set_texture(EXPLOSION_TEXTURE)

          animation:load(EXPLOSION_ANIM_PATH)
          animation:set_state("DEFAULT")
          animation:on_complete(function()
            spell:delete()
          end)

          Resources.play_audio(EXPLOSION_SFX)
        end

        spell.on_collision_func = function()
          hit_something = true
        end

        Field.spawn(spell, user:current_tile())
      end
    elseif time == 62 then
      step:complete_step()
    end
  end

  action.on_action_end_func = function()
    user:set_counterable(false)
  end

  return action
end

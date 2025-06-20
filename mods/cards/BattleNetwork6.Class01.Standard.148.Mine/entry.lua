---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("mine.png")
local ANIM_PATH = bn_assets.fetch_animation_path("mine.animation")

local APPEAR_SFX = bn_assets.load_audio("mine.ogg")

local HIT_OBSTACLE = bn_assets.load_audio("hit_obstacle.ogg")
local HIT_ENTITY = bn_assets.load_audio("hit_impact.ogg")

local EXPLOSION_TEXTURE = bn_assets.load_texture("mine_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("mine_explosion.animation")

local COUNTER = 128

function card_init(user, props)
  local action = Action.new(user)

  action:set_lockout(ActionLockout.new_sequence())

  action.on_execute_func = function()
    local tile_checks = 0
    local step = action:create_step()
    local time = 0
    local field = user:field()

    local mine = Spell.new(Team.Other)

    mine:set_hit_props(HitProps.from_card(props, user:context()))

    mine.on_update_func = function(self)
      if TurnGauge.frozen() then return end
      local tile = self:current_tile()
      local target_list = tile:find_entities(function(ent)
        if not ent:hittable() then return false end
        if Obstacle.from(ent) == nil and Character.from(ent) == nil then return false end
        if ent:ignoring_negative_tile_effects() then return false end
        return true
      end)

      if #target_list > 0 then self:attack_tile() end
    end

    mine.on_collision_func = function(self, other)
      --TODO: Spawn explosion
      local explosion = Explosion.new()
      explosion:set_texture(EXPLOSION_TEXTURE)

      local explosion_animation = explosion:animation()
      explosion_animation:load(EXPLOSION_ANIM_PATH)
      explosion_animation:set_state("DEFAULT")

      explosion.on_spawn_func = function()
        if Obstacle.from(other) ~= nil then
          Resources.play_audio(HIT_OBSTACLE)
        else
          Resources.play_audio(HIT_ENTITY)
        end
      end

      explosion_animation:on_complete(function()
        explosion:erase()
      end)

      field:spawn(explosion, other:current_tile())

      self:erase()
    end

    mine._is_set = false

    mine:set_texture(TEXTURE)

    local mine_anim = mine:animation()

    mine_anim:load(ANIM_PATH)
    mine_anim:set_state("DEFAULT")
    mine_anim:set_playback(Playback.Loop)

    mine.can_move_to_func = function(tile)
      return mine._is_set == false
    end

    local tile_list = field:find_tiles(function(tile)
      if not tile:is_walkable() then return false end

      if #tile:find_obstacles(function(o)
            return true
          end) > 0 then
        return false
      end

      if #tile:find_characters(function(c)
            return true
          end) > 0 then
        return false
      end

      return tile:team() ~= user:team()
    end)

    step.on_update_func = function()
      time = time + 1

      if time == COUNTER then return step:complete_step() end

      local index = math.random(1, #tile_list)
      local destination_tile = tile_list[index]

      tile_checks = tile_checks + 1

      if tile_checks == 119 then
        mine._is_set = true
        mine:hide()
        step:complete_step()
        return
      end

      if time % 2 == 0 then return end

      if mine:spawned() then
        if destination_tile == mine:current_tile() then
          if index >= math.floor(#tile_list / 2) then index = index - 1 else index = index + 1 end
          destination_tile = tile_list[index]
        end

        mine:teleport(destination_tile)
      else
        field:spawn(mine, destination_tile)
      end

      Resources.play_audio(APPEAR_SFX)
    end
  end

  return action
end

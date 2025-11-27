---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("meteor_land.ogg")

local TEXTURE = bn_assets.load_texture("meteor.png")
local ANIM_PATH = bn_assets.fetch_animation_path("meteor.animation")

local APPEAR_SFX = bn_assets.load_audio("mine.ogg")

local EXPLOSION_TEXTURE = bn_assets.load_texture("ring_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")

local function create_impact_explosion(tile, team)
  local explosion = Spell.new(team)
  explosion:set_texture(EXPLOSION_TEXTURE)

  local new_anim = explosion:animation()
  new_anim:load(EXPLOSION_ANIM_PATH)
  new_anim:set_state("DEFAULT")

  explosion:sprite():set_layer(-2)

  Resources.play_audio(AUDIO)

  explosion.on_spawn_func = function()
    Field.shake(5, 18)
  end

  Field.spawn(explosion, tile)

  new_anim:on_complete(function()
    explosion:erase()
  end)
end

local function create_meteor(player, props)
  local meteor = Spell.new(player:team())

  meteor:set_tile_highlight(Highlight.Flash)
  meteor:set_facing(player:facing())

  meteor:set_hit_props(HitProps.from_card(props, player:context(), Drag.None))

  meteor:set_texture(TEXTURE)

  local anim = meteor:animation()
  anim:load(ANIM_PATH)
  anim:set_state("DEFAULT")
  meteor:sprite():set_layer(-2)

  local vel_x = 14
  local vel_y = 14

  if player:facing() == Direction.Left then
    vel_x = -vel_x
  end

  meteor:set_offset(-vel_x * 8, -vel_y * 8)

  meteor.on_update_func = function(self)
    local offset = self:offset()
    if offset.y < 0 then
      self:set_offset(offset.x + vel_x, offset.y + vel_y)
      return
    end

    local tile = self:current_tile()

    if tile:is_walkable() then
      self:attack_tile()
      create_impact_explosion(tile, self:team())
    end

    self:erase()
  end

  return meteor
end


function card_init(user, props)
  local action = Action.new(user)

  action:set_lockout(ActionLockout.new_sequence())

  action.on_execute_func = function()
    local tile_checks = 0
    local step = action:create_step()
    local time = 0
    local wait_timer = 60

    local tile_list = {}
    for x = Field.width(), 0, -1 do
      for y = 0, Field.height(), 1 do
        local tile = Field.tile_at(x, y)

        if not tile then goto continue end
        if tile:is_edge() then goto continue end
        if tile:team() == user:team() then goto continue end

        table.insert(tile_list, tile)

        ::continue::
      end
    end

    local tile_list_index = 1
    local meteor_spawn_timings = {}
    local timing_index = 1

    for i = 0, 30, 1 do
      table.insert(meteor_spawn_timings, 32 + (10 * i))
    end

    step.on_update_func = function()
      if tile_checks == 30 then
        if wait_timer > 0 then
          wait_timer = wait_timer - 1
          return
        end

        step:complete_step()
        return
      end

      time = time + 1

      local destination_tile = tile_list[tile_list_index]

      destination_tile:set_highlight(Highlight.Flash)

      if time < 32 then return end

      if time ~= meteor_spawn_timings[timing_index] then return end

      local meteor = create_meteor(user, props)
      Field.spawn(meteor, destination_tile)

      tile_list_index = tile_list_index + 1

      tile_checks = tile_checks + 1
      if tile_list_index > #tile_list then tile_list_index = 1 end

      timing_index = math.min(30, timing_index + 1)
    end
  end

  return action
end

local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("meteor_land.ogg")

local TEXTURE = bn_assets.load_texture("meteor.png")
local ANIM_PATH = bn_assets.fetch_animation_path("meteor.animation")

local EXPLOSION_TEXTURE = bn_assets.load_texture("ring_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")

local function create_impact_explosion(tile, team)
  local explosion = Spell.new(team)
  explosion:set_texture(EXPLOSION_TEXTURE)

  local new_anim = explosion:animation()
  new_anim:load(EXPLOSION_ANIM_PATH)
  new_anim:set_state("DEFAULT")

  explosion:sprite():set_layer(-2)

  explosion.on_spawn_func = function()
    if tile:can_set_state(TileState.Broken) then tile:set_state(TileState.Broken) else tile:set_state(TileState.Cracked) end
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

function card_init(player, props)
  local action = Action.new(player)

  action:set_lockout(ActionLockout.new_async(20))

  action.on_execute_func = function(self, user)
    create_meteor_component(player, props)
  end

  return action
end

function create_meteor_component(player, props)
  if not player or player and player:deleted() then return end

  local meteor_component = player:create_component(Lifetime.ActiveBattle)
  local count = 0
  local health = player:health()
  local max_health = player:max_health()

  if health <= max_health * 0.25 then
    count = 16
  elseif health <= max_health * 0.65 then
    count = 14
  else
    count = 12
  end

  local initial_cooldown = 1
  local attack_cooldown = 12

  local stored_team = player:team()
  local enemy_filter = function(character)
    return character:team() ~= stored_team
  end

  meteor_component.on_update_func = function(self)
    if player:deleted() then return end

    if count == 0 then
      self:eject()
      return
    end

    if initial_cooldown > 0 then
      initial_cooldown = initial_cooldown - 1
      return
    end

    attack_cooldown = attack_cooldown - 1

    if attack_cooldown == 0 then
      local target_list = Field.find_nearest_characters(player, enemy_filter)

      if #target_list == 0 then
        return
      end

      count = count - 1
      attack_cooldown = 16

      Resources.play_audio(AUDIO)

      Field.spawn(create_meteor(player, props), target_list[1]:current_tile())
    end
  end
end

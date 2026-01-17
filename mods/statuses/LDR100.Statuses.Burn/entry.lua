local bn_assets = require("BattleNetwork.Assets")

local FIRE_TEXTURE = bn_assets.load_texture("flame_rings.png")
local FIRE_ANIM_PATH = bn_assets.fetch_animation_path("flame_rings.animation")
local F_AUDIO = bn_assets.load_audio("fireball.ogg")
local TEXTURE = Resources.load_texture("burn.png")

local BOOM_TEXT = bn_assets.load_texture("fire_tower.png")
--local BOOM_ANIM = Resources.fetch_animation_path("fire_tower.animation")

local BURN_INTERVAL = 6

local function spawn_alert(parent)
  local alert_artifact = Alert.new()
  alert_artifact:sprite():set_never_flip(true)

  local movement_offset = parent:movement_offset()
  alert_artifact:set_offset(movement_offset.x, movement_offset.y - parent:height())

  parent:field():spawn(alert_artifact, parent:current_tile())
end

---@param status Status
function status_init(status)
  local entity = status:owner()

  -- Immunity to freeze
  local frz_armr = AuxProp.new():declare_immunity(Hit.Freeze)
  entity:add_aux_prop(frz_armr)

  local red = Color.new(220, 80, 80)
  local black = Color.new(0, 0, 0)
  local fire_cd = 60
  local bigburn = 0
  local burst = 1
  local re_tile = entity:current_tile()
  local active = false
  local tick = 180

  -- handle color
  local component = entity:create_component(Lifetime.ActiveBattle)
  local sprite = entity:sprite()

  -- Handling the overhead sprite
  local head = entity:create_node()
  head:set_texture(TEXTURE)
  head:set_offset(0, -entity:height())
  head:set_layer(-1)
  -- Animator
  local anim = Animation.new()
  anim:load("burn.animation")
  anim:set_state("DEFAULT")
  anim:apply(head)
  anim:set_playback(Playback.Loop)

  local time = 32
  component.on_update_func = function()
    if entity:remaining_status_time(Hit.Flash) <= 0 then
      local progress = math.abs(time % 64 - 32) / 32
      time = time + 1

      sprite:set_color_mode(ColorMode.Add)

      local new_color = Color.mix(red, black, progress)
      new_color.a = entity:color().a
      sprite:set_color(new_color)
    end

    if bigburn >= 12 then
      anim:set_state("BIGGEST")
      anim:apply(head)
    elseif bigburn >= 9 then
      anim:set_state("BIGGER")
      anim:apply(head)
    elseif bigburn >= 6 then
      anim:set_state("BIG")
      anim:apply(head)
    elseif bigburn >= 3 then
      anim:set_state("SMALL")
      anim:apply(head)
    elseif bigburn < 3 then
      anim:set_state("DEFAULT")
      anim:apply(head)
    end

    if fire_cd <= 0 then
      active = false
      fire_cd = tick
    end

    if active == true then
      fire_cd = fire_cd - 1
    end

    if entity:remaining_status_time(Hit.BurnLDR) > 900 then
      bigburn = bigburn + 3
      status:set_remaining_time(900)
    end

    if bigburn >= 15 then
      Resources.play_audio(F_AUDIO)
      spawn_fire(entity, entity:get_tile(entity:facing(), 1), tick)
      spawn_fire(entity, entity:get_tile(entity:facing_away(), 1), tick)
      spawn_fire(entity, entity:get_tile(Direction.Up, 1), tick)
      spawn_fire(entity, entity:get_tile(Direction.Down, 1), tick)
      if burst > 0 then
        create_artifact(entity)
        entity:set_health(entity:health() - entity:max_health() // 20)
        burst = burst - 1
      end
      bigburn = 0
    end

    if entity:current_tile():state() == TileState.Ice then
      if entity:health() > 25 then
        entity:set_health(entity:health() - 25)
      else
        entity:set_health(1)
      end
      entity:current_tile():set_state(TileState.Sea)
    end
  end

  -- spawn_alert(entity) just so i have it incase I need it
  -- defense rule extend status and place fire on fire hit & to remove on aqua hit..
  local defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)

  defense_rule.filter_func = function(hit_props)
    if hit_props.flags & Hit.Drain ~= 0 then
      return hit_props
    end

    if hit_props.element == Element.Fire or hit_props.secondary_element == Element.Fire then
      bigburn = bigburn + 1
      status:set_remaining_time(math.max(300, entity:remaining_status_time(Hit.BurnLDR) + 90))

      if fire_cd >= tick or entity:current_tile() ~= re_tile then
        Resources.play_audio(F_AUDIO)
        spawn_fire(entity, entity:current_tile(), tick)
        re_tile = entity:current_tile()
        active = true
      end
    end

    if hit_props.element == Element.Aqua or hit_props.secondary_element == Element.Aqua then
      hit_props.damage = 0
      entity:apply_status(Hit.Blind, entity:remaining_status_time(Hit.BurnLDR))
      status:set_remaining_time(0)
    end

    -- remove freeze from flags, we ignore getting frozen.
    hit_props.flags = hit_props.flags & ~Hit.Freeze

    return hit_props
  end
  entity:add_defense_rule(defense_rule)

  local reup_aux_prop = AuxProp.new()
      :require_hit_flags(Hit.BurnLDR)
      :with_callback(function()
        bigburn = bigburn + 3
        local plus = math.max(300, entity:remaining_status_time(Hit.BurnLDR) + 180)
        status:set_remaining_time(plus)
      end)
  entity:add_aux_prop(reup_aux_prop)

  local drain_aux_prop = AuxProp.new()
      :require_interval(BURN_INTERVAL)
      :require_health(Compare.GT, 1)
      :drain_health(1)
  entity:add_aux_prop(drain_aux_prop)

  status.on_delete_func = function()
    component:eject()
    entity:sprite():remove_node(head)
    entity:remove_defense_rule(defense_rule)
    entity:remove_aux_prop(reup_aux_prop)
    entity:remove_aux_prop(drain_aux_prop)
    entity:remove_aux_prop(frz_armr)
  end
end

function spawn_fire(user, spawn_tile, tick)
  if not spawn_tile or spawn_tile:is_edge() or spawn_tile:team() ~= user:team() then return end

  local fire = Spell.new(Team.Other)
  fire:set_texture(FIRE_TEXTURE)

  local fire_anim = fire:animation()
  fire_anim:load(FIRE_ANIM_PATH)
  fire_anim:set_state("DEFAULT")
  fire_anim:set_playback(Playback.Loop)

  local props = HitProps.new(4, Hit.Drain | Hit.PierceGround | Hit.PierceInvis | Hit.RetainIntangible, Element.None)

  fire:set_facing(user:facing())
  fire:set_hit_props(props)

  -- attack on the first frame
  fire.on_spawn_func = function()
    fire:attack_tile()
  end

  local time = tick
  fire.on_update_func = function(self)
    if TurnGauge.frozen() == true then return end
    if time % 12 == 0 then self:current_tile():attack_entities(self) end
    if time <= 0 then self:delete() end
    time = time - 1
  end

  -- spawn the fire
  Field.spawn(fire, spawn_tile)
end

function create_artifact(user)
  local artifact = Artifact.new()
  artifact:set_texture(BOOM_TEXT)
  artifact:set_facing(user:facing())
  artifact:sprite():set_layer(-1)

  local anim = artifact:animation()
  anim:load("fire_tower.animation")
  anim:set_state("DEFAULT")
  anim:on_complete(function()
    artifact:erase()
  end)

  Field.spawn(artifact, user:current_tile())
end

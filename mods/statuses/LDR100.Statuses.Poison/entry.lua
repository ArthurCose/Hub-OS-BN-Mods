local bn_assets = require("BattleNetwork.Assets")
local TEXT = Resources.load_texture("pois.png")

local DRAIN_INTERVAL = 60

local function spawn_poi(parent)
  local artifact = Artifact.new()
  artifact:set_texture(TEXT)
  artifact:set_facing(parent:facing())
  artifact:sprite():set_layer(-1)

  local anim = artifact:animation()
  anim:load("pois.animation")
  anim:set_state("DEFAULT")
  anim:on_complete(function()
    artifact:erase()
  end)
  artifact:sprite():set_never_flip(true)

  local movement_offset = parent:movement_offset()
  artifact:set_offset(movement_offset.x, movement_offset.y - parent:height())

  Field.spawn(artifact, parent:current_tile())
end

function status_init(status)
  local entity = status:owner()
  local burst = entity:health()//20
  local bigburst = 0
  local popcd = 0

  local purp = Color.new(160, 0, 160)
  local black = Color.new(0, 0, 0)

  -- handle color
  local component = entity:create_component(Lifetime.ActiveBattle)
  local sprite = entity:sprite()
  local time = 32
  local on_pois = false

  component.on_update_func = function()
    if entity:remaining_status_time(Hit.Flash) <= 0 then
      local progress = math.abs(time % 64 - 32) / 32
      time = time + 1

      sprite:set_color_mode(ColorMode.Add)

      local new_color = Color.mix(purp, black, progress)
      new_color.a = entity:color().a
      sprite:set_color(new_color)
    end
    
    if entity:current_tile():state() == TileState.Poison then
      on_pois = true
    else
      on_pois = false
    end

    if popcd >= 1 then
      popcd = popcd - 1
    end
    
    if bigburst >= 3 then
      burst = entity:health()//40
      entity:set_health(math.min(entity:health() - 20, entity:health() - burst))
      bigburst = 0
    end

    if entity:remaining_status_time(Hit.PoisonLDR) > 900 and popcd <= 0 then 
      burst = entity:health()//40
      entity:set_health(entity:health() - burst)
      spawn_poi(entity)
      status:set_remaining_time(900)
      popcd = 45
    end
  end

  -- spawn_alert(entity) just so i have it incase I need it
  -- defense rule extend status and place fire on fire hit & to remove on aqua hit..
  local defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)

  defense_rule.filter_func = function(hit_props)
    if hit_props.flags & Hit.Drain ~= 0 then
      return hit_props
    end

    if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
      local remain = entity:remaining_status_time(Hit.PoisonLDR)
      status:set_remaining_time(remain + 120)
    end

    if hit_props.flags & Hit.PoisonLDR ~= 0 and popcd <= 0 then
      burst = entity:health()//20
      entity:set_health(math.min(entity:health() - 30, entity:health() - burst))
      spawn_poi(entity)
      if entity:remaining_status_time(Hit.PoisonLDR) < 360 then
        status:set_remaining_time(360)
      end
      popcd = 75
    end

    if on_pois then
      hit_props.damage = math.floor(hit_props.damage * 1.25)
    end

    return hit_props
  end
  
  entity:add_defense_rule(defense_rule)

  local drain_aux_prop = AuxProp.new()
        :require_interval(DRAIN_INTERVAL)
        :require_health(Compare.GT, 5)
        :drain_health(5)
        :with_callback(function() 
        bigburst = bigburst + 1
        end)
    entity:add_aux_prop(drain_aux_prop)

  status.on_delete_func = function()
    component:eject()
    entity:remove_defense_rule(defense_rule)
    entity:remove_aux_prop(drain_aux_prop)
  end
end
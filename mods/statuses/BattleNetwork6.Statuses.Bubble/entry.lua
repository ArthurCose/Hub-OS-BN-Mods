local TEXTURE = Resources.load_texture("bubble.png")
local SFX = Resources.load_audio("pop.ogg")

-- recycling animator
local animator = Animation.new()
animator:load("bubble.animation")

-- mashing helper
local inputs = {}

for _, value in pairs(Input.Pressed) do
  inputs[#inputs + 1] = value
end

local function is_mashing(entity)
  for _, value in ipairs(inputs) do
    if entity:input_has(value) then
      return true
    end
  end

  return false
end

local function spawn_alert(parent)
  local alert_artifact = Alert.new()
  alert_artifact:sprite():set_never_flip(true)

  local movement_offset = parent:movement_offset()
  alert_artifact:set_offset(movement_offset.x, movement_offset.y - parent:height())

  Field.spawn(alert_artifact, parent:current_tile())
end

local function spawn_pop(parent)
  Resources.play_audio(SFX)

  local artifact = Artifact.new()
  artifact:set_texture(TEXTURE)
  artifact:sprite():set_never_flip(true)

  local animator = artifact:animation()
  animator:load("bubble.animation")
  animator:set_state("STATUS_POP")
  animator:on_complete(function()
    artifact:erase()
  end)

  local parent_offset = parent:offset()

  if parent:facing() == Direction.Left then
    parent_offset.x = -parent_offset.x
  end

  local movement_offset = parent:movement_offset()
  artifact:set_offset(
    parent_offset.x + movement_offset.x,
    parent_offset.y + movement_offset.y - parent:height() * 0.5
  )

  Field.spawn(artifact, parent:current_tile())

  return artifact
end

---@param status Status
function status_init(status)
  Resources.play_audio(SFX)

  local entity = status:owner()
  local entity_animation = entity:animation()
  local sprite = entity:create_node()
  sprite:set_texture(TEXTURE)
  sprite:set_offset(0, -entity:height() / 2)
  sprite:set_layer(-1)

  if entity_animation:has_state("CHARACTER_HIT") then
    entity:cancel_actions()
    entity:cancel_movement()

    entity_animation:set_state("CHARACTER_HIT", { { 1, 1 } })
    entity_animation:on_complete(function()
      entity:set_idle()
    end)
  end

  local animator_state = "STATUS"
  local playback = Playback.Loop

  animator:set_state(animator_state)
  animator:apply(sprite)

  -- this component updates the bubble's animation and handles mashing
  local component = entity:create_component(Lifetime.ActiveBattle)
  local time = 0
  local last_added_elevation = 0

  component.on_update_func = function()
    sprite:set_offset(0, -entity:height() / 2)

    animator:set_state(animator_state)
    animator:set_playback(playback)
    animator:sync_time(time)
    animator:apply(sprite)

    -- calculate additional elevation
    local angle = time * (math.pi * 2) / 150;
    local added_elevation = -math.floor(math.sin(angle) * 6)

    -- subtract the last elevation addition
    entity:set_elevation(entity:elevation() - last_added_elevation + added_elevation)

    -- store the old elevation addition
    last_added_elevation = added_elevation

    time = time + 1

    if is_mashing(entity) then
      local remaining_time = status:remaining_time()
      status:set_remaining_time(remaining_time - 1)

      -- speed up animation
      time = time + 1
    end
  end

  -- defense rule to pop on hit and add Elec weakness
  local defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)

  defense_rule.filter_func = function(hit_props)
    if hit_props.flags & Hit.Drain ~= 0 then
      return hit_props
    end

    if hit_props.damage > 0 then
      status:set_remaining_time(0)
    end

    if hit_props.element == Element.Elec or hit_props.secondary_element == Element.Elec then
      hit_props.damage = hit_props.damage * 2

      spawn_alert(entity)
    end

    -- remove bubble from flags, we ignore getting bubbled again so we can pop out
    hit_props.flags = hit_props.flags & ~Hit.Bubble

    return hit_props
  end

  entity:add_defense_rule(defense_rule)

  -- clean up
  status.on_delete_func = function()
    entity:remove_defense_rule(defense_rule)
    entity:set_elevation(entity:elevation() - last_added_elevation)

    -- pop
    local artifact = spawn_pop(entity)

    -- remove sprites after the artifact spawns for a seamless pop
    artifact.on_spawn_func = function()
      entity:sprite():remove_node(sprite)
      component:eject()
    end
  end
end

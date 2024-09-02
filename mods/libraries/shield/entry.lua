local function spawn_particle(texture, animation_path, field, tile)
  if not texture or not animation_path then
    return
  end

  local artifact = Artifact.new()
  artifact:set_texture(texture)
  artifact:sprite():set_layer(-5)

  local animation = artifact:animation()
  animation:load(animation_path)
  animation:set_state("DEFAULT")
  animation:on_complete(function()
    artifact:erase()
  end)

  field:spawn(artifact, tile)

  return artifact
end

---@class Shield
local Shield = {}
Shield.__index = Shield

function Shield:set_execute_sfx(audio)
  self._execute_sfx = audio
end

--- If there's no shield texture set and no SHIELD state set on the player's animation,
--- the texture specified here will be used.
function Shield:set_default_shield_texture(texture)
  self._default_shield_texture = texture
end

--- If there's no shield texture set and no SHIELD state set on the player's animation,
--- the animation specified here will be used.
function Shield:set_default_shield_animation_path(animation_path)
  self._default_shield_animation_path = animation_path
end

function Shield:set_default_shield_animation_state(state)
  self._default_shield_animation_state = state
end

--- Specifies a shield texture that must be used.
function Shield:set_shield_texture(texture)
  self._shield_texture = texture
end

--- Specifies a shield animation that must be used.
function Shield:set_shield_animation_path(animation_path)
  self._shield_animation_path = animation_path
end

function Shield:set_shield_animation_state(state)
  self._shield_animation_state = state
end

function Shield:set_impact_texture(texture)
  self._impact_texture = texture
end

function Shield:set_impact_animation_path(animation_path)
  self._impact_animation_path = animation_path
end

function Shield:set_duration(duration)
  self._duration = duration
end

function Shield:duration()
  return self._duration
end

---@param self Shield
---@param user Entity
local function spawn_shield_artifact(self, user)
  local shield = Artifact.new()
  shield:set_facing(user:facing())

  local shield_sprite = shield:sprite()
  shield_sprite:set_layer(-1)

  shield_sprite:set_offset(Tile:width() / 2, 0)

  local shield_anim = shield:animation()

  local actor_animation = user:animation()

  if self._shield_texture then
    shield_sprite:set_texture(self._shield_texture)
    shield_anim:load(self._shield_animation_path)
    shield_anim:set_state(self._shield_animation_state or "DEFAULT")
  elseif actor_animation:has_state("SHIELD") then
    shield_sprite:set_texture(user:texture())
    shield_anim:copy_from(actor_animation)
    shield_anim:set_state("SHIELD")

    local palette = user:palette()

    if palette then
      shield_sprite:set_palette(palette)
    end
  else
    shield_sprite:set_texture(self._default_shield_texture)
    shield_anim:load(self._default_shield_animation_path)
    shield_anim:set_state(self._default_shield_animation_state or "DEFAULT")
  end

  shield.on_spawn_func = function()
    shield_anim:pause()
  end

  shield_anim:on_complete(function()
    shield:erase()
  end)

  user:field():spawn(shield, user:current_tile())

  return shield
end

---@param self Shield
---@param user Entity
local function spawn_impact_particle(self, user)
  local field = user:field()
  local tile = user:current_tile()
  local artifact = spawn_particle(self._impact_texture, self._impact_animation_path, field, tile)

  if not artifact then
    return
  end

  local sprite = artifact:sprite()
  local width = user:sprite():width()
  local height = user:height()

  sprite:set_offset(
    math.random(-width * .25, width * .25),
    math.random(-height * .75, -height * .25)
  )
end

---@param user Entity
---@param impact_callback? fun()
function Shield:create_action(user, impact_callback)
  local action = Action.new(user, "CHARACTER_IDLE")
  action:set_lockout(ActionLockout.new_animation())
  action:override_animation_frames({ { 1, self._duration } })

  local shield
  local defense_rule

  action.on_execute_func = function()
    if self._execute_sfx then
      Resources.play_audio(self._execute_sfx)
    end

    defense_rule = DefenseRule.new(DefensePriority.Action, DefenseOrder.CollisionOnly)

    defense_rule.defense_func = function(defense, _, _, props)
      if props.flags & Hit.PierceGuard ~= 0 then
        -- pierced
        user:remove_defense_rule(defense_rule)
        defense_rule = nil
        action:end_action()
        return
      end

      defense:block_damage()

      if defense:impact_blocked() or props.flags & Hit.Impact == 0 then
        -- non impact
        return
      end

      defense:block_impact()

      spawn_impact_particle(self, user)

      if impact_callback then
        impact_callback()
      end
    end

    user:add_defense_rule(defense_rule)

    shield = spawn_shield_artifact(self, user)
  end

  action.on_action_end_func = function()
    if shield then
      shield:animation():resume()
    end

    if defense_rule then
      user:remove_defense_rule(defense_rule)
    end
  end

  return action
end

---@class ShieldReflect
local ShieldReflect = {}
ShieldReflect.__index = ShieldReflect

function ShieldReflect:set_attack_texture(texture)
  self._attack_texture = texture
end

function ShieldReflect:set_attack_animation_path(animation_path)
  self._attack_animation_path = animation_path
end

---@param self ShieldReflect
local function spawn_reflect_attack_particle(self, field, tile)
  local artifact = spawn_particle(self._attack_texture, self._attack_animation_path, field, tile)

  if not artifact then
    return
  end

  artifact:set_offset(0, -tile:height() / 2)
end

---@param user Entity
---@param damage number
function ShieldReflect:spawn_spell(user, damage)
  local field = user:field()
  local direction = user:facing()

  local spell = Spell.new(user:team())
  spell:set_facing(direction)
  spell:set_hit_props(
    HitProps.new(
      damage,
      Hit.Impact,
      Element.None,
      user:context()
    )
  )

  local i = 0

  spell.on_update_func = function()
    i = i + 1

    if i % 2 == 1 then
      local tile = spell:current_tile()
      tile:attack_entities(spell)
      spawn_reflect_attack_particle(self, field, tile)
    else
      local next_tile = spell:get_tile(direction, 1)

      if next_tile then
        spell:teleport(next_tile)
      else
        spell:erase()
      end
    end
  end

  local tile = user:get_tile(direction, 1)

  if tile then
    field:spawn(spell, tile)
  end
end

---@class ShieldLib
local ShieldLib = {}

function ShieldLib.new_shield()
  ---@type Shield
  local shield = {}
  setmetatable(shield, Shield)

  shield:set_duration(1)

  return shield
end

function ShieldLib.new_reflect()
  ---@type ShieldReflect
  local reflect = {}
  setmetatable(reflect, ShieldReflect)

  return reflect
end

return ShieldLib

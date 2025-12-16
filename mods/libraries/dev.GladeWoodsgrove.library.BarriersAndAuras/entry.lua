---@class BarrierLib
local BarrierLib = {}
BarrierLib.__index = BarrierLib

---@alias dev.GladeWoodsgrove.library.BarriersAndAuras BarrierLib

local function debug_print(args)
  print("[BARRIER LIBRARY]" .. args)
end

local BarrierLibraryDefenseList = {}

function BarrierLib:entity_has_defense(entity, is_aura)
  if #BarrierLibraryDefenseList == 0 then return false end

  local entry = BarrierLibraryDefenseList[entity:id()]

  -- No defense found in the list, return false
  if entry == nil then return false end

  -- Doesn't matter if it's a barrier or aura, a defense is registered in the list so return true
  if is_aura == nil then return true end

  return entry[1] == true and entry[2] == is_aura
end

function BarrierLib:check_anim_exists(is_print_warning)
  if self._anim_path == nil then
    if is_print_warning then debug_print("Attempted to set animation behavior,\nbut no animation file was set!") end
    return false
  end
  return true
end

function BarrierLib:set_display_health(is_draw)
  self._is_draw_health = is_draw
end

-- Image that is added to the player when the defense is active.
-- If unset, there will be no image, but it will print a debug warning.
-- Use textures loaded by Resources.load_texture for better performance.
function BarrierLib:set_texture(texture)
  self._texture = texture
end

function BarrierLib:get_texture()
  return self._texture
end

-- Animation file that will be used to animate the barrier.
-- If unset, the barrier will remain static.
-- This will draw the entire sprite sheet, and so this will print a debug warning just in case.
function BarrierLib:set_animation_path(anim_path)
  self._anim_path = anim_path
end

function BarrierLib:get_animation_path()
  return self._anim_path
end

-- Sets the active state of the barrier
-- This is the default state for when the barrier is active.
function BarrierLib:set_active_state(state)
  if self:check_anim_exists(true) == false then return end
  self._active_state = state
end

function BarrierLib:get_active_state()
  return self._active_state
end

-- Set the state for the barrier fading naturally
-- Many barriers last a set amount of time, and will fade away if not destroyed by then.
-- Most barriers share this state with their "Destroyed" behavior.
function BarrierLib:set_fade_state(state)
  if self:check_anim_exists(true) == false then return end
  self._fade_state = state
end

function BarrierLib:set_destroyed_state(state)
  if self:check_anim_exists(true) == false then return end
  self._destroyed_state = state
end

function BarrierLib:set_destruction_sound(sound)
  self._destruction_sound = sound
end

function BarrierLib:get_destruction_sound()
  return self._destruction_sound
end

function BarrierLib:get_fade_state()
  return self._fade_state
end

function BarrierLib:get_destroyed_state()
  return self._destroyed_state
end

function BarrierLib:set_max_health(health)
  self._max_health = health
end

function BarrierLib:set_health(health)
  self._health = health
end

function BarrierLib:set_removal_timer(time)
  self._removal_timer = time
end

function BarrierLib:get_health()
  return self._health
end

function BarrierLib:get_max_health()
  return self._max_health
end

-- Sets whether you are creating a Barrier-type or an Aura-type.
-- Barrier-types are the default, and lose health on every hit. They are destroyed at 0 HP.
-- Aura-types must be enabled, and only take damage if the hit is greater than their health. However, they are destroyed immediately.
function BarrierLib:set_is_aura(is_aura)
  self._is_aura = is_aura

  if is_aura then
    self:set_default_defense_aura()
  else
    self:set_default_defense_barrier()
  end
end

function BarrierLib:is_aura()
  return self._is_aura or false
end

function BarrierLib:set_weakness_element(element_list)
  self._elemental_weakness = element_list
end

function BarrierLib:get_weakness_element()
  return self._elemental_weakness
end

---@param flags table
function BarrierLib:set_hit_flag_weakness(flags)
  self._hit_flag_weakness = flags
end

function BarrierLib:get_hit_flag_weakness()
  return self._hit_flag_weakness
end

function BarrierLib:set_blocks_damage_on_destruction(should_block)
  if type(should_block) ~= "boolean" then return end
  self._blocks_damage_on_destruction = should_block
end

function BarrierLib:blocks_damage_on_destruction()
  return self._blocks_damage_on_destruction
end

function BarrierLib:set_blocks_damage_on_weakness_hit(should_block)
  self._block_damage_despite_weakness = should_block
end

function BarrierLib:blocks_damage_on_weakness_hit()
  return self._block_damage_despite_weakness
end

---@param self BarrierLib
---@param hit_props HitProps
local function shared_weakness_check(self, hit_props)
  if self._health == 0 then return true end

  if self:check_weakness_hit(hit_props) then
    self._is_weakness_hit = true
    return true
  end

  if hit_props.flags & Hit.Drain ~= 0 then return true end

  return false
end

function BarrierLib:set_default_defense_barrier()
  self._defense_rule.defense_func = function(defense, attacker, defender, hit_props)
    if shared_weakness_check(self, hit_props) then
      if self:blocks_damage_on_weakness_hit() == true then defense:block_damage() end
      return
    end

    self._health = math.max(0, self._health - hit_props.damage)

    if self._health == 0 then
      self:do_destruction_removal()
      if self:blocks_damage_on_destruction() == true then defense:block_damage() end
      return
    end

    defense:block_damage()
  end
end

function BarrierLib:set_default_defense_aura()
  self._defense_rule.defense_func = function(defense, attacker, defender, hit_props)
    if shared_weakness_check(self, hit_props) then
      if self:blocks_damage_on_weakness_hit() == true then defense:block_damage() end
      return
    end

    if hit_props.damage >= self._health then
      self._health = 0
      self:do_destruction_removal()
      if self:blocks_damage_on_destruction() == true then defense:block_damage() end
      return
    end

    defense:block_damage()
  end
end

---@param hit_props HitProps
function BarrierLib:check_weakness_hit(hit_props)
  if self._hit_flag_weakness ~= nil then
    for i = 1, #self._hit_flag_weakness do
      local flag = self._hit_flag_weakness[i]

      if hit_props.flags & flag ~= 0 then
        return true
      end
    end
  end

  if self._elemental_weakness ~= nil then
    for i = 1, #self._elemental_weakness do
      local elem = self._elemental_weakness[i]

      if hit_props.element == elem or hit_props.secondary_element == elem then
        return true
      end
    end
  end

  return false
end

---@param self BarrierLib
function BarrierLib:setup(owner)
  self:set_entity_as_owner(owner)

  self:set_blocks_damage_on_destruction(true)
  self:set_blocks_damage_on_weakness_hit(true)

  self._defense_rule = DefenseRule.new(DefensePriority.Barrier, DefenseOrder.Always)

  self._is_fade = false
  self._is_weakness_hit = false
  self._block_damage_despite_weakness = false
  if self._regenerate_after_wait == nil then self._regenerate_after_wait = false end
end

function BarrierLib:enable_regeneration_timer(is_enabled)
  self._regenerate_after_wait = is_enabled
  self._barrier_regeneration_timer = 0

  self._regeneration_timer_component = self._owner:create_component(Lifetime.ActiveBattle)

  self._regeneration_timer_component.on_update_func = function()
    if self._health > 0 then return end
    if self._regenerate_after_wait == false then return end

    if self._is_draw_health then
      self._number_root:hide()
    end

    if self._barrier_regeneration_timer >= self._regenerate_barrier_after then
      self._barrier_node:reveal()

      if self._is_draw_health then
        self._number_root:reveal()
      end

      self:set_health(self:get_max_health())

      if self._regeneration_audio ~= nil then
        Resources.play_audio(self._regeneration_audio)
      end

      self._barrier_regeneration_timer = 0
    end

    self._barrier_regeneration_timer = self._barrier_regeneration_timer + 1
  end
end

function BarrierLib:set_regeneration_timer(time)
  self._regenerate_barrier_after = time
  self:enable_regeneration_timer(true)
end

function BarrierLib:set_regeneration_audio(audio)
  self._regeneration_audio = audio
end

function BarrierLib:setup_animation()
  local texture = self:get_texture()

  self._barrier_node = self._owner:create_node()
  self._barrier_node:set_layer(3)
  self._barrier_node:set_texture(texture)

  local anim = self:get_animation_path()

  self._barrier_animation = Animation.new(anim)

  self._barrier_animation:set_state(self._active_state)
  self._barrier_animation:set_playback(Playback.Loop)
  self._barrier_animation:apply(self._barrier_node)

  self._animation_component = self._owner:create_component(Lifetime.Battle)

  if self._is_draw_health then
    self._number_root = self._owner:create_node()
    self._number_root:set_never_flip(true)

    self._health_text = self._number_root:create_text_node(TextStyle.new("THICK"), tostring(self._health))
    self._health_text:set_color(Color.new(0, 0, 0, 255))
    self._health_text:set_offset(-2 * (#tostring(self._health)) - 1, 2)
    self._health_text:set_layer(-3)

    self._health_text._shadow = self._health_text:create_text_node(TextStyle.new("THICK"), tostring(self._health))
    self._health_text._shadow:set_offset(-1, -1)
  end

  self._animation_component.on_update_func = function()
    if self:check_needs_removal() then
      self:remove_barrier()
      return
    end

    if type(self._removal_timer) == "number" and TurnGauge.frozen() == false then
      self._removal_timer = self._removal_timer - 1
      if self._removal_timer == 0 then
        self._is_fade = true
        self:do_fade_removal()
        return
      end
    end

    self._barrier_animation:update()
    self._barrier_animation:apply(self._barrier_node)
  end

  self._destruction_handler_component = self._owner:create_component(Lifetime.Battle)

  self._defense_rule.on_replace_func = function()
    self:default_replace_behavior()
  end
end

function BarrierLib:default_replace_behavior()
  self._is_fade = false
  self._is_weakness_hit = false
  self:remove_barrier()
end

function BarrierLib:do_shared_removal()
  if self._regeneration_timer_component ~= nil then self._regeneration_timer_component:eject() end

  if self._is_draw_health then
    self._owner:sprite():remove_node(self._number_root)
  end

  self._animation_component:eject()
  self._destruction_handler_component:eject()
  self._owner:sprite():remove_node(self._barrier_node)
  self._owner:remove_defense_rule(self._defense_rule)

  BarrierLibraryDefenseList[self._owner:id()] = nil
end

function BarrierLib:do_destruction_removal()
  if self._destruction_sound ~= nil then
    Resources.play_audio(self._destruction_sound)
  end

  if self._destroyed_state ~= nil then
    self._barrier_animation:set_state(self._destroyed_state)
  end

  self._barrier_animation:on_complete(function()
    self._barrier_node:hide()
    self._barrier_animation:set_state(self._active_state)
    self._barrier_animation:set_playback(Playback.Loop)
    self._barrier_animation:apply(self._barrier_node)
  end)

  if self._regenerate_after_wait and not self._is_weakness_hit then return end

  self:do_shared_removal()
end

function BarrierLib:do_fade_removal()
  if self._fade_state ~= nil then
    self._barrier_animation:set_state(self._fade_state)
  end

  self:do_shared_removal()

  self._is_removing = true
end

function BarrierLib:check_needs_removal()
  if self._is_fade then return true end
  if self._is_weakness_hit then return true end
  if self._health == 0 and self._regenerate_after_wait == false then return true end

  return false
end

function BarrierLib:remove_barrier(is_force)
  -- Forced removal.
  if is_force == true then
    self:do_shared_removal()
    return
  end

  -- Already trying to remove, stop trying.
  if self._is_removing == true then return end

  if self._is_weakness_hit then
    self:do_destruction_removal()
  elseif self._is_fade then
    self:do_fade_removal()
  else
    self:do_shared_removal()
  end
end

function BarrierLib:add_to_owner(offset)
  self:setup_animation()
  self._owner:add_defense_rule(self._defense_rule)

  if not self._barrier_node:visible() then self._barrier_node:reveal() end

  if self._is_draw_health then
    self._health_text:reveal()
    self._health_text._shadow:reveal()
  end

  if offset ~= nil then
    self:set_barrier_offset(offset)
  end
end

function BarrierLib:set_entity_as_owner(entity)
  self._owner = entity
end

function BarrierLib:get_owner()
  return self._owner
end

function BarrierLib:set_barrier_offset(offset)
  self._barrier_node:set_offset(offset.x, offset.y)
end

function BarrierLib:get_barrier_offset()
  return self._barrier_node:offset()
end

function BarrierLib:get_defense_rule()
  return self._defense_rule
end

---@return BarrierLib
function BarrierLib.new_barrier(owner, health)
  local barrier = {}

  setmetatable(barrier, BarrierLib)

  barrier:set_health(health)
  barrier:set_max_health(health)
  barrier:setup(owner)
  barrier:set_is_aura(false)

  BarrierLibraryDefenseList[owner:id()] = { true, false }

  return barrier
end

function BarrierLib.new_aura(owner, health)
  local aura = {}

  setmetatable(aura, BarrierLib)

  aura:set_health(health)
  aura:set_max_health(health)
  aura:setup(owner)
  aura:set_is_aura(true)

  BarrierLibraryDefenseList[owner:id()] = { true, true }

  return aura
end

return BarrierLib

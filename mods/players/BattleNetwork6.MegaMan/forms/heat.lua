local bn_assets = require("BattleNetwork.Assets")

local flame_texture = bn_assets.load_texture("bn6_flame_thrower.png")
local flame_animation_path = bn_assets.fetch_animation_path("bn6_flame_thrower.animation")

local hit_texture = bn_assets.load_texture("bn6_hit_effects.png")
local hit_anim_path = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local FORM_TEXTURE = Resources.load_texture("heat.png")
local FORM_ANIMATION_PATH = _folder_path .. "heat.animation"
local FORM_EMOTIONS_TEXTURE = Resources.load_texture("heat_emotions.png")
local FORM_EMOTIONS_ANIMATION_PATH = _folder_path .. "heat_emotions.animation"
local FORM_MUG = _folder_path .. "heat_mug.png"

local function create_flame_spell(user, props)
  local tile
  local spell = Spell.new(user:team())

  local animation = spell:animation()

  spell:set_hit_props(
    HitProps.new(
      props.damage,
      props.hit_flags,
      props.element,
      props.secondary_element,
      user:context(),
      Drag.None
    )
  )

  spell:set_texture(flame_texture)

  animation:load(flame_animation_path)
  animation:set_state("0")
  animation:set_playback(Playback.Loop)

  spell:set_tile_highlight(Highlight.Solid)

  local sprite = spell:sprite()
  sprite:set_layer(-2)

  animation:apply(sprite)

  spell:set_facing(user:facing())

  spell.on_spawn_func = function(self)
    tile = self:current_tile()

    if tile:is_walkable() then
      if tile:state() == TileState.Cracked then
        tile:set_state(TileState.Broken)
      else
        tile:set_state(TileState.Cracked)
      end
    end
  end

  spell.on_collision_func = function(self, other)
    local fx = Spell.new(self:team())

    fx:set_texture(hit_texture)

    local anim = fx:animation()

    local fx_sprite = fx:sprite()

    anim:load(hit_anim_path)
    anim:set_state("FIRE")

    sprite:set_layer(-3)

    anim:apply(fx_sprite)
    anim:on_complete(function()
      fx:erase()
    end)

    self:field():spawn(fx, tile)
  end

  spell.on_update_func = function(self)
    self:current_tile():attack_entities(self)
  end
  return spell
end

local function charged_buster(user, props)
  local action = Action.new(user, "PLAYER_SHOOTING")
  local field = user:field()
  local tile_array = {}
  local AUDIO = Resources.load_audio("sfx.ogg")
  local frames = { { 1, 67 } }

  local flame1, flame2, flame3

  action:override_animation_frames(frames)
  action:set_lockout(ActionLockout.new_animation())
  action.on_execute_func = function(self, user)
    local self_tile = user:current_tile()
    local y = self_tile:y()
    local x = self_tile:x()
    local increment = 1
    if user:facing() == Direction.Left then increment = -1 end
    for i = 1, 3, 1 do
      local prospective_tile = field:tile_at(x + (i * increment), y)
      if prospective_tile and not prospective_tile:is_edge() then
        table.insert(tile_array, prospective_tile)
      end
    end

    local buster = self:create_attachment("BUSTER")
    local buster_sprite = buster:sprite()
    buster_sprite:set_texture(user:texture())
    buster_sprite:set_layer(-2)

    flame1 = create_flame_spell(user, props)
    flame2 = create_flame_spell(user, props)
    flame3 = create_flame_spell(user, props)

    local buster_anim = buster:animation()
    buster_anim:copy_from(user:animation())
    buster_anim:set_state("CHARGED_BUSTER")
    buster_anim:set_playback(Playback.Loop)

    local buster_point = user:animation():get_point("BUSTER")
    local origin = user:sprite():origin()
    local fire_x = buster_point.x - origin.x + 21 - Tile:width()
    local fire_y = buster_point.y - origin.y
    flame1:set_offset(fire_x, fire_y)
    flame2:set_offset(fire_x, fire_y)
    flame3:set_offset(fire_x, fire_y)

    -- spawn first flame
    Resources.play_audio(AUDIO)
    if #tile_array > 0 then
      field:spawn(flame1, tile_array[1])
    end

    local time = 0
    action.on_update_func = function()
      time = time + 1

      if time == 5 then
        if #tile_array > 1 then
          -- queue spawn frame 5, should appear frame 6
          field:spawn(flame2, tile_array[2])
        end
      elseif time == 9 then
        if #tile_array > 2 then
          -- queue spawn frame 9, should appear frame 10
          field:spawn(flame3, tile_array[3])
        end
      elseif time == 61 - 7 then
        if flame1:spawned() then
          flame1:animation():set_state("1")
          flame1:animation():apply(flame1:sprite())
          flame1:animation():on_complete(function()
            flame1:erase()
          end)
        end
      elseif time == 62 - 7 then
        if flame2:spawned() then
          flame2:animation():set_state("1")
          flame2:animation():apply(flame2:sprite())
          flame2:animation():on_complete(function()
            flame2:erase()
          end)
        end
      elseif time == 67 - 7 then
        if flame3:spawned() then
          flame3:animation():set_state("1")
          flame3:animation():apply(flame3:sprite())
          flame3:animation():on_complete(function()
            flame3:erase()
          end)
        end
      end
    end
  end

  action.on_action_end_func = function()
    if not flame1:deleted() then flame1:erase() end
    if not flame2:deleted() then flame2:erase() end
    if not flame3:deleted() then flame3:erase() end
  end

  return action
end

---@param player Entity
---@param form PlayerForm
---@param base_texture string
---@param base_animation_path string
return function(player, form, base_texture, base_animation_path)
  local base_element = player:element()
  local base_emotions_texture = player:emotions_texture()
  local base_emotions_animation_path = player:emotions_animation_path()
  local prev_emotion
  local prev_emotions_texture
  local prev_emotions_animation_path

  local fire_boost_aux_prop

  form:set_mugshot_texture(FORM_MUG)

  form.on_select_func = function()
    prev_emotion = player:emotion()
    prev_emotions_texture = player:emotions_texture()
    prev_emotions_animation_path = player:emotions_animation_path()

    player:set_emotions_texture(FORM_EMOTIONS_TEXTURE)
    player:load_emotions_animation(FORM_EMOTIONS_ANIMATION_PATH)
    player:set_emotion("DEFAULT")
  end

  form.on_deselect_func = function()
    player:set_emotions_texture(prev_emotions_texture)
    player:load_emotions_animation(prev_emotions_animation_path)
    player:set_emotion(prev_emotion)
  end

  form.on_activate_func = function()
    player:set_element(Element.Fire)
    player:set_texture(FORM_TEXTURE)
    player:load_animation(FORM_ANIMATION_PATH)

    fire_boost_aux_prop = AuxProp.new()
        :require_card_element(Element.Fire)
        :increase_card_damage(50)
    player:add_aux_prop(fire_boost_aux_prop)

    -- load emotions again in case we activated outside of card select
    player:set_emotions_texture(FORM_EMOTIONS_TEXTURE)
    player:load_emotions_animation(FORM_EMOTIONS_ANIMATION_PATH)
    player:set_emotion("DEFAULT")
  end

  form.on_deactivate_func = function()
    player:set_element(base_element)
    player:set_texture(base_texture)
    player:load_animation(base_animation_path)
    player:remove_aux_prop(fire_boost_aux_prop)
    player:set_emotions_texture(base_emotions_texture)
    player:load_emotions_animation(base_emotions_animation_path)
  end

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level() + 1)
  end

  form.charged_attack_func = function()
    local props = CardProperties.new()
    props.damage = player:attack_level() * 20 + 30
    props.element = Element.Fire
    props.hit_flags = Hit.Flinch | Hit.Flash | Hit.Impact
    return charged_buster(player, props)
  end

  local charge_timing = { 70, 60, 50, 45, 40 }
  form.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or 40
  end
end

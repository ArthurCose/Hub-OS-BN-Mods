local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FLAME_TEXTURE = bn_assets.load_texture("bn6_flame_thrower.png")
local FLAME_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_flame_thrower.animation")
local FLAME_SFX = bn_assets.load_audio("dragon4.ogg")

local FORM_MUG = _folder_path .. "mug.png"

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

  spell:set_texture(FLAME_TEXTURE)

  animation:load(FLAME_ANIMATION_PATH)
  animation:set_state("0")
  animation:set_playback(Playback.Loop)

  spell:set_tile_highlight(Highlight.Solid)

  local sprite = spell:sprite()
  sprite:set_layer(-2)

  animation:apply(sprite)

  spell:set_facing(user:facing())

  spell.on_collision_func = function(self, other)
    shared.spawn_hit_artifact(other, "FIRE", math.random(-8, 8), -other:height() // 2 + math.random(-8, 8))
  end

  spell.on_update_func = function(self)
    self:current_tile():attack_entities(self)
  end
  return spell
end

local function charged_buster(user, props)
  local action = Action.new(user, "CHARACTER_SHOOT")
  local tile_array = {}
  local frames = { { 1, 67 } }

  local flame1, flame2, flame3

  action:override_animation_frames(frames)
  action:set_lockout(ActionLockout.new_animation())
  action.on_execute_func = function(self, user)
    user:set_counterable(true)

    local self_tile = user:current_tile()
    local y = self_tile:y()
    local x = self_tile:x()
    local increment = 1
    if user:facing() == Direction.Left then increment = -1 end
    for i = 1, 3, 1 do
      local prospective_tile = Field.tile_at(x + (i * increment), y)
      if prospective_tile and not prospective_tile:is_edge() then
        table.insert(tile_array, prospective_tile)
      end
    end

    local buster = self:create_attachment("BUSTER")
    local buster_sprite = buster:sprite()
    buster_sprite:set_texture(user:texture())
    buster_sprite:set_layer(-2)
    buster_sprite:use_root_shader()

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
    Resources.play_audio(FLAME_SFX)

    if #tile_array > 0 then
      Field.spawn(flame1, tile_array[1])
    end

    local time = 0
    action.on_update_func = function()
      time = time + 1

      if time % 20 == 0 then
        Resources.play_audio(FLAME_SFX)
      end

      if time == 5 then
        if #tile_array > 1 then
          -- queue spawn frame 5, should appear frame 6
          Field.spawn(flame2, tile_array[2])
        end
      elseif time == 9 then
        if #tile_array > 2 then
          -- queue spawn frame 9, should appear frame 10
          Field.spawn(flame3, tile_array[3])
        end
      elseif time == 61 - 7 then
        if flame1:spawned() then
          flame1:animation():set_state("1")
          flame1:animation():apply(flame1:sprite())
          flame1:animation():on_complete(function()
            flame1:erase()
          end)
        end
      elseif time == 16 then
        user:set_counterable(false)
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
    user:set_counterable(false)
    if not flame1:deleted() then flame1:erase() end
    if not flame2:deleted() then flame2:erase() end
    if not flame3:deleted() then flame3:erase() end
  end

  return action
end

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local fire_boost_aux_prop

  shared.implement_form(player, form, {
    base_animation_path = base_animation_path,
    folder_path = _folder_path,
    element = Element.Fire,
    charge_timing = { 70, 60, 50, 45, 40 },
    activate_callback = function()
      fire_boost_aux_prop = AuxProp.new()
          :require_card_element(Element.Fire)
          :require_card_time_freeze(false)
          :increase_card_damage(50)
      player:add_aux_prop(fire_boost_aux_prop)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(fire_boost_aux_prop)
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level() + 1)
  end

  form.charged_attack_func = function()
    local props = CardProperties.new()
    props.damage = player:attack_level() * 20 + 30
    props.element = Element.Fire
    props.hit_flags = Hit.Flinch | Hit.Flash
    return charged_buster(player, props)
  end
end

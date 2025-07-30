local bn_assets = require("BattleNetwork.Assets")

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local Shared = {}

---@class _BattleNetwork6.GregarMegaman.FormConfig
---@field base_animation_path string
---@field folder_path string
---@field element Element
---@field charge_timing number[]
---@field activate_callback fun()?
---@field deactivate_callback fun()?

---@param player Entity
---@param form PlayerForm
---@param config _BattleNetwork6.GregarMegaman.FormConfig
function Shared.implement_form(player, form, config)
  -- form assets
  local form_texture = Resources.load_texture(config.folder_path .. "battle.png")
  local form_animation_path = config.folder_path .. "battle.animation"
  local form_emotions_texture = Resources.load_texture(config.folder_path .. "emotions.png")
  local form_emotions_animation_path = config.folder_path .. "emotions.animation"

  -- resolve base assets to restore on deactivate
  local base_element = player:element()
  local base_texture = player:texture()
  local base_emotions_texture = player:emotions_texture()
  local base_emotions_animation_path = player:emotions_animation_path()

  -- storage for restoring emotions on deselect
  local prev_emotion
  local prev_emotions_texture
  local prev_emotions_animation_path

  local decross_auxprop

  form.on_select_func = function()
    prev_emotion = player:emotion()
    prev_emotions_texture = player:emotions_texture()
    prev_emotions_animation_path = player:emotions_animation_path()

    player:set_emotions_texture(form_emotions_texture)
    player:load_emotions_animation(form_emotions_animation_path)
    player:set_emotion("DEFAULT")
  end

  form.on_deselect_func = function()
    player:set_emotions_texture(prev_emotions_texture)
    player:load_emotions_animation(prev_emotions_animation_path)
    player:set_emotion(prev_emotion)
  end

  form.on_activate_func = function()
    player:set_element(config.element)
    player:set_texture(form_texture)
    player:load_animation(form_animation_path)

    -- load emotions again in case we activated outside of card select
    player:set_emotions_texture(form_emotions_texture)
    player:load_emotions_animation(form_emotions_animation_path)
    player:set_emotion("DEFAULT")

    -- handle decross
    decross_auxprop = AuxProp.new()
        :require_hit_element_is_weakness()
        :with_callback(function()
          form:deactivate()
        end)
        :once()

    player:add_aux_prop(decross_auxprop)

    if config.activate_callback then
      config.activate_callback()
    end
  end

  form.on_deactivate_func = function()
    player:set_element(base_element)
    player:set_texture(base_texture)
    player:load_animation(config.base_animation_path)
    player:set_emotions_texture(base_emotions_texture)
    player:load_emotions_animation(base_emotions_animation_path)
    player:remove_aux_prop(decross_auxprop)

    if config.deactivate_callback then
      config.deactivate_callback()
    end
  end

  form.calculate_charge_time_func = function()
    return config.charge_timing[player:charge_level()] or config.charge_timing[#config.charge_timing]
  end
end

---@param character Entity
---@param state string
---@param offset_x number
---@param offset_y number
function Shared.spawn_hit_artifact(character, state, offset_x, offset_y)
  local artifact = Artifact.new()
  artifact:set_facing(Direction.Right)
  artifact:set_never_flip()
  artifact:set_texture(HIT_TEXTURE)

  artifact:load_animation(HIT_ANIMATION_PATH)
  local anim = artifact:animation()
  anim:set_state(state)
  anim:apply(artifact:sprite())

  anim:on_complete(function()
    artifact:erase()
  end)

  local movement_offset = character:movement_offset()
  artifact:set_offset(
    movement_offset.x + offset_x,
    movement_offset.y + offset_y
  )

  character:field():spawn(artifact, character:current_tile())
end

return Shared

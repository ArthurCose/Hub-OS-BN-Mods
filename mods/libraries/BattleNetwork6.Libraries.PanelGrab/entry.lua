---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local TEXTURE = bn_assets.load_texture("panelgrab.png")
local ANIMATION_PATH = bn_assets.fetch_animation_path("panelgrab.animation")
local START_SFX = bn_assets.load_audio("panelgrab1.ogg")
local END_SFX = bn_assets.load_audio("panelgrab2.ogg")


---@class PanelGrabOptions
---@field claim boolean?

---@param team Team
---@param direction Direction
---@param options PanelGrabOptions?
local function create_spell(team, direction, options)
  local spell = Spell.new(team)
  spell:set_facing(direction)
  spell:set_texture(TEXTURE)
  spell:set_hit_props(HitProps.new(10, Hit.Flinch | Hit.PierceGround, Element.None))

  local animation = spell:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state("FALL")
  animation:set_playback(Playback.Loop)

  local SPEED = 8
  local y = -20 * 8

  spell.on_spawn_func = function()
    Resources.play_audio(START_SFX, AudioBehavior.NoOverlap)
  end

  spell.on_update_func = function()
    y = y + SPEED

    spell:set_offset(0, y)

    if y < 0 then
      return
    end

    spell.on_update_func = nil
    animation:set_state("GRAB")
    animation:on_complete(function()
      spell:delete()
    end)

    if not options or options.claim ~= false then
      -- only claim if options.claim is not explicitly set to false
      spell:current_tile():set_team(team, direction)
    end

    spell:attack_tile()

    Resources.play_audio(END_SFX, AudioBehavior.NoOverlap)
  end

  return spell
end

---@class BattleNetwork6.Libraries.PanelGrab
local Lib = {
  create_spell = create_spell
}

return Lib

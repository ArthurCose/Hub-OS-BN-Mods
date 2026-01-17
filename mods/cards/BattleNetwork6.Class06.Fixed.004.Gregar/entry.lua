---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local ERASE_BEAM_TEXTURE = bn_assets.load_texture("erase_beam.png")
local ERASE_BEAM_ANIM_PATH = bn_assets.fetch_animation_path("erase_beam.animation")

local ATTACK_AUDIO = bn_assets.load_audio("shock.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 30 + user:attack_level() * 20
end

local function create_beam_spell()
  local spell = Spell.new()
  spell:set_texture(ERASE_BEAM_TEXTURE)

  local animation = spell:animation()
  animation:load(ERASE_BEAM_ANIM_PATH)
  animation:set_state("FORWARD")
  animation:set_playback(Playback.Loop)

  local remaining_time = 50
  spell.on_update_func = function()
    spell:attack_tile()

    remaining_time = remaining_time - 1

    if remaining_time <= 0 then
      spell:delete()
    end
  end

  spell.on_attack_func = function(_, other)
    local particle = bn_assets.HitParticle.new("ELEC")

    local movement_offset = other:movement_offset()
    particle:set_offset(
      movement_offset.x + math.random(-16, 16),
      movement_offset.y + math.random(-16, 16) - other:height() // 2
    )

    Field.spawn(particle, spell:current_tile())
  end

  return spell
end

---@param user Entity
---@param props CardProperties
local function spawn_beam(user, props)
  local hit_props = HitProps.from_card(props, user:context())
  local tile = user:get_tile(user:facing(), 1)

  while tile do
    local spell = create_beam_spell()
    spell:set_team(user:team())
    spell:set_facing(user:facing())
    spell:set_hit_props(hit_props)
    spell:set_elevation(38)
    Field.spawn(spell, tile)

    tile = tile:get_tile(user:facing(), 1)
  end
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "BEAM_START")
  action:set_lockout(ActionLockout.new_sequence())

  local startup_step = action:create_step()

  local remaining_wait_time = 80
  local wait_step = action:create_step()
  wait_step.on_update_func = function()
    remaining_wait_time = remaining_wait_time - 1

    if remaining_wait_time <= 0 then
      wait_step:complete_step()
    end
  end

  action.on_execute_func = function()
    user:set_counterable(true)

    local animation = user:animation()
    animation:on_complete(function()
      user:set_counterable(false)

      startup_step:complete_step()
      animation:set_state("BEAM")
      spawn_beam(user, props)

      Resources.play_audio(ATTACK_AUDIO)
    end)
  end

  action.on_action_end_func = function()
    user:set_counterable(false)
  end

  return action
end

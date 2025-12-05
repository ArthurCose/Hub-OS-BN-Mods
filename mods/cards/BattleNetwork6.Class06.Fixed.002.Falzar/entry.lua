---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TOMAHAWK_TEXTURE = Resources.load_texture("tomahawk.png")
local TOMAHAWK_ANIM_PATH = "tomahawk.animation"

local ARTIFACT_TEXTURE = bn_assets.load_texture("golmhit_artifact.png")
local ARTIFACT_ANIMATION_PATH = bn_assets.fetch_animation_path("golmhit_artifact.animation")

-- not the correct sound
local SFX = bn_assets.load_audio("thawk_swing.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 100 + user:attack_level() * 30
end

local function create_spell(team, direction, hit_props)
  local spell = Spell.new(team)
  spell:set_hit_props(hit_props)
  spell:set_texture(ARTIFACT_TEXTURE)
  spell:sprite():set_layer(-3)

  local animation = spell:animation()
  animation:load(ARTIFACT_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:on_complete(function()
    spell:erase()
  end)

  animation:on_frame(2, function()
    local tile = spell:get_tile(direction, 1)

    if tile then
      local spell = create_spell(team, direction, hit_props)
      Field.spawn(spell, tile)
    end
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
    local tile = spell:current_tile()
    tile:set_state(TileState.Cracked)
    tile:set_state(TileState.Broken)
  end

  return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "EAGLE_TOMAHAWK")

  local sync_node

  action.on_execute_func = function()
    user:set_counterable(true)

    local animation = user:animation()
    animation:set_state("EAGLE_TOMAHAWK")

    sync_node = user:create_sync_node()
    sync_node:sprite():set_texture(TOMAHAWK_TEXTURE)
    sync_node:animation():load(TOMAHAWK_ANIM_PATH)
  end

  action:on_anim_frame(4, function()
    user:set_counterable(false)
  end)

  action:on_anim_frame(9, function()
    Field.shake(3, 30)

    local tile = user:get_tile(user:facing(), 1)

    if tile then
      local spell = create_spell(
        user:team(),
        user:facing(),
        HitProps.from_card(props, user:context())
      )
      Field.spawn(spell, tile)
    end

    Resources.play_audio(SFX)
  end)

  action.on_action_end_func = function()
    user:set_counterable(false)

    if sync_node then
      user:remove_sync_node(sync_node)
    end
  end

  return action
end

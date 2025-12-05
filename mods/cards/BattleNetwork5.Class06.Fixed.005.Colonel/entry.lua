---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local MACE_TEXTURE = bn_assets.load_texture("navi_knightman_mace.png")
local MACE_ANIM_PATH = bn_assets.fetch_animation_path("navi_knightman_mace.animation")

local LAUNCH_SFX = bn_assets.load_audio("canguard.ogg") -- is this correct?

---@param user Entity
function card_dynamic_damage(user)
  return 70 + user:attack_level() * 10
end

---@param user Entity
function card_init(user, props)
  local action = Action.new(user, "KINGDOM_CRUSHER")
  action:override_animation_frames({ { 1, 1 }, { 2, 3 }, { 3, 50 } })
  action:set_lockout(ActionLockout:new_sequence())
  action:create_step()

  action.on_execute_func = function()
    local animation = user:animation()
    animation:on_complete(function()
      animation:set_state("KINGDOM_CRUSHER_END")
      animation:on_complete(function()
        action:end_action()
      end)
    end)

    Resources.play_audio(LAUNCH_SFX)

    local tile = user:get_tile(user:facing(), 1)

    if tile then
      local spell = Spell.new(user:team())
      spell:set_facing(user:facing())
      spell:set_elevation(41)
      spell:set_hit_props(
        HitProps.from_card(props, user:context())
      )
      spell:set_tile_highlight(Highlight.Solid)

      spell:set_texture(MACE_TEXTURE)
      local spell_anim = spell:animation()
      spell_anim:load(MACE_ANIM_PATH)
      spell_anim:set_state("DEFAULT")

      spell.on_update_func = function()
        spell:attack_tile()

        if spell:is_moving() then
          return
        end

        local next_tile = spell:get_tile(spell:facing(), 1)

        if not next_tile then
          spell:delete()
        end

        spell:slide(next_tile, 8)
      end

      Field.spawn(spell, tile)
    end
  end

  action:on_anim_frame(2, function()
    local poof = bn_assets.ParticlePoof.new()
    local offset_x = 39
    local offset_y = -41

    if user:facing() == Direction.Left then
      offset_x = -offset_x
    end

    poof:set_offset(offset_x, offset_y)

    Field.spawn(poof, user:current_tile())
  end)

  return action
end

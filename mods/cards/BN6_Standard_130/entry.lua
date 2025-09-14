---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local METEOR_SFX = bn_assets.load_audio("meteor_land.ogg")
local EXPLOSION_SFX = bn_assets.load_audio("explosion_defeatedboss.ogg")

local FIST_TEXTURE = bn_assets.load_texture("duo_fist.png")
local FIST_ANIM_PATH = bn_assets.fetch_animation_path("duo_fist.animation")

local RING_EXPLOSION_TEXTURE = bn_assets.load_texture("ring_explosion.png")
local RING_EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")

local EXPLOSION_TEXTURE = bn_assets.load_texture("spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("spell_explosion.animation")

local function create_explosion(team)
  local spell = Spell.new(team)
  spell:set_texture(EXPLOSION_TEXTURE)
  spell:set_hit_props(HitProps.new(100, Hit.Flinch | Hit.Flash, Element.None))

  local animation = spell:animation()
  animation:load(EXPLOSION_ANIM_PATH)
  animation:set_state("DEFAULT")
  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
  end

  return spell
end

---@param user Entity
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_async(20))

  action.on_execute_func = function()
    local spawn_tile

    if user:facing() == Direction.Right then
      spawn_tile = Field.tile_at(Field.width() - 3, Field.height() // 2)
    else
      spawn_tile = Field.tile_at(2, Field.height() // 2)
    end

    if not spawn_tile then
      return
    end

    local team = user:team()

    local spell = Spell.new(team)
    spell:set_facing(user:facing())
    spell:set_hit_props(HitProps.from_card(props))
    spell:set_texture(FIST_TEXTURE)

    local animation = spell:animation()
    animation:load(FIST_ANIM_PATH)
    animation:set_state("DEFAULT")

    Resources.play_audio(METEOR_SFX)

    local time = 16
    spell.on_update_func = function()
      time = time - 1

      local x_offset = time * -16

      if spell:facing() == Direction.Left then
        x_offset = -x_offset
      end

      spell:set_offset(x_offset, time * -16)

      if time >= 0 then
        return
      end

      Resources.play_audio(EXPLOSION_SFX)
      spell:attack_tile()
      Field.shake(12, 40)

      spell.on_update_func = nil

      spell:set_texture(RING_EXPLOSION_TEXTURE)
      animation:load(RING_EXPLOSION_ANIM_PATH)
      animation:set_state("DEFAULT")
      animation:on_complete(function()
        spell:delete()
      end)

      local spell_tile = spell:current_tile()
      local center_x = spell_tile:x()
      local center_y = spell_tile:y()

      for x = center_x - 1, center_x + 1 do
        for y = center_y - 1, center_y + 1 do
          local tile = Field.tile_at(x, y)

          if not tile or tile:is_edge() then
            goto continue
          end

          if tile:state() == TileState.Cracked then
            tile:set_state(TileState.Broken)
          else
            tile:set_state(TileState.Cracked)
          end

          if tile ~= spell_tile then
            local explosion = create_explosion(team)
            Field.spawn(explosion, tile)
          end

          ::continue::
        end
      end
    end

    Field.spawn(spell, spawn_tile)
  end

  return action
end

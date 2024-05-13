---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

---@class SeedBomb
---@field private _bomb Bomb
---@field private _element Element
---@field private _tile_state TileState
---@field private _tile_texture string
---@field private _tile_animation_path string
---@field private _tile_animation_state string
---@field private _tile_sfx string
local SeedBomb = {}
SeedBomb.__index = SeedBomb

function SeedBomb:bomb()
  return self._bomb
end

---@param tile_state TileState
function SeedBomb:set_tile_state(tile_state)
  self._tile_state = tile_state
end

---@param texture string
function SeedBomb:set_tile_change_texture(texture)
  self._tile_texture = texture
end

---@param path string
function SeedBomb:set_tile_change_animation_path(path)
  self._tile_animation_path = path
end

---@param state string
function SeedBomb:set_tile_change_animation_state(state)
  self._tile_animation_state = state
end

---@param sfx string
function SeedBomb:set_tile_change_sfx(sfx)
  self._tile_sfx = sfx
end

function SeedBomb:create_panel_change_spell()
  local spell = Spell.new()
  spell:set_texture(self._tile_texture)
  spell:sprite():set_layer(5)

  local animation = spell:animation()
  animation:load(self._tile_animation_path)
  animation:set_state(self._tile_animation_state)
  animation:on_complete(function()
    spell:erase()
  end)

  spell.on_spawn_func = function()
    local tile = spell:current_tile()
    tile:set_state(self._tile_state)
  end

  return spell
end

---@param user Entity
---@param props CardProperties
function SeedBomb:create_action(user, props)
  local field = user:field()

  return self._bomb:create_action(user, function(tile)
    if not tile or not tile:is_walkable() then
      return
    end

    local spell = Spell.new(user:team())
    spell:set_facing(user:facing())
    spell:set_hit_props(
      HitProps.new(
        10,
        props.hit_flags,
        props.element,
        props.secondary_element,
        user:context(),
        Drag.None
      )
    )

    spell.on_collision_func = function()
      Resources.play_audio(self._tile_sfx)
      field:spawn(self:create_panel_change_spell(), tile)
      spell:erase()
    end

    local first_frame = true
    spell.on_update_func = function()
      if first_frame then
        spell:attack_tile()
        first_frame = false
        return
      end

      for y = tile:y() - 1, tile:y() + 1 do
        for x = tile:x() - 1, tile:x() + 1 do
          local tile = field:tile_at(x, y)

          if tile and tile:can_set_state(self._tile_state) then
            field:spawn(self:create_panel_change_spell(), tile)
          end
        end
      end

      Resources.play_audio(self._tile_sfx)
      spell:erase()
    end

    field:spawn(spell, tile)
  end)
end

---@class SeedBombLib
local Lib = {}

---@return SeedBomb
function Lib.new_seed_bomb()
  local seedbomb = {
    _bomb = BombLib.new_bomb()
  }
  setmetatable(seedbomb, SeedBomb)

  return seedbomb
end

return Lib

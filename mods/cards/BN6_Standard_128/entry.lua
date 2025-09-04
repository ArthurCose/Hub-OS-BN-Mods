local bn_assets = require("BattleNetwork.Assets")

local ARTIFACT_TEXTURE = bn_assets.load_texture("golmhit_artifact.png")
local ARTIFACT_ANIMATION_PATH = bn_assets.fetch_animation_path("golmhit_artifact.animation")
local TEXTURE = Resources.load_texture("fist.png")
local ANIMATION_PATH = _folder_path .. "fist.animation"
local SPAWN_SFX = bn_assets.load_audio("golmhit1.ogg")
local LAND_SFX = bn_assets.load_audio("golmhit2.ogg")

local GHOST_COLOR = Color.new(250, 30, 230)

local function create_ghost(direction, state)
  local ghost = Artifact.new()
  ghost:set_facing(direction)
  ghost:set_texture(TEXTURE)

  local animation = ghost:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state(state)

  local sprite = ghost:sprite()
  sprite:set_layer(-2)

  ghost.on_spawn_func = function()
    -- weird engine quirk (as of writing)
    -- non Local components will update even if the entity isn't spawned

    local component = ghost:create_component(Lifetime.Scene)
    local time = 0

    component.on_update_func = function()
      sprite:set_visible(math.floor(time / 2) % 2 == 0)
      sprite:set_shader_effect(SpriteShaderEffect.Grayscale)
      sprite:set_color_mode(ColorMode.Multiply)
      sprite:set_color(GHOST_COLOR)
      time = time + 1

      if time >= 12 then
        ghost:erase()
      end
    end
  end

  return ghost
end

---@param spell Entity
---@param tile Tile
local function spawn_tile_hit_artifact(spell, tile)
  if not tile:is_walkable() then
    return
  end

  -- spawn artifact
  local artifact = Artifact.new()
  artifact:set_texture(ARTIFACT_TEXTURE)
  artifact:sprite():set_layer(-3)

  local animation = artifact:animation()
  animation:load(ARTIFACT_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:on_complete(function()
    artifact:erase()
  end)

  Field.spawn(artifact, tile)
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_async(20))

  action.on_execute_func = function()
    local direction = user:facing()
    ---@type Tile?
    local tile = user:current_tile()

    while tile and tile:team() == user:team() do
      tile = tile:get_tile(direction, 1)
    end

    if not tile then
      -- can't spawn the spell
      return
    end

    local spell = Spell.new(user:team())
    spell:set_facing(user:facing())
    spell:set_texture(TEXTURE)
    spell:set_hit_props(HitProps.from_card(props, user:context()))

    local can_attack = false

    ---@type (Tile|nil)[]
    local side_tiles

    local animation = spell:animation()
    animation:load(ANIMATION_PATH)
    animation:set_state("DEFAULT")

    animation:on_frame(2, function()
      Field.spawn(create_ghost(direction, "ARTIFACT_2"), spell:current_tile())
    end)

    animation:on_frame(3, function()
      if not spell:current_tile():is_walkable() then
        return
      end

      -- spawn artifacts
      for _, tile in ipairs(side_tiles) do
        if tile then
          spawn_tile_hit_artifact(spell, tile)
        end
      end

      spawn_tile_hit_artifact(spell, spell:current_tile())
    end)

    animation:on_frame(4, function()
      Resources.play_audio(LAND_SFX)
      Field.shake(3, 30)

      for _, tile in ipairs(side_tiles) do
        if tile and tile:is_walkable() then
          spell:attack_tile(tile)
        end
      end

      can_attack = true
    end)

    animation:on_complete(function()
      spell:erase()
    end)

    spell.on_spawn_func = function()
      side_tiles = {
        spell:get_tile(Direction.Up, 1),
        spell:get_tile(Direction.Down, 1)
      }

      Field.spawn(create_ghost(direction, "ARTIFACT_1"), spell:current_tile())
      Resources.play_audio(SPAWN_SFX)
    end

    spell.on_update_func = function()
      if not can_attack then
        for _, tile in ipairs(side_tiles) do
          if tile then
            tile:set_highlight(Highlight.Solid)
          end
        end
      end

      spell:current_tile():set_highlight(Highlight.Solid)

      if can_attack then
        spell:attack_tile()
      end
    end

    Field.spawn(spell, tile)
  end

  return action
end

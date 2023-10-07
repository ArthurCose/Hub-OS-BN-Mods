local TEXTURE = Resources.load_texture("uninstall.png")

local function spawn_artifact(parent)
  local artifact = Artifact.new()
  artifact:set_texture(TEXTURE)
  artifact:sprite():set_never_flip(true)

  local animator = artifact:animation()
  animator:load("uninstall.animation")
  animator:set_state("DEFAULT")
  animator:on_complete(function()
    artifact:erase()
  end)

  local parent_offset = parent:offset()

  if parent:facing() == Direction.Left then
    parent_offset.x = -parent_offset.x
  end

  local tile_offset = parent:tile_offset()
  artifact:set_offset(
    parent_offset.x + tile_offset.x,
    parent_offset.y + tile_offset.y - parent:height() * 0.5
  )

  parent:field():spawn(artifact, parent:current_tile())

  return artifact
end

function status_init(status)
  local entity = status:owner()
  spawn_artifact(entity)

  if not Player.from(entity) then
    return
  end

  for _, augment in ipairs(entity:augments()) do
    if augment:has_tag("FLAT_BLOCK") then
      entity:boost_augment(augment:id(), -augment:level())
    end
  end
end

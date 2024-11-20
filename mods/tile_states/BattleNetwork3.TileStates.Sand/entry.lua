---@param custom_state CustomTileState
function tile_state_init(custom_state)
  local field = custom_state:field()
  custom_state.on_entity_stop_func = function(self, entity, prev_tile)
    if entity:ignoring_negative_tile_effects() then return end

    entity:apply_status(Hit.Root, 20)

    local artifact = Artifact.new()
    artifact:set_texture("poof.png")
    artifact:set_never_flip(true)

    local artifact_animation = artifact:animation()
    artifact_animation:load("poof.animation")
    artifact_animation:set_state("DEFAULT")
    artifact_animation:on_complete(function()
      artifact:delete()
    end)

    field:spawn(artifact, entity:current_tile())
  end
end

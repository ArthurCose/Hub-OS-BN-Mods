---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local break_buster = AuxProp.new()
      :require_action(ActionType.Normal)
      :update_context(function(context)
        context.flags = context.flags & ~Hit.mutual_exclusions_for(Hit.PierceGuard) | Hit.PierceGuard
        return context
      end)

  player:add_aux_prop(break_buster)

  augment.on_delete_func = function()
    player:remove_aux_prop(break_buster)
  end
end

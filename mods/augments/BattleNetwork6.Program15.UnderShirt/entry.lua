function augment_init(augment)
  local entity = augment:owner()

  local aux_prop = AuxProp.new()
      :require_total_damage(Compare.GT, 0)
      :decrease_total_damage("DAMAGE - clamp(DAMAGE, 1, HEALTH - 1)")

  entity:add_aux_prop(aux_prop)

  augment.on_delete_func = function()
    entity:remove_aux_prop(aux_prop)
  end
end

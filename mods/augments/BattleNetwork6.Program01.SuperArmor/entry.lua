---@param augment Augment
function augment_init(augment)
	local player = augment:owner()

	local super_armor = AuxProp.new():declare_immunity(Hit.Flinch)
	player:add_aux_prop(super_armor)

	augment.on_delete_func = function()
		player:remove_aux_prop(super_armor)
	end
end

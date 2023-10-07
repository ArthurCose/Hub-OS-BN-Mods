local init_conveyor = require("BattleNetwork6.Libraries.Conveyor")

---@param custom_state CustomTileState
function tile_state_init(custom_state)
  init_conveyor(custom_state, Direction.Down)
end

---@type dev.konstinople.library.stage_augment
local StageAugmentLib = require("dev.konstinople.library.stage_augment")

---@param augment Augment
function augment_init(augment)
  StageAugmentLib.set_stage(augment:owner(), function(tile)
    tile:set_state(TileState.Sand)
  end)
end

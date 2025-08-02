---@param augment Augment
function augment_init(augment)
  local state = TileState.Holy

  local player = augment:owner()
  local width = Field.width()
  local height = Field.height()
  local tile;

  local cooldown = 60
  local wait = player:create_component(Lifetime.Scene)
  wait.on_update_func = function(self)
    cooldown = cooldown - 1
    if cooldown > 0 then return end
    for x = 1, width, 1 do
      for y = 1, height, 1 do
        tile = Field.tile_at(x, y)

        if tile == nil then goto continue end

        if tile and tile:state() == TileState.Normal and player:is_team(tile:team()) then
          tile:set_state(state)
        end

        ::continue::
      end
    end
    self:eject()
  end
end

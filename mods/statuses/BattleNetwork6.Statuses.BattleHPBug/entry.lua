local HPBugLevels = {}

---@param status Status
function status_init(status)
    local entity = status:owner()

    if Player.from(entity) then
        entity:boost_augment("BattleNetwork6.Bugs.BattleHPBug", status:remaining_time())
        return
    elseif Obstacle.from(entity) then
        return
    end

    -- simulate battle hp bug for non players

    local hp_bug_level = HPBugLevels[entity:id()]

    if HPBugLevels[entity:id()] then
        hp_bug_level = hp_bug_level + status:remaining_time()
    else
        hp_bug_level = status:remaining_time()
        HPBugLevels[entity:id()] = hp_bug_level
    end

    local component = entity:create_component(Lifetime.ActiveBattle)
    local time = 0

    component.on_update_func = function()
        time = time + 1

        -- [40, 10], changes at a rate of 5 frames per level
        local rate = math.max(45 - HPBugLevels[entity:id()] * 5, 10)

        if time % rate ~= 0 then
            return
        end

        entity:add_aux_prop(AuxProp.new():drain_health(1):once())
    end

    entity:on_delete(function()
        HPBugLevels[entity:id()] = nil
    end)
end

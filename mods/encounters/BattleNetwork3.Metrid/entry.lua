local metrid_id = "BattleNetwork3.Metrid.Enemy"
local metrod_id = "BattleNetwork3.Metrod.Enemy"
local metrodo_id = "BattleNetwork3.Metrodo.Enemy"

---@param mob Encounter
function encounter_init(mob)
    mob:create_spawner(metrid_id, Rank.V1):spawn_at(4, 1)
    mob:create_spawner(metrod_id, Rank.V1):spawn_at(4, 2)
    mob:create_spawner(metrodo_id, Rank.V1):spawn_at(4, 3)

    mob:create_spawner(metrid_id, Rank.Omega):spawn_at(6, 1)
    mob:create_spawner(metrid_id, Rank.NM):spawn_at(6, 3)
end

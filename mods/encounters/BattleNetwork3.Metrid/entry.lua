local metrid_id = "BattleNetwork3.Metrid.Enemy"

---@param mob Encounter
function encounter_init(mob)
    mob:create_spawner(metrid_id, Rank.V1):spawn_at(4, 1)
    mob:create_spawner(metrid_id, Rank.V2):spawn_at(4, 2) -- metrod
    mob:create_spawner(metrid_id, Rank.V3):spawn_at(4, 3) -- metrodo

    mob:create_spawner(metrid_id, Rank.Omega):spawn_at(6, 1)
    mob:create_spawner(metrid_id, Rank.NM):spawn_at(6, 3)
end

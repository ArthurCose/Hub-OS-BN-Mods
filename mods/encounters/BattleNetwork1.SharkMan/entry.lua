local character_id = "BattleNetwork1.SharkMan.Enemy"

---@param encounter Encounter
function encounter_init(encounter)
    encounter
        :create_spawner(character_id, Rank.V3)
        :spawn_at(5, 2)
end

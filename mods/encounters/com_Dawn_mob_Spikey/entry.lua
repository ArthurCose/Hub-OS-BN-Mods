local package_prefix = "Dawn"
local character_name = "Spikey"

--Everything under this comment is standard and does not need to be edited
local character_package_id = ""..package_prefix..".char."..character_name
local mob_package_id = ""..package_prefix..".mob."..character_name





function encounter_init(mob) 
    --can setup backgrounds, music, and field here
    local test_spawner = mob:create_spawner(character_package_id,Rank.V1)
    test_spawner:spawn_at(4, 1)
	test_spawner = mob:create_spawner(character_package_id,Rank.V2)
    test_spawner:spawn_at(4, 3)
	test_spawner = mob:create_spawner(character_package_id,Rank.V3)
    test_spawner:spawn_at(6, 1)
    test_spawner = mob:create_spawner(character_package_id,Rank.SP)
    test_spawner:spawn_at(6, 3)
end
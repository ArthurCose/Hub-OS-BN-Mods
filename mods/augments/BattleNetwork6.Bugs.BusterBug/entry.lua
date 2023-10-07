-- Level 1: 6/16 Blank; 1/16 ChargeShot; 9/16 MegaBuster
-- Level 2: 10/16 Blank; 2/16 ChargeShot; 4/16 MegaBuster
-- Level 3: 13/16 Blank; 3/16 ChargeShot; 0/16 MegaBuster

local JammedBuster = require("jammed_buster.lua")

local jam_chances = { 6, 10, 13 }
local charge_chances = { 1, 2, 3 }

function augment_init(augment)
  local owner = augment:owner()
  owner:boost_augment("BattleNetwork6.Bugs.BusterJam", 1)

  augment.normal_attack_func = function(augment)
    local level = math.min(augment:level(), 3)
    local roll = math.random(1, 16)

    -- test jam
    local can_jam = owner:get_augment("BattleNetwork6.Bugs.BusterJam") ~= nil
    local jam_chance = jam_chances[level]

    if roll <= jam_chance then
      if not can_jam then
        return
      end
      return JammedBuster.new(owner)
    end

    -- test charge shot
    local charge_chance = charge_chances[level]

    -- slide the roll for the charge shot
    roll = roll - jam_chance

    if roll <= charge_chance then
      return Buster.new(owner, true, owner:attack_level() * 10)
    end

    -- allow another augment override to or fallback to the player defined normal_attack_func
  end
end

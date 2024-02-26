local MobTracker = require("mob_tracker.lua")
local left_mob_tracker = MobTracker:new()
local right_mob_tracker = MobTracker:new()

function get_tracker_from_direction(facing)
    if facing == Direction.Left then
        return left_mob_tracker
    elseif facing == Direction.Right then
        return right_mob_tracker
    end
    return left_mob_tracker
end

function advance_a_turn_by_facing(facing)
    local mob_tracker = get_tracker_from_direction(facing)
    return mob_tracker:advance_a_turn()
end

function get_active_mob_id_for_same_direction(facing)
    local mob_tracker = get_tracker_from_direction(facing)
    return mob_tracker:get_active_mob()
end

function add_enemy_to_tracking(enemy)
    local facing = enemy:facing()
    local id = enemy:id()
    local mob_tracker = get_tracker_from_direction(facing)
    mob_tracker:add_by_id(id)
end

function remove_enemy_from_tracking(enemy)
    local facing = enemy:facing()
    local id = enemy:id()
    local mob_tracker = get_tracker_from_direction(facing)
    mob_tracker:remove_by_id(id)
end

local function create_meteor(enemy)
    if not enemy or enemy and enemy:deleted() then return end
    local meteor = Spell.new(enemy:team())
    meteor:set_highlight(Highlight.Flash)
    meteor:set_facing(enemy:facing())
    local flags = Hit.Impact | Hit.Flash | Hit.Flinch
    if enemy:rank() == Rank.NM then
        flags = flags & ~Hit.Flash
    end
    meteor:set_hit_props(
        HitProps.new(
            enemy._attack,
            flags,
            Element.Fire,
            enemy:context(),
            Drag.None
        )
    )
    meteor.field = enemy:field()
    meteor:set_texture(enemy._meteor_texture)
    local anim = meteor:animation()
    anim:load("meteor.animation")
    anim:set_state("DEFAULT")
    anim:apply(meteor:sprite())
    meteor:sprite():set_layer(-2)
    meteor.boom = enemy._explosion_texture
    meteor.cooldown = 16
    local x = 224
    meteor.increment_x = 14
    meteor.increment_y = 14
    local sound_1 = enemy._landing_sound
    local sound_2 = enemy._explosion_sound
    meteor:set_offset(meteor:offset().x + x * 0.5, meteor:offset().y - 224 * 0.5)
    meteor.on_update_func = function(self)
        if self.cooldown <= 0 then
            local tile = self:current_tile()
            if tile and tile:is_walkable() then
                tile:attack_entities(self)
                self:field():shake(5, 18)
                local explosion = Spell.new(self:team())
                explosion:set_texture(self.boom)
                local new_anim = explosion:animation()
                new_anim:load("ring_explosion.animation")
                new_anim:set_state("DEFAULT")
                new_anim:apply(explosion:sprite())
                explosion:sprite():set_layer(-2)
                Resources.play_audio(sound_1)
                self.field:spawn(explosion, tile)
                new_anim:on_frame(3, function()
                    Resources.play_audio(sound_2)
                end)
                new_anim:on_complete(function()
                    explosion:erase()
                end)
            end
            self:erase()
        else
            local offset = self:offset()
            self:set_offset(offset.x - self.increment_x * 0.5, offset.y + self.increment_y * 0.5)
            self.cooldown = self.cooldown - 1
        end
    end
    meteor.can_move_to_func = function(tile)
        return true
    end
    return meteor
end

local function create_mob_move(enemy, is_appear)
    if not enemy or enemy and enemy:deleted() then return end --Don't bother if the mob is deleted
    local movement = Spell.new(enemy:team())                  --Use a spell so it doesn't animate during time freeze
    movement:set_texture(enemy._move_texture)                 --Use the stored texture
    local anim = movement:animation()
    anim:load("mob_move.animation")
    --determine the state to use
    anim:set_state("MOB_MOVE")
    if is_appear then
        anim:set_state("MOB_APPEAR")
    end
    anim:on_complete(function()
        movement:erase()
    end)
    anim:apply(movement:sprite())
    movement:sprite():set_layer(-2) --Set layer so it appears over the metrid
    return movement
end

local function find_best_target(virus)
    if not virus or virus and virus:deleted() then return end
    local target = nil          --Grab a basic target from the virus itself.
    local field = virus:field() --Grab the field so you can scan it.
    local query = function(c)
        return c:team() ~=
            virus:team()                                   --Make sure you're not targeting the same team, since that won't work for an attack.
    end
    local potential_threats = field:find_characters(query) --Find CHARACTERS, not entities, to attack.
    local goal_hp = 999999                                 --Start with a ridiculous health.
    if #potential_threats > 0 then                         --If the list is bigger than 0, we go in to a loop.
        for i = 1, #potential_threats, 1 do                --The pound sign, or hashtag if you're more familiar with that term, is used to denote length of a list or array in lua.
            local possible_target = potential_threats[i]   --Index with square brackets.
            --Make sure it exists, is not deleted, and that its health is less than the goal HP. First one always will be.
            if possible_target and not possible_target:deleted() and possible_target:health() <= goal_hp then
                --Make it the new target. This way the lowest HP target is attacked.
                target = possible_target
            end
        end
    end
    --Return whoever the target is.
    return target
end

local function create_meteor_component(metrid)
    if not metrid or metrid and metrid:deleted() then return end
    local meteor_component = metrid:create_component(Lifetime.Battle)
    meteor_component.count = math.random(metrid._minimum_meteors, metrid._maximum_meteors)
    meteor_component.attack_cooldown_max = metrid._meteor_cooldown
    meteor_component.highlight_cooldown_max = 24
    meteor_component.highlight_cooldown = 24
    meteor_component.initial_cooldown = metrid._cooldown
    meteor_component.attack_cooldown = 0
    meteor_component.owner = metrid
    meteor_component.animate_once = true
    meteor_component.accuracy_chance = metrid._accuracy_chance
    meteor_component.tile_list = {}
    meteor_component.create_once = true
    meteor_component.next_tile = nil
    meteor_component.desired_cooldown = 0
    if metrid:rank() == Rank.NM then meteor_component.desired_cooldown = meteor_component.attack_cooldown_max - 16 end
    meteor_component.field = metrid.field
    for t = 1, #metrid._tiles, 1 do
        local desired_tile = metrid._tiles[t]
        --Neat trick: if you only have one declaration, you can put it all in a single line like this with the if statement.
        if not metrid:is_team(desired_tile:team()) then table.insert(meteor_component.tile_list, desired_tile) end
    end
    meteor_component.on_update_func = function(self)
        if self.owner:deleted() then return end
        if self.count <= 0 then
            if self.animate_once then
                self.animate_once = false
                local owner_anim = self.owner:animation()
                owner_anim:set_state("DRESS")
                owner_anim:on_complete(function()
                    owner_anim:set_state("IDLE")
                    owner_anim:set_playback(Playback.Loop)
                    self.owner._ai_state = "MOVE"
                    self.owner._cooldown = self.owner._cooldown_max
                    self.owner._attack_start = true
                    self.owner._pattern_index = self.owner._pattern_index +
                        1                                                                                      --Increment the pattern to the next slot
                    if self.owner._pattern_index > #self.owner._pattern then self.owner._pattern_index = 1 end --Loop the pattern if we hit the end.
                    advance_a_turn_by_facing(self.owner:facing())
                end)
            end
        else
            if self.initial_cooldown > 0 then self.initial_cooldown = self.initial_cooldown - 1 end
            if self.initial_cooldown <= 0 then
                if self.next_tile ~= nil then self.next_tile:set_highlight(Highlight.Flash) end
                if self.highlight_cooldown <= 0 then
                    --Use less than or equal to copmarison to confirm a d100 roll of accuracy.
                    --Example: if a Metrid has an accuracy chance of 20, then a 1 to 100 roll will
                    --Only target the player's tile on a roll of 1-20, leading to an 80% chance of
                    --Targeting a random player tile.
                    if math.random(1, 100) <= self.accuracy_chance then
                        local target = find_best_target(self.owner)
                        if target ~= nil then
                            self.next_tile = target:current_tile()
                        else
                            self.next_tile = self.tile_list[math.random(1, #self.tile_list)]
                        end
                    else
                        self.next_tile = self.tile_list[math.random(1, #self.tile_list)]
                    end
                    self.highlight_cooldown = self.highlight_cooldown_max
                else
                    self.highlight_cooldown = self.highlight_cooldown - 1
                end
                if self.attack_cooldown <= self.desired_cooldown and self.next_tile ~= nil then
                    self.count = self.count - 1
                    self.attack_cooldown_max = self.attack_cooldown_max
                    self.attack_cooldown = self.attack_cooldown_max
                    self.field:spawn(create_meteor(self.owner), self.next_tile)
                else
                    self.attack_cooldown = self.attack_cooldown - 1
                end
            end
        end
    end
end

function character_init(self)
    --Obtain the rank of the virus.
    --This can be V1, V2, V3, EX, SP, R1, R2, or NM.
    --There's also RV, DS, virus, Beta, and Omega in the next build.
    local rank = self:rank()
    --Set its name, health, and attack based on rank.
    --Start with V2 because Omega will share a name with V1, just with a symbol.
    self._minimum_meteors = 4
    self._maximum_meteors = 8
    self._cooldown = 40
    self._cooldown_max = 40
    self._accuracy_chance = 20
    self._meteor_cooldown = 32
    if rank == Rank.V2 then
        self:set_name("Metrod")
        self:set_texture(Resources.load_texture("Metrod.png"))
        self:set_health(200)
        self._attack = 80
        self._cooldown = 30
        self._cooldown_max = 30
    elseif rank == Rank.V3 then
        self:set_name("Metrodo")
        self:set_texture(Resources.load_texture("Metrodo.png"))
        self:set_health(250)
        self._attack = 120
        self._cooldown = 20
        self._cooldown_max = 20
    else
        --All ranks like this will be called Metrid, so use that name.
        self:set_name("Metrid")
        if rank == Rank.NM then
            self:set_texture(Resources.load_texture("MetridNM.png"))
            self:set_health(500)
            self._attack = 300
            self._cooldown = 16
            self._cooldown_max = 16
            self._minimum_meteors = 20
            self._maximum_meteors = 40
            self._accuracy_chance = 40
        elseif rank == Rank.SP then
            self:set_texture(Resources.load_texture("Omega.png"))
            self:set_health(300)
            self._attack = 200
            self._cooldown = 16
            self._cooldown_max = 16
        else
            --If unsupported, assume rank 1.
            self:set_texture(Resources.load_texture("Metrid.png"))
            self:set_health(150)
            self._attack = 40
        end
    end
    self:set_element(Element.Fire)
    self.virusbody = DefenseVirusBody.new()
    self:add_defense_rule(self.virusbody)
    local anim = self:animation()
    anim:load("metrid.animation")
    anim:set_state("IDLE")
    anim:apply(self:sprite())
    anim:set_playback(Playback.Loop)
    self._pattern = { "MOVE", "MOVE", "MOVE", "MOVE", "MOVE", "ATTACK" }
    self._pattern_index = 1
    self.field = nil
    self._tiles = {}
    self._attack_start = true
    self._meteor_texture = Resources.load_texture("meteor.png")
    self._explosion_texture = Resources.load_texture("ring_explosion.png")
    self._explosion_sound = Resources.load_audio("sounds/explosion.ogg")
    self._landing_sound = Resources.load_audio("sounds/meteor_land.ogg")
    self._move_texture = Resources.load_texture("mob_move.png")
    self.on_battle_end_func = function(self)
        left_mob_tracker:clear()
        right_mob_tracker:clear()
    end
    self.on_battle_start_func = function(self)
        local field = self:field()
        add_enemy_to_tracking(self)
        local mob_sort_func = function(a, b)
            local met_a_tile = field:get_entity(a):current_tile()
            local met_b_tile = field:get_entity(b):current_tile()
            local var_a = (met_a_tile:x() * 3) + met_a_tile:y()
            local var_b = (met_b_tile:x() * 3) + met_b_tile:y()
            return var_a < var_b
        end
        left_mob_tracker:sort_turn_order(mob_sort_func)
        right_mob_tracker:sort_turn_order(mob_sort_func, true)
    end
    self.on_delete_func = function(self)
        remove_enemy_from_tracking(self)
        self:erase()
    end
    self.on_spawn_func = function(self)
        self.field = self:field()
        left_mob_tracker:clear()
        right_mob_tracker:clear()
        for x = 1, 6, 1 do
            for y = 1, 3, 1 do
                local tile = self.field:tile_at(x, y)
                if tile and not tile:is_edge() then
                    table.insert(self._tiles, tile)
                end
            end
        end
    end
    self._query = function(e)
        if e and not e:deleted() then
            return Obstacle.from(e) ~= nil or Character.from(e) ~= nil or Player.from(e) ~= nil
        end
        return false
    end
    self._obstacle_query = function(o)
        return o and not o:deleted()
    end
    self.can_move_to_func = function(tile)
        return tile and self:is_team(tile:team()) and tile:is_walkable() and not tile:is_edge() and
            #tile:find_entities(self._query) == 0
    end
    local activity = nil
    self.on_update_func = function(self)
        if self._cooldown <= 0 then
            self._cooldown = self._cooldown_max
            activity = self._pattern[self._pattern_index]
            if activity == "MOVE" then
                local list_2 = {}
                for i = 1, #self._tiles, 1 do
                    local check = self:can_move_to(self._tiles[i])
                    if check then table.insert(list_2, self._tiles[i]) end
                end
                local dest = list_2[math.random(1, #list_2)]
                self.field:spawn(create_mob_move(self, false), self:current_tile())
                self:teleport(dest, function()
                    self.field:spawn(create_mob_move(self, true), dest)
                    self._pattern_index = self._pattern_index +
                        1                                                                    --Increment the pattern to the next slot
                    if self._pattern_index > #self._pattern then self._pattern_index = 1 end --Loop the pattern if we hit the end.
                end)
            elseif activity == "ATTACK" then
                if get_active_mob_id_for_same_direction(facing) == self:id() and self._attack_start then
                    local list_2 = {}
                    for i = 1, #self._tiles, 1 do
                        local check_tile = self._tiles[i]
                        local check = self:can_move_to(check_tile)
                        if check then
                            local tile_preferred = check_tile:get_tile(self:facing(), 1)
                            if check_tile and self:can_move_to(check_tile) and #tile_preferred:find_obstacles(self._obstacle_query) > 0 then
                                self.field:spawn(create_mob_move(self, false), self:current_tile())
                                self:teleport(check_tile, function()
                                    self.field:spawn(create_mob_move(self, true), check_tile)
                                end)
                                break
                            end
                        end
                    end
                    self._attack_start = false
                    anim:set_state("DISROBE")
                    anim:on_complete(function()
                        anim:set_state("ATTACK")
                        anim:set_playback(Playback.Loop)
                        create_meteor_component(self)
                    end)
                else
                    if anim:state() == "IDLE" then
                        self._pattern_index = self._pattern_index +
                            1                                                                    --Increment the pattern to the next slot
                        if self._pattern_index > #self._pattern then self._pattern_index = 1 end --Loop the pattern if we hit the end.
                    end
                end
            end
        else
            self._cooldown = self._cooldown - 1
        end
    end
end

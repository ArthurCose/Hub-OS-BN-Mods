local teleport_animation_path = "teleport.animation"
local teleport_texture_path = "teleport.png"
local teleport_texture = Resources.load_texture(teleport_texture_path)

local debug = false
local function debug_print(text)
    if debug then
        print("[spikey] " .. text)
    end
end

local MobTracker = require("mob_tracker.lua")
local left_mob_tracker = MobTracker:new()
local right_mob_tracker = MobTracker:new()
function get_tracker_from_direction(facing)
    if facing == Direction.Left then
        return left_mob_tracker
    elseif facing == Direction.Right then
        return right_mob_tracker
    end
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

-- Required function, main package information
function character_init(self)
    debug_print("package_init called")
    -- Load character resources
    self.texture = Resources.load_texture("battle.greyscaled.png")
    self.animation = self:animation()
    self.animation:load("battle.animation")
    -- Set up character meta
    self:set_texture(self.texture, true)
    self:set_height(54)
    self:enable_sharing_tile(false)
    self:set_offset(0 * 0.5, 0 * 0.5)
    self:set_name("Spikey")
    self:set_element(Element.Fire)
    local rank = self:rank()
    if rank == Rank.V2 then
        self:set_health(140)
        self:set_palette(Resources.load_texture("battle_v2.palette.png"))
        self.move_before_attack = 6
        self.current_moves = 6
        self.cascade_frame_index = 10
    elseif rank == Rank.V3 then
        self:set_health(190)
        self:set_palette(Resources.load_texture("battle_v3.palette.png"))
        self.move_before_attack = 5
        self.current_moves = 5
        self.cascade_frame_index = 5
    elseif rank == Rank.SP then
        self:set_health(260)
        self:set_palette(Resources.load_texture("battle_v4.palette.png"))
        self.move_before_attack = 3
        self.current_moves = 3
        self.cascade_frame_index = 3
    else
        self:set_health(90)
        self:set_palette(Resources.load_texture("battle_v1.palette.png"))
        self.move_before_attack = 7
        self.current_moves = 7
        self.cascade_frame_index = 16
    end

    --defense rules
    self.defense = DefenseVirusBody.new()
    self:add_defense_rule(self.defense)

    -- Initial state
    self.animation:set_state("IDLE")
    self.animation:set_playback(Playback.Loop)
    self.frames_between_actions = 40
    self.ai_wait = self.frames_between_actions
    self.ai_taken_turn = false

    self.on_update_func = function(self)
        take_turn(self)
        if self.current_moves <= 0 then
            initiate_attack(self)
        end
    end

    self.on_battle_start_func = function(self)
        debug_print("battle_start_func called")
        local field = self:field()
        add_enemy_to_tracking(self)
        local mob_sort_func = function(a, b)
            local var_a = Character.from(field:get_entity(a)):rank()
            local var_b = Character.from(field:get_entity(b)):rank()
            return var_a < var_b
        end
        left_mob_tracker:sort_turn_order(mob_sort_func)
        right_mob_tracker:sort_turn_order(mob_sort_func)
    end
    self.on_battle_end_func = function(self)
        debug_print("battle_end_func called")
        left_mob_tracker:clear()
        right_mob_tracker:clear()
    end
    self.on_spawn_func = function(self, spawn_tile)
        debug_print("on_spawn_func called")
        left_mob_tracker:clear()
        right_mob_tracker:clear()
    end
    self.can_move_to_func = function(tile)
        debug_print("can_move_to_func called")
        return is_tile_free_for_movement(tile, self)
    end
    self.on_delete_func = function(self)
        debug_print("delete_func called")
        remove_enemy_from_tracking(self)
        self:erase()
    end
end

function take_turn(self)
    local id = self:id()
    if self.ai_wait > 0 or self.ai_taken_turn then
        self.ai_wait = self.ai_wait - 1
        return
    end

    local moved_randomly = move_at_random(self)

    if moved_randomly then
        self.ai_wait = self.frames_between_actions
        self.ai_taken_turn = false
        self.current_moves = self.current_moves - 1
        return
    else
        self.ai_wait = self.frames_between_actions
        self.ai_taken_turn = false
        return
    end
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

function initiate_attack(self)
    local id = self:id()
    if self.ai_wait > 0 or self.ai_taken_turn then
        self.ai_wait = self.ai_wait - 1
        return
    end

    local moved = move_towards_character(self)

    if not moved then
        return
    end

    self.current_moves = self.move_before_attack

    local fireball_action = action_fireball(self)
    local next_action = fireball_action
    next_action.on_action_end_func = function()
        local facing = self:facing()
        self.ai_wait = self.frames_between_actions
        self.ai_taken_turn = false
        advance_a_turn_by_facing(facing)
    end
    self:queue_action(next_action)
end

function move_at_random(self)
    local field = self:field()
    local target_tile = nil
    local tile_array = {}
    local moved = false
    for x = 1, 6, 1 do
        for y = 1, 3, 1 do
            local prospective_tile = field:tile_at(x, y)
            if self:can_move_to(prospective_tile) then
                table.insert(tile_array, prospective_tile)
            end
        end
    end
    if #tile_array == 0 then return false end
    target_tile = tile_array[math.random(1, #tile_array)]
    if target_tile then
        target_tile:reserve_for_id(self:id())
        moved = self:teleport(target_tile)
        if moved then
            self:set_facing(target_tile:facing())
            spawn_visual_artifact(target_tile, self, teleport_texture, teleport_animation_path, "SMALL_TELEPORT_FROM", 0,
                0)
        end
    end
    return moved
end

function move_towards_character(self)
    local target_character = find_best_target(self)
    if target_character == nil then return false end
    local tile = self:current_tile()
    local moved = false
    local target_movement_tile = nil
    for i = 1, 6, 1 do
        if target_movement_tile ~= nil then
            break
        else
            local check_tile = target_character:get_tile(target_character:facing(), i)
            if self:can_move_to(check_tile) then
                target_movement_tile = check_tile
            end
        end
    end
    if target_movement_tile then
        target_movement_tile:reserve_for_id(self:id())
        moved = self:teleport(target_movement_tile)
        if moved then
            self:set_facing(target_movement_tile:facing())
            spawn_visual_artifact(tile, self, teleport_texture, teleport_animation_path, "SMALL_TELEPORT_FROM", 0, 0)
        end
    end
    return moved
end

function action_fireball(character)
    debug_print("started fireball action")
    local action_name = "fireball"
    local facing = character:facing()
    debug_print('action ' .. action_name)
    --Set the damage. Default is 30.
    local damage = 30
    local rank = character:rank()
    if rank == Rank.V2 then
        damage = 60
    elseif rank == Rank.V3 then
        damage = 90
    elseif rank == Rank.SP then
        damage = 150
    end
    local action = Action.new(character, "ATTACK")
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        self:add_anim_action(2, function()
            character:set_counterable(true)
        end)
        self:add_anim_action(4, function()
            local tile = character:get_tile(facing, 1)
            spawn_fireball(character, tile, facing, damage, character.cascade_frame_index)
        end)
        self:add_anim_action(6, function()
            character:set_counterable(false)
        end)
    end
    action.on_animation_end_func = function(self, user)
        character.animation:set_state("IDLE")
    end
    character.ai_taken_turn = true
    return action
end

--Basic check to see if a tile is suitable for a chracter of a team to move to
function is_tile_free_for_movement(tile, character)
    --If we're dead, don't move lol.
    if character:health() <= 0 then return false end

    --If the tile isn't real, don't move lol.
    if not tile then return false end

    --If we're rooted in place, don't move lol.
    if character:remaining_status_time(Hit.Root) > 0 then return false end

    --If it's red and we're blue / blue and we're red, don't move lol.
    if not character:is_team(tile:team()) then return false end

    --If it's not walkable and we're walking, don't move lol.
    if not tile:is_walkable() and not character:ignoring_hole_tiles() then return false end

    --Setup filtering for obstacles & characters.
    local occupants = tile:find_entities(function(ent)
        if Character.from(ent) ~= nil or Obstacle.from(ent) ~= nil then
            return true
        end
    end)

    --If it's occupied by an obstacle or character, don't move lol.
    if #occupants > 0 then
        return false
    end

    --Cool let's go there.
    return true
end

function spawn_visual_artifact(tile, character, texture, animation_path, animation_state, position_x, position_y)
    local field = character:field()
    local visual_artifact = Artifact.new()
    visual_artifact:set_texture(texture, true)
    local anim = visual_artifact:animation()
    anim:load(animation_path)
    anim:set_state(animation_state)
    anim:on_complete(function()
        visual_artifact:delete()
    end)
    visual_artifact:sprite():set_offset(position_x * 0.5, position_y * 0.5)
    field:spawn(visual_artifact, tile:x(), tile:y())
end

function spawn_fireball(owner, tile, direction, damage, cascade_frame_index)
    debug_print("in spawn fireball")
    local owner_id = owner:context()
    local team = owner:team()
    local field = owner:field()
    local fireball_texture = Resources.load_texture("fireball.png", true)
    local fireball_sfx = Resources.load_audio("sfx.ogg", true)
    local explosion_texture = Resources.load_texture("spell_explosion.png")
    Resources.play_audio(fireball_sfx)
    local spell = Spell.new(team)
    spell:set_texture(fireball_texture)
    spell:set_facing(direction)

    spell:set_tile_highlight(Highlight.Solid)
    spell:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.Flash,
            Element.Fire,
            owner_id,
            Drag.None
        )
    )
    local sprite = spell:sprite()
    sprite:set_layer(-1)
    local animation = spell:animation()
    animation:load("fireball.animation")
    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Loop)
    animation:apply(sprite)

    spell.has_hit = false
    spell.on_update_func = function(self)
        local own_tile = self:current_tile()
        own_tile:attack_entities(self)
        --Erase spell if we're on an edge and we've started sliding, but AREN'T currently sliding. Make it clean.
        if own_tile:is_edge() and not self:is_sliding() and self.slide_started then self:delete() end

        --Destination is one tile ahead.
        local dest = self:get_tile(spell:facing(), 1)
        local ref = self
        --If a hit has not landed...
        if not self.has_hit then
            --Slide for the fireball's slide time. 12f for V1, 9f for V2, 6f for V3. Signal the slide has started.
            self:slide(dest, cascade_frame_index, function()
                ref.slide_started = true
            end)
        end
    end
    local function rank_relevant_boom(attack, explosion_table)
        for explosions = 1, #explosion_table, 1 do
            if explosion_table[explosions] and not explosion_table[explosions]:is_edge() then
                local hitbox = Hitbox.new(spell:team())
                hitbox:set_hit_props(attack:copy_hit_props())
                local fx = Spell.new(attack:team())
                fx:set_texture(explosion_texture, true)
                local fx_anim = fx:animation()
                fx_anim:load("spell_explosion.animation")
                fx_anim:set_state("Default")
                fx_anim:apply(fx:sprite())
                fx:sprite():set_layer(-2)
                fx_anim:on_complete(function() fx:erase() end)
                field:spawn(fx, explosion_table[explosions])
                field:spawn(hitbox, explosion_table[explosions])
            end
        end
        attack:erase()
    end

    spell.on_collision_func = function(self, other)
        self.has_hit = true
        local explosion_tiles = {}
        local rank = owner:rank()
        if rank == Rank.V1 or rank == Rank.SP then
            explosion_tiles = { self:current_tile(), self:get_tile(self:facing(), 1) }
        elseif rank == Rank.V2 then
            explosion_tiles = { self:current_tile(), self:get_tile(Direction.join(self:facing(), Direction.Up), 1),
                self:get_tile(Direction.join(self:facing(), Direction.Down), 1) }
        elseif rank == Rank.V3 then
            explosion_tiles = { self:current_tile(), self:get_tile(Direction.Up, 1), self:get_tile(Direction.Down, 1) }
        end
        rank_relevant_boom(self, explosion_tiles)
    end
    spell.can_move_to_func = function(move_tile)
        return true
    end
    field:spawn(spell, tile)
end

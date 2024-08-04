local character_info = { name = "BigBrute", hp = 120, height = 60 }
function debug_print(text)
    --print("[bigbrute] " .. text)
end

function character_init(self)
    debug_print("character_init called")
    -- Required function, main package information

    -- Load character resources
    self.texture = Resources.load_texture("battle.png")
    local animation = self:animation()
    animation:load("battle.animation")

    -- Load extra resources
    fire_tower_animation_path = "firetower.animation"

    fire_tower_texture = Resources.load_texture("firetower.png")
    fire_tower_sound = Resources.load_audio("firetower.ogg")

    teleport_animation_path = "teleport.animation"

    teleport_texture = Resources.load_texture("teleport.png")

    impacts_animation_path = "impacts.animation"

    impacts_texture = Resources.load_texture("impacts.png")


    -- Set up character meta
    self:set_name(character_info.name)
    self:set_health(character_info.hp)
    self:set_texture(self.texture, true)
    self:set_height(character_info.height)
    self:enable_sharing_tile(false)
    -- self:set_explosion_behavior(4, 1.0, false)
    self:set_offset(0 * 0.5, 0 * 0.5)

    --defense rules
    self:add_aux_prop(StandardEnemyAux.new())

    -- Initial state
    animation:set_state("IDLE")
    animation:set_playback(Playback.Loop)

    self.ai_state = "spawning"
    self.ai_jumps = 0
    self.ai_target_jumps = math.random(4, 5)
    self.frames_between_jumps = 40
    self.ai_timer = self.frames_between_jumps

    self.on_update_func = function(self)
        local character = self
        local character_facing = character:facing()
        -- debug_print("original update_func called: "..character.ai_state)
        if character.ai_state == "idle" then
            character.ai_timer = character.ai_timer + 1
            if character.ai_timer > character.frames_between_jumps then
                local is_attacking = false

                character.ai_jumps = character.ai_jumps + 1

                if character.ai_jumps >= character.ai_target_jumps then
                    is_attacking = true
                    character.ai_state = "attacking"
                end

                big_brute_teleport(character, is_attacking)

                if is_attacking then
                    local action = action_beast_breath(character)
                    character:queue_action(action, nil)
                    action.on_action_end_func = function()
                        character.ai_state = "idle"
                        character.ai_jumps = 0
                        self.ai_target_jumps = math.random(4, 5)
                    end
                end

                character.ai_timer = 0
            end
        end
    end

    self.on_battle_start_func = function(self)
        self.ai_state = "idle"
        debug_print("battle_start_func called")
    end

    self.on_battle_end_func = function(self)
        debug_print("battle_end_func called")
    end

    self.on_spawn_func = function(self, spawn_tile)
        debug_print("on_spawn_func called")
    end

    self.can_move_to_func = function(tile)
        if tile:team() ~= self:team() and tile:team() ~= Team.Other then return false end

        if not tile:is_walkable() then return false end

        local occupants = tile:find_entities(function(entity)
            if not entity:hittable() then return false end
            if Obstacle.from(entity) ~= nil then return false end
            return true
        end)

        if #occupants > 0 then
            return false
        end

        return true
    end

    self.on_delete_func = function(self)
        self:default_character_delete()
    end
end

function big_brute_teleport(character, is_attacking)
    local field = character:field()
    local user_team = character:team()

    local target_list = field:find_characters(function(entity)
        if not entity:hittable() then return false end
        if Obstacle.from(entity) ~= nil then return false end
        return entity:team() ~= user_team
    end)

    if #target_list == 0 then
        debug_print("No targets found!")
        return
    end

    local target_character = target_list[1]
    local target_character_tile = target_character:current_tile()

    local target_tile = nil

    allowed_movement_tiles = field:find_tiles(function(other_tile)
        if not character:can_move_to(other_tile) then
            return false
        end

        if other_tile:is_reserved({ character:id() }) then
            return false
        end

        local target_y = target_character_tile:y()
        local other_y = other_tile:y()

        if is_attacking then
            local next_tile = other_tile:get_tile(character:facing(), 1)
            local next_tile_team = next_tile:team()

            if next_tile_team == Team.Red and user_team == Team.Blue then
                return target_y == other_y
            elseif next_tile_team == Team.Blue and user_team == Team.Red then
                return target_y == other_y
            else
                -- If all tiles are passable because they're all Team.Other, warp 3 or less tiles away every time.
                local distance = (next_tile:x() - other_tile:x())
                return distance > 0 and distance < 3
            end
        elseif not is_attacking then
            return target_y ~= other_y
        end

        return other_tile ~= character:current_tile()
    end)

    if #allowed_movement_tiles > 0 then
        target_tile = allowed_movement_tiles[math.random(#allowed_movement_tiles)]
    else
        target_tile = character:current_tile()
    end

    local teleport_action = action_teleport(character, target_tile)
    target_tile:reserve_for_id(character:id())

    teleport_action.on_action_end_func = function(self)
        local departure_tile = character:current_tile()

        spawn_visual_artifact(departure_tile, character, teleport_texture, teleport_animation_path,
            teleport_action.teleport_size .. "_TELEPORT_FROM", 0, -character_info.height)

        character:teleport(target_tile, function()
            local anim = character:animation()
            -- anim:set_state("IDLE")
            anim:set_playback(Playback.Loop)
        end)
    end

    character:queue_action(teleport_action, nil)
end

function is_tile_free_for_movement(tile, character, must_be_walkable)
    --Basic check to see if a tile is suitable for a chracter of a team to move to


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

function action_teleport(character, target_tile)
    local action_name = "teleport"
    debug_print('action ' .. action_name)

    local action = Action.new(character, "IDLE")

    action:set_lockout(ActionLockout.new_sequence())

    local character_height = character:height()

    if character_height > 60 then
        action.teleport_size = "BIG"
    elseif character_height > 40 then
        action.teleport_size = "MEDIUM"
    else
        action.teleport_size = "SMALL"
    end

    action.on_execute_func = function(self)
        local step1 = self:create_step()
        local actor = self:owner()

        --add a reference to this function to indicate that it can be canceled

        action.pre_teleport_frames = 2
        action.elapsed = 0
        action.arrival_artifact_created = false
        action.departure_artifact_created = false

        step1.on_update_func = function(self)
            -- debug_print('action ' .. action_name .. ' step 1 update')
            if not action.arrival_artifact_created then
                spawn_visual_artifact(target_tile, character, teleport_texture, teleport_animation_path,
                    action.teleport_size .. "_TELEPORT_TO", 0, 0)
                action.arrival_artifact_created = true
            end
            if action.elapsed <= action.pre_teleport_frames then
                action.elapsed = action.elapsed + 1
                return
            end
            self:complete_step()
            -- debug_print('action ' .. action_name .. ' step 1 complete')
        end
    end

    action.on_action_end_func = function(self)
        local owner = self:owner()
        local anim = owner:animation()
        anim:set_state("IDLE")
        anim:set_playback(Playback.Loop)
    end

    return action
end

function action_beast_breath(character)
    local action_name = "beast breath"
    debug_print('action ' .. action_name)

    local action = Action.new(character, "IDLE")
    action:set_lockout(ActionLockout.new_sequence())

    action.on_execute_func = function(self)
        debug_print('executing action ' .. action_name)
        local step1 = self:create_step()
        local step2 = self:create_step()

        --add a reference to this function to indicate that it can be canceled
        local actor = self:owner()
        action.pre_attack_anim_started = false
        action.attack_anim_started = false
        action.pre_attack_time_counter = 0
        action.pre_attack_time = 42
        action.attack_time_counter = 0
        action.attack_time = 60
        action.pre_attack_counter_time = 12
        action.counter_enabled = false

        action.warning_toggle_frames = 4
        action.warning_toggle = false
        action.warning_toggle_frames_elapsed = 0
        action.target_tiles = {}

        step1.on_update_func = function(self)
            -- debug_print('pre attack update'.. action.pre_attack_time_counter)
            -- debug_print('action '..action_name..' step 1')
            if not action.pre_attack_anim_started then
                local anim = actor:animation()
                anim:set_state("PRE_ATTACK")
                anim:set_playback(Playback.Loop)

                action.pre_attack_anim_started = true

                local direction = actor:facing()
                local t1 = actor:get_tile(direction, 1)
                local t2 = actor:get_tile(direction, 2)
                local t3 = actor:get_tile(direction, 3)
                if t1 then
                    action.target_tiles[#action.target_tiles + 1] = t1
                end
                if t2 then
                    local t2a = t2:get_tile(Direction.Up, 1)
                    local t2b = t2:get_tile(Direction.Down, 1)
                    action.target_tiles[#action.target_tiles + 1] = t2
                    action.target_tiles[#action.target_tiles + 1] = t2a
                    action.target_tiles[#action.target_tiles + 1] = t2b
                end
                if t3 then
                    action.target_tiles[#action.target_tiles + 1] = t3
                end
            end
            if action.pre_attack_time_counter < action.pre_attack_time then
                action.pre_attack_time_counter = action.pre_attack_time_counter + 1

                --flash target tiles
                for index, target_tile in ipairs(action.target_tiles) do
                    if action.warning_toggle then
                        target_tile:set_highlight(Highlight.Solid)
                    end
                end
                --cycle flashing
                action.warning_toggle_frames_elapsed = action.warning_toggle_frames_elapsed + 1
                if action.warning_toggle_frames_elapsed >= action.warning_toggle_frames then
                    action.warning_toggle_frames_elapsed = 0
                    action.warning_toggle = not action.warning_toggle
                end

                --enable counter frames at certain time before attack
                if action.pre_attack_time_counter <= action.pre_attack_time - action.pre_attack_counter_time and not action.counter_enabled then
                    actor:set_counterable(true)
                end
            else
                actor:set_counterable(false)
                self:complete_step()
            end
        end

        step2.on_update_func = function(self)
            -- debug_print('action '..action_name..' step 2')
            if not action.attack_anim_started then
                local anim = actor:animation()
                anim:set_state("ATTACK")
                anim:set_playback(Playback.Loop)

                action.attack_anim_started = true

                Resources.play_audio(fire_tower_sound, AudioBehavior.Default)

                --Do attacking
                for index, target_tile in ipairs(action.target_tiles) do
                    fire_tower_spell(character, 50, 30, target_tile)
                end
            end
            if action.attack_time_counter < action.attack_time then
                action.attack_time_counter = action.attack_time_counter + 1
            else
                debug_print('action ' .. action_name .. ' step 2 complete')
                local anim = actor:animation()
                anim:on_complete(function()
                    anim:set_state("IDLE")
                    anim:set_playback(Playback.Loop)
                    self:complete_step()
                end)
            end
        end
    end

    action.on_action_end_func = function(self)
        local owner = self:owner()
        local anim = owner:animation()
        anim:set_state("IDLE")
        anim:set_playback(Playback.Loop)
    end

    return action
end

function fire_tower_spell(user, damage, duration, tile)
    local field = user:field()
    local target_tile = tile
    if target_tile:is_edge() then
        return
    end
    local spell = Spell.new(user:team())
    spell:set_texture(fire_tower_texture, true)
    spell:set_hit_props(HitProps.new(damage, Hit.Impact | Hit.Flash | Hit.Flinch,
        Element.Fire, user:context(),
        Drag.None))
    spell.elapsed = 0
    spell.current_state = 1
    spell.state_changed = true

    spell.duration_states = { 999, duration, 999, 999 }

    spell.on_attack_func = function(self, other)
        local tile = self:current_tile()
        --TODO replace this with volcano effect (gotta make the animation)
        spawn_visual_artifact(tile, self, impacts_texture, impacts_animation_path, "VOLCANO", 0, 0)
    end

    spell.on_update_func = function(self)
        -- damage entities
        local current_tile = self:current_tile()
        current_tile:attack_entities(self)
        -- update elapsed time
        self.elapsed = self.elapsed + 1
        if self.elapsed >= self.duration_states[spell.current_state] then
            self.current_state = self.current_state + 1
            self.state_changed = true
            self.elapsed = 0
        end
        --on state change
        if self.state_changed then
            local anim = self:animation()
            if self.current_state == 1 then
                anim:set_state("START")
                anim:set_playback(Playback.Once)
                anim:on_complete(function()
                    self.current_state = self.current_state + 1
                    self.state_changed = true
                    self.elapsed = 0
                end)
            end
            if self.current_state == 2 then
                anim:set_state("LOOP")
                anim:set_playback(Playback.Loop)
            end
            if self.current_state == 3 then
                anim:set_state("END")
                anim:set_playback(Playback.Once)
                anim:on_complete(function()
                    self.current_state = self.current_state + 1
                    self.state_changed = true
                    self.elapsed = 0
                end)
            end
            if self.current_state == 4 then
                -- debug_print('spell complete')
                spell:delete()
            end
            self.state_changed = false
        end
    end

    local anim = spell:animation()
    anim:load(fire_tower_animation_path)
    anim:set_state("START")
    field:spawn(spell, target_tile)
    return spell
end

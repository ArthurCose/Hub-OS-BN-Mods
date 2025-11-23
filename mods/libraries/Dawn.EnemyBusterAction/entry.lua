local Buster_Action = {}

Buster_Action.new = function(user, charged, damage, action_user)
    local action = Action.new(action_user, "CHARACTER_SHOOT")
    local context = action_user:context()
    local rapid_level = user:rapid_level()

    -- override animation

    local frame_data = { { 1, 1 }, { 2, 2 }, { 3, 2 }, { 1, 1 } }

    action:override_animation_frames(frame_data)

    -- setup buster attachment
    local buster_attachment = action:create_attachment("BUSTER")

    local buster_sprite = buster_attachment:sprite()
    buster_sprite:set_texture(action_user:texture())
    buster_sprite:set_palette(action_user:palette())
    buster_sprite:set_layer(-2)
    buster_sprite:use_root_shader()

    local buster_animation = buster_attachment:animation()
    buster_animation:copy_from(action_user:animation())
    buster_animation:set_state("BUSTER", frame_data)

    -- spell
    local cooldown_table = {
        { 5, 9, 13, 17, 21, 25 },
        { 4, 8, 11, 15, 18, 21 },
        { 4, 7, 10, 13, 16, 18 },
        { 3, 5, 7,  9,  11, 13 },
        { 3, 4, 5,  6,  7,  8 }
    }

    rapid_level = math.max(math.min(rapid_level, #cooldown_table), 1)

    local cooldown = cooldown_table[rapid_level][6]
    local elapsed_frames = 0
    local spell_erased_frame = 0

    local spell = Spell.new(action_user:team())

    spell:set_facing(action_user:facing())

    action.on_update_func = function()
        if spell_erased_frame == 0 and spell:will_erase_eof() then
            spell_erased_frame = elapsed_frames
        end

        elapsed_frames = elapsed_frames + 1

        if spell_erased_frame > 0 and elapsed_frames - spell_erased_frame >= cooldown then
            action_user:animation():resume()
        end
    end

    action:add_anim_action(2, function()
        Resources.play_audio(Resources.game_folder() .. "resources/sfx/pew.ogg");

        spell:set_hit_props(HitProps.new(
            damage,
            Hit.Impact,
            Element.None,
            context,
            Drag.None
        ))

        local tiles_travelled = 1
        local move_timer = 0
        local goal_time = { 1, 2, 3 }
        local goal_time_index = 1
        local total_time = 0

        spell.on_update_func = function()
            spell:current_tile():attack_entities(spell)

            -- Increment total time spent on-screen.
            total_time = total_time + 1;
            -- Increment movement countdown
            move_timer = move_timer + 1;

            if move_timer < goal_time[goal_time_index] then
                return
            end

            local tile = spell:get_tile(spell:facing(), 1)

            if tile then
                tiles_travelled = tiles_travelled + 1
                spell:teleport(tile, function()
                    local check_tile = tile:get_tile(user:facing(), 1);
                    -- Increment time before teleport based on time spent existing or location
                    if total_time == 1 or check_tile:is_edge() then
                        goal_time_index = goal_time_index + 1;
                    end
                end)
            else
                spell:delete()
            end
        end

        spell.on_collision_func = function(self, entity)
            Resources.play_audio(Resources.game_folder() .. "resources/sfx/hurt.ogg");

            local hit_x = 0
            local hit_y = entity:height()
            local state = "HIT"

            if charged then
                hit_y = hit_y / 2
                state = "CHARGED_HIT"
            else
                hit_x = entity:sprite():width() * (math.random(0, 1) - 0.5)
                hit_y = math.random() * hit_y
            end

            local hit_artifact = Artifact.new()
            hit_artifact:load_animation(Resources.game_folder() .. "resources/scenes/battle/spell_bullet_hit.animation")
            hit_artifact:set_texture(Resources.game_folder() .. "resources/scenes/battle/spell_bullet_hit.png")
            hit_artifact:set_offset(hit_x, -hit_y)

            local hit_animation = hit_artifact:animation()
            hit_animation:set_state(state)
            hit_animation:on_complete(function()
                hit_artifact:erase()
            end)

            spell:field():spawn(hit_artifact, spell:current_tile())
            spell:delete()
        end

        spell.on_delete_func = function()
            local calculated_cooldown = cooldown_table[rapid_level][tiles_travelled]

            if calculated_cooldown ~= nil then
                cooldown = calculated_cooldown
            end

            spell:erase()
        end

        Field.spawn(spell, action_user:current_tile())
    end)

    -- flare attachment
    action:add_anim_action(3, function()
        local flare_attachment = buster_attachment:create_attachment("ENDPOINT")
        local flare_sprite = flare_attachment:sprite()
        flare_sprite:set_texture(Resources.game_folder() .. "resources/scenes/battle/buster_flare.png")
        flare_sprite:set_layer(-3)

        local animation = flare_attachment:animation()
        animation:load(Resources.game_folder() .. "resources/scenes/battle/buster_flare.animation")
        animation:set_state("DEFAULT")

        animation:apply(flare_sprite)
    end)

    action:add_anim_action(4, function()
        local animation = action_user:animation()

        animation:on_interrupt(function()
            animation:resume()
        end)

        animation:pause()
    end)

    action.on_animation_end_func = function()
        action:end_action()
    end

    return action
end

return Buster_Action

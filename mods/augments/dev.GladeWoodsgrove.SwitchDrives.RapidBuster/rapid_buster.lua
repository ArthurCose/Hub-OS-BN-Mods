-- tweaked from client/src/lua_api/battle_api/built_in/buster.lua
local RapidBuster = {}

---@param user Entity
---@param damage number
function RapidBuster.new(user, damage)
    local action = Action.new(user, "CHARACTER_SHOOT")
    local context = user:context()

    -- override animation
    local frame_data = { { 1, 1 }, { 2, 2 }, { 3, 2 }, { 1, 1 } }

    action:override_animation_frames(frame_data)

    -- setup buster attachment
    local buster_attachment = action:create_attachment("BUSTER")

    local buster_sprite = buster_attachment:sprite()
    buster_sprite:set_texture(user:texture())
    buster_sprite:set_layer(-2)
    buster_sprite:use_root_shader()

    if user:palette() ~= nil then
        buster_sprite:set_palette(user:palette())
    end

    local buster_animation = buster_attachment:animation()
    buster_animation:copy_from(user:animation())
    buster_animation:set_state("BUSTER", frame_data)

    local spell = Spell.new(user:team())
    local can_move = false

    spell:set_facing(user:facing())

    local function movement_check()
        local motion_x = 0
        local motion_y = 0

        if user:input_has(Input.Held.Left) or user:input_has(Input.Pressed.Left) then
            motion_x = motion_x - 1
        end

        if user:input_has(Input.Held.Right) or user:input_has(Input.Pressed.Right) then
            motion_x = motion_x + 1
        end

        if user:input_has(Input.Held.Up) or user:input_has(Input.Pressed.Up) then
            motion_y = motion_y - 1
        end

        if user:input_has(Input.Held.Down) or user:input_has(Input.Pressed.Down) then
            motion_y = motion_y + 1
        end

        if user:team() == Team.Blue then
            motion_x = -motion_x
        end

        if (motion_x ~= 0 and user:can_move_to(user:get_tile(Direction.Right, motion_x))) or (motion_y ~= 0 and user:can_move_to(user:get_tile(Direction.Down, motion_y))) then
            return true
        end

        return false
    end

    local frame_two_action = function()
        Resources.play_audio(Resources.game_folder() .. "resources/sfx/pew.ogg");

        local last_tile = user:current_tile()

        spell:set_hit_props(HitProps.new(
            damage,
            Hit.None,
            Element.None,
            context,
            Drag.None
        ))

        local tiles_travelled = 1
        local move_timer = 0

        spell.on_update_func = function()
            last_tile:attack_entities(spell)
            last_tile = spell:current_tile()
            last_tile:attack_entities(spell)

            move_timer = move_timer + 1

            if move_timer < 2 then
                return
            end

            local tile = spell:get_tile(spell:facing(), 1)

            if tile then
                tiles_travelled = tiles_travelled + 1
                spell:teleport(tile)
            else
                spell:delete()
            end

            move_timer = 0
        end

        spell.on_collision_func = function(self, entity)
            Resources.play_audio(Resources.game_folder() .. "resources/sfx/hurt.ogg");

            local hit_x = entity:sprite():width() * (math.random() - 0.5)
            local hit_y = entity:height() * math.random()
            local state = "HIT"

            local hit_artifact = Artifact.new()
            hit_artifact:load_animation(Resources.game_folder() .. "resources/scenes/battle/spell_bullet_hit.animation")
            hit_artifact:set_texture(Resources.game_folder() .. "resources/scenes/battle/spell_bullet_hit.png")
            hit_artifact:set_offset(hit_x, -hit_y)

            local hit_animation = hit_artifact:animation()
            hit_animation:set_state(state)
            hit_animation:on_complete(function()
                hit_artifact:erase()
            end)

            Field.spawn(hit_artifact, spell:current_tile())
            spell:delete()
        end

        spell.on_delete_func = function()
            spell:erase()
        end

        Field.spawn(spell, last_tile)
    end

    local add_flare = function()
        local flare_attachment = buster_attachment:create_attachment("ENDPOINT")
        local flare_sprite = flare_attachment:sprite()
        flare_sprite:set_texture(Resources.game_folder() .. "resources/scenes/battle/buster_flare.png")
        flare_sprite:set_layer(-3)

        local animation = flare_attachment:animation()
        animation:load(Resources.game_folder() .. "resources/scenes/battle/buster_flare.animation")
        animation:set_state("DEFAULT")
        animation:on_frame(3, function()
            can_move = true
        end)

        animation:apply(flare_sprite)
    end

    action.on_update_func = function()
        if can_move then
            if movement_check() == true then
                action:end_action()
            end
        end
    end

    action:on_anim_frame(2, function()
        frame_two_action()
    end)

    -- flare attachment
    action:on_anim_frame(3, function()
        add_flare()
    end)

    action.on_animation_end_func = function()
        action:end_action()
    end

    return action
end

return RapidBuster

local GutsMachGun = {}

local bn_assets = require("BattleNetwork.Assets")

local guts_mach_gun_audio = bn_assets.load_audio("guts_mach_gun.ogg")

---@param user Entity
---@param damage number
function GutsMachGun.new(user, damage)
    local action = Action.new(user, "CHARACTER_SHOOT")
    local context = user:context()

    -- override animation
    local frame_data = { { 1, 2 },
        { 2, 3 }, { 3, 4 },
        { 2, 3 }, { 3, 4 },
        { 2, 3 }, { 3, 4 },
        { 2, 3 }, { 3, 4 },
        { 2, 3 }, { 3, 4 },
        { 1, 3 } }

    action:override_animation_frames(frame_data)

    action.on_execute_func = function()
        user:apply_status(Hit.Invincible, 40)
    end

    -- setup buster attachment
    local buster_attachment = action:create_attachment("BUSTER")

    local buster_sprite = buster_attachment:sprite()
    buster_sprite:set_texture(user:texture())
    buster_sprite:set_layer(-2)
    buster_sprite:use_root_shader()

    local buster_animation = buster_attachment:animation()
    buster_animation:copy_from(user:animation())
    buster_animation:set_state("BUSTER", frame_data)

    local spell_list = {}
    local cooldown = 4

    action.on_update_func = function()
        for _, shot in ipairs(spell_list) do
            if shot._spell and shot._spell:deleted() then goto continue end

            if shot._spell_erased_frame == 0 and shot._spell:will_erase_eof() then
                shot._spell_erased_frame = shot._elapsed_frames
            end

            shot._elapsed_frames = shot._elapsed_frames + 1

            if shot._spell_erased_frame > 0 and shot._elapsed_frames - shot._spell_erased_frame >= cooldown then
                user:animation():resume()
            end

            ::continue::
        end
    end

    for i = 2, 10, 2 do
        action:add_anim_action(i, function()
            local spell = Spell.new(user:team())

            spell:set_facing(user:facing())

            Resources.play_audio(guts_mach_gun_audio)

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

                local hit_x = 0
                local hit_y = entity:height()
                local state = "CHARGED_HIT"

                hit_y = hit_y / 2

                local hit_artifact = Artifact.new()
                hit_artifact:load_animation(Resources.game_folder() ..
                    "resources/scenes/battle/spell_bullet_hit.animation")
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

            table.insert(spell_list,
                {
                    _spell = spell,
                    _spell_erased_frame = 0,
                    _elapsed_frames = 0
                }
            )

            Field.spawn(spell, last_tile)
        end)

        -- flare attachment
        action:add_anim_action(i + 1, function()
            local flare_attachment = buster_attachment:create_attachment("ENDPOINT")
            local flare_sprite = flare_attachment:sprite()
            flare_sprite:set_texture(Resources.game_folder() .. "resources/scenes/battle/buster_flare.png")
            flare_sprite:set_layer(-3)

            local animation = flare_attachment:animation()
            animation:load(Resources.game_folder() .. "resources/scenes/battle/buster_flare.animation")
            animation:set_state("DEFAULT")

            animation:apply(flare_sprite)
        end)
    end

    action.on_animation_end_func = function()
        action:end_action()
    end

    return action
end

return GutsMachGun

local battle_helpers = require("Battle.Helpers")
local bn_helpers = require("BattleNetwork.Assets")

local attachment_texture = bn_helpers.load_texture("vulcan_attachment.png")
local attachment_animation_path = bn_helpers.fetch_animation_path("vulcan_attachment.animation")

local vulcan_impact_texture = bn_helpers.load_texture("vulcan_impact.png")
local vulcan_impact_animation_path = bn_helpers.fetch_animation_path("vulcan_impact.animation")

local bullet_hit_texture = bn_helpers.load_texture("vulcan_bullet_hit.png")
local bullet_hit_animation_path = bn_helpers.fetch_animation_path("vulcan_bullet_hit.animation")

local gun_sfx = bn_helpers.load_audio("vulcan.ogg")

function card_init(user, props)
    local action = Action.new(user, "PLAYER_SHOOTING")
    local shots_animated = 1
    local hits = 0
    if props.short_name == "Vulcan1" then
        shots_animated = 4
        hits = 3
    elseif props.short_name == "Vulcan2" then
        shots_animated = 5
        hits = 4
    elseif props.short_name == "Vulcan3" then
        shots_animated = 6
        hits = 5
    elseif props.short_name == "SuprVulc" then
        shots_animated = 17
        hits = 10
    elseif props.short_name == "DarkVulc" then
        shots_animated = 36;
        hits = 24
    end
    local vulcan_direction = user:facing()
    local f_padding = { 1, 2 }
    local frames = { f_padding, f_padding, f_padding, f_padding, f_padding, f_padding, f_padding }

    local hit_props = HitProps.new(
        props.damage,
        props.hit_flags,
        props.element,
        props.secondary_element,
        user:context(),
        Drag.None
    )

    local f_flash = { 2, 2 }
    local f_between = { 3, 3 }

    for i = 1, shots_animated, 1 do
        table.insert(frames, 3, f_between)
        table.insert(frames, 3, f_flash)
    end

    action:override_animation_frames(frames)

    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local field = user:field();
        local facing = user:facing();
        local attachment = self:create_attachment("BUSTER")
        local attachment_sprite = attachment:sprite()
        attachment_sprite:set_texture(attachment_texture)
        attachment_sprite:set_layer(-2)

        local attachment_animation = attachment:animation()
        attachment_animation:load(attachment_animation_path)
        attachment_animation:set_state("SPAWN_" .. props.short_name)

        user:set_counterable(true)

        self:add_anim_action(2, function()
            attachment_animation:set_state("ATTACK_" .. props.short_name)
            attachment_animation:set_playback(Playback.Loop)
        end)

        for i = 1, hits, 1 do
            self:add_anim_action(i * 4, function()
                Resources.play_audio(gun_sfx)
                local target = battle_helpers.get_first_target_ahead(user)
                if not target then
                    --ignore any hits beyond the first one
                    return
                end
                local hit_tile = target:current_tile()

                -- Impact effect
                battle_helpers.create_effect(facing, vulcan_impact_texture, vulcan_impact_animation_path, "IMPACT",
                    -10 * 0.5, -55 * 0.5, -3, field, hit_tile, Playback.Once, true, nil)

                -- Hit particle
                battle_helpers.create_effect(facing, bullet_hit_texture, bullet_hit_animation_path, "HIT",
                    math.random(-20, 20) * 0.5, math.random(-55, -30) * 0.5, -3, field, hit_tile, Playback.Once, true,
                    nil)

                create_vulcan_damage(user, vulcan_direction, hit_tile, hit_props)
            end)
        end

        self:add_anim_action(5, function()
            user:set_counterable(false)
        end)

        self:add_anim_action(#frames - 5, function()
            --show lag animation for last 5 overriden frames
            attachment_animation:set_state("END_" .. props.short_name)
        end)
    end
    action.on_action_end_func = function()
        user:set_counterable(false)
    end
    return action
end

function create_vulcan_damage(user, direction, tile, hit_props)
    local hit_tiles = { tile }
    if not hit_tiles[1]:is_edge() then
        hit_tiles[2] = hit_tiles[1]:get_tile(direction, 1)
    end
    for index, new_tile in ipairs(hit_tiles) do
        local spell = Spell.new(user:team())
        spell:set_hit_props(hit_props)
        spell.on_update_func = function(self)
            local current_tile = self:current_tile()
            current_tile:attack_entities(self)
            self:delete()
        end
        user:field():spawn(spell, new_tile)
    end
end

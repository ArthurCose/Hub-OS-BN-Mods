local battle_helpers = require("Battle.Helpers")
local bn_assets = require("BattleNetwork.Assets")

local attachment_texture = bn_assets.load_texture("vulcan_attachment.png")
local attachment_animation_path = bn_assets.fetch_animation_path("vulcan_attachment.animation")

local vulcan_impact_texture = bn_assets.load_texture("vulcan_impact.png")
local vulcan_impact_animation_path = bn_assets.fetch_animation_path("vulcan_impact.animation")

local bullet_hit_texture = bn_assets.load_texture("vulcan_bullet_hit.png")
local bullet_hit_animation_path = bn_assets.fetch_animation_path("vulcan_bullet_hit.animation")

local gun_sfx = bn_assets.load_audio("vulcan.ogg")

local Lib = {
    PREFIX = "VULCANDATA:",
}

---@param s string
---@param separator string
local function read_until(s, separator)
    local start_index, end_index = s:find(separator)
    return s:sub(1, start_index - 1), s:sub(end_index + 1)
end

---Parses a tag with the format `VULCANDATA:SHOTS#_ANIMATED#_STATE`
---SHOTS# is the number of attacks the vulcan performs
---ANIMATED# is the number of attacks the vulcan _seems_ to perform
---STATE is the animation state for the vulcan attachment, relevant values are "Vulcan1", "Vulcan2", "Vulcan3", "SuprVulc", and "DarkVulc"
---`*` is processed as either -infinity or infinity.
---@param tag string
---@return number shots, number shots_animated, string anim_state
function Lib.data_from_tag(tag)
    local shots, shots_animated, anim_state

    local remaining_tag = tag:sub(#Lib.PREFIX + 1)
    local value_str

    value_str, remaining_tag = read_until(remaining_tag, "_")
    shots = tonumber(string.match(value_str, "%d+")) or 3

    value_str, remaining_tag = read_until(remaining_tag, "_")
    shots_animated = tonumber(string.match(value_str, "%d+")) or 4

    anim_state = tostring(remaining_tag) or "Vulcan1"
    print(anim_state)

    return shots, shots_animated, anim_state
end

function card_init(user, props)
    local action = Action.new(user, "CHARACTER_SHOOT")
    local shots_animated = 1
    local hits = 0
    local data

    for _, tag in ipairs(props.tags) do
        if string.find(tag, "VULCANDATA") then
            data = tag
            break
        end
    end

    if data == nil then
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
    else
        hits, shots_animated, props.short_name = Lib.data_from_tag(data)
    end

    local vulcan_direction = user:facing()
    local f_padding = { 1, 2 }
    local frames = { f_padding, f_padding, f_padding, f_padding, f_padding, f_padding, f_padding }

    local hit_props = HitProps.from_card(
        props,
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
        local facing = user:facing();
        local attachment = self:create_attachment("BUSTER")
        local attachment_sprite = attachment:sprite()
        attachment_sprite:set_texture(attachment_texture)
        attachment_sprite:set_layer(-2)
        attachment_sprite:use_root_shader()

        local attachment_animation = attachment:animation()
        attachment_animation:load(attachment_animation_path)
        attachment_animation:set_state("SPAWN_" .. props.short_name)

        user:set_counterable(true)

        self:on_anim_frame(2, function()
            attachment_animation:set_state("ATTACK_" .. props.short_name)
            attachment_animation:set_playback(Playback.Loop)
        end)

        for i = 1, hits, 1 do
            self:on_anim_frame(i * 3, function()
                Resources.play_audio(gun_sfx)
                local target = battle_helpers.get_first_target_ahead(user)
                if not target then
                    --ignore any hits beyond the first one
                    return
                end

                local hit_tile = target:current_tile()

                -- Impact effect
                battle_helpers.create_effect(facing, vulcan_impact_texture, vulcan_impact_animation_path, "IMPACT",
                    -5, -15, -3, hit_tile, Playback.Once, true, nil)

                -- Hit particle
                battle_helpers.create_effect(facing, bullet_hit_texture, bullet_hit_animation_path, "HIT",
                    math.random(-10, 10), math.random(-15, -15), -3, hit_tile, Playback.Once, true, nil)

                create_vulcan_damage(user, vulcan_direction, hit_tile, hit_props)
            end)
        end

        self:on_anim_frame(5, function()
            user:set_counterable(false)
        end)

        self:on_anim_frame(#frames - 5, function()
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
        Field.spawn(spell, new_tile)
    end
end

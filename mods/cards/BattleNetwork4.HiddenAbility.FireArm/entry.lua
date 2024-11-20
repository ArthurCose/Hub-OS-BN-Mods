local bn_assets = require("BattleNetwork.Assets")

local buster_texture = bn_assets.load_texture("bn4_buster_firearm.png")
local buster_anim_path = bn_assets.fetch_animation_path("bn4_buster_firearm.animation")

local flame_texture = bn_assets.load_texture("bn4_spell_firearm.png")
local flame_animation_path = bn_assets.fetch_animation_path("bn4_spell_firearm.animation")

local hit_texture = bn_assets.load_texture("bn6_hit_effects.png")
local hit_anim_path = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local AUDIO = bn_assets.load_audio("dragon3.ogg")

local function create_flame_spell(user, props)
    local tile = nil
    local spell = Spell.new(user:team())

    local animation = spell:animation()

    spell:set_hit_props(
        HitProps.from_card(
            props,
            user:context(),
            Drag.None
        )
    )

    spell:set_texture(flame_texture)

    animation:load(flame_animation_path)
    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Loop)

    spell:set_tile_highlight(Highlight.Solid)

    local sprite = spell:sprite()
    sprite:set_layer(-2)

    animation:apply(sprite)

    spell:set_facing(user:facing())

    spell._has_spawned = false

    spell.on_spawn_func = function(self)
        tile = self:current_tile()

        self._has_spawned = true

        if not tile:is_walkable() then return end
    end

    spell.on_collision_func = function(self, other)
        local fx = Spell.new(self:team())

        fx:set_texture(hit_texture)

        local anim = fx:animation()

        local fx_sprite = fx:sprite()

        anim:load(hit_anim_path)
        anim:set_state("FIRE")

        sprite:set_layer(-3)

        anim:apply(fx_sprite)
        anim:on_complete(function()
            fx:erase()
        end)

        self:field():spawn(fx, tile)
    end

    spell.on_update_func = function(self)
        self:current_tile():attack_entities(self)
    end
    return spell
end

local function despawn_flame(flame)
    -- Do nothing if:
    -- 1. The flame is nil;
    -- 2. The flame isn't nil but never spawned, was only created;
    -- 3. Is already deleted;
    -- 4. Will erase at the end of the current frame;
    -- These are all conditions in which erasing the flame is at best unnecessary,
    -- and at worst will throw an error in to the player's console.
    if not flame then return end
    if flame._has_spawned ~= true then return end
    if flame:deleted() then return end
    if flame:will_erase_eof() then return end

    -- Change the animation and erase on completion.
    local anim = flame:animation()
    anim:set_playback(Playback.Once)
    anim:set_state("DEFAULT")
    anim:apply(flame:sprite())
    anim:on_complete(function()
        flame:erase()
    end)
end


function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_SHOOT")
    local field = actor:field()
    local tile_array = {}
    local flame_list = {}

    local frames = { { 1, 35 } }
    action:override_animation_frames(frames)
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local self_tile = user:current_tile()
        local facing = user:facing()
        local distance = 3

        -- If it's a charged card attack.
        if props.damage > 50 then distance = 6 end

        for i = 1, distance, 1 do
            local prospective_tile = self_tile:get_tile(facing, i)
            if prospective_tile and not prospective_tile:is_edge() then
                table.insert(tile_array, prospective_tile)
            end
        end

        local buster = self:create_attachment("BUSTER")
        local buster_sprite = buster:sprite()
        buster_sprite:set_texture(user:texture())
        buster_sprite:set_layer(-2)

        buster_sprite:set_texture(buster_texture)
        buster_sprite:set_layer(-2)

        local buster_anim = buster:animation()
        buster_anim:load(buster_anim_path)
        buster_anim:set_state("SPAWN")
        buster_anim:apply(buster_sprite)

        local buster_point = user:animation():get_point("BUSTER")
        local origin = user:sprite():origin()
        local fire_x = buster_point.x - origin.x + 21 - Tile:width()
        local fire_y = buster_point.y - origin.y

        for i = 1, #tile_array, 1 do
            local flame = create_flame_spell(user, props)
            flame:set_offset(fire_x, fire_y)
            table.insert(flame_list, flame)
        end

        local time = 0
        local flame_index = 1
        local spawn_timing = 1
        local despawn_index = 1
        local despawn_timing = 25
        action.on_update_func = function()
            time = time + 1

            if time % 10 == 0 then Resources.play_audio(AUDIO) end

            if time == spawn_timing and #tile_array >= (flame_index) then
                print(flame_index)
                field:spawn(flame_list[flame_index], tile_array[flame_index])
                flame_index = flame_index + 1
                spawn_timing = spawn_timing + 4
            elseif time >= despawn_timing and #flame_list >= despawn_index then
                despawn_flame(flame_list[despawn_index])
                despawn_index = despawn_index + 1
            end
        end
    end
    action.on_action_end_func = function(self)
        for i = 1, #flame_list, 1 do
            if flame_list[i] and not flame_list[i]:deleted() then despawn_flame(flame_list[i]) end
        end
    end
    return action
end

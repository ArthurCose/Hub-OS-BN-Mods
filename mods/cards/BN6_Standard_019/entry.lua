local bn_assets = require("BattleNetwork.Assets")

local buster_texture = bn_assets.load_texture("bn6_flame_buster.png")
local buster_anim_path = bn_assets.fetch_animation_path("bn6_flame_buster.animation")

local flame_texture = bn_assets.load_texture("bn6_flame_thrower.png")
local flame_animation_path = bn_assets.fetch_animation_path("bn6_flame_thrower.animation")

local hit_texture = bn_assets.load_texture("bn6_hit_effects.png")
local hit_anim_path = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local AUDIO = bn_assets.load_audio("fireburn.ogg")

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
    animation:set_state("0")
    animation:set_playback(Playback.Loop)

    spell:set_tile_highlight(Highlight.Solid)

    local sprite = spell:sprite()
    sprite:set_layer(-2)

    animation:apply(sprite)

    spell:set_facing(user:facing())

    spell.has_spawned = false

    spell.on_spawn_func = function(self)
        tile = self:current_tile()

        self.has_spawned = true

        if not tile:is_walkable() then return end

        if tile:state() == TileState.Cracked then
            tile:set_state(TileState.Broken)
        else
            tile:set_state(TileState.Cracked)
        end
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
    -- Do nothing if the flame never appeared.
    if flame._has_spawned ~= true then return end

    -- Change the animation and erase on completion.
    local anim = flame:animation()
    anim:set_playback(Playback.Once)
    anim:set_state("1")
    anim:apply(flame:sprite())
    anim:on_complete(function()
        flame:erase()
    end)
end

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_SHOOT")
    local field = actor:field()
    local tile_array = {}
    local frames = { { 1, 35 } }
    action:override_animation_frames(frames)
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local self_tile = user:current_tile()
        local facing = user:facing()

        for i = 1, 3, 1 do
            local prospective_tile = self_tile:get_tile(facing, i)
            if prospective_tile and not prospective_tile:is_edge() then
                table.insert(tile_array, prospective_tile)
            end
        end

        local buster = self:create_attachment("BUSTER")
        local buster_sprite = buster:sprite()
        buster_sprite:set_texture(user:texture())
        buster_sprite:set_layer(-2)
        buster_sprite:use_root_shader()

        self.flame1 = create_flame_spell(user, props)
        self.flame2 = create_flame_spell(user, props)
        self.flame3 = create_flame_spell(user, props)

        buster_sprite:set_texture(buster_texture)
        buster_sprite:set_layer(-2)

        local buster_anim = buster:animation()
        buster_anim:load(buster_anim_path)
        buster_anim:set_state("0")
        buster_anim:apply(buster_sprite)

        local buster_point = user:animation():get_point("BUSTER")
        local origin = user:sprite():origin()
        local fire_x = buster_point.x - origin.x + 21 - Tile:width()
        local fire_y = buster_point.y - origin.y

        self.flame1:set_offset(fire_x, fire_y)
        self.flame2:set_offset(fire_x, fire_y)
        self.flame3:set_offset(fire_x, fire_y)

        -- spawn first flame
        Resources.play_audio(AUDIO)
        if #tile_array > 0 then
            field:spawn(self.flame1, tile_array[1])
        end

        local time = 0
        action.on_update_func = function()
            time = time + 1

            if time == 5 then
                if #tile_array > 1 then
                    -- queue spawn frame 5, should appear frame 6
                    field:spawn(self.flame2, tile_array[2])
                end
            elseif time == 9 then
                if #tile_array > 2 then
                    -- queue spawn frame 9, should appear frame 10
                    field:spawn(self.flame3, tile_array[3])
                end
            elseif time == 25 then
                despawn_flame(self.flame1)
            elseif time == 26 then
                despawn_flame(self.flame2)
            elseif time == 27 then
                despawn_flame(self.flame3)
            end
        end
    end
    action.on_action_end_func = function(self)
        if not self.flame1:deleted() then self.flame1:erase() end
        if not self.flame2:deleted() then self.flame2:erase() end
        if not self.flame3:deleted() then self.flame3:erase() end
    end
    return action
end

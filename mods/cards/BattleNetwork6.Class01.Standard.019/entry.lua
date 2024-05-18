local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local buster_texture = bn_helpers.load_texture("bn6_flame_buster.png")
local buster_anim_path = bn_helpers.fetch_animation_path("bn6_flame_buster.animation")

local flame_texture = bn_helpers.load_texture("bn6_flame_thrower.png")
local flame_animation_path = bn_helpers.fetch_animation_path("bn6_flame_thrower.animation")

local hit_texture = bn_helpers.load_texture("bn6_hit_effects.png")
local hit_anim_path = bn_helpers.fetch_animation_path("bn6_hit_effects.animation")

local function create_flame_spell(user, props)
    local tile = nil
    local spell = Spell.new(user:team())

    local animation = spell:animation()

    spell:set_hit_props(
        HitProps.new(
            props.damage,
            props.hit_flags,
            props.element,
            props.secondary_element,
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

    spell:set_elevation(user:animation():get_point("BUSTER").y)

    animation:apply(sprite)

    spell:set_facing(user:facing())

    spell.has_spawned = false


    spell.on_spawn_func = function(self)
        tile = self:current_tile()
        self.has_spawned = true
        if tile:is_walkable() then
            if tile:state() == TileState.Cracked then
                tile:set_state(TileState.Broken)
            else
                tile:set_state(TileState.Cracked)
            end
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



function card_init(actor, props)
    local action = Action.new(actor, "PLAYER_SHOOTING")
    local field = actor:field()
    local frame1 = { 1, 1 }
    local frame2 = { 1, 3 }
    local frame3 = { 2, 2 }
    local tile_array = {}
    local AUDIO = Resources.load_audio("sfx.ogg")
    local frames = { frame1,
        frame2, frame3, frame2, frame3, frame2, frame3, frame2, frame2, frame3, frame2, frame2, frame3, frame2,
        frame2, frame3, frame2, frame3, frame2, frame3, frame2, frame2, frame3, frame2, frame2, frame3, frame2,
        frame2, frame3, frame2, frame3, frame2, frame3, frame2, frame2, frame3, frame2, frame2, frame3, frame2
    }
    action:override_animation_frames(frames)
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local self_tile = user:current_tile()
        local y = self_tile:y()
        local x = self_tile:x()
        local increment = 1
        if user:facing() == Direction.Left then increment = -1 end
        for i = 1, 3, 1 do
            local prospective_tile = field:tile_at(x + (i * increment), y)
            if prospective_tile and not prospective_tile:is_edge() then
                table.insert(tile_array, prospective_tile)
            end
        end
        local get_point = user:animation():get_point("BUSTER")
        local buster = self:create_attachment("BUSTER")
        local buster_sprite = buster:sprite()
        buster_sprite:set_texture(user:texture())
        buster_sprite:set_layer(-2)

        self.flame1 = create_flame_spell(user, props)
        self.flame2 = create_flame_spell(user, props)
        self.flame3 = create_flame_spell(user, props)

        local buster_anim = buster:animation()
        buster_anim:copy_from(user:animation())
        buster_anim:set_state("BUSTER")
        buster_anim:apply(buster_sprite)

        self:add_anim_action(1, function()
            buster_sprite:set_texture(buster_texture)
            buster_sprite:set_layer(-2)

            buster_anim:load(buster_anim_path)
            buster_anim:set_state("0")
            buster_anim:apply(buster_sprite)
        end)
        self:add_anim_action(5, function()
            Resources.play_audio(AUDIO)
            if #tile_array > 0 then
                field:spawn(self.flame1, tile_array[1])
            end
        end)

        self:add_anim_action(9, function()
            if #tile_array > 1 then
                field:spawn(self.flame2, tile_array[2])
            end
        end)

        self:add_anim_action(13, function()
            if #tile_array > 2 then
                field:spawn(self.flame3, tile_array[3])
            end
        end)

        self:add_anim_action(32, function()
            if self.flame1.has_spawned then
                self.flame1:animation():set_state("1")
                self.flame1:animation():apply(self.flame1:sprite())
                self.flame1:animation():on_complete(function()
                    self.flame1:erase()
                end)
            end
        end)

        self:add_anim_action(36, function()
            if self.flame2.has_spawned then
                self.flame2:animation():set_state("1")
                self.flame2:animation():apply(self.flame2:sprite())
                self.flame2:animation():on_complete(function()
                    self.flame2:erase()
                end)
            end
        end)

        self:add_anim_action(40, function()
            if self.flame3.has_spawned then
                self.flame3:animation():set_state("1")
                self.flame3:animation():apply(self.flame3:sprite())
                self.flame3:animation():on_complete(function()
                    self.flame3:erase()
                end)
            end
        end)
    end
    action.on_action_end_func = function(self)
        if not self.flame1:deleted() then self.flame1:erase() end
        if not self.flame2:deleted() then self.flame2:erase() end
        if not self.flame3:deleted() then self.flame3:erase() end
    end
    return action
end

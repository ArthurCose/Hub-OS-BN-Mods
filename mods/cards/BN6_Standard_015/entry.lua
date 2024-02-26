local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local gunhilt_texture = bn_helpers.load_texture("gun_del_sol_buster.png")
local gunhilt_anim_path = bn_helpers.fetch_animation_path("gun_del_sol_buster.animation")
local sunray_texture = bn_helpers.load_texture("gun_del_sol_ray.png")
local sunray_anim_path = bn_helpers.fetch_animation_path("gun_del_sol_ray.animation")
local sun_noise = bn_helpers.load_audio("gundel_3.ogg")

function card_init(actor, props)
    local frame_wait = 0
    if props.short_name == "GunDelS1" then
        frame_wait = 74
    elseif props.short_name == "GunDelS2" then
        frame_wait = 104
    else
        frame_wait = 134
    end

    -- Wait 8 frames, then stay posed for the attack depending on which chip is used.
    local STARTUP = { 1, 8 }
    local THE_REST = { 1, frame_wait }

    local FRAMES = { STARTUP, THE_REST }

    local action = Action.new(actor, "PLAYER_SHOOTING")
    action:set_lockout(ActionLockout.new_animation())

    action:override_animation_frames(FRAMES)

    action.on_execute_func = function(self, user)
        local buster = self:create_attachment("BUSTER")
        buster:sprite():set_texture(gunhilt_texture, true)
        buster:sprite():set_layer(-1)

        local buster_anim = buster:animation()
        buster_anim:load(gunhilt_anim_path)
        buster_anim:set_state("SPAWN_" .. props.short_name)
        buster_anim:apply(buster:sprite())
        buster_anim:set_playback(Playback.Once)

        buster_anim:on_complete(function()
            buster_anim:set_state("LOOP_" .. props.short_name)
            buster_anim:apply(buster:sprite())
            buster_anim:set_playback(Playback.Loop)
        end)

        action:add_anim_action(2, function()
            self.ray_of_sun = summon_sun(user, props, frame_wait)
            local tile = user:get_tile(user:facing(), 2)
            actor:field():spawn(self.ray_of_sun, tile)
        end)
    end
    action.on_action_end_func = function(self)
        if self.ray_of_sun and not self.ray_of_sun:deleted() then self.ray_of_sun:erase() end
    end
    return action
end

function summon_sun(user, props, frame_wait)
    local spell = Spell.new(user:team())

    spell.framedata = 0
    spell.frame_limit = frame_wait - 14

    local sun_noise_countdown = 0

    spell:set_facing(user:facing())
    spell:set_texture(sunray_texture)

    local spell_sprite = spell:sprite()

    local anim = spell:animation()
    anim:load(sunray_anim_path)

    if props.short_name == "GunDelEX" then
        anim:set_state("OUTDOORS_EX")
    else
        anim:set_state("OUTDOORS")
    end

    anim:set_playback(Playback.Loop)
    anim:apply(spell_sprite)

    spell_sprite:set_layer(-3)

    spell.on_update_func = function(self)
        if self.framedata > self.frame_limit then
            self:delete()
        else
            if self.framedata > 0 then
                local call_hit = spell_damage_summon(self, props)
                local tile = user:get_tile(user:facing(), 2)
                user:field():spawn(call_hit, tile)
                if sun_noise_countdown <= 0 then
                    Resources.play_audio(sun_noise, AudioBehavior.Default)
                    sun_noise_countdown = 15
                end
                sun_noise_countdown = sun_noise_countdown - 1
            end
        end
        self.framedata = self.framedata + 1
    end


    spell.can_move_to_func = function(self, other)
        return true
    end

    return spell
end

function spell_damage_summon(user, props)
    local spell_damage = Spell.new(user:team())

    spell_damage.facing = user:facing()

    spell_damage.second_row = false
    if props.short_name == "GunDelEX" then spell_damage.second_row = true end

    spell_damage.obstacle_finder = function(o)
        if not o then return false end
        if not o:hittable() then return false end
        return true
    end

    spell_damage:set_hit_props(
        HitProps.new(
            4,
            props.hit_flags,
            props.element,
            props.secondary_element,
            user:context(),
            Drag.None
        )
    )

    spell_damage.on_update_func = function(self)
        local own_tile = self:current_tile() --Dawn: get the tile this entity is on
        if not own_tile or own_tile and own_tile:is_edge() then
            self:erase()
            return;
        else
            own_tile:set_highlight(Highlight.Flash)
            own_tile:attack_entities(self)
        end

        local up_tile = own_tile:get_tile(Direction.Up, 1) --Dawn: get the tile above
        if up_tile and not up_tile:is_edge() then
            up_tile:set_highlight(Highlight.Flash)
            up_tile:attack_entities(self)
        end

        local down_tile = own_tile:get_tile(Direction.Down, 1) --Dawn: get the tile below
        if down_tile and not down_tile:is_edge() then
            down_tile:set_highlight(Highlight.Flash)
            down_tile:attack_entities(self)
        end

        if self.second_row == true then
            local forward_tile = own_tile:get_tile(self.facing, 1)
            if forward_tile and not forward_tile:is_edge() then
                forward_tile:set_highlight(Highlight.Flash)
                forward_tile:attack_entities(self)
            end

            local forward_up_tile = own_tile:get_tile(Direction.join(Direction.Up, self.facing), 1)
            if forward_up_tile and not forward_up_tile:is_edge() then
                forward_up_tile:set_highlight(Highlight.Flash)
                forward_up_tile:attack_entities(self)
            end

            local forward_down_tile = own_tile:get_tile(Direction.join(Direction.Down, self.facing), 1)
            if forward_down_tile and not forward_down_tile:is_edge() then
                forward_down_tile:set_highlight(Highlight.Flash)
                forward_down_tile:attack_entities(self)
            end
        end
        self:erase()
    end

    return spell_damage
end

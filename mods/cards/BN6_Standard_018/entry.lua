local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local buster_texture = bn_helpers.load_texture("yoyo_buster.png")
local yoyo_texture = bn_helpers.load_texture("yoyo_projectile.png")

local buster_animation_path = bn_helpers.fetch_animation_path("yoyo_buster.animation")
local yoyo_animation_path = bn_helpers.fetch_animation_path("yoyo_projectile.animation")

local yoyo_sfx = bn_helpers.load_audio("yoyo_sfx.ogg")
local hit_sfx = bn_helpers.load_audio("hit_impact.ogg")

function card_init(user, props)
    local action = Action.new(user, "PLAYER_SHOOTING")

    action:set_lockout(ActionLockout.new_async(60))
    local FRAMES = { { 1, 1 }, { 1, 4 }, { 1, 7 }, { 1, 2 }, { 1, 26 }, { 1, 7 }, { 1, 7 }, { 1, 7 }, { 1, 2 } }
    action:override_animation_frames(FRAMES)

    action.on_execute_func = function(self, user)
        local buster_attachment = self:create_attachment("BUSTER")
        local buster_sprite = buster_attachment:sprite()
        buster_sprite:set_texture(buster_texture)
        buster_sprite:set_layer(-2)

        local buster_animation = buster_attachment:animation()
        buster_animation:load(buster_animation_path)
        buster_animation:set_state("DEFAULT")

        self:add_anim_action(1, function()
            user:set_counterable(true);
        end)

        self:add_anim_action(2, function()
            local attack = create_attack(user, props)
            Resources.play_audio(yoyo_sfx, AudioBehavior.Default)
            local tile = user:current_tile()
            user:field():spawn(attack, tile)
        end)

        self:add_anim_action(5, function()
            user:set_counterable(false);
        end)
    end

    return action
end

function create_attack(owner, props)
    local team = owner:team()
    local facing = owner:facing()

    local spell = Spell.new(team)

    spell:set_facing(facing)

    spell:set_hit_props(
        HitProps.new(
            props.damage,
            props.hit_flags,
            props.element,
            props.secondary_element,
            owner:context(),
            Drag.None
        )
    )

    local sprite = spell:sprite()
    sprite:set_texture(yoyo_texture)

    local animation = spell:animation()
    animation:load(yoyo_animation_path)
    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Loop)

    spell:set_elevation(owner:animation():get_point("BUSTER").y)

    animation:apply(sprite)

    spell.can_move_to_func = function(tile)
        return true
    end

    spell.on_attack_func = function()
        Resources.play_audio(hit_sfx, AudioBehavior.Default)
    end

    spell.on_delete_func = function(self)
        -- local fx = Explosion.new(1, 1.0)
        -- self:field():spawn(fx, self:current_tile())
        self:erase()
    end

    spell.activity_timer = 0
    spell.destination_tile = owner:get_tile(facing, 1)
    spell.slide_timer = 1
    spell.wait_timer = 0
    spell.wait_timer_goal = 26
    spell.tiles_passed = 0
    spell.delete_self = false
    spell.facing = facing

    spell.on_update_func = function(self)
        if self.tiles_passed == 3 then
            if self.delete_self == true then
                self:erase()
            else
                if self.wait_timer % 13 == 0 then
                    self:current_tile():attack_entities(self)
                end

                self.wait_timer = self.wait_timer + 1

                if self.wait_timer >= self.wait_timer_goal then
                    self.tiles_passed = -1
                    self.delete_self = true;
                    self.facing = Direction.reverse(self.facing)
                    self.destination_tile = self.destination_tile:get_tile(self.facing, 1)
                end
            end
        else
            if self.activity_timer % self.slide_timer == 0 then
                self:current_tile():attack_entities(self)
            end
            self:slide(self.destination_tile, self.slide_timer, function()
                if self.slide_timer == 1 then
                    self.slide_timer = 4
                else
                    self.slide_timer = 7
                end

                self.tiles_passed = self.tiles_passed + 1

                self.destination_tile = self.destination_tile:get_tile(self.facing, 1)
            end)
        end
        self.activity_timer = self.activity_timer + 1
    end

    return spell
end

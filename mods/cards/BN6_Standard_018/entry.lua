local bn_helpers = require("BattleNetwork.Assets")

local buster_texture = bn_helpers.load_texture("yoyo_buster.png")
local yoyo_texture = bn_helpers.load_texture("yoyo_projectile.png")

local buster_animation_path = bn_helpers.fetch_animation_path("yoyo_buster.animation")
local yoyo_animation_path = bn_helpers.fetch_animation_path("yoyo_projectile.animation")

local yoyo_sfx = bn_helpers.load_audio("yoyo_sfx.ogg")

function card_init(user, props)
    local action = Action.new(user, "CHARACTER_SHOOT")

    action:set_lockout(ActionLockout.new_async(60))
    local FRAMES = { { 1, 1 }, { 1, 4 }, { 1, 7 }, { 1, 2 }, { 1, 26 }, { 1, 7 }, { 1, 7 }, { 1, 7 }, { 1, 2 } }
    action:override_animation_frames(FRAMES)

    action.on_execute_func = function(self, user)
        local buster_attachment = self:create_attachment("BUSTER")
        local buster_sprite = buster_attachment:sprite()
        buster_sprite:set_texture(buster_texture)
        buster_sprite:set_layer(-2)
        buster_sprite:use_root_shader()

        local buster_animation = buster_attachment:animation()
        buster_animation:load(buster_animation_path)
        buster_animation:set_state("DEFAULT")

        self:add_anim_action(1, function()
            user:set_counterable(true)
        end)

        self:add_anim_action(2, function()
            local attack = create_attack(user, props)
            Resources.play_audio(yoyo_sfx, AudioBehavior.Default)
            local tile = user:get_tile(user:facing(), 1)

            if tile then
                Field.spawn(attack, tile)
            end
        end)

        self:add_anim_action(5, function()
            user:set_counterable(false)
        end)
    end

    action.on_action_end_func = function()
        user:set_counterable(false)
    end

    return action
end

---@param owner Entity
---@param props CardProperties
function create_attack(owner, props)
    local team = owner:team()
    local facing = owner:facing()

    local spell = Spell.new(team)
    spell:set_facing(facing)
    spell:set_hit_props(
        HitProps.from_card(props, owner:context())
    )

    local sprite = spell:sprite()
    sprite:set_texture(yoyo_texture)

    local animation = spell:animation()
    animation:load(yoyo_animation_path)
    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Loop)
    animation:apply(sprite)

    local activity_timer = 0
    local slide_timer = 8
    local wait_timer = 0
    local wait_timer_goal = 20
    local tiles_passed = 0
    local lost_tiles = 0
    local returning = false
    local direction = facing

    local disabled = false

    spell.on_collision_func = function()
        disabled = true
    end

    spell.on_update_func = function(self)
        if activity_timer % slide_timer == 0 then
            disabled = false
        end

        if not disabled then
            local tile = self:current_tile()
            tile:attack_entities(self)
            tile:set_highlight(Highlight.Solid)
        end

        if self:is_moving() then
            return
        end


        if tiles_passed == 2 then
            if returning == true then
                self:erase()
                return
            end

            wait_timer = wait_timer + 1

            if wait_timer >= wait_timer_goal then
                tiles_passed = lost_tiles
                returning = true
                direction = Direction.reverse(direction)
            end
        else
            local destination_tile = self:get_tile(direction, 1)

            if not destination_tile then
                destination_tile = self:current_tile()
                lost_tiles = lost_tiles + 1
            end

            self:slide(destination_tile, slide_timer)
            tiles_passed = tiles_passed + 1
        end

        activity_timer = activity_timer + 1
    end

    return spell
end

local debug = false

local attachment_texture = Resources.load_texture("attachment.png")
local attachment_animation_path = "attachment.animation"
local explosion_texture = Resources.load_texture("explosion.png")
local explosion_animation_path = "explosion.animation"
local throw_sfx = Resources.load_audio("toss_item.ogg")

function debug_print(text)
    if debug then
        print("[minibomb] " .. text)
    end
end

local bomb = {
    name = "MiniBomb",
    damage = 50,
    element = Element.None,
    description = "Throws a MiniBomb 3sq ahead",
    codes = { "B", "L", "R", "*" }
}

bomb.card_init = function(user, props)
    local action = Action.new(user, "CHARACTER_THROW")
    action:set_lockout(ActionLockout.new_animation())
    local override_frames = { { 1, 4 }, { 2, 4 }, { 3, 4 }, { 4, 4 }, { 5, 4 } }
    local frame_data = override_frames
    action:override_animation_frames(frame_data)

    local hit_props = HitProps.new(
        10,
        Hit.Flinch | Hit.Flash,
        props.element,
        user:context(),
        Drag.None
    )

    action.on_execute_func = function(self, user)
        --local props = self:copy_metadata()
        local attachment = self:create_attachment("HAND")
        local attachment_sprite = attachment:sprite()
        attachment_sprite:set_texture(attachment_texture)
        attachment_sprite:set_layer(-2)

        local attachment_animation = attachment:animation()
        attachment_animation:load(attachment_animation_path)
        attachment_animation:set_state("0")
        attachment_animation:set_playback(Playback.Loop)

        user:set_counterable(true)
        self:add_anim_action(3, function()
            attachment_sprite:hide()
            --self.remove_attachment(attachment)
            local tiles_ahead = 3
            local frames_in_air = 40
            local toss_height = 70
            local facing = user:facing()
            local target_tile = user:get_tile(facing, tiles_ahead)
            if not target_tile then
                return
            end
            action.on_landing = function()
                if target_tile:is_walkable() then
                    hit_explosion(user, target_tile, hit_props, explosion_texture, explosion_animation_path)
                end
            end
            toss_spell(user, toss_height, attachment_texture, attachment_animation_path, target_tile, frames_in_air,
                action.on_landing)
        end)
        self:add_anim_action(4, function()
            user:set_counterable(false)
        end)
        self.on_action_end_func = function()
            user:set_counterable(false)
        end

        Resources.play_audio(throw_sfx)
    end
    return action
end

function toss_spell(tosser, toss_height, texture, animation_path, target_tile, frames_in_air, arrival_callback)
    local starting_height = -110
    local start_tile = tosser:current_tile()
    local spell = Spell.new(tosser:team())
    local spell_animation = spell:animation()
    spell_animation:load(animation_path)
    spell_animation:set_state("DEFAULT")
    if tosser:height() > 1 then
        starting_height = -(tosser:height() * 2)
    end

    spell.jump_started = false
    spell.starting_y_offset = starting_height
    spell.starting_x_offset = 10
    if tosser:facing() == Direction.Left then
        spell.starting_x_offset = -10
    end
    spell.y_offset = spell.starting_y_offset
    spell.x_offset = spell.starting_x_offset
    local sprite = spell:sprite()
    sprite:set_texture(texture)
    spell:set_offset(spell.x_offset * 0.5, spell.y_offset * 0.5)

    spell.on_update_func = function(self)
        if not spell.jump_started then
            self:jump(target_tile, toss_height, (frames_in_air), (frames_in_air))
            self.jump_started = true
        end
        if self.y_offset < 0 then
            self.y_offset = self.y_offset + math.abs(self.starting_y_offset / frames_in_air)
            self.x_offset = self.x_offset - math.abs(self.starting_x_offset / frames_in_air)
            self:set_offset(self.x_offset * 0.5, self.y_offset * 0.5)
        else
            arrival_callback()
            self:delete()
        end
    end
    spell.can_move_to_func = function(tile)
        return true
    end
    Field.spawn(spell, start_tile)
end

function hit_explosion(user, target_tile, props, texture, anim_path)
    local spell = Spell.new(user:team())
    local whirlpool = Spell.new(user:team())
    whirlpool:set_texture(explosion_texture)
    local whirly_animation = whirlpool:animation()
    whirly_animation:load(explosion_animation_path)
    whirly_animation:set_state("0")
    whirly_animation:apply(whirlpool:sprite())
    whirlpool.cooldown = 999
    whirly_animation:on_complete(function()
        whirly_animation:set_state("1")
        whirly_animation:set_playback(Playback.Loop)
        whirlpool.cooldown = 120
    end)
    whirlpool.is_erasing = false
    whirlpool.on_update_func = function(self)
        self:get_tile():attack_entities(self)
        if self.cooldown <= 0 and not self.is_erasing then
            self.is_erasing = true
            local anim = self:animation()
            anim:set_state("2")
            anim:on_complete(function()
                self:erase()
            end)
        else
            self.cooldown = self.cooldown - 1
        end
    end
    local query = function(ent)
        return Obstacle.from(ent) ~= nil or Character.from(ent) ~= nil
    end
    whirlpool.spawned_hitbox = false
    whirlpool.on_attack_func = function(self, other)
        local hitbox_damage = 400
        local hitbox = Hitbox.new(self:team())
        if Player.from(other) then hitbox_damage = math.min(400, math.floor(other:max_health() * 0.25)) end
        hitbox:set_hit_props(
            HitProps.new(
                hitbox_damage,
                Hit.Flinch | Hit.Flash,
                props.element,
                nil,
                Drag.None
            )
        )
        if not self.spawned_hitbox then
            Field.spawn(hitbox, whirlpool:current_tile())
            self.spawned_hitbox = true
        end
        self:erase()
    end
    spell:set_hit_props(props)
    spell.has_attacked = false
    spell.on_update_func = function(self)
        if not spell.has_attacked then
            spell:current_tile():attack_entities(self)
            spell.has_attacked = true
            if #target_tile:find_entities(query) == 0 then
                Field.spawn(whirlpool, target_tile)
            end
            self:erase()
        end
    end
    Field.spawn(spell, target_tile)
end

return bomb

local attachment_texture = Resources.load_texture("attachment.png")
local attachment_animation_path = "attachment.animation"

local ice_tower_texture = Resources.load_texture("freezebomb/frost_tower.png")
local ice_animation_path = "freezebomb/frost_tower.animation"

local explosion_sfx = Resources.load_audio("explosion.ogg")
local throw_sfx = Resources.load_audio("toss_item.ogg")

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_THROW")
    local override_frames = { { 1, 4 }, { 2, 4 }, { 3, 4 }, { 4, 4 }, { 5, 4 } }
    local frame_data = override_frames

    action:override_animation_frames(frame_data)
    action:set_lockout(ActionLockout.new_animation())

    local hit_props = HitProps.new(
        props.damage,
        props.hit_flags,
        props.element,
        actor:context(),
        Drag.None
    )

    action.on_execute_func = function(self, user)
        local attachment = self:create_attachment("HAND")
        local attachment_sprite = attachment:sprite()
        attachment_sprite:set_texture(attachment_texture)
        attachment_sprite:set_layer(-2)

        local attachment_animation = attachment:animation()
        attachment_animation:load(attachment_animation_path)
        attachment_animation:set_state("DEFAULT")

        self:add_anim_action(3, function()
            attachment_sprite:hide()
            --self.remove_attachment(attachment)
            local tiles_ahead = 3
            local frames_in_air = 40
            local toss_height = 70
            local facing = user:facing()
            local target_tile = user:get_tile(facing, tiles_ahead)

            if not target_tile then return end

            action.on_landing = function()
                if target_tile:is_walkable() then
                    hit_explosion(user, target_tile, hit_props, ice_tower_texture, ice_animation_path, explosion_sfx)
                end
            end

            toss_spell(user, toss_height, attachment_texture, attachment_animation_path, target_tile, frames_in_air,
                action.on_landing)

            Resources.play_audio(throw_sfx)
        end)
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
        starting_height = -(tosser:height() + 40)
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

function hit_explosion(user, target_tile, props, texture, anim_path, explosion_sound)
    local spell = Spell.new(user:team())

    local spell_animation = spell:animation()
    spell_animation:load(anim_path)
    spell_animation:set_state("DEFAULT")
    local sprite = spell:sprite()
    sprite:set_texture(texture)
    spell_animation:apply(sprite)
    sprite:set_layer(-2)
    spell_animation:on_complete(function()
        spell:erase()
    end)

    spell:set_hit_props(props)
    spell.has_attacked = false
    spell.on_update_func = function(self)
        if not spell.has_attacked then
            Resources.play_audio(explosion_sound)
            spell:current_tile():attack_entities(self)
            spell.has_attacked = true
        end
    end

    spell.on_attack_func = function(self, other)
        local freeze_prop = AuxProp.new()
            :apply_status(Hit.Freeze, 30)
            :immediate()

        other:add_aux_prop(freeze_prop)
    end


    Field.spawn(spell, target_tile)
end

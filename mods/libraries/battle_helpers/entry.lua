--Functions for easy reuse in scripts
--Version 1.7 (fixed find targets ahead getting non character/obstacles)

local battle_helpers = {}

function battle_helpers.find_all_enemies(user)
    local field = user:field()
    local user_team = user:team()
    local list = field:find_characters(function(character)
        if character:team() ~= user_team then
            --if you are not with me, you are against me
            return true
        end
    end)
    return list
end

function battle_helpers.find_targets_ahead(user)
    local field = user:field()
    local user_tile = user:current_tile()
    local user_team = user:team()
    local user_facing = user:facing()
    local list = field:find_entities(function(entity)
        if Character.from(entity) == nil and Obstacle.from(entity) == nil then
            return false
        end
        local entity_tile = entity:current_tile()
        if entity_tile:y() == user_tile:y() and entity:team() ~= user_team then
            if user_facing == Direction.Left then
                if entity_tile:x() < user_tile:x() then
                    return true
                end
            elseif user_facing == Direction.Right then
                if entity_tile:x() > user_tile:x() then
                    return true
                end
            end
            return false
        end
    end)
    return list
end

function battle_helpers.get_first_target_ahead(user)
    local facing = user:facing()
    local targets = battle_helpers.find_targets_ahead(user)
    table.sort(targets, function(a, b)
        return a:current_tile():x() > b:current_tile():x()
    end)
    if #targets == 0 then
        return nil
    end
    if facing == Direction.Left then
        return targets[1]
    else
        return targets[#targets]
    end
end

function battle_helpers.drop_trace_fx(target_artifact, lifetimems)
    --drop an afterimage artifact mimicking the appearance of an existing spell/artifact/character and fade it out over it's lifetimems
    local fx = Artifact.new()
    local anim = target_artifact:animation()
    local field = target_artifact:field()
    local offset = target_artifact:offset()
    local texture = target_artifact:texture()
    local elevation = target_artifact:elevation()
    fx:set_facing(target_artifact:facing())
    fx:set_texture(texture, true)
    fx:animation():copy_from(anim)
    fx:animation():set_state(anim:state())
    fx:set_offset(offset.x * 0.5, offset.y * 0.5)
    fx:set_elevation(elevation)
    fx:animation():apply(fx:sprite())
    fx.starting_lifetimems = lifetimems
    fx.lifetimems = lifetimems
    fx.on_update_func = function(self)
        self.lifetimems = math.max(0, self.lifetimems - math.floor((1 / 60) * 1000))
        local alpha = math.floor((fx.lifetimems / fx.starting_lifetimems) * 255)
        self:set_color(Color.new(0, 0, 0, alpha))

        if self.lifetimems == 0 then
            self:erase()
        end
    end

    local tile = target_artifact:current_tile()
    field:spawn(fx, tile:x(), tile:y())
    return fx
end

function battle_helpers.create_effect(effect_facing, effect_texture, effect_animpath, effect_state, offset_x, offset_y,
                                      offset_layer,
                                      field, tile,
                                      playback, erase,
                                      move_function)
    local hitfx = Artifact.new()
    hitfx:set_facing(effect_facing)
    hitfx:set_texture(effect_texture)
    hitfx:set_offset(offset_x * 0.5, offset_y * 0.5)
    local hitfx_sprite = hitfx:sprite()
    hitfx_sprite:set_layer(offset_layer)
    local hitfx_anim = hitfx:animation()
    hitfx_anim:load(effect_animpath)
    hitfx_anim:set_state(effect_state)
    hitfx_anim:apply(hitfx_sprite)
    hitfx_anim:set_playback(playback)

    if move_function ~= nil then
        hitfx.can_move_to_func = move_function
    end

    if erase then
        hitfx_anim:on_complete(function()
            hitfx:erase()
        end)
    end

    field:spawn(hitfx, tile)

    return hitfx
end

return battle_helpers

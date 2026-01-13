local RapidBuster = require("rapid_buster.lua")

function augment_init(augment)
    local owner = augment:owner()

    augment:set_charge_with_shoot(false)

    local rapid_buster_component = owner:create_component(Lifetime.ActiveBattle)
    local timer = 0

    local function movement_check()
        local motion_x = 0
        local motion_y = 0

        if owner:input_has(Input.Held.Left) or owner:input_has(Input.Pressed.Left) then
            motion_x = motion_x - 1
        end

        if owner:input_has(Input.Held.Right) or owner:input_has(Input.Pressed.Right) then
            motion_x = motion_x + 1
        end

        if owner:input_has(Input.Held.Up) or owner:input_has(Input.Pressed.Up) then
            motion_y = motion_y - 1
        end

        if owner:input_has(Input.Held.Down) or owner:input_has(Input.Pressed.Down) then
            motion_y = motion_y + 1
        end

        if owner:team() == Team.Blue then
            motion_x = -motion_x
        end

        if (motion_x ~= 0 and owner:can_move_to(owner:get_tile(Direction.Right, motion_x))) or (motion_y ~= 0 and owner:can_move_to(owner:get_tile(Direction.Down, motion_y))) then
            return true
        end

        return false
    end

    rapid_buster_component.on_update_func = function()
        if owner:is_inactionable() then return end
        if movement_check() == true then return end

        if timer > 0 then
            timer = timer - 1
            return
        end

        if owner:input_has(Input.Held.Shoot) then
            local damage = math.min(owner:attack_level(), 5)
            owner:queue_action(RapidBuster.new(owner, damage))
            timer = 5
        end
    end

    augment.normal_attack_func = function(self)
        return nil
    end

    augment.charged_attack_func = function()
        return nil
    end

    augment.on_delete_func = function()
        rapid_buster_component:eject()
    end
end

function player_init(player)
    -- Set the element of this Navi. An Element determines if they are weak to certain attacks.
    player:set_element(Element.Wind)

    -- Set the height of this Navi. This affects the display of the Battle Chip icons in combat.
    player:set_height(70.0)

    -- If desired, set a shadow for this Navi. You may use a Small, Large, or Custom shadow.
    player:set_shadow(Shadow.Small)

    -- Since we set a shadow, we must make sure we toggle it, so that it displays in combat.
    player:show_shadow(true)

    -- Save the Package IDs of the Battle Chips we will be using.
    -- This is not entirely necessary, but I feel it keeps things tidy.
    local AirShot = "BattleNetwork6.Class01.Standard.004"
    local WindRack = "BattleNetwork6.Class01.Standard.079"

    -- Load the image for the Navi's texture.
    local base_texture = Resources.load_texture("windman_EXE4.5.png")

    -- Save the animation path. Like the Package IDs above, this is not strictly necessary.
    local base_animation_path = "windman.animation"

    -- Create and store the charge effect color.
    -- Storing it as a variable like this is slightly more efficient in some cases,
    -- as sometimes you will change the color, such as when changing forms.
    local base_charge_color = Color.new(0, 128, 255, 128)

    -- Assign the Cooldown for repeat uses of this Navi's special ability.
    -- This will be used later in the code.
    local special_cooldown = 0

    -- Set the texture so that the Navi can appear.
    player:set_texture(base_texture, true)

    -- Set the animation path that the Navi will use by default.
    -- Determines animation state availability.
    -- Without this, the texture would be static and unmoving.
    player:load_animation(base_animation_path)

    -- Set the color for when a charge shot is ready.
    player:set_fully_charged_color(base_charge_color)

    -- Position charge effect.
    player:set_charge_position(4, -35)

    -- Return the action for the Navi's default attack.
    -- Determines what happens when you press B.
    player.normal_attack_func = function(self)
        -- Normal buster attack. Damage = player attack stat.
        return Buster.new(self, false, player:attack_level())
    end

    -- Return the action for a charge shot.
    -- Determines what happens when you hold B and then release.
    player.charged_attack_func = function(self)
        -- Custom charge shot; use the Battle Chip we have set as a dependency.
        local props = CardProperties.from_package(AirShot)

        -- Customize the damage.
        props.damage = (player:attack_level() * 5)

        -- Return an Action, not the CardProperties.
        return Action.from_card(self, props)
    end

    -- Return the action for when the player presses Special.
    -- This is functionally equivalent to Back + B.
    player.special_attack_func = function(self)
        -- I have given this Navi a restriction - their Special may only be used again after a Cooldown.
        -- If the Navi's Special ability is not available due to the cooldown, return nil so that they don't do anything.

        -- This allows the Operator to mash the button if they wish to do so without interrupting other options like using
        -- a different Battle Chip, moving, or firing their Normal or Charged Attack actions.
        if special_cooldown > 0 then return nil end

        -- Use a Battle Chip passed to the Navi as a Dependency again.
        local props = CardProperties.from_package(WindRack)

        -- Customize the damage.
        props.damage = 50

        -- Reset the cooldown.
        special_cooldown = 180
        -- Return the Action, just like before.
        return Action.from_card(self, props)
    end

    -- Every time the player updates, this runs.
    player.on_update_func = function(self)
        -- Decrement the cooldown for using the Navi's special abiity.
        if special_cooldown > 0 then special_cooldown = special_cooldown - 1 end
    end

    -- Determines whether or not a Navi can "charge" a Battle Chip for an additional effect.
    player.can_charge_card_func = function(card_properties)
        -- The Navi cannot charge the Battle Chip if the Battle Chip stops time.
        if card_properties.time_freeze == true then return false end

        -- The Navi cannot charge the Battle Chip if the Battle Chip does no damage.
        if card_properties.damage == 0 then return false end

        -- If the Primary or Secondary Element of the Battle Chip is the Wind Element,
        -- then given other criteria are met, the Battle Chip may be charged by this Navi.
        return card_properties.element == Element.Wind or card_properties.secondary_element == Element.Wind
    end

    -- Determines what happens when a Battle Chip is successfully "charged" by a Navi.
    player.charged_card_func = function(self, card_properties)
        -- Increase the damage by one stage.
        card_properties.damage = card_properties.damage + card_properties.damage

        -- Return the Action with the alterations from "charging" the Battle Chip.
        return Action.from_card(self, card_properties)
    end
end

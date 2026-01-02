function player_init(player)
    player:set_name("Searchman")
    player:set_height(52.0)
    player:set_charge_position(0, -30)

    local base_animation_path = "battle.animation"
    local base_texture = Resources.load_texture("battle.png")

    player:load_animation(base_animation_path)
    player:set_texture(base_texture)
    player:set_fully_charged_color(Color.new(0, 128, 0, 255))

    local cursor = nil

    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        local enemy_filter = function(character)
            return character:team() ~= player:team() and character:hittable()
        end

        --Find an enemy to attack.
        local enemy_list = Field.find_nearest_characters(player, enemy_filter)

        --If no foe exists, use a regular buster attack
        if #enemy_list == 0 then return Buster.new(player, false, player:attack_level() * 10) end

        local action = Action.new(player, "RIFLE FIRE")

        action.on_execute_func = function(self, user)
            --Assign the cursor to the player for later erasure
            cursor = create_cursor(player)
            --Play the sound.
            Resources.play_audio(Resources.load_audio("BN5_Lockon.ogg"))
            local target = enemy_list[1]
            local tile = target:current_tile()
            --Spawn the cursor.
            Field.spawn(cursor, target:current_tile())
            --Hit Props are necessary to deal damage.
            local damage_props = HitProps.new(
                10 + (player:attack_level() * 2),         --This is the actual damage amount.
                Hit.Flinch | Hit.Flash | Hit.PierceInvis, --The flags used. Flinch makes them reel back, Flash makes them mercy invulnerable, and Pierce ignores mercy invuln.
                Element.None,                             --The element.
                player:context(),                         --Used for stuff like knowing who fired the attack.
                Drag.None                                 --Does it move you when it hits? In this case, no.
            )
            local gun = Resources.load_audio("gun.ogg")
            --This feels silly, but it works, so what's really silly here?
            --In the Searchman animation file I cloned the firing frames.
            --So from frames 2 to 10 there's just him shooting.
            --Which means every even frame (2, 4, 6, 8, 10) I need to spawn a bullet.
            --Thus, I can loop over starting at frame 2 and spawn the shot instead of repeating code.
            for i = 2, 10, 2 do
                self:on_anim_frame(i, function()
                    --Play the gun sound.
                    Resources.play_audio(gun)
                    --If the target exists, spawn the hitbox. We don't want to spawn it otherwise.
                    --That's because the hitbox will linger and hit something else.
                    if not target:deleted() then
                        --Make it our team.
                        local hitbox = Hitbox.new(user:team())
                        --Use the props.
                        hitbox:set_hit_props(damage_props)
                        --Spawn it!
                        Field.spawn(hitbox, tile)
                    end
                end)
            end

            action.on_action_end_func = function(self)
                if cursor == nil then return end

                cursor:erase() --Erase the cursor if interrupted or action finishes
            end
        end

        return action
    end
end

function create_cursor(player)
    local cursor = Spell.new(player:team())
    cursor:set_texture(Resources.load_texture("cursor.png"))
    local anim = cursor:animation()
    anim:load("cursor.animation")
    cursor:sprite():set_layer(-5)
    cursor:set_offset(0, -10)
    anim:set_state("0")
    anim:apply(cursor:sprite())
    anim:set_playback(Playback.Loop)
    return cursor
end

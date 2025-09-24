---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local doll_texture = bn_assets.load_texture("vdoll.png")
local doll_anim_path = bn_assets.fetch_animation_path("vdoll.animation")

local pointer_texture = bn_assets.load_texture("pointer.png")
local pointer_anim_path = bn_assets.fetch_animation_path("pointer.animation")
local pointer_audio = bn_assets.load_audio("indicate.ogg")

local explosion_texture = bn_assets.load_texture("bn4_spell_explosion.png")
local explosion_anim_path = bn_assets.fetch_animation_path("bn4_spell_explosion.animation")
local explosion_sfx = bn_assets.load_audio("explosion_defeatedmob.ogg")

local pointer_animation = Animation.new(pointer_anim_path)

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(doll_texture)
bomb:set_bomb_animation_path(doll_anim_path)
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

bomb:set_bomb_animation_state("IDLE")
bomb:set_bomb_held_animation_state("IDLE")

bomb:set_air_duration(67)

---@param user Entity
function card_init(user, props)
    return bomb:create_action(user, function(main_tile)
        if not main_tile or not main_tile:is_walkable() then
            return
        end

        local doll = Obstacle.new(Team.Other)
        local doll_immunities = Hit.Flash | Hit.Freeze | Hit.Paralyze | Hit.Blind | Hit.Confuse

        local status_immunity_aux = AuxProp.new()
            :declare_immunity(doll_immunities)

        doll:add_aux_prop(status_immunity_aux)

        doll:set_owner(user:team())

        doll:set_health(2048)

        doll:enable_hitbox(true)

        doll:set_texture(doll_texture)

        local doll_anim = doll:animation()
        doll_anim:load(doll_anim_path)
        doll_anim:set_state("IDLE")

        -- VDoll faces same way
        doll:set_facing(user:facing())

        -- VDoll does not flip based on tile but bsaed on user
        -- Ignore auto-flipping and defer to the set facing above
        doll:set_never_flip(true)
        doll:set_shadow(Shadow.Small)

        doll._timer = 420

        doll.on_spawn_func = function()
            main_tile:set_state(TileState.Poison)
        end

        doll.on_update_func = function(self)
            -- Don't count down if already set to erase
            if self:will_erase_eof() then return end

            -- Don't count down during time freeze
            if TurnGauge.frozen() then return end

            if self._timer == 0 then
                self:delete()
                return
            end

            self._timer = self._timer - 1
        end

        doll.on_delete_func = function(self)
            local mob_move = bn_assets.MobMove.new("MEDIUM_START")

            mob_move.on_spawn_func = function()
                doll:erase()
            end

            Field.spawn(mob_move, main_tile)
        end

        local curse_defense = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)
        curse_defense.defense_func = function(defense, attacker, defender, hit_props)
            if hit_props.flags & Hit.Drain == Hit.Drain then return end
            if defense:responded() == true then return end

            defense:set_responded()

            local action = Action.new(doll, "IDLE")

            local action_props = CardProperties.new()

            action_props.short_name = "Curse"
            action_props.time_freeze = true
            action_props.prevent_time_freeze_counter = true
            action_props.damage = math.min(2048, hit_props.damage)

            action:set_card_properties(action_props)

            action.on_action_end_func = function()
                doll:delete()
            end

            action.on_execute_func = function(self)
                -- reset animation
                pointer_animation:set_state("DEFAULT")
                pointer_animation:set_playback(Playback.Loop)

                -- create sprite
                local list = Field.find_nearest_characters(doll, function(ent)
                    if ent:team() == user:team() then return false end
                    return true
                end)

                if #list == 0 then
                    self:end_action()
                    return
                end

                local target = list[1]

                local pointer = target:create_node()

                pointer:set_never_flip(true)

                pointer:set_texture(pointer_texture)

                pointer_animation:apply(pointer)

                action:set_lockout(ActionLockout.new_sequence())

                -- create step to update the animation and wait for completion
                local step = action:create_step()

                local loops = 0
                local end_step = false
                local attacking = false
                step.on_update_func = function()
                    if end_step == true then step:complete_step() end
                    if attacking == true then return end

                    pointer_animation:update()
                    pointer_animation:apply(pointer)
                end

                pointer_animation:on_complete(function()
                    loops = loops + 1

                    if loops == 4 then
                        attacking = true
                        target:remove_node(pointer)
                        local explosion = Spell.new(user:team())
                        explosion:set_hit_props(HitProps.new(math.min(2048, hit_props.damage), Hit.PierceInvis,
                            Element.None))

                        explosion:set_texture(explosion_texture)

                        local explosion_anim = explosion:animation()
                        explosion_anim:load(explosion_anim_path)

                        explosion_anim:set_state("DARK")

                        explosion_anim:on_frame(7, function()
                            Resources.play_audio(explosion_sfx)
                        end)

                        explosion_anim:on_complete(function()
                            explosion:erase()
                            end_step = true
                        end)

                        explosion.on_spawn_func = function(self)
                            Resources.play_audio(explosion_sfx)
                        end

                        explosion.on_update_func = function(self)
                            self:attack_tile()
                        end

                        Field.spawn(explosion, target:current_tile())
                    else
                        Resources.play_audio(pointer_audio)
                    end
                end)

                Resources.play_audio(pointer_audio)
            end

            doll:queue_action(action)
        end

        doll:add_defense_rule(curse_defense)

        Field.spawn(doll, main_tile)
    end)
end

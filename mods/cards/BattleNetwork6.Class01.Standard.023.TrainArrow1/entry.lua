local bn_assets = require("BattleNetwork.Assets")

local attachment_texture = bn_assets.load_texture("bn6_bow_buster.png")
local attachment_animation_path = bn_assets.fetch_animation_path("bn6_bow_buster.animation")

local audio = bn_assets.load_audio("train_arrow.ogg")

function card_init(user, props)
    local action = Action.new(user, "CHARACTER_SHOOT")

    local frames = { { 1, 60 } }
    local total_timer = 0
    local attachment, attachment_animation

    action.on_update_func = function()
        total_timer = total_timer + 1
        if total_timer == 7 then
            attachment_animation:set_state("SHOOT")
        elseif total_timer == 53 then
            attachment_animation:set_state("END")
        end
    end

    action:override_animation_frames(frames)

    action.on_execute_func = function(self, user)
        local hit_props = HitProps.from_card(
            props,
            user:context(),
            Drag.None
        )

        local user_tile = user:current_tile()

        local facing = user:facing()
        local user_x = user_tile:x()
        local user_y = user_tile:y()

        local tiles = {}

        attachment = self:create_attachment("BUSTER")

        local attachment_sprite = attachment:sprite()
        attachment_sprite:set_texture(attachment_texture)
        attachment_sprite:set_layer(-2)
        attachment_sprite:use_root_shader()

        attachment_animation = attachment:animation()
        attachment_animation:load(attachment_animation_path)
        attachment_animation:set_state("START")

        user:set_counterable(true)

        local team = user:team()

        attachment_animation:on_frame(1, function()
            for x = 0, 6, 1 do
                local check_tile = Field.tile_at(user_x + x, user_y)
                if check_tile == nil then break end
                if check_tile:is_edge() then break end

                if #check_tile:find_obstacles(function(obs) return obs:hittable() end) > 0 then break end
                if #check_tile:find_characters(function(c) return not c:is_team(team) end) > 0 then break end

                table.insert(tiles, check_tile)
            end
        end)

        local arrows = 0

        local buster_point = user:animation():get_point("BUSTER")
        local origin = user:sprite():origin()
        local fire_y = origin.y - buster_point.y

        attachment_animation:on_frame(2, function()
            for i = #tiles, 1, -1 do
                local arrow = Spell.new(user:team())
                local arrow_sprite = arrow:sprite()
                local arrow_anim = arrow:animation()

                arrow_sprite:set_texture(attachment_texture)
                arrow_anim:load(attachment_animation_path)

                arrow_anim:set_state("ARROW")

                arrow:set_elevation(fire_y)

                arrow:set_facing(facing)
                arrow:set_shadow(Shadow.Small)
                arrow:show_shadow(true)

                arrow:set_hit_props(hit_props)

                if i == 1 then
                    arrow:set_layer(2)
                else
                    arrow:set_layer(-2)
                end

                local timer = 5 + (5 * arrows)
                arrows = arrows + 1
                arrow.on_update_func = function(self)
                    self:attack_tile()

                    timer = timer - 1
                    if timer > 0 then return end
                    if timer == 0 then Resources.play_audio(audio) end
                    if self:is_moving() then return end

                    local current_tile = self:current_tile()

                    if current_tile:is_edge() then
                        self:erase()
                        return
                    end

                    local dest = current_tile:get_tile(facing, 1)
                    if not dest then
                        self:erase()
                        return
                    end

                    self:slide(dest, 4, function()
                        self:set_layer(-2)
                    end)
                end

                arrow.on_collision_func = function(self, other)
                    self:erase()
                end

                arrow.on_attack_func = function(self, other)
                    local hit = bn_assets.HitParticle.new("AQUA", math.random(-1, 1), math.random(-1, 1))
                    Field.spawn(hit, other:current_tile())
                    self:erase()
                end

                Field.spawn(arrow, tiles[i])
            end
        end)
    end

    action.on_action_end_func = function()
        user:set_counterable(false)
    end

    return action
end

local bn_helpers = require("BattleNetwork.Assets")

local TEXTURE = bn_helpers.load_texture("recover.png")
local ANIMATION = bn_helpers.fetch_animation_path("recover.animation")
local AUDIO = bn_helpers.load_audio("recover.ogg")

local function create_recov(user)
    local artifact = Artifact.new()
    artifact:set_texture(TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load(ANIMATION)
    anim:set_state("DEFAULT")
    anim:on_complete(function()
        artifact:erase()
    end)

    Resources.play_audio(AUDIO)

    Field.spawn(artifact, user:current_tile())
end

function card_mutate(player, index)
    local left_card = player:field_card(index - 1)

    if left_card and left_card.damage > 0 then
        local recover = math.floor(player:max_health() / 10)
        local pill_effect_component = player:create_component(Lifetime.Battle)

        pill_effect_component._stored_id = left_card.package_id
        pill_effect_component._activate_aux_prop = false
        pill_effect_component._recover_amount = recover

        left_card.recover = recover

        player:set_field_card(index - 1, left_card)

        -- remove this card
        player:remove_field_card(index)

        pill_effect_component.on_update_func = function(self)
            if self._activate_aux_prop == true and player:input_has(Input.Pressed.Use) then
                local aux_prop = AuxProp.new()
                    :recover_health(self._recover_amount)
                    :with_callback(create_recov(player))
                    :once()

                player:add_aux_prop(aux_prop)

                self:eject()
                return
            end

            local card = player:field_card(1)

            if card and card.package_id ~= self._stored_id then
                return
            end

            if card.recover == self._recover_amount then
                self._activate_aux_prop = true
            end
        end
    end
end

function card_init()
    return nil
end

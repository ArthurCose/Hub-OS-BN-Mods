local TEXTURE = Resources.load_texture("artifact.png")
local AUDIO = Resources.load_audio("sfx.ogg")

function card_init(user)
    local action = Action.new(user, "PLAYER_BUFF")

    action.on_execute_func = function()
        local recov = create_recov(user)
        user:field():spawn(recov, user:current_tile())
        user:boost_attack_level(1)
    end

    return action
end

function create_recov(user)
    local artifact = Artifact.new()
    artifact:set_texture(TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load("artifact.animation")
    anim:set_state("DEFAULT")
    anim:on_complete(
        function()
            artifact:erase()
        end
    )

    Resources.play_audio(AUDIO)

    return artifact
end

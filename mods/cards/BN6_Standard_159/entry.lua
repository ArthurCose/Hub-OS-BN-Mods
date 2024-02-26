local TEXTURE = Resources.load_texture("heal_artifact.png")
local AUDIO = Resources.load_audio("sfx.ogg")

function card_init(user)
    local action = Action.new(user, "PLAYER_IDLE")

    action.on_execute_func = function()
        local recov = create_recov(user)
        user:field():spawn(recov, user:current_tile())
        user:set_health(user:health() + 80)
    end

    return action
end

function create_recov(user)
    local artifact = Artifact.new()
    artifact:set_texture(TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load("heal_artifact.animation")
    anim:set_state("DEFAULT")
    anim:on_complete(
        function()
            artifact:erase()
        end
    )

    Resources.play_audio(AUDIO)

    return artifact
end

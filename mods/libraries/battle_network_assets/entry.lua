local Lib = {}

local images_animations_folder = _folder_path .. "Animations & Images/"
local sounds_folder = _folder_path .. "Sounds/"

function Lib.fetch_animation_path(name)
    -- This is because we'll add the extension ourselves.
    return images_animations_folder .. name
end

function Lib.load_texture(name)
    return Resources.load_texture(images_animations_folder .. name)
end

function Lib.load_audio(name)
    return Resources.load_audio(sounds_folder .. name)
end

-- Poof support
Lib.ParticlePoof = {}
function Lib.ParticlePoof.new()
    local TEXTURE = Lib.load_texture("poof.png")
    local fx = Artifact.new()
    fx:set_texture(TEXTURE)

    local fx_animation = fx:animation()
    fx_animation:load(Lib.fetch_animation_path("poof.animation"))
    fx_animation:set_state("DEFAULT")
    fx_animation:on_complete(function()
        fx:erase()
    end)

    return fx;
end

Lib.MobMove = {}
function Lib.MobMove.new(target)
    local fx = Artifact.new()
    local field = target:field()
    local anim = fx:animation()

    fx:set_texture(Lib.load_texture("mob_move.png"))

    anim:load(Lib.fetch_animation_path("mob_move.animation"))
    anim:set_state("DEFAULT")
    anim:apply(fx:sprite())
    anim:on_complete(function()
        fx:erase()
    end)

    field:spawn(fx, target:current_tile())
end

return Lib;

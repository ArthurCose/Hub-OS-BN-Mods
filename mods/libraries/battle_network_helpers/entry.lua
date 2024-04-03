local HelpersBN = {}

local images_animations_folder = _folder_path .. "Animations & Images/"
local sounds_folder = _folder_path .. "Sounds/"

function HelpersBN.fetch_animation_path(name)
    -- This is because we'll add the extension ourselves.
    return images_animations_folder .. name
end

function HelpersBN.load_texture(name)
    return Resources.load_texture(images_animations_folder .. name)
end

function HelpersBN.load_audio(name)
    return Resources.load_audio(sounds_folder .. name)
end

-- Poof support
HelpersBN.ParticlePoof = {}
function HelpersBN.ParticlePoof.new()
    local TEXTURE = HelpersBN.load_texture("poof.png")
    local fx = Artifact.new()
    fx:set_texture(TEXTURE)

    local fx_animation = fx:animation()
    fx_animation:load(HelpersBN.fetch_animation_path("poof.animation"))
    fx_animation:set_state("DEFAULT")
    fx_animation:on_complete(function()
        fx:erase()
    end)

    return fx;
end

HelpersBN.MobMove = {}
function HelpersBN.MobMove.new(target)
    local fx = Artifact.new()
    local field = target:field()
    local anim = fx:animation()

    fx:set_texture(HelpersBN.load_texture("mob_move.png"))

    anim:load(HelpersBN.fetch_animation_path("mob_move.animation"))
    anim:set_state("DEFAULT")
    anim:apply(fx:sprite())
    anim:on_complete(function()
        fx:erase()
    end)

    field:spawn(fx, target:current_tile())
end

return HelpersBN;

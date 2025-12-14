---@class BattleChipChallenge.Libraries.Ring
local Lib = {}

local images_animations_folder = _folder_path .. "animation_images/"
local sounds_folder = _folder_path .. "sounds/"

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

return Lib
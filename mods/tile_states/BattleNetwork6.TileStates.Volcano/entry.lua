local VOLCANO_TEXTURE = Resources.load_texture("volcano.png")
local VOLCANO_ANIM_PATH = "volcano.animation"
local HIT_TEXTURE = Resources.load_texture("volcano_hit.png")
local HIT_ANIM_PATH = "volcano_hit.animation"

local timers = {}

local function spawn_spell(tile)
    local spell = Spell.new(Team.Other)
    spell:set_hit_props(
        HitProps.new(
            50,
            Hit.Flinch,
            Element.None
        )
    )

    spell._timer = 0
    spell._start_attacking = false

    spell:set_texture(VOLCANO_TEXTURE)
    spell:load_animation(VOLCANO_ANIM_PATH)

    local spell_animation = spell:animation()

    spell_animation:set_state("FLICKER")
    spell_animation:set_playback(Playback.Loop)

    spell:sprite():set_layer(-2)

    spell.on_update_func = function()
        if spell._start_attacking == true then
            spell:attack_tile(spell:current_tile())
        end

        if spell._timer == 40 then
            spell_animation = spell:animation()

            spell_animation:set_state("ERUPT")
            spell_animation:set_playback(Playback.Once)

            spell._start_attacking = true
        elseif spell._timer >= 80 then
            spell:erase()
        end

        spell._timer = spell._timer + 1
    end

    spell.on_collision_func = function()
        local fx = Artifact.new()

        fx:set_texture(HIT_TEXTURE)
        fx:load_animation(HIT_ANIM_PATH)

        fx:animation():set_state("HIT")

        fx:animation():on_complete(function()
            fx:erase()
        end)

        fx:sprite():set_layer(-4)

        fx:set_offset(math.random(-12, 12), math.random(-8, 8))

        Field.spawn(fx, tile)
    end

    Field.spawn(spell, tile)
end

function tile_state_init(custom_state)
    local erupt_at = 140

    custom_state.on_update_func = function(self, tile)
        local time = timers[tile]

        if not time then time = 0 end

        time = time + 1

        -- Add the eruption artifact to the tile.
        if time == erupt_at then
            spawn_spell(tile)
        elseif time == erupt_at + 80 then
            time = 0
        end

        timers[tile] = time
    end

    custom_state.on_replace_func = function(self, tile)
        timers[tile] = 0
    end
end

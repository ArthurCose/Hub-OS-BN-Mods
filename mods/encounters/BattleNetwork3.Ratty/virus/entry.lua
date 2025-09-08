local bn_assets = require("BattleNetwork.Assets")

-- Use a prebuilt function to build the ratton. While not necessary for this
-- Particular enemy, I feel it should be standard practice to segment attacks
-- In to other functions, as sometimes you need to create an attack multiple
-- Times. So, you'll want it in a function that declares the code once,
-- Instead of repeating the code each time.
function create_ratton(ratty)
    -- Ratty itself is input as the argument, so we can get various facts about it.
    local spell = Obstacle.new(ratty:team()) -- Create as an obstacle, not a spell, so that it can be destroyed, just like in BN3.

    spell:set_facing(ratty:facing())         -- Make sure the spell faces the right way. Must face the same way as the ratty so it looks at the player.

    local direction = spell:facing()         -- Store the facing. This will be used later to determine the spell's travel direction.

    -- Load and Set the texture. We're using palettes here, so we use a greyscaled texture. Palette determination comes in a bit.
    -- The palette decision is because the bomb changes color depending on the rank of the Ratty.
    local spell_texture = Resources.load_texture("ratton_bomb.greyscaled.png")
    spell:set_texture(spell_texture)

    -- Get, load, and refresh the animation. You refresh so it doesn't show the entire sheet.
    local spell_anim = spell:animation()
    spell_anim:load("ratton_bomb.animation")
    spell_anim:set_state("0")
    spell_anim:apply(spell:sprite())

    -- Set the properties of the attack. Refer to Ratty's stored attack value.
    -- Ratton Bombs should make the target Flinch, have Impact (be stopped by barriers), and grant mercy invulnerability (Flash) on hit.
    -- They are Null element by default. They rely on the Ratty's hit context.
    -- They do not inflict Drag. Would be funny to see, though.
    spell:set_hit_props(
        HitProps.new(
            ratty._attack,
            Hit.Flinch | Hit.Flash,
            Element.None,
            ratty:context(),
            Drag.None
        )
    )
    -- I don't know if this is accurate, but I took a guess that a Ratton has about 50 health.
    spell:set_health(50)

    -- Rattons can share tiles. This lets the obstacle collide with other obstacles and players and stuff. I hope.
    spell:enable_sharing_tile(true)

    -- Make sure it draws over other things it collides with.
    spell:sprite():set_layer(-2)

    -- Determine the palette to use, based on the Ratty's rank.
    local rank = ratty:rank()
    if rank == Rank.V2 then
        spell:set_palette(Resources.load_texture("ratton_bomb_v2.palette.png"))
    elseif rank == Rank.V3 then
        spell:set_palette(Resources.load_texture("ratton_bomb_v3.palette.png"))
    elseif rank == Rank.SP then
        spell:set_palette(Resources.load_texture("ratton_bomb_sp.palette.png"))
    else
        -- As a failsafe, put the V1 Palette under an Else statement.
        -- This way, if the rank is V1 *or any other, invalid rank* than the above ranks,
        -- We still get a visible bomb.
        spell:set_palette(Resources.load_texture("ratton_bomb.palette.png"))
    end

    spell.slide_started = false

    -- When the spell collides, trigger its delete function. We want to blow up and erase it at that point.
    spell.on_collision_func = function(self, other)
        self:delete()
    end

    spell.on_delete_func = function(self)
        -- If the tile is an edge or broken tile, use a Mob Move effect to get rid of it without "exploding", as it didn't attack.
        if self:current_tile():is_edge() or self:current_tile():state() == TileState.Broken then
            local fx = bn_assets.MobMove.new("SMALL_END")

            Field.spawn(fx, self:current_tile())
        else
            -- Otherwise, use an explosion animation to get rid of it and play the sound, as it hit something and we want to recognize that.
            -- We can use the built-in Explosion object for this.
            local explosion = Explosion.new()

            Field.spawn(explosion, self:current_tile())
        end
        self:erase()
    end
    -- This is fun. Filter out deleted targets, make sure the target is not the same team as the spell, and the X and Y of the spell & target's tile's aren't the same.
    -- That's it, that's the filter. If it matches all those conditions, return true.
    local same_column_query = function(c)
        return not c:deleted() and c:team() ~= spell:team() and c:current_tile():x() == spell:current_tile():x() and
            c:current_tile():y() ~= spell:current_tile():y()
    end
    -- Can only turn once, so set a boolean to use.
    local has_turned = false
    -- Slide at a specific speed, based on whether or not the Ratty is angry.
    local slide_speed = ratty._ratton_move_speed
    spell.on_update_func = function(self)
        -- If the bomb is deleted, return and don't do anything else. Wastes processing power otherwise.
        if self:deleted() then return end
        -- Store the current tile since we call it a fair bit.
        local cur_tile = self:current_tile()
        -- This line is important, it means the spell can attack.
        cur_tile:attack_entities(self)
        -- Highlight the tile we're attacking, for a little help in the chaos of some battles.
        cur_tile:set_highlight(Highlight.Solid)
        -- If it's an edge tile or it's broken, and we're sliding and not already deleted, then self-delete. We'll puff out of existence.
        if (cur_tile:is_edge() or cur_tile:state() == TileState.Broken) and self.slide_started and not self:deleted() then
            self:delete()
        end
        -- If we're not sliding, then we need to slide.
        if not self:is_sliding() then
            -- The destination is the direction we're facing, 1 tile over at a time.
            local dest = self:get_tile(direction, 1)
            -- If we haven't turned, we can run the search. Don't run it if we have turned, as it would be a waste of processing power, however little.
            -- At least, a bigger one than checking a boolean, I feel.
            if not has_turned then
                if #Field.find_characters(same_column_query) > 0 then
                    -- While I could write a sorting check for every character it finds in this list to determine who to turn towards
                    -- In the case of multiple found characters, for now it's faster and easier to assume 1 player is the target and
                    -- Target the first entry in the list.
                    local target = Field.find_characters(same_column_query)[1]
                    -- If the Y is less, they're above you. If it's more, they're below you.
                    if target:current_tile():y() < cur_tile:y() then
                        direction = Direction.Up
                    else
                        direction = Direction.Down
                    end
                    -- Change direction and thus destination.
                    dest = self:get_tile(direction, 1)
                    -- Set has_turned so that we don't do this again. If warp step is ever added it could confuse the rattons.
                    has_turned = true
                end
            end
            -- Do the slide.
            local ref = self
            self:slide(dest, slide_speed, function()
                ref.slide_started = true
            end)
        end
    end
    -- Spell can move anywhere.
    spell.can_move_to_func = function(tile)
        return true
    end
    return spell
end

function character_init(self)
    self:set_texture(Resources.load_texture("ratty.greyscaled.png"), true)
    local anim = self:animation()
    anim:load("ratty.animation")
    anim:set_state("0")
    anim:apply(self:sprite())
    anim:set_playback(Playback.Loop)
    self:set_height(53)
    self:set_name("Ratty")
    self._attack = 0
    self._move_before_attack = 0
    self._slide_speed = 20
    self._angry_slide_speed = 10
    self._pause_between_moves = 10
    self._pause_between_moves_angry = 5
    self._idle_state = "0"
    self._angry_idle_state = "1"
    self._attack_state = "2"
    self._angry_attack_state = "3"
    self._current_moves = 0
    local rank = self:rank()
    if rank == Rank.V1 then
        self:set_health(40)
        self._attack = 20
        self._move_before_attack = 10
        self:set_palette(Resources.load_texture("ratty_v1.palette.png"))
    elseif rank == Rank.V2 then
        self:set_health(100)
        self._attack = 50
        self._move_before_attack = 8
        self._slide_speed = 16
        self._angry_slide_speed = 8
        self:set_palette(Resources.load_texture("ratty_v2.palette.png"))
    elseif rank == Rank.V3 then
        self:set_health(160)
        self._attack = 80
        self._move_before_attack = 6
        self._slide_speed = 12
        self._angry_slide_speed = 6
        self:set_palette(Resources.load_texture("ratty_v3.palette.png"))
    elseif rank == Rank.SP then
        self:set_health(230)
        self._attack = 150
        self._move_before_attack = 4
        self._slide_speed = 8
        self._angry_slide_speed = 4
        self:set_palette(Resources.load_texture("ratty_sp.palette.png"))
    end
    self._ratton_move_speed = self._slide_speed
    self._wait_after_bombing = 0
    local is_occupied = function(ent)
        return Character.from(ent) ~= nil or Obstacle.from(ent) ~= nil
    end

    self.can_move_to_func = function(tile)
        if self:team() ~= tile:team() then return false end
        if #tile:find_entities(is_occupied) > 0 then return false end
        if tile:is_reserved({ self:id() }) then return false end
        return tile:is_walkable()
    end

    local has_changed_pattern = false
    local direction_table = { Direction.Up, Direction.Down, Direction.Left, Direction.Right }

    local random_move_direction = Direction.None

    self._do_once = true

    local reserved_tiles = {}

    self._wait_before_moving = 0;

    self:add_aux_prop(StandardEnemyAux.new())

    self.on_spawn_func = function(self)
        self._wait_before_moving = self._pause_between_moves
    end

    self.on_update_func = function(self)
        if self:is_sliding() then return end

        if self:health() <= math.floor(self:max_health() / 2) and not has_changed_pattern then
            self._slide_speed = self._angry_slide_speed
            self._pause_between_moves = self._pause_between_moves_angry
            self._idle_state = self._angry_idle_state
            self._attack_state = self._angry_attack_state

            anim:set_state(self._idle_state)
            anim:set_playback(Playback.Loop)

            has_changed_pattern = true
        end

        if self._wait_before_moving > 0 then
            self._wait_before_moving = self._wait_before_moving - 1
            return
        elseif self._wait_after_bombing > 0 then
            self._wait_after_bombing = self._wait_after_bombing - 1
            return
        end

        if self._current_moves <= self._move_before_attack then
            local next_tile;

            random_move_direction = direction_table[math.random(1, #direction_table)]

            next_tile = self:get_tile(random_move_direction, 1)
            table.insert(reserved_tiles, self:current_tile())

            self:slide(next_tile, self._slide_speed, function()
                if next_tile ~= self:current_tile() then
                    next_tile:reserve_for(self)
                    self._current_moves = self._current_moves + 1
                    for index, tile in ipairs(reserved_tiles) do
                        tile:remove_reservation_for(self)
                    end
                end
            end)
        else
            if self._do_once then
                anim:set_state(self._attack_state)
                anim:set_playback(Playback.Once)
                anim:on_frame(3, function()
                    local ratton = create_ratton(self)
                    local spawn_tile = self:get_tile(self:facing(), 1)
                    Field.spawn(ratton, spawn_tile)
                end)
                anim:on_complete(function()
                    anim:set_state(self._idle_state)
                    anim:set_playback(Playback.Loop)
                    self._current_moves = 0
                    self._do_once = true
                    self._wait_after_bombing = 10
                end)
                self._do_once = false
            end
        end
    end
end

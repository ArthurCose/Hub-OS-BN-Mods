local noop = function() end
local texture = Resources.load_texture("gunner.greyscaled.png")
local animation_path = "gunner.animation"

local Cursor = {}

local function attack_tile(gunner, attack_spell, tile)
	if not tile then
		attack_spell:delete()
		return
	end
	Resources.play_audio(Resources.load_audio("gun.ogg"))
	-- set the cursor up for damage
	local hitbox = Hitbox.new(gunner:team())
	hitbox:set_hit_props(HitProps.new(
		gunner._attack,
		Hit.Flinch,
		Element.Cursor,
		gunner:context(),
		Drag.None
	))
	local fx = Artifact.new()
	fx:set_texture(texture)
	fx:set_facing(Direction.reverse(gunner:facing()))
	fx:set_palette(Resources.load_texture("gunner_v1.pallet.png"))
	local anim = fx:animation()
	anim:load(animation_path)
	anim:set_state("BURST")
	fx:sprite():set_layer(-2)
	anim:on_complete(function()
		fx:erase()
	end)
	Field.spawn(hitbox, tile)
	Field.spawn(fx, tile)
end

local function attack_tile_flinch(gunner, attack_spell, tile)
	if not tile then
		attack_spell:delete()
		return
	end
	Resources.play_audio(Resources.load_audio("gun.ogg"))
	-- set the cursor up for damage
	local hitbox = Hitbox.new(gunner:team())
	hitbox:set_hit_props(HitProps.new(
		gunner._attack,
		Hit.Flinch | Hit.Flash,
		Element.Cursor,
		gunner:context(),
		Drag.None
	))
	local fx = Artifact.new()
	fx:set_texture(texture)
	fx:set_facing(Direction.reverse(gunner:facing()))
	fx:set_palette(Resources.load_texture("gunner_v1.pallet.png"))
	local anim = fx:animation()
	anim:load(animation_path)
	anim:set_state("BURST")
	fx:sprite():set_layer(-2)
	anim:on_complete(function()
		fx:erase()
	end)
	Field.spawn(hitbox, tile)
	Field.spawn(fx, tile)
end

local function attack(gunner, cursor)
	local gunner_anim = gunner:animation()
	gunner_anim:set_state("ATTACK")
	gunner._cursor_send_once = false
	gunner_anim:on_complete(function()
		gunner._cursor_send_once = true
		gunner._count_between_attack_sends = 30
	end)
	-- create a new attack spell to deal damage
	-- we can't deal damage to a target if we've hit them and they haven't moved
	local attack_spell = Spell.new(gunner:team())
	local tile = cursor.spell.tile
	cursor:erase()
	local direction = gunner:facing()
	local attack_cooldown = 10
	local hits = 0
	local query = function(ent)
		return ent ~= nil and not ent:deleted() and not ent:is_team(gunner:team())
	end
	local can_continue_moving = true
	attack_spell.on_update_func = function(self)
		if attack_cooldown <= 0 then
			if hits < 2 then
				attack_tile(gunner, attack_spell, tile)
				attack_cooldown = 10
				hits = hits + 1
			else
				attack_tile_flinch(gunner, attack_spell, tile)
				gunner_anim:set_state("IDLE")
				self:delete()
			end
		else
			attack_cooldown = attack_cooldown - 1
		end
	end



	attack_spell.on_delete_func = function(self)
		attack_spell:erase()
	end
	attack_spell.on_attack_func = function()
		can_continue_moving = false
	end
	Field.spawn(attack_spell, tile)
end

local function begin_attack(gunner, cursor)
	-- stop the cursor from scanning for players
	cursor.spell.on_update_func = noop
	cursor.spell.on_attack_func = noop
	cursor.spell.on_collision_func = noop

	local cursor_anim = cursor.spell:animation()
	cursor_anim:set_state("CURSOR_LOCKON")
	Resources.play_audio(Resources.load_audio("scanning_lock.ogg"))
	cursor_anim:set_playback(Playback.Once)
	cursor_anim:on_complete(function()
		gunner._should_attack = true
	end)
end

local function spawn_cursor(cursor, gunner, tile)
	local spell = Spell.new(gunner:team())
	spell:set_facing(gunner:facing())
	spell:set_texture(gunner:texture())
	spell:set_palette(Resources.load_texture("gunner_v1.pallet.png"))
	spell:sprite():set_layer(-1)
	spell:set_hit_props(HitProps.new(
		0,
		Hit.None,
		Element.None,
		gunner:context(),
		Drag.None
	))

	local anim = spell:animation()
	anim:load(animation_path)
	anim:set_state("CURSOR")
	Resources.play_audio(Resources.load_audio("scanning_click.ogg"))
	anim:set_playback(Playback.Once)

	Field.spawn(spell, tile)
	spell.slide_started = false
	spell.on_update_func = function(self)
		if gunner:rank() == Rank.V1 then
			if spell:current_tile():is_edge() and spell.slide_started then
				gunner:animation():set_state("IDLE")
				spell:delete()
			end
		else
			if spell:current_tile():get_tile(spell:facing(), 1) then
				if spell:current_tile():get_tile(spell:facing(), 1):is_edge() or spell:current_tile():team() ~= gunner:team() and spell:current_tile():get_tile(spell:facing(), 1):team() == gunner:team() and spell:current_tile():get_tile(spell:facing(), 1):team() ~= Team.Other then
					spell:set_facing(Direction.reverse(spell:facing()))
				end
			end
		end
		tile = spell:get_tile(spell:facing(), 1)
		cursor.spell.tile = spell:current_tile()
		if not spell:is_sliding() then
			local ref = spell
			spell:slide(tile, gunner._frames_per_cursor_movement, function()
				ref.slide_started = true
			end)
		end
	end

	spell.on_delete_func = function(self)
		gunner._count_between_attack_sends = 30
		spell:erase()
	end

	spell.on_collision_func = function(self, other)
		if Character.from(other) ~= nil then
			begin_attack(gunner, cursor)
		end
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	return spell
end

function Cursor:new(gunner, tile)
	local cursor = {
		gunner = gunner,
		spell = nil,
		remaining_frames = gunner._frames_per_cursor_movement
	}

	setmetatable(cursor, self)
	self.__index = self

	cursor.spell = spawn_cursor(cursor, gunner, tile)

	return cursor
end

function Cursor:erase()
	self.spell:erase()
	self.gunner._cursor = nil
end

local target_update, idle_update

target_update = function(gunner)
	if gunner._cursor then
		local spell = gunner._cursor.spell
		if gunner._cursor.spell:deleted() then
			gunner.on_update_func = idle_update
		else
			spell:current_tile():attack_entities(spell)

			if gunner._should_attack then
				gunner._should_attack = false
				attack(gunner, gunner._cursor)
			end
		end
	else
		gunner.on_update_func = idle_update
	end
end

idle_update = function(gunner)
	local y = gunner:current_tile():y()
	local team = gunner:team()

	local targets = Field.find_characters(function(c)
		-- same row, different team
		return c:team() ~= team and c:current_tile():y() == y
	end)

	if #targets == 0 then return end -- no target
	if gunner._count_between_attack_sends <= 0 then
		if gunner._cursor_send_once then
			gunner._cursor_send_once = false
			gunner:animation():set_state("FOE_SPOTTED")
			gunner:animation():on_complete(function()
				-- found a target, spawn a cursor and change state
				local cursor_tile = gunner:current_tile()
				gunner._cursor = Cursor:new(gunner, cursor_tile)
				gunner.on_update_func = target_update
			end)
		end
	else
		gunner:animation():set_state("IDLE")
		gunner._count_between_attack_sends = gunner._count_between_attack_sends - 1
		gunner._cursor_send_once = true
	end
end

function character_init(gunner)
	-- private variables
	gunner._frames_per_cursor_movement = 15
	gunner._cursor = nil
	gunner._should_attack = false
	gunner._stop_updating_tile = false
	gunner._count_between_attack_sends = 0
	gunner._cursor_send_once = true
	gunner._attack = 0
	-- meta
	gunner:set_height(53)
	gunner:set_texture(texture, true)
	local rank = gunner:rank()
	if rank == Rank.V1 then
		gunner:set_name("Gunner")
		gunner:set_health(60)
		gunner._attack = 10
		gunner:set_palette(Resources.load_texture("gunner_v1.pallet.png"))
	elseif rank == Rank.V2 then
		gunner:set_name("Shooter")
		gunner:set_health(140)
		gunner._attack = 30
		gunner:set_palette(Resources.load_texture("gunner_v2.pallet.png"))
	elseif rank == Rank.V3 then
		gunner:set_name("Sniper")
		gunner:set_health(220)
		gunner._attack = 50
		gunner:set_palette(Resources.load_texture("gunner_v3.pallet.png"))
	end

	local anim = gunner:animation()
	anim:load(animation_path)
	anim:set_state("IDLE")

	-- setup defense rules
	gunner:add_aux_prop(StandardEnemyAux.new())

	-- setup event hanlders
	gunner.on_update_func = idle_update
	gunner.on_battle_start_func = noop
	gunner.on_battle_end_func = noop
	gunner.on_spawn_func = noop
	gunner.on_delete_func = function(self)
		if self._cursor then
			self._cursor:erase()
		end
		self:default_character_delete()
	end
end

---@type dev.konstinople.library.sword
local SwordLib = require("dev.konstinople.library.sword")

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("puck.png")
local TEXTURE_ANIM = bn_assets.fetch_animation_path("puck.animation")
local LAUNCH_AUDIO = bn_assets.load_audio("hockey_launch.ogg")

local BOUNCE_AUDIO = {
	bn_assets.load_audio("hockey1.ogg"),
	bn_assets.load_audio("hockey2.ogg")
}

local sword = SwordLib.new_sword()
sword:use_hand()
sword:set_frame_data({ { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 25 } })

function card_init(user, props)
	local action = sword:create_action(user, function()
		local dir = user:facing()
		local tile = user:get_tile(dir, 1)
		if tile then
			local puck = create_puck(user, props)
			Field.spawn(puck, tile)
		end
	end)

	action:set_lockout(ActionLockout.new_async(32))

	action:on_anim_frame(2, function()
		user:set_counterable(true)
	end)

	action:on_anim_frame(4, function()
		user:set_counterable(false)
	end)

	action.on_action_end_func = function()
		user:set_counterable(false)
	end

	return action
end

local function drop_trace_fx(target_artifact, duration, direction, tile_count)
	local team = target_artifact:team()

	local fx = Artifact.new(team)

	local texture = target_artifact:texture()

	fx:set_facing(target_artifact:facing())
	fx:set_texture(texture)

	local fx_anim = fx:animation()
	fx_anim:copy_from(target_artifact:animation())
	fx_anim:set_state(target_artifact:animation():state())

	local alpha = 255
	local slide_wait = 5
	local dest, play_bounce
	local original_duration = duration

	local color = Color.new(0, 8, 48, alpha)

	fx.can_move_to_func = function(tile)
		-- Can't move to tiles that don't exist
		if not tile then return false end

		-- Can't move to unwalkable tiles e.g. broken, missing, and edge tiles.
		if not tile:is_walkable() then return false end
		return true
	end

	fx:set_layer(2)

	fx.on_update_func = function(self)
		if slide_wait > 0 then
			slide_wait = slide_wait - 1
		else
			if not self:is_sliding() then
				local tile = self:current_tile()
				if not tile or tile:is_edge() then
					self:erase()
					return
				end

				if tile_count == 0 then
					self:erase()
					return
				end

				dest, play_bounce, direction = Bounce(tile, self, direction, team)

				if not dest then
					self:erase()
					return
				end

				self:slide(dest, 6, function()
					tile_count = tile_count - 1
				end)
			end
		end

		duration = duration - 1

		alpha = math.max(0, alpha * (duration / original_duration))

		color = Color.new(0, 8, 48, alpha)

		self:sprite():set_color_mode(ColorMode.Adopt)
		self:set_color(color)

		if duration == 0 then
			self:erase()
		end
	end

	local tile = target_artifact:current_tile()

	Field.spawn(fx, tile)

	return fx
end

function create_puck(user, props)
	local spell = Spell.new(user:team())
	local tile_count = 11
	local afterimage = false

	if props.card_class == CardClass.Recipe then
		tile_count = 21
		afterimage = true
	end

	local self_team = user:team()
	local direction = Direction.join(user:facing(), Direction.Down)

	local audio_index = 1

	local anim = spell:animation()
	anim:load(TEXTURE_ANIM)
	anim:set_state("DEFAULT")

	local sprite = spell:sprite()
	sprite:set_texture(TEXTURE)
	anim:apply(sprite)
	anim:set_playback(Playback.Loop)

	spell:set_tile_highlight(Highlight.Flash)

	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		local tile = self:current_tile()
		if not tile then
			self:delete()
			return
		end

		if not tile:is_walkable() then
			self:delete()
			return
		end

		if afterimage == true and tile_count > 1 then
			drop_trace_fx(self, 8, direction, tile_count)
		end

		tile:attack_entities(self)

		if tile_count < 1 then
			self:delete()
		end

		if not self:is_sliding() then
			local dest
			local play_bounce
			dest, play_bounce, direction = Bounce(tile, spell, direction, self_team)
			if dest then
				self:slide(dest, 6)
				if play_bounce then
					Resources.play_audio(BOUNCE_AUDIO[audio_index])
					if audio_index + 1 > #BOUNCE_AUDIO then audio_index = 1 else audio_index = 2 end
				end
			else
				self:delete()
			end

			tile_count = tile_count - 1
		end
	end

	spell.on_collision_func = function(self, other)
		local fx = bn_assets.HitParticle.new("BREAK", math.random(-1, 1), math.random(-1, 1))
		Field.spawn(fx, other:current_tile())
	end

	spell.on_attack_func = function(self, other)
	end

	spell.on_delete_func = function(self)
		local fx = bn_assets.MobMove.new("SMALL_END")

		local fx_anim = fx:animation()
		fx_anim:on_complete(function() fx:erase() end)

		Field.spawn(fx, spell:current_tile())

		self:erase()
	end

	spell.can_move_to_func = function(tile)
		-- Can't move to tiles that don't exist
		if not tile then return false end

		-- Can't move to unwalkable tiles e.g. broken, missing, and edge tiles.
		if not tile:is_walkable() then return false end
		return true
	end

	Resources.play_audio(LAUNCH_AUDIO)

	return spell
end

function Bounce(tile, spell, direction, self_team)
	local play_bounce = true
	local new_dir = direction
	local tile_team = tile:team() -- this is the team of the tile we're currently on

	-- no entry if the target tile is friendly and we aren't currently on a friendly tile
	local function teamcheck(new_tile)
		local new_tile_team = new_tile:team()
		if (new_tile_team == self_team) and not (new_tile_team == tile_team) then
			return true
		end
		return false
	end

	-- wraps up all the checks into one function and returns true if we can't move to the tile
	local function bad()
		local new_tile = tile:get_tile(new_dir, 1)
		if new_tile and not new_tile:is_walkable() and not new_tile:is_edge() then
			spell:delete()
			return false
		end

		if teamcheck(new_tile) then return true end

		return not spell:can_move_to(new_tile)
	end

	-- check if any tile is accessible, 1) no flip, 2) flip x, 3) flip y, 4) flip x and y
	-- (there's no reason to check x before y, it's arbitrary, but the order matters for the other ones)
	if bad() then
		new_dir = Direction.flip_x(direction)
		if bad() then
			new_dir = Direction.flip_y(direction)
			if bad() then
				new_dir = Direction.reverse(direction)
				if bad() then
					-- by returning false, we nil some expected returns, but it's ok cuz the puck will die immediately
					return false
				end
			end
		end
	else
		play_bounce = false
	end

	direction = new_dir
	local dest = tile:get_tile(direction, 1)
	return dest, play_bounce, direction
end

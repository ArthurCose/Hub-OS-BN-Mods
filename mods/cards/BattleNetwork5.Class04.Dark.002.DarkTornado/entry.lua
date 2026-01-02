---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("wind_burst.ogg")
local TEXTURE = bn_assets.load_texture("tornado_bn6.png")
local BUSTER_TEXTURE = bn_assets.load_texture("buster_fan.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("buster_fan.animation")
local SPELL_ANIM_PATH = bn_assets.fetch_animation_path("tornado_bn6.animation")

local FRAME1 = { 1, 6 }
local FRAME2 = { 2, 3 }
local FRAME3 = { 3, 3 }
local FRAMES = { FRAME1, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME1, FRAME3,
	FRAME2, FRAME3, FRAME2 }

function card_mutate(user, index)
	if Player.from(user) == nil then return end
	user:boost_augment("BattleNetwork6.Bugs.CustomHPBug", 1)
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE)
		buster:sprite():set_layer(-1)

		self:on_anim_frame(1, function()
			user:set_counterable(true)
		end)

		local buster_anim = buster:animation()

		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT_DARK")
		buster_anim:apply(buster:sprite())
		buster_anim.on_complete = function()
			buster_anim:set_state("LOOP")
			buster_anim:set_playback(Playback.Loop)
		end

		self:on_anim_frame(4, function()
			user:set_counterable(false)
			local tile = user:get_tile(user:facing(), 2)
			if tile ~= nil and tile:is_edge() == false then
				create_and_spawn_attack(user, props, tile)
			end

			local health = user:health()
			local max_health = user:max_health()
			if health <= math.floor(max_health * 0.75) then
				local front_tile = user:get_tile(user:facing(), 1)
				if front_tile ~= nil and front_tile:is_edge() == false then
					create_and_spawn_attack(user, props, front_tile)
				end
			end

			if health <= math.floor(max_health * 0.5) then
				local up_tile = tile:get_tile(Direction.Up, 1)
				if up_tile ~= nil and up_tile:is_edge() == false then
					create_and_spawn_attack(user, props, up_tile)
				end

				local down_tile = tile:get_tile(Direction.Down, 1)
				if down_tile ~= nil and down_tile:is_edge() == false then
					create_and_spawn_attack(user, props, down_tile)
				end
			end

			if health <= math.floor(max_health * 0.25) then
				local far_tile = user:get_tile(user:facing(), 3)
				if far_tile ~= nil and far_tile:is_edge() == false then
					create_and_spawn_attack(user, props, far_tile)
				end
			end
		end)
	end
	return action
end

function create_and_spawn_attack(user, props, tile)
	local spell = Spell.new(user:team())

	local hits = 8

	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Solid)
	spell:set_texture(TEXTURE)
	spell:sprite():set_layer(-1)

	spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))

	local anim = spell:animation()
	anim:load(SPELL_ANIM_PATH)
	anim:set_state("DARK")

	anim:set_playback(Playback.Loop)
	anim:on_complete(function()
		hits = hits - 1

		if hits == 0 then
			spell:erase()
			return
		end

		local hitbox = Hitbox.new(spell:team())
		hitbox:set_hit_props(spell:copy_hit_props())
		Field.spawn(hitbox, spell:current_tile())
	end)

	local hit_targets = {}

	spell.on_attack_func = function(self, other)
		if Player.from(other) == nil then return end

		if hit_targets[other:id()] == true then return end

		other:boost_augment("BattleNetwork6.Bugs.CustomHPBug", 1)

		hit_targets[other:id()] = true
	end

	spell.on_delete_func = function(self) self:erase() end

	Resources.play_audio(AUDIO, AudioBehavior.NoOverlap)

	Field.spawn(spell, tile)
end

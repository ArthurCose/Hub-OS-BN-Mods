local bn_assets = require("BattleNetwork.Assets")
local battle_helpers = require("Battle.Helpers")

local SPELL_TEXTURE = bn_assets.load_texture("thunder_bn6.png")
local SPELL_ANIM_PATH = bn_assets.fetch_animation_path("thunder_bn6.animation")

local IMPACT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local IMPACT_ANIM_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local THUNDER_AUDIO = bn_assets.load_audio("thunder.ogg")
local BUG_DEATH_THUNDER_AUDIO = bn_assets.load_audio("bug_death_thunder.ogg")

function card_init(user, props)
	local card_action = Action.new(user, "CHARACTER_SHOOT")

	-- override animation

	local frame_data = { { 1, 1 }, { 2, 2 }, { 3, 2 }, { 1, 1 } }

	card_action:override_animation_frames(frame_data)

	card_action.on_execute_func = function()
		user:set_counterable(true)
		-- setup buster attachment
		local buster_attachment = card_action:create_attachment("BUSTER")

		local buster_sprite = buster_attachment:sprite()
		buster_sprite:set_texture(user:texture())
		buster_sprite:set_layer(-2)
		buster_sprite:use_root_shader()

		local buster_animation = buster_attachment:animation()
		buster_animation:copy_from(user:animation())
		buster_animation:set_state("BUSTER", frame_data)

		card_action:add_anim_action(2, function()
			user:set_counterable(false)

			local shot = create_spell(user, props)

			local tile = user:get_tile(user:facing(), 1)

			user:field():spawn(shot, tile)
		end)
	end

	return card_action
end

local function get_chase_direction(entity)
	local result = Direction.None
	local direction_table = { Direction.Up, Direction.Down, Direction.Left, Direction.Right }

	local field = entity:field()
	local enemy_list = field:find_nearest_characters(entity, function(character)
		if not character then return false end
		if character:deleted() or character:will_erase_eof() then return false end
		if not character:spawned() then return false end
		return character:team() ~= entity:team()
	end)

	local own_tile = entity:current_tile()

	if #enemy_list > 0 then
		local target = enemy_list[1]
		local target_tile = target:current_tile()
		local own_coordinates = { x = own_tile:x(), y = own_tile:y() }
		local target_coordinates = { x = target_tile:x(), y = target_tile:y() }

		if own_coordinates == target_coordinates then
			result = direction_table[math.random(1, #direction_table)]
		elseif own_coordinates.x < target_coordinates.x then
			result = Direction.Right
		elseif own_coordinates.x > target_coordinates.x then
			result = Direction.Left
		elseif own_coordinates.y < target_coordinates.y then
			result = Direction.Down
		elseif own_coordinates.y > target_coordinates.y then
			result = Direction.Up
		end
	end

	if own_tile:get_tile(result, 1):is_edge() then
		result = Direction.reverse(result)
	end

	return result
end

function create_spell(user, props)
	local spell = Spell.new(user:team())

	local timer = 300
	local slide_timer = 60
	local paralyze_timer = 90
	local state_prefix = "THUNDER_"
	local AUDIO = THUNDER_AUDIO

	if props.damage == 0 and props.card_class == CardClass.Giga then
		timer = 480
		slide_timer = 40
		state_prefix = "BDT_"
		props.damage = 200
		AUDIO = BUG_DEATH_THUNDER_AUDIO
	end

	props.status_durations[Hit.Paralyze] = { paralyze_timer }

	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell:set_tile_highlight(Highlight.Solid)

	local anim = spell:animation()
	spell:set_texture(SPELL_TEXTURE)


	anim:load(SPELL_ANIM_PATH)
	anim:set_state(state_prefix .. "START")
	anim:set_playback(Playback.Loop)


	spell.on_update_func = function(self)
		if timer > 0 then
			timer = timer - 1
		else
			self:animation():set_state(state_prefix .. "END")
			self:animation():set_playback(Playback.Once)
			self:animation():on_complete(function()
				self:delete()
			end)
			return
		end

		local tile = self:current_tile()

		self:attack_tile()

		if self:is_sliding() == false then
			if tile:is_edge() then self:delete() end

			local dest = tile:get_tile(get_chase_direction(self), 1)

			self:slide(dest, slide_timer)
		end
	end

	spell.on_collision_func = function(self, other)
		local field = self:field()
		local tile = self:current_tile()

		battle_helpers.spawn_visual_artifact(field, tile, IMPACT_TEXTURE, IMPACT_ANIM_PATH, "ELEC", 0, 0)

		self:delete()
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	spell.on_spawn_func = function()
		Resources.play_audio(AUDIO)
	end

	return spell
end

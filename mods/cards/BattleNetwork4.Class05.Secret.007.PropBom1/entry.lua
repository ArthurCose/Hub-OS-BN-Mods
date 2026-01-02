local bn_assets = require("BattleNetwork.Assets")

local EXPLOSION_TEXTURE = bn_assets.load_texture("bn4_spell_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("bn4_spell_explosion.animation")
local SHOT_TEXTURE = Resources.load_texture("PropBom.png")

local AUDIO = Resources.load_audio("PropBomb.ogg")
local EXPLOSION_AUDIO = bn_assets.load_audio("explosion_defeatedmob.ogg")


function create_impact_explosion(user, props)
	local tiles = {}
	local backRow1, backRow2 = Field.width() - 2, Field.width() - 3

	if user:facing() == Direction.Left then
		backRow1, backRow2 = 1, 2
	end

	for i = 1, Field.height() - 2 do
		local tile1 = Field.tile_at(backRow1, i)
		local tile2 = Field.tile_at(backRow2, i)
		tiles[#tiles + 1] = tile1
		tiles[#tiles + 1] = tile2
	end



	for _, tile in ipairs(tiles) do
		local explosion = Spell.new(user:team())
		explosion:set_texture(EXPLOSION_TEXTURE)
		local total_explosion = 6
		local new_anim = explosion:animation()
		new_anim:load(EXPLOSION_ANIM_PATH)
		new_anim:set_state("DEFAULT")


		explosion:sprite():set_layer(-2)
		explosion:set_hit_props(
			HitProps.from_card(
				props,
				user:context(),
				Drag.None
			)
		)
		explosion.on_update_func = function(self)
			local tile = self:current_tile()
			self:attack_tile(tile)
		end
		new_anim:on_complete(function()
			explosion:erase()
		end)
		Field.spawn(explosion, tile)
	end
	Resources.play_audio(EXPLOSION_AUDIO)
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")


	local start_columns = 0
	local end_columns = Field.width() - 1
	local x_increment = 1


	if (actor:facing() == Direction.Right) then
		start_columns, end_columns = end_columns, start_columns
		x_increment = -x_increment
	end


	local frame = { 1, 26 }
	local frame_times = { { 1, 26 } }


	action:override_animation_frames(frame_times)
	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(user:texture("battle.png"))
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:copy_from(user:animation("battle.animation"))


		buster_anim:set_state("BUSTER", frame_times)



		local shot = create_projectile(user, props)

		local tile = user:get_tile(user:facing(), 1)




		Field.spawn(shot, tile)
	end



	return action
end

function create_projectile(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	local newProps = HitProps.new(0, Hit.None, Element.None)
	spell:set_hit_props(newProps)

	local attacking = false
	spell:set_tile_highlight(Highlight.Flash)

	local anim = spell:animation()
	spell:set_texture(SHOT_TEXTURE)

	spell._can_move_yet = false

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local fire_x = buster_point.x - origin.x + (21 - user:current_tile():width())
	local fire_y = buster_point.y - origin.y

	spell:set_offset(fire_x, fire_y)

	anim:load("PropBom.animation")
	anim:set_state("SPAWN")
	anim:set_playback(Playback.Once)
	anim:on_complete(function()
		anim:set_state("MOVE")
		anim:set_playback(Playback.Loop)
		-- Allowed to attack
		attacking = true

		-- Allowed to move
		spell._can_move_yet = true
	end)
	-- Allowed to attack
	attacking = true

	-- Allowed to move
	--spell._can_move_yet = true


	spell.on_update_func = function(self)
		if not attacking then return end

		local tile = self:current_tile()
		self:attack_tile(tile)

		if self:is_sliding() == false and spell._can_move_yet == true then
			if tile:is_edge() then
				self:delete()
				create_impact_explosion(user, props)
			end

			local dest = self:get_tile(spell:facing(), 1)
			--anim:set_state("MOVE")
			--anim:set_playback(Playback.Loop)
			self:slide(dest, 15)
		end
	end

	spell.on_collision_func = function(self, other)
		self:delete()
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return spell._can_move_yet
	end

	spell.on_spawn_func = function()
		Resources.play_audio(AUDIO)
	end

	return spell
end

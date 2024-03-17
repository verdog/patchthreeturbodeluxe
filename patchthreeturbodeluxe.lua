-- title:   patch three turbo deluxe
-- authors: dogsplusplus (programming, music) and thetainfelix (art, game design)
-- desc:    battle of the bits game jam five
-- site:    battleofthebits.com
-- license: MIT License
-- version: 1.0
-- script:  lua

-- LIST OF DELUXE IDEAS
--
-- another resource type with the same rarity as the grow time one,
--   that cuts all resources in a straight line (following the direction you match it)
-- little guys coming out of cabins - one guy per match three (?)
--   and more guys coming in and building cabins
-- redo grow mechanic - every set of 3/4 makes bud, 1/2 grows vine, moving fruit/buds
--   with it. bud becomes fruit on second grow time. automatic vine growth?
-- make the game a little more predictable - maybe make edges dormant so you can plan
-- figure out a more sane way to map fruit list to screen
-- MAXIMUM PEPPER
-- rare fruit - maybe the slice powerup is a fruit?
-- modes - endless? with and end? linear?
-- redo fruit matches - same fruit only, gradually introduce more fruits
-- only two time of day: morning and evening

-- `GAME` is all of the game data. everything!
GAME = {
	time_of_day = 0, -- 0: morning, 1: noon, 2: evening
	state = "title",
	combo = 0,
	moves = 0,
	energy = 30,
	froots = 0,
	seed = math.random(),

	-- the trellis grid data
	GRID = {
		--[[
		`cells` is the actual grid data. it contains veggies - see veg_make.
		the first fruit is at index 0 for math reasons.
		]] --
		cells = {},

		x = 20,      -- x location of the upper left corner of the grid
		y = 19,      -- y location of the upper left corner of the grid
		cols = 19,   -- how many columns make up the grid
		rows = 6,    -- how many rows make up the grid. each row is actually two visible rows
		px_space = 8, -- pixel space between grid items
		hover_i = nil, -- the index in `cells` of the currently hovered-over cell. nil if not hovering on grid.
		held_i = nil, -- the index in `cells` of the selected (mouse down) cell. nil if not clicking.
	},

	PLOTS = {},    -- "plots" are the data associated with collected resources. the bar graphs.
	PARTICLES = {}, -- any active particles flying around
	FREE_VEGS = {}, -- any active veggies, freed from their vines, flying around

	-- game state for the grow phase
	GROW = {
		delay = 12,     -- how many frames to wait between each little grow
		survived = false, -- set to true if at least one grow happened in the grow phase
	},

	LILGUY = {
		state = "wait",
		x = 216,
		y = 116,
		vx = 0,  -- x velocity
		vy = 0,  -- y velocity
		onground = false,
		blink = 0, -- how many frames left to do the blink animation
		wait = 0, -- how many frames left to do the fruit claim animation
	},
}

-- `UI` is the data associated with turning data from `GAME` into nice icons n stuff.
UI = {
	notify_queue = {}, -- list of notification messages on the top of the screen

	-- energy, combo, and clock are the little icons attached to the trellis. they all
	-- have the same fields.
	energy = {
		zerox = 160,         -- x/y position the icon should be when energy is zero
		zeroy = 96,
		maxx = 160,          -- x/y position the icon should be when energy is max
		maxy = -8,
		x = GAME.GRID.x + 160, -- current x/y position. these numbers only matter for frame 0.
		y = GAME.GRID.y + 96, -- they are otherwise set every frame by the ui update fn.
		dx = 0,              -- destination x/y position. every frame, move towards this point.
		dy = 0,
	},
	combo = {
		zerox = -15,
		zeroy = 96,
		maxx = -15,
		maxy = -8,
		x = GAME.GRID.x + -15,
		y = GAME.GRID.y + 96,
		dx = 0,
		dy = 0,
	},
	clock = {
		zerox = -16,
		zeroy = -16,
		maxx = 162,
		maxy = -16,
		x = GAME.GRID.x + -16,
		y = GAME.GRID.y + -16,
		dx = 0,
		dy = 0,
	},
}

-- random debug stuff
DEBUG = {
	-- list of things to print in the debug print fn
	items = {},
}

--[[ game ------------------------------------------------
main startup/game loop functions

functions that start with "game_enter" change GAME.state
--]]
function BOOT()
	game_enter_title()
end

function TIC()
	debug_reset()
	game_update()
	game_draw()
	debug_print()
end

function game_enter_title()
	GAME.state = "title"
	GAME.LILGUY.state = "wait"
	GAME.FREE_VEGS = {}
	free_vegs_spawn_inner(math.random(240), -10, 0, 0, math.random())
	music(0)
end

function game_enter_play()
	GAME.time_of_day = 0
	grid_init()
	plots_init()
	GAME.LILGUY.state = "wait"
	GAME.FREE_VEGS = {}
	GAME.state = "play"
	music(1)
end

function game_enter_grow()
	sfx(4)
	GAME.state = "grow"
	GAME.GROW.delay = 60
	GAME.GROW.survived = false
	ui_notify("GROW TIME!!!")
end

function game_enter_lose()
	GAME.state = "lose"
end

function game_update()
	cls(14) -- 14 is sky color
	if GAME.state == "play" then
		grid_update()
		plots_update()
		particle_update()
		free_vegs_update()
		lilguy_update()
		ui_update()
	elseif GAME.state == "grow" then
		grid_update(false) -- disable mouse
		grow_update()
		plots_update()
		particle_update()
		ui_update()
	elseif GAME.state == "lose" then
		ui_update()
	elseif GAME.state == "title" then
		free_vegs_update()
		lilguy_update()
		ui_update()
	end
end

function game_draw()
	if GAME.state ~= "title" then
		bg_draw()
		grid_draw()
		plots_draw()
		ui_bars_draw()
		particle_draw()
		lilguy_draw()
		free_vegs_draw()
		ui_draw()
	else
		bg_draw(true)
		lilguy_draw()
		free_vegs_draw()
		ui_draw()
	end
end

function bg_draw(title)
	map(0, 0, 30, 17, 0, 0, 15)
	map(0, 17, 30, 17, 0, 0, 15)
	map(0, 34, 30, 17, 0, 0, 15)
	if not title then
		map(0, 51, 30, 17, 0, 0, 15)

		-- this palette map is to turn the grey outlines of the trellis into
		-- light grey to reduce visual noise
		palette_map({3}, {4})
		map(0, 68, 30, 17, 0, 0, 15)
		palette_map_reset()
	end
end

-- particles ---------------------------------------------

function particle_make(t, x, y, l)
	return {
		t = t,
		x = x,
		y = y,
		vx = math.random() * 9 - 4.5,
		vy = math.random() * 9 - 4.5,
		life = l + math.random(5),
		maxlife = l + math.random(5),
	}
end

function particle_make_drop(x, y, type)
	table.insert(GAME.PARTICLES, {
		t = 1,
		type = type,
		x = x,
		y = y,
		vx = 0,
		vy = 0,
		life = 999999,
		maxlife = 999999,
	})
end

function particle_make_splash(x, y, type)
	table.insert(GAME.PARTICLES, {
		t = 2,
		type = type,
		x = x,
		y = y,
		life = 30,
		maxlife = 30,
	})
end

function particle_update()
	local msx, msy, msl = mouse()

	for i, p in pairs(GAME.PARTICLES) do
		if p.t == 0 then
			p.x = p.x + p.vx
			p.y = p.y + p.vy
			p.vx = p.vx * 0.6
			p.vy = p.vy * 0.6
		elseif p.t == 1 then
			p.x = p.x + p.vx
			p.y = p.y + p.vy
			p.vy = p.vy + 0.08
			if p.vy > 2 then p.vy = 2 end
		end

		p.life = p.life - 1
		if p.life < 0 then
			table.remove(GAME.PARTICLES, i)
			i = i - 1
		end

		if p.t == 1 then
			if p.y > GAME.GRID.y + 90 then
				table.remove(GAME.PARTICLES, i)
				particle_make_splash(p.x, GAME.GRID.y + 90, p.type)
				i = i - 1
			end
		end
	end
end

function particle_draw()
	for i, p in pairs(GAME.PARTICLES) do
		if p.t == 0 then
			circ(p.x, p.y, lerp(1, 5, p.life / p.maxlife), 6)
		elseif p.t == 1 then
			spr(352 + 2 * p.type, p.x - 4, p.y, 15, 1, 0, 0, 2, 2)
		elseif p.t == 2 then
			local frame = math.floor(3 * ((p.maxlife - math.max(1, p.life)) / p.maxlife))
			spr(384 + 2 * p.type + 32 * frame, p.x - 4, p.y, 15, 1, 0, 0, 2, 2)
		end
	end
end

-- veg ---------------------------------------------------

function veg_make()
	local color = math.random(13)
	if color <= 12 then color = math.floor((color - 1) / 3) + 1 end
	if color == 13 then color = 5 end
	return {
		color = color,
		random = math.random(),
		up_matches = 0,
		dn_matches = 0,
		dormant = 80 + math.floor(math.random(10)),
		age = 0,

		x = 0,
		y = 0,
		dx = 0,
		dy = 0,
	}
end

function veg_snap_grid(veg, i)
	local gx, gy = grid_idx_to_grid_xy(i)
	local px, py = grid_xy_to_pixel_xy(gx, gy)
	veg.dx = px + GAME.GRID.px_space / 2
	veg.dy = py + GAME.GRID.px_space / 2
end

function veg_update(i, v)
	v.x = v.x + (v.dx - v.x) / 7
	v.y = v.y + (v.dy - v.y) / 7
	if math.abs(v.dx - v.x) <= 1 then
		v.x = v.dx
	end
	if math.abs(v.dy - v.y) <= 1 then
		v.y = v.dy
	end
end

function veg_draw(i, v, x, y)
	local frame = math.floor((time() / 600 * 4) % 4)
	if frame == 3 then frame = 1 end
	if GAME.GRID.hover_i and i ~= GAME.GRID.hover_i then frame = 1 end

	if v.color == 0 then
		-- empty space
	elseif v.color == 1 then
		-- sun
		spr(256 + frame * 32, v.x - GAME.GRID.px_space + x, v.y - GAME.GRID.px_space + y, 15, 1, 0, 0, 2, 2)
	elseif v.color == 2 then
		-- water
		spr(258 + frame * 32, v.x - GAME.GRID.px_space + x, v.y - GAME.GRID.px_space + y, 15, 1, 0, 0, 2, 2)
	elseif v.color == 3 then
		-- poop
		spr(260 + frame * 32, v.x - GAME.GRID.px_space + x, v.y - GAME.GRID.px_space + y, 15, 1, 0, 0, 2, 2)
	elseif v.color == 4 then
		-- seed
		spr(262 + frame * 32, v.x - GAME.GRID.px_space + x, v.y - GAME.GRID.px_space + y, 15, 1, 0, 0, 2, 2)
	elseif v.color == 5 then
		-- hourglass
		local frame = math.floor(time() / 1500) % 4
		if frame == 3 then frame = 0 end
		spr(264 + 32 * frame, v.x - GAME.GRID.px_space + x, v.y - GAME.GRID.px_space + y, 13, 1, 0, 0, 2, 2)
	elseif v.color == 6 or v.color == 7 or v.color == 8 then
		-- vine
		local variant = math.floor(v.random * 4) * 2
		local shape = 0
		local flip = 0

		local me_x, _ = grid_idx_to_grid_xy(i)

		if v.up and v.dn then
			local up_x, _ = grid_idx_to_grid_xy(v.up)
			local dn_x, _ = grid_idx_to_grid_xy(v.dn)

			if dn_x < me_x and me_x < up_x then
				-- growing left to right, no flip
				shape = 1
			elseif dn_x > me_x and me_x > up_x then
				-- growing right to left, flip
				shape = 1
				flip = 1
			else
				-- must be a change in direction
				shape = 2
				if me_x < up_x then
					flip = 1
				end
			end
		elseif v.up then
			local up_x, _ = grid_idx_to_grid_xy(v.up)
			-- only an up part means the root vine
			shape = 4
			if up_x > me_x then
				flip = 1
			end
		elseif v.dn then
			local dn_x, _ = grid_idx_to_grid_xy(v.dn)
			-- only a down part means the tip of a vine
			shape = 0
			if me_x < dn_x then
				flip = 1
			end
		else
			-- no up and no down means we are a lil sprout
			shape = 3
			flip = math.floor(v.random * 2)
		end

		spr(96 + shape * 32 + variant, v.x - GAME.GRID.px_space, v.y - GAME.GRID.px_space,
			15, 1, flip, 0, 2, 2)
	end

	if v.color == 7 then
		-- froot
		local variant = math.floor(v.random * 8) * 32
		local flip = math.floor(v.random * 2)
		local frame = math.floor(time() / 1000 + v.random * 4) % 4
		if frame == 3 then frame = 1 end
		spr(266 + variant + frame * 2, v.x - GAME.GRID.px_space, v.y - GAME.GRID.px_space,
			15, 1, flip, 0, 2, 2)
	elseif v.color == 8 then
		local flip = math.floor(v.random * 2)
		spr(392, v.x - GAME.GRID.px_space, v.y - GAME.GRID.px_space,
			15, 1, flip, 0, 2, 2)
	end
end

function free_vegs_spawn(veg)
	free_vegs_spawn_inner(veg.dx, veg.dy, math.random() * 4 - 2, -2, veg.random)
end

function free_vegs_spawn_inner(x, y, vx, vy, random)
	table.insert(GAME.FREE_VEGS, {
		x = x,
		y = y,
		vx = vx,
		vy = vy,
		random = random,
	})
end

function free_vegs_update()
	for i, v in pairs(GAME.FREE_VEGS) do
		v.x = v.x + v.vx
		v.y = v.y + v.vy

		v.vy = v.vy + 0.05
		if v.vy > 2 then v.vy = 2 end

		if v.x < 0 then
			v.x = 0
			v.vx = -v.vx * 0.9
			v.vy = v.vy * 0.7
		end
		if v.x > 231 then
			v.x = 231
			v.vx = -v.vx * 0.9
			v.vy = v.vy * 0.7
		end
		if v.y > 123 then
			v.y = 123
			v.vx = v.vx * 0.9
			v.vy = math.min(0, (-v.vy) * 0.5)
		end
	end
end

function free_vegs_draw()
	for i, v in pairs(GAME.FREE_VEGS) do
		local variant = math.floor(v.random * 8) * 32
		local flip = math.floor(v.random * 2)
		local frame = math.floor(time() / 250 + v.random * 4) % 4
		if frame == 3 then frame = 1 end
		spr(266 + variant + frame * 2, v.x - 4, math.floor(v.y - 4 + 0.5),
			15, 1, flip, 0, 2, 2)
	end
end

function lilguy_update()
	GAME.LILGUY.blink = GAME.LILGUY.blink - 1

	local blink = math.random() * 4 < 0.01
	if blink then
		GAME.LILGUY.blink = 8
	end

	GAME.LILGUY.x = GAME.LILGUY.x + GAME.LILGUY.vx
	GAME.LILGUY.y = GAME.LILGUY.y + GAME.LILGUY.vy
	GAME.LILGUY.vy = GAME.LILGUY.vy + 0.06

	GAME.LILGUY.onground = GAME.LILGUY.y >= 116
	if GAME.LILGUY.onground then
		GAME.LILGUY.vx = GAME.LILGUY.vx * 0.93
		GAME.LILGUY.y = 116
		GAME.LILGUY.vy = 0
	end

	if GAME.LILGUY.state == "wait" then
		if math.abs(GAME.LILGUY.x - 216) > 1 then
			GAME.LILGUY.vx = GAME.LILGUY.vx + sign(216 - GAME.LILGUY.x) * 0.06
		end

		if #GAME.FREE_VEGS > 0 then
			GAME.LILGUY.state = "fetch"
			GAME.LILGUY.vy = -2
		end
	elseif GAME.LILGUY.state == "fetch" then
		if GAME.LILGUY.onground then
			GAME.LILGUY.vx = GAME.LILGUY.vx + sign(GAME.FREE_VEGS[1].x - GAME.LILGUY.x) * 0.06
		end
		if GAME.LILGUY.vx > 1 then GAME.LILGUY.vx = 1 end
		if GAME.LILGUY.vx < -1 then GAME.LILGUY.vx = -1 end

		if math.abs(GAME.LILGUY.x - GAME.FREE_VEGS[1].x) < 1 and
				math.abs(GAME.LILGUY.vx) < 0.25 and
				math.abs(GAME.FREE_VEGS[1].vx) < 0.25 and
				math.abs(GAME.FREE_VEGS[1].vy) < 0.25 then
			GAME.LILGUY.state = "claim"
			GAME.LILGUY.wait = 45
			GAME.LILGUY.vx = 0
			if GAME.state ~= "title" then
				sfx(6)
			end
		end
	elseif GAME.LILGUY.state == "claim" then
		if GAME.LILGUY.wait > 0 then
			GAME.LILGUY.wait = GAME.LILGUY.wait - 1
			GAME.FREE_VEGS[1].x = GAME.LILGUY.x + 6
			GAME.FREE_VEGS[1].y = GAME.LILGUY.y - 8
		else
			table.remove(GAME.FREE_VEGS, 1)

			if #GAME.FREE_VEGS == 0 then
				GAME.LILGUY.state = "wait"
			else
				GAME.LILGUY.state = "fetch"
			end
		end
	end
end

function lilguy_draw()
	local flip = 0

	if GAME.LILGUY.blink > 0 then
		palette_map({4, 6}, {3, 3})
	end

	if GAME.LILGUY.state == "claim" then
		spr(488, math.floor(GAME.LILGUY.x - 4 + 0.5), GAME.LILGUY.y, 15, 1, 0, 0, 2, 2)
	else
		flip = (GAME.LILGUY.vx > 0.1) and 1 or 0
		local sp = 424

		if GAME.LILGUY.onground then
			if math.abs(GAME.LILGUY.vx) > 0.02 then
				sp = 480 + (math.floor(time() / 50) % 4) * 2
			else
				-- idle
				sp = 424
			end
		else
			-- in air
			sp = 456
		end

		spr(sp, math.floor(GAME.LILGUY.x - 4 + 0.5), GAME.LILGUY.y, 15, 1, flip, 0, 2, 2)
	end

	palette_map_reset()
end

--[[ grid ------------------------------------------------
the grid logic. this is the most complicated part of the whole game! :-)
this stuff handles dragging, dropping, and more :o
FIXME(josh): write more about this weird stuff.
]]
--

function grid_init()
	for i = 0, (GAME.GRID.cols * GAME.GRID.rows) - 1 do
		GAME.GRID.cells[i] = veg_make()
		GAME.GRID.cells[i].color = ((i * 2) % 4) + 1
		veg_snap_grid(GAME.GRID.cells[i], i)
		GAME.GRID.cells[i].x = GAME.GRID.cells[i].dx
		GAME.GRID.cells[i].y = GAME.GRID.cells[i].dy
	end
end

function grid_update_dragndrop(gx, gy, msl, msr)
	if gx == nil or gy == nil then return end

	-- grab/swap/drop grid item
	if not GAME.GRID.held_i and msl then
		-- grab it
		local i = grid_xy_to_grid_idx(gx, gy)
		if i and GAME.GRID.cells[i].color ~= 0 and GAME.GRID.cells[i].color <= 5 then
			GAME.GRID.held_i = i
		end
	elseif GAME.GRID.held_i and msl then
		-- swap it
		local i = grid_xy_to_grid_idx(gx, gy)
		if i and GAME.GRID.cells[i].color ~= 0 and GAME.GRID.cells[i].color <= 5 then
			local held_ns = grid_calc_neighbors(GAME.GRID.held_i)
			if table.contains(held_ns, i) then
				grid_swap(GAME.GRID.held_i, i)
				GAME.GRID.held_i = nil
				GAME.moves = GAME.moves + 1
				GAME.energy = GAME.energy - 5
				sfx(2)

				if GAME.energy < 1 then
					ui_notify("OUT OF MOVES!!! GAME OVER!!!")
					game_enter_lose()
				end
			end
		end
	else
		-- drop it
		GAME.GRID.held_i = nil
	end
end

function grid_update_tally_local_matches()
	for i, v in pairs(GAME.GRID.cells) do
		-- clean up dangling ups left after big fruit match
		if v.up and GAME.GRID.cells[v.up].color < 6 then
			v.up = nil
		end

		if v.color ~= 6 and v.color ~= 8 then
			v.up_matches = 0
			v.dn_matches = 0
			local ns = grid_calc_neighbors(i)
			for j, ui in pairs(ns) do
				if GAME.GRID.cells[ui].color == v.color and
						GAME.GRID.cells[ui].dormant == 0 and
						v.color ~= 0
				then
					if j % 2 == 0 then
						v.up_matches = v.up_matches + 1
					else
						v.dn_matches = v.dn_matches + 1
					end
				end
			end
		end
	end
end

function grid_update_spread_local_matches()
	for i, v in pairs(GAME.GRID.cells) do
		local ns = grid_calc_neighbors(i)
		if v.up_matches >= 2 then
			for j, ui in pairs(ns) do
				if v.color == GAME.GRID.cells[ui].color and j % 2 == 0 then
					GAME.GRID.cells[ui].up_matches = 2
				end
			end
		end

		if v.dn_matches >= 2 then
			for j, ui in pairs(ns) do
				if v.color == GAME.GRID.cells[ui].color and j % 2 == 1 then
					GAME.GRID.cells[ui].dn_matches = 2
				end
			end
		end
	end
end

function grid_update_pop_match(i, v)
	-- if fruit, BIG MATCH
	if v.color == 7 then
		GAME.froots = GAME.froots + 1
		ui_notify("FRUITS GET!!!")
		free_vegs_spawn(v)
	end

	if v.color == 6 or v.color == 7 then
		if v.up then
			-- pop all the way up
			grid_update_pop_match(v.up, GAME.GRID.cells[v.up])
			-- todo other fruit stuff
		end
	end

	-- replace veg
	local new_v = veg_make()
	new_v.color = 0
	veg_snap_grid(new_v, i)
	new_v.x = GAME.GRID.cells[i].dx
	new_v.y = GAME.GRID.cells[i].dy
	GAME.GRID.cells[i] = new_v

	-- particles
	local gx, gy = grid_idx_to_grid_xy(i)
	local px, py = grid_xy_to_pixel_xy(gx, gy)
	for i = 0, 4 do
		table.insert(GAME.PARTICLES, particle_make(0, px + 8, py + 8, 24))
	end

	-- audio
	if v.color == 7 then
		sfx(0)
	else
		sfx(1, math.floor(8 + lerp(0, 77, GAME.combo / 300)))
	end

	-- combo/moves
	GAME.combo = GAME.combo + 1
	GAME.energy = GAME.energy + 1
end

function grid_update_pop_matches(advance_time_t)
	for i, v in pairs(GAME.GRID.cells) do
		if v.dormant > 0 then
			v.dormant = v.dormant - 1
		elseif v.up_matches >= 2 or v.dn_matches >= 2 then
			if v.color ~= 7 or GAME.state == "play" then
				grid_update_pop_match(i, v)
			end
			-- fall to plot
			local gx, gy = grid_idx_to_grid_xy(i)
			if gx % 2 == 1 then
				if v.color == 1 then
					GAME.PLOTS[gx].sun = GAME.PLOTS[gx].sun + 1
				elseif v.color == 2 then
					GAME.PLOTS[gx].water = GAME.PLOTS[gx].water + 1
				elseif v.color == 3 then
					GAME.PLOTS[gx].poop = GAME.PLOTS[gx].poop + 1
				elseif v.color == 4 then
					GAME.PLOTS[gx].seed = GAME.PLOTS[gx].seed + 1
				end

				if v.color < 5 then
					local px, py = grid_xy_to_pixel_xy(gx, gy)
					particle_make_drop(px, py, v.color - 1)
				end
			elseif v.color == 5 then
				-- advance time
				advance_time_t[1] = true
			end
		end
	end
end

function grid_update_trickle(any_dormant_t)
	for i, v in pairs(GAME.GRID.cells) do
		v.age = v.age + 1
		v.swapped = false
		if v.color > 0 and v.color < 6 and v.dormant > 0 then
			any_dormant_t[1] = true
		end
	end

	for i, v in pairs(GAME.GRID.cells) do
		if v.color == 0 and v.swapped == false and
				v.age % 5 == 0 then
			local ns_cand = grid_calc_up_neighbors(i)
			local ns = {}

			for i, n in pairs(ns_cand) do
				if GAME.GRID.cells[n].color > 0 and GAME.GRID.cells[n].color < 6 then
					table.insert(ns, n)
				end
			end

			if #ns > 0 then
				local pick = 1

				if GAME.time_of_day == 0 then
					-- morning: right: last
					pick = #ns
				elseif GAME.time_of_day == 1 then
					-- noon: random
					pick = math.random(#ns)
				elseif GAME.time_of_day == 2 then
					-- evening: left
					pick = 1
				end

				if GAME.GRID.cells[ns[pick]].color ~= 0 and
						not GAME.GRID.cells[ns[pick]].swapped then
					GAME.GRID.cells[i].swapped = true
					GAME.GRID.cells[ns[pick]].swapped = true
					GAME.GRID.cells[i].dormant = 35
					GAME.GRID.cells[ns[pick]].dormant = 35
					grid_swap(i, ns[pick])
				end
			elseif math.floor(i / GAME.GRID.cols) == 0 then
				-- no up neighbors, top row
				GAME.GRID.cells[i] = veg_make()
				veg_snap_grid(GAME.GRID.cells[i], i)
				GAME.GRID.cells[i].x = GAME.GRID.cells[i].dx
				GAME.GRID.cells[i].y = GAME.GRID.cells[i].dy
			end
		end
	end
end

function grid_update(enable_mouse)
	local msx, msy, msl, msm, msr = mouse()
	local gx, gy = pixel_xy_to_grid_xy(msx, msy)
	if enable_mouse ~= nil and enable_mouse == false then
		msl = false
	end

	-- grid hover
	if gx then
		GAME.GRID.hover_i = grid_xy_to_grid_idx(gx, gy)

		-- froot cheets
		if msr then
			-- grid[grid_hover_i].color = 7
		end
	end

	grid_update_dragndrop(gx, gy, msl, msr)
	-- this just moves the veg x/y for drawing
	for i, v in pairs(GAME.GRID.cells) do
		veg_update(i, v)
	end

	local advance_time = { false }
	local any_dormant = { false }

	if msl == false then
		grid_update_tally_local_matches()
		grid_update_spread_local_matches()
		grid_update_pop_matches(advance_time)
		grid_update_trickle(any_dormant)
	else
		any_dormant[1] = true
	end

	if advance_time[1] == true then
		game_enter_grow()
	end

	if any_dormant[1] == false then
		if GAME.combo > 25 then
			sfx(5)
		end
		GAME.combo = 0
	end
end

function grid_swap(idx1, idx2)
	local tmp = GAME.GRID.cells[idx1]
	GAME.GRID.cells[idx1] = GAME.GRID.cells[idx2]
	GAME.GRID.cells[idx2] = tmp
	veg_snap_grid(GAME.GRID.cells[idx1], idx1)
	veg_snap_grid(GAME.GRID.cells[idx2], idx2)
end

function grid_draw()
	for i, v in pairs(GAME.GRID.cells) do
		if v.color >= 1 and v.color <= 5 and v.dormant > 0 then
			veg_draw(i, v, 0, 0)
		elseif v.color > 5 then
			if v.age < 24 then
				palette_map_all(6)
				veg_draw(i, v, 0, 0)
				palette_map_reset()
			else
				veg_draw(i, v, 0, 0)
			end
		else
			veg_draw(i, v, 0, 0)
		end
	end

	if GAME.GRID.held_i then
		local gx, gy = grid_idx_to_grid_xy(GAME.GRID.held_i)
		local px, py = grid_xy_to_pixel_xy(gx, gy)
		rectb(px - 2, py - 2,
			GAME.GRID.px_space + 5, GAME.GRID.px_space + 5, 0)
	end

	if GAME.GRID.hover_i then
		local gx, gy = grid_idx_to_grid_xy(GAME.GRID.hover_i)
		local px, py = grid_xy_to_pixel_xy(gx, gy)
		rectb(px - 2, py - 2,
			GAME.GRID.px_space + 5, GAME.GRID.px_space + 5, 0)
	end
end

function add_valid_grid_idx(t, i)
	local GRID_SIZE = GAME.GRID.rows * GAME.GRID.cols
	if i >= 0 and i < GRID_SIZE then
		table.insert(t, i)
	end
end

function grid_calc_up_neighbors(i)
	local result = {}
	local col = i % GAME.GRID.cols
	local lastc = GAME.GRID.cols - 1

	if (i % GAME.GRID.cols) % 2 == 0 then
		if col ~= 0 then add_valid_grid_idx(result, i - GAME.GRID.cols - 1) end
		if col ~= lastc then add_valid_grid_idx(result, i - GAME.GRID.cols + 1) end
	else
		if col ~= 0 then add_valid_grid_idx(result, i - 1) end
		if col ~= lastc then add_valid_grid_idx(result, i + 1) end
	end

	return result
end

function grid_calc_dn_neighbors(i)
	local result = {}
	local col = i % GAME.GRID.cols
	local lastc = GAME.GRID.cols - 1

	if (i % GAME.GRID.cols) % 2 == 1 then
		if col ~= lastc then add_valid_grid_idx(result, i + GAME.GRID.cols + 1) end
		if col ~= 0 then add_valid_grid_idx(result, i + GAME.GRID.cols - 1) end
	else
		if col ~= lastc then add_valid_grid_idx(result, i + 1) end
		if col ~= 0 then add_valid_grid_idx(result, i - 1) end
	end

	return result
end

function grid_calc_neighbors(i)
	local result = {}
	local up = grid_calc_up_neighbors(i)
	local dn = grid_calc_dn_neighbors(i)
	return table.concat(up, dn)
end

function grid_idx_to_grid_xy(idx)
	local x = math.floor(idx % GAME.GRID.cols)
	local y = math.floor(idx / GAME.GRID.cols)
	return x, y
end

function grid_xy_to_grid_idx(x, y)
	return math.floor(y * GAME.GRID.cols + x)
end

function grid_pixel_size()
	return GAME.GRID.px_space * GAME.GRID.cols,
			GAME.GRID.px_space * GAME.GRID.rows * 2
end

function grid_xy_to_pixel_xy(x, y)
	if x % 2 == 0 then
		return GAME.GRID.x + x * GAME.GRID.px_space,
				GAME.GRID.y + y * 2 * GAME.GRID.px_space
	else
		return GAME.GRID.x + x * GAME.GRID.px_space,
				GAME.GRID.y + GAME.GRID.px_space + y * 2 * GAME.GRID.px_space
	end
end

function pixel_xy_to_grid_xy(x, y)
	local gpx = x - GAME.GRID.x
	local gpy = y - GAME.GRID.y
	local gw, gh = grid_pixel_size()

	-- if x,y is outside of the grid's bounding box, return nil
	if gpx < 0 or gpx >= gw or gpy < 0 or gpy >= gh then
		return nil, nil
	end

	-- calculate which cell of the subgrid x,y is in
	local spx = math.floor(gpx / GAME.GRID.px_space)
	local spy = math.floor(gpy / GAME.GRID.px_space)

	-- mouse is directly over an occupied space
	if spx % 2 == 0 then
		if spy % 2 == 0 then
			return math.floor(spx), math.floor(spy / 2)
		end
	else
		if spy % 2 == 1 then
			return math.floor(spx), math.floor(spy / 2)
		end
	end

	-- mouse is over a void space. take the pointer's
	-- angle relative to the center of the void and
	-- find the closest occupied space.
	local grid_middle_x = GAME.GRID.x + spx * GAME.GRID.px_space + GAME.GRID.px_space / 2
	local grid_middle_y = GAME.GRID.y + spy * GAME.GRID.px_space + GAME.GRID.px_space / 2

	local to_p_x = x - grid_middle_x
	local to_p_y = y - grid_middle_y
	local angle = math.atan(to_p_y, to_p_x) % (2 * math.pi)

	if angle < math.pi / 4 or angle > math.pi / 4 * 7 then
		return pixel_xy_to_grid_xy(x + GAME.GRID.px_space, y)
	elseif angle < math.pi / 4 * 3 then
		return pixel_xy_to_grid_xy(x, y + GAME.GRID.px_space)
	elseif angle < math.pi / 4 * 5 then
		return pixel_xy_to_grid_xy(x - GAME.GRID.px_space, y)
	else
		return pixel_xy_to_grid_xy(x, y - GAME.GRID.px_space)
	end
end

-- plots -------------------------------------------------

function plot_make()
	return {
		sun = 0,
		water = 0,
		poop = 0,
		seed = 0,
	}
end

function plots_init()
	for i = 1, GAME.GRID.cols - 1, 2 do
		GAME.PLOTS[i] = plot_make()
	end
end

function plots_update()

end

function plots_draw()
	for i, p in pairs(GAME.PLOTS) do
		local x = GAME.GRID.x + i * GAME.GRID.px_space
		local y = GAME.GRID.y + 102
		for j = 0, p.sun do
			local color = j == p.sun and 3 or 12
			line(x, y + j, x + 1, y + j, color)
		end
		for j = 0, p.water do
			local color = j == p.water and 3 or 14
			line(x + 2, y + j, x + 3, y + j, color)
		end
		for j = 0, p.poop do
			local color = j == p.poop and 3 or 15
			line(x + 4, y + j, x + 5, y + j, color)
		end
		for j = 0, p.seed do
			local color = j == p.seed and 3 or 13
			line(x + 6, y + j, x + 7, y + j, color)
		end
	end
end

function grow_update()
	-- wait for combo to be over
	if GAME.combo ~= 0 then return end

	if GAME.GROW.delay > 0 then
		-- wait
		GAME.GROW.delay = GAME.GROW.delay - 1
		return
	else
		-- grow a little
		local grew_any = false

		local order = {}
		for i, _ in pairs(GAME.PLOTS) do
			table.insert(order, i)
		end
		table.shuffle(order)

		for _, i in pairs(order) do
			local p = GAME.PLOTS[i]

			local power = 0
			if p.sun > 0 then power = power + 1 end
			if p.water > 0 then power = power + 1 end
			if p.poop > 0 then power = power + 1 end
			if p.seed > 0 then power = power + 1 end

			if power >= 1 then
				if p.sun > 0 then p.sun = p.sun - 1 end
				if p.water > 0 then p.water = p.water - 1 end
				if p.poop > 0 then p.poop = p.poop - 1 end
				if p.seed > 0 then p.seed = p.seed - 1 end

				grew_any = true

				local grid_idx = GAME.GRID.cols * (GAME.GRID.rows - 1) + i
				grow_plot(grid_idx, power)
				break
			end
		end

		if grew_any == true then
			GAME.GROW.delay = 12
			GAME.GROW.survived = true
		else
			if GAME.GROW.survived then
				GAME.state = "play"
				GAME.time_of_day = (GAME.time_of_day + 1) % 3
			else
				ui_notify("UNDERGROWTH!!! ENERGY PENALTY!!!")
				GAME.state = "play"
				GAME.time_of_day = (GAME.time_of_day + 1) % 3
				GAME.energy = GAME.energy - 25
			end
		end
	end
end

function grow_plot(grid_idx, power)
	if GAME.GRID.cells[grid_idx].color < 6 then
		-- not a vine, put first sprout
		grow_plot_set_stem(nil, grid_idx, 0)
	else
		if power == 1 or power >= 4 then
			-- 1 means a plain vine grow, 4 means fruit sprout on top
			local p = grid_idx
			while GAME.GRID.cells[p].color >= 6 do
				if GAME.GRID.cells[p].up then
					p = GAME.GRID.cells[p].up
				else
					local ns = grid_calc_up_neighbors(p)
					local valid = {}

					for i, n in pairs(ns) do
						if GAME.GRID.cells[n].color < 6 then
							table.insert(valid, n)
						end
					end

					if #valid > 0 then
						local pick
						if GAME.time_of_day == 0 then
							pick = 1
						elseif GAME.time_of_day == 1 then
							pick = math.random(#valid)
						elseif GAME.time_of_day == 2 then
							pick = #valid
						end
						grow_plot_set_stem(p, valid[pick], power)
					elseif power == 4 then
						grow_plot(grid_idx, 3)
					else
						-- nothing we can do!
					end
					break
				end
			end
		elseif power == 2 then
			-- put a pod on the vine somewhere

			-- pick a random spot
			local ticks = math.random(16)
			local first = grid_idx
			local p = grid_idx
			for i = 0, ticks do
				if GAME.GRID.cells[p].up then
					p = GAME.GRID.cells[p].up
				else
					p = first
				end
			end

			if p == first and not GAME.GRID.cells[first].up then
				-- can't do anything, just grow vine
				grow_plot(grid_idx, 1)
			else
				if p == first then p = GAME.GRID.cells[first].up end
				-- put a pod there
				if GAME.GRID.cells[p].color ~= 7 and GAME.GRID.cells[p].color ~= 8 then
					GAME.GRID.cells[p].color = 8
					GAME.GRID.cells[p].age = 0
					sfx(3)
				else
					grow_plot(grid_idx, 1)
				end
			end
		elseif power == 3 then
			-- convert highest pod into fruit

			local p = grid_idx
			local hipod = nil
			while GAME.GRID.cells[p].up do
				if GAME.GRID.cells[p].color == 8 then hipod = p end
				p = GAME.GRID.cells[p].up
			end

			if hipod then
				GAME.GRID.cells[hipod].color = 7
				GAME.GRID.cells[p].age = 0
				sfx(3)
			else
				-- no pod, just try to put a pod somewhere
				grow_plot(grid_idx, 2)
			end
		end
	end
end

function grow_plot_set_stem(prev_idx, idx, power)
	sfx(3)
	local v = veg_make()

	if power >= 4 then
		v.color = 7 -- FROOT
	elseif power == 2 then
		v.color = 8 -- pod
	else
		v.color = 6 -- vine
	end

	veg_snap_grid(v, idx)
	v.x = v.dx
	v.y = v.dy
	v.dormant = 3

	if prev_idx then
		GAME.GRID.cells[prev_idx].up = idx
		v.dn = prev_idx
	end

	GAME.GRID.cells[idx] = v
end

function grow_plot_kill_stem(i)
	local p = GAME.GRID.cells[i]
	while p do
		local nexti = p.up
		p.color = 0
		p.up = nil
		p.dormant = 0
		if nexti then
			p = GAME.GRID.cells[nexti]
		else
			p = nil
		end
	end
end

-- ui ----------------------------------------------------

function ui_update()
	if GAME.state ~= "title" then
		for i, notif in pairs(UI.notify_queue) do
			notif.x = notif.x - 1
			if notif.x < -240 then
				table.remove(UI.notify_queue, i)
				i = i - 1
			end
		end

		UI.energy.dx = GAME.GRID.x + lerp(UI.energy.zerox, UI.energy.maxx, (GAME.energy / 300))
		UI.energy.dy = GAME.GRID.y + lerp(UI.energy.zeroy, UI.energy.maxy, (GAME.energy / 300))

		UI.combo.dx = GAME.GRID.x + lerp(UI.combo.zerox, UI.combo.maxx, (GAME.combo / 150))
		UI.combo.dy = GAME.GRID.y + lerp(UI.combo.zeroy, UI.combo.maxy, (GAME.combo / 150))

		if GAME.time_of_day == 0 then
			UI.clock.dx = GAME.GRID.x - 16
			UI.clock.dy = GAME.GRID.y - 16
		elseif GAME.time_of_day == 1 then
			UI.clock.dx = GAME.GRID.x + 73
			UI.clock.dy = GAME.GRID.y - 16
		else
			UI.clock.dx = GAME.GRID.x + 162
			UI.clock.dy = GAME.GRID.y - 16
		end

		UI.energy.x = UI.energy.x + (UI.energy.dx - UI.energy.x) / 7
		UI.energy.y = UI.energy.y + (UI.energy.dy - UI.energy.y) / 7
		UI.combo.x = UI.combo.x + (UI.combo.dx - UI.combo.x) / 7
		UI.combo.y = UI.combo.y + (UI.combo.dy - UI.combo.y) / 7
		UI.clock.y = UI.clock.y + (UI.clock.dy - UI.clock.y) / 7
		UI.clock.x = UI.clock.x + (UI.clock.dx - UI.clock.x) / 7
	else
		local _, _, msl, _, _ = mouse()
		if msl == true then
			game_enter_play()
		end

		if math.random() < 0.003 then
			free_vegs_spawn_inner(math.random(240), -10, 0, 0, math.random())
		end
	end
end

function ui_draw()
	if GAME.state ~= "title" then
		spr(51, 186, 1, 15)
		if GAME.time_of_day == 0 then
			print("TIME:\n morning", 195, 2, 3)
		elseif GAME.time_of_day == 1 then
			print("TIME:\n noon", 195, 2, 3)
		elseif GAME.time_of_day == 2 then
			print("TIME:\n evening", 195, 2, 3)
		end

		spr(66, 186, 12, 15)
		print(string.format("COMBO:\n %d", GAME.combo), 195, 14, 3)
		print(string.format("MOVES:\n %d", GAME.moves), 195, 26, 3)
		spr(50, 186, 36, 15)
		local ecolor = 3
		if GAME.energy < 30 and GAME.moves > 2 then
			ecolor = 3 + 12 * math.floor((time() / 250) % 2)
		end
		print(string.format("ENERGY:\n %d", GAME.energy), 195, 38, ecolor)
		print(string.format("FRUITS:\n %d", GAME.froots), 195, 50, 3)

		-- debug stuff
		-- print(string.format("STATE: %s", GAME.state), 180, 38, 14)

		for i, notif in pairs(UI.notify_queue) do
			local c = 6 + 8 * (math.floor(notif.x / 8) % 2)
			-- make it BOOOLLLDD!!!
			print(notif.words, notif.x, notif.y - 1, 3)
			print(notif.words, notif.x + 1, notif.y, 3)
			print(notif.words, notif.x, notif.y + 1, 3)
			print(notif.words, notif.x - 1, notif.y, 3)
			print(notif.words, notif.x, notif.y, c)
		end

		if GAME.state == "lose" then
			local tips = {
				"TIP: low fruit matches clear the whole vine!",
				"TIP: plants grow towards the clock icon!",
				"TIP: all fruits can match all other fruits!",
				"TIP: balanced plant diets are the best!",
				"TIP: combos restore more energy!",
				"TIP: matches must be diagonal!",
			}
			print(tips[math.floor(GAME.seed * #tips) + 1], 6, 128, 4)
		end
	else
		-- map all colors to black to draw outlines
		local x = 104
		local y = 18 + 8 * math.sin(time() / 2000)
		palette_map_all(3)

		spr(76, x - 1, y - 1, 15, 1, 0, 0, 4, 3)
		spr(76, x, y - 1, 15, 1, 0, 0, 4, 3)
		spr(76, x + 1, y - 1, 15, 1, 0, 0, 4, 3)

		spr(76, x - 1, y, 15, 1, 0, 0, 4, 3)
		spr(76, x, y, 15, 1, 0, 0, 4, 3)
		spr(76, x + 1, y, 15, 1, 0, 0, 4, 3)

		spr(76, x - 1, y + 1, 15, 1, 0, 0, 4, 3)
		spr(76, x, y + 1, 15, 1, 0, 0, 4, 3)
		spr(76, x + 1, y + 1, 15, 1, 0, 0, 4, 3)

		palette_map_reset()

		spr(76, x, y, 15, 1, 0, 0, 4, 3)

		print("presented by", x - 6, y + 32, 3, false, 1, true)
		print("dogsplusplus and thetainfelix", x - 40, y + 38, 3, false, 1, true)
		print("for the fifth battleofthebits game jam", x - 52, y + 48, 3, false, 1, true)
		print("match icons in groups of three to feed your plants,", x - 70, y + 58, 3, false, 1, true)
		print("match veggies in groups of three to GET them!", x - 58, y + 64, 3, false, 1, true)
		print("click anywhere to start", x - 26, y + 78, 3, false, 1, true)
	end
end

function ui_bars_draw()
	rect(UI.energy.x + 3, UI.energy.y, 1, GAME.GRID.y + UI.energy.zeroy - UI.energy.y + 5, 8)
	spr(50, UI.energy.x, UI.energy.y, 15, 1, 0, 0)

	rect(UI.combo.x + 3, UI.combo.y, 1, GAME.GRID.y + UI.combo.zeroy - UI.combo.y + 5, 14)
	spr(66, UI.combo.x, UI.combo.y, 15, 1, 0, 0)

	spr(51, UI.clock.x, UI.clock.y - 1, 15, 1, 0, 0)
end

function ui_notify(str)
	table.insert(UI.notify_queue, {
		words = str,
		x = 240,
		y = 3
	})
end

-- debug/util --------------------------------------------

function debug_reset()
	DEBUG.items = {}
end

function debug_print()
	local y = 0
	for k, l in pairs(DEBUG.items) do
		print(l, 0, y, 0)
		print(l, 0, y + 2, 0)
		print(l, 0, y + 1, 12)
		y = y + 8
	end
end

function dprint(thing)
	table.insert(DEBUG.items, thing)
end

function lerp(a, b, t)
	return a + (b - a) * t
end

function sign(number)
	if number > 0 then
		return 1
	elseif number < 0 then
		return -1
	else
		return 0
	end
end

function palette_map_all(to)
	local PAL_MAP = 0x3FF0
	for i=0,15 do
		poke4(PAL_MAP * 2 + i, to)
	end
end

function palette_map(from, to)
	local PAL_MAP = 0x3FF0
	for i=1,#from do
		poke4(PAL_MAP * 2 + from[i], to[i])
	end
end

function palette_map_reset()
	local PAL_MAP = 0x3FF0
	for j = 0,15 do
		poke4(PAL_MAP * 2 + j, j)
	end
end

function table.contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end

function table.concat(t1, t2)
	for i=1,#t2 do
		t1[#t1+1] = t2[i]
	end
	return t1
end

function table.len(table)
	local count = 0
	for i, _ in table do count = count + 1 end
	return count
end

function table.shuffle(tbl)
	for i = #tbl, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

-- <TILES>
-- 000:ff33fffff3663fff356663ff356663ff356663ff356663ff356663ff356663ff
-- 001:ffffffffffffffffff333fffff3663fffff3563fffff3563fffff356ffffff35
-- 002:fffffffffffffffffff333ffff3663fff3653fff3653ffff353fffff63ffffff
-- 003:ffffffffffffffffff333fffff3663fffff3563fffff3563fffff356ffffff35
-- 004:fffffffffffffffffff333ffff3663fff3653fff3653ffff353fffff63ffffff
-- 005:ffff33fffff3563fff355563ff355563ff355564ff355563ff355563ff355563
-- 006:fffffffffffffffffffffffffffffff7fffff777ffff7777ff777877f7777777
-- 007:fffffffffffffffffff777777777788877777777797777777777777777778888
-- 008:ffffffffffffff77ffff77777777777777777777777788877788777877777777
-- 009:ffff777777777777778887778877788777777777777777777777777777777778
-- 010:ffffffffffffffffffffffffffffffffffff6666ff6666666666666666662222
-- 011:ffffffffffffffffffffffffffffffff6fffffff6666ffff66666fff666666ff
-- 012:fffffffffffffffffffffffffffffffffffffffffffffffffffffffcffffffc6
-- 013:fffffffffffffffffffffffffffffcccffccc666cc6666666666666666666666
-- 014:ffffffffffffffffffffffffcccfffff666cccff666666cf6666666c66666666
-- 015:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfffffff
-- 016:356663ff356463ff356633ff356563ff3563563f356535633566535335665336
-- 017:fffff333ffff3543fff3653fff3653fff3653fff3653ffff653fffff53ffffff
-- 018:563fffff3563fffff3563fffff3563fffff3563fffff3563fffff353ffffff36
-- 019:fffff333ffff3543fff3653fff3653fff3653fff3653ffff653fffff53ffffff
-- 020:563fffff3563fffff3563fffff3563fffff3563fffff3563fffff353ffffff36
-- 021:ff355563ff353563ff335563ff355563f3653563365345636534556353345563
-- 022:f7777777ff777778fff77777ffffff77ffffffffffffffffffffffffffffffff
-- 023:77787777777777777777777777777799f7777777ffff7777ffffffffffffffff
-- 024:887777777788778877777777777777777777777777777777fff77777ffffffff
-- 025:777777878777777778877777777779777777777777777777777fffffffffffff
-- 026:6622222262222222222222222222222222222222222222222222222222222222
-- 027:2666666f2222666f222226662222266622222666222226666622666226626662
-- 028:fffffc66ffffc6666fffc6666ffc666666fc666666666666666c666666666666
-- 029:6666666666666666666666666666666666666666666666666666666666666666
-- 030:6666666666666666666666666666666666666666666666666666666666666666
-- 031:6cffffff6cffffff66cfffff66cfffff66cfffff666cffff666cffff666cffff
-- 032:35666365356635533564653f356653ff356533ff356353ff356553ff356653ff
-- 033:333fffff3453fffff3563fffff3563fffff3563fffff3563fffff356ffffff35
-- 034:fffff365ffff3653fff3653fff3653fff3653fff3653ffff353fffff63ffffff
-- 035:333fffff3453fffff3563fffff3563fffff3563fffff3563fffff356ffffff35
-- 036:fffff365ffff3653fff3653fff3653fff3653fff3653ffff353fffff63ffffff
-- 037:3335556334535563f3553563ff355563ff335563ff343563ff344563ff345563
-- 038:7777ffff7777777f777777777777887777977787777777777777777788888777
-- 039:ffff7777f7777777777788877778777877777777777777777777777777777777
-- 040:7777ffff77777777777777778777777777977777777777787777777777777777
-- 041:ffffff777fff7777777777777777777778888877877777877777777777777777
-- 042:2222222222222222222222222222222222222222222222222222222222222222
-- 043:2266666622226666222262262222222622222222222222222666222622266666
-- 044:2222666662666666666662266662222266222222662222226622222666622226
-- 045:ffffffff6fffffff6fffffff66ffffff66ffffff66ffffff66ffffff6fffffff
-- 046:6666666666666666666666666666666666666666666666666666666666666666
-- 047:666cffff666cffff666cffff666cffff66cfffff66cfffff66cfffff6cffffff
-- 048:356663ff356463ff356633ff356563ff3563563f356535633566535335665336
-- 049:fffff333ffff3543fff3653fff3653fff3653fff3653ffff653fffff53ffffff
-- 050:f77777ff7884887f8888868f8888688f8888888f7888887f7488847ff77877ff
-- 051:ff3433fff363663f36636663366366633666336336666663f366663fff3333ff
-- 052:563fffff3563fffff3563fffff3563fffff3563fffff3563fffff353ffffff36
-- 053:ff355563ff353563ff335563ff355563f3653563365345636534556353345563
-- 054:777778877777777777777777777777777777777777ffff77ffffffffffffffff
-- 055:777777887777887777777777778777777777777977777777f7777777fff77777
-- 056:8877777777887777777777777777877777777777777777ff777fffff7fffffff
-- 057:7777778878887777877777777777777777777777f7777777fff7777fffffffff
-- 058:2222222222222222222222222222222222222222222222222222222222222222
-- 059:2222622222222622222222222222222222222222222222222222222222222222
-- 060:6226666622226666222222662222222622222226222226622222222222222222
-- 061:6fffffffff6666ff666666666622666622222266222222262222222222222222
-- 062:6666666666666666666666666666666666666666666666226666222266622222
-- 063:6cffffffcfffffff666fffff666666ff6666666f226666662226666622222266
-- 064:35666365356635533564653f356653ff356533ff356353ff356553ff356653ff
-- 065:333fffff3453fffff3563fffff3563fffff3563fffff3563fffff356ffffff35
-- 066:f44c44ff4eecee4f4ecc6e4fcccccccf4eccce4f4ecece4f4ceeec4ff44444ff
-- 067:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 068:fffff365ffff3653fff3653fff3653fff3653fff3653ffff353fffff63ffffff
-- 069:3335556334535563f3553563ff355563ff335563ff343563ff344563ff345563
-- 070:7777777f77777777778888777877778777777777777777777777777888877787
-- 071:ffffffff777fffff777777777777777777777777788888778777778777777777
-- 072:ffffffff777777ff777777777777797778777777777777777777777877777777
-- 073:ffffffffffffffffffffffff77777fff777777ff887777ff7778777f7777777f
-- 074:fffffffffffffffffffffffffffffffffffffff6ff66ff66f6666666f6622262
-- 075:ffffffffffffffffffffffffffffffff66ffffff6666ffff66666fff222666ff
-- 076:fff3333fff31ddd3f31dd222f31ddd2231dd33dd31dd3f3d31dd13dd31dddddd
-- 077:ffffff33ff3333dd33dd231d1ddd2202ddd1d202d131dd1dd031d1ddd31ddddd
-- 078:ffffffff3fffffffd3fff33323ff312223331d222dd31d2dddd1ddd3d100dd13
-- 079:f33fffff3dd3ffff0ddd3fff10dd3fffd1d233ffd0d22d3f31d2ddd331dd1dd3
-- 080:356653ff356663ff356663ff356663ff35666fff3566ffff356fffffffffffff
-- 081:fffff333ffff3543fff3653fff3653fff3653fff3653ffffffffffffffffffff
-- 082:563fffff3563fffff3563fffff3563fffff3563fffff3563ffffffffffffffff
-- 083:fffff333ffff3543fff3653fff3653fff3653fff3653ffffffffffffffffffff
-- 084:563fffff3563fffff3563fffff3563fffff3563fffff3563ffffffffffffffff
-- 085:ff345563ff355563ff355563ff355563fff55563ffff5563fffff563ffffffff
-- 086:777877777777797777777777777777777777778777777777ff77777fffffffff
-- 087:77777777777777778887778777787777777777777ff77777fffff777ffffffff
-- 088:778887778877787777777777977777777777777777777fff7777ffffffffffff
-- 089:7777777f777777ff777fffff777fffff77ffffffffffffffffffffffffffffff
-- 090:ff622222fff62222ffff6622ffffff66ffffffffffffffffffffffffffffffff
-- 091:222266ff2222666f2226666f6226266ff6622266fff62266ffff666fffffffff
-- 092:31d22ddd31d22d1331d2133331dd3ff331dd3ff331ddcff3f31dc3fff30cd3ff
-- 093:3ddddd1d1dd11d1ddd131d0dd23f3d1ddc233d0dccdddd0dc1dd1131c31133f3
-- 094:d331dd3fd331dd3fd3d0dd3f23d1d23322d0d22ddd131ddddd1331dd113ff311
-- 095:31dd01d331dd31d331dd31d3d0dd31d3d1dd31d3d0dd301310d1333f33113fff
-- 096:ffffffffffffffffffffff3ffffff3d3fffff3ddfffff3d1fffff33dffff3100
-- 097:ffffffffffffffffffffffffffffffff3fffffff33ffffff303fffff3303ffff
-- 098:fffffffffffffffffffffffffffffffffffffff3ffffff31fffff313fffff303
-- 099:ffffffffffffffffffffffffffffffff3fffffff13ffffff313333ff303ddd3f
-- 100:ffffffffffffffffffffffffffffffffffff333ffff3ddd3ffff31ddfffff331
-- 101:ffffffffffffffffffffffffffffffffffffffff33ffffff113fffff3313ffff
-- 102:fffffffffffffffffffffffffffffffffffffffffffffff3ffffff30fffff303
-- 103:ffffffffffffffffffffffffffffffffffffffff33ffffff013fffff3013ffff
-- 104:2222222222222222222222222222222222222222662222222662222622662226
-- 105:2222222222222266222266662266666626666666666666666666666666666666
-- 106:2222222266662222666666226666666666666666666666666666666666666666
-- 107:2222222222222222222222222222222262222222662222226662222266622222
-- 108:ff3c3ffcfcccccfcffcffffcffcfffccfcffffcffcffffcffcfffcffffcccfff
-- 109:ff33fccffcccfcfccffcffccffcffccfffcffcfffcfffcfffcfffcffffcccfff
-- 110:33ffff33fccfffffcfcfffccffcffcfffcffcfcccfffccffcfcccfffccffcccc
-- 111:ff33ffffccffffccfcffccfccffcffcfffcfccffffccfffccccfffcfffccccff
-- 112:fff31033fff303fffff3033fffff3303fff30003ff30033ffff33fffffffffff
-- 113:1303ffff3003fffff33fffffffffffffffffffffffffffffffffffffffffffff
-- 114:fffff33ffffffff3ffffff31fffff303fffff303ffffff3fffffffffffffffff
-- 115:301dd3ff10333fff03ffffff3fffffffffffffffffffffffffffffffffffffff
-- 116:fffff313fffff33ffffffff3fffff330fffff300ffffff33ffffffffffffffff
-- 117:f303ffff3103ffff303fffff13ffffff3fffffffffffffffffffffffffffffff
-- 118:fffff303ffffff30ffff3333fffff011ffffff03ffffffffffffffffffffffff
-- 119:0303ffff3303ffff103fffff03ffffff3fffffffffffffffffffffffffffffff
-- 120:2222226622222266222226662222266622266666266666662666666622666666
-- 122:6666666666666666666666666666666666666666666666666666666666666666
-- 123:6666222666662266666666666666666666666662666666226666222266622222
-- 124:fffffffffffffffffffffffffffffffffffffffffffffffffffffff1ffffff19
-- 125:ffffffffffffffffffffffffffff1111ff119999119999c999c99c999c99c999
-- 126:fffffffff11fffff1981ffff19881fff99881fffc9991fff99cc91ff9c99c91f
-- 127:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 128:fffffffffffffffffffffffffffffffffffffffffffffff3ffffff31fffff310
-- 129:ffffffffffffffffffffffffffffffff33ffffff100fffff0333ffff3fffffff
-- 130:fffffffffffffffffffffffffffffffffffffffffffffff3ffffff31ffffff30
-- 131:ffffffffffffffffffffffffffffffff30ffffff103fffff03ffffff3fffffff
-- 132:fffffffffffffffffffffffffffffffffffffffffffffff3ffffff30ffffff33
-- 133:ffffffffffffffffffffffffffffffff33ffffff100fffff033fffff33ffffff
-- 134:fffffffffffffffffffffffffffffffffffffffffffffff3ffffff31ffffff30
-- 135:ffffffffffffffffffffffffffffffff33ffffff103fffff0300ffff3333ffff
-- 136:2226666622266666222262222222222222222266222226662222662266666666
-- 137:6666666666666666226666662222666662222666662222662262226622222226
-- 138:6666666666666666666666666666666666666666622222662222222666222222
-- 139:6662662266666662666622626662222266222222662222222222222222222222
-- 140:fffff19cfffff1c9ffff1998ffff1989ffff1855fffff155fffff155fffff155
-- 141:c99c999999999989989895555955555555555885555588985558989811589898
-- 142:89c99c915989899155959981555595115555551f5115551f5555551f5555551f
-- 143:fffffffffffffffffffffffffffffffff8ff111ff8811111f8811111f8811111
-- 144:fffff303ffff3003ffff003ffffff33fffffffffffffffffffffffffffffffff
-- 145:333fffff11d3ffff3d1d3ffff3dd3fffff33ffffffffffffffffffffffffffff
-- 146:ffffff30fff33f30ff3113f3f3100030f330ff00ff3fff33ffffffffffffffff
-- 147:3fffffff03ffffff03ffffff03ffffff3fffffffffffffffffffffffffffffff
-- 148:fffff311ffff3103ffff0033fffff3f3ffffffffffffffffffffffffffffffff
-- 149:003fffff3303ffff3303ffff003fffff33ffffffffffffffffffffffffffffff
-- 150:fffff313ffff3100ffff3030fffff033ffffff3fffffffffffffffffffffffff
-- 151:003fffff303fffff003fffff33ffffffffffffffffffffffffffffffffffffff
-- 152:6226666622222222222222222222222222222222222222222222222222222222
-- 153:2222226662222666222226622666666262266662222266662222262222222662
-- 154:6662222222266622226666622226666622226662222666222222222222222222
-- 155:2222222226662222662222226222222222222222222222222222222222222222
-- 156:fffff151fffff151fffff151fffff155fffff151fffff155fffff155ffffff5f
-- 157:1158989811589888115888c8555899881558889855589898555898985f58f8f8
-- 158:5551151f5555551f5555551f5555551f5511551f555555ff5f55f5ff5ff5ffff
-- 159:f8811111c8c15151f8851511f8815551f8851511f8855551f8855551ff85f5f1
-- 160:fffffffffffffffffffffffffffffffffffffffffffff03fffff3013fffff303
-- 161:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 162:ffffffffffffffffffffffffffffffffffffff3fffff3003ffff3301ffffff30
-- 163:ffffffffffffffffffffffffffffffffffffffffffffffff3fffffff3fffffff
-- 164:fffffffffffffffffffffffffffffffffffffffffffff3f3ffff0031ffff3310
-- 165:ffffffffffffffffffffffffffffffffffffffff33ffffff103fffff3003ffff
-- 166:fffffffffffffffffffffffffffffffffffffffffffff033ffff3011fffff300
-- 167:ffffffffffffffffffffffffffffffff333fffff0013ffff03003fff3f303fff
-- 168:aaaaaaaaaaaaaaaaaaaaaaaaaa1aa1a1aa1aa1aa1aaaaaaaaaaaaaaaffffffff
-- 169:aaaaaaaaaa1aaaa1aa1a1aa1aaaa1aaaaaaaaaaaaaaaaaaaaaaaaaaaffffffff
-- 170:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 171:ffff88fffff8888ffff89898fff89898fff89898fff89898fff88898ffc8c888
-- 172:ff4444ff4444444f4444444f4445444f4444444f4545454f5444544f4545454f
-- 173:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 174:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff444444
-- 175:fffffffffffffffffffffffffffffffff44fffff4984ffff49884fff48884fff
-- 176:fffff301ff33ff30f3113f3031003300303f3003f33ff33fffffffffffffffff
-- 177:3fffffff3fffffff3fffffff3fffffffffffffffffffffffffffffffffffffff
-- 178:fffffff3ffffff33fffff300ffff3003fffff03fffffffffffffffffffffffff
-- 179:13ffffff13ffffff03ffffff3fffffffffffffffffffffffffffffffffffffff
-- 180:fffff303ffff3103fff30033ffff03f3ffffffffffffffffffffffffffffffff
-- 181:f303ffff3003ffff003fffff33ffffffffffffffffffffffffffffffffffffff
-- 182:ffffff33fffff330ffff3000fffff033ffffffffffffffffffffffffffffffff
-- 183:33003fff0003ffff333fffffffffffffffffffffffffffffffffffffffffffff
-- 184:aaaaaaaaaaaaaaaaaaaaaaaaaaa1aaaaa1aa1a1aa1aa1aa1aaaaaaa1aaaaaaaa
-- 185:aaaaaaaaaaaaaaaa1aa1aaaaa1a1aa1aa1aa1a1aa1aa1aaaaaaaaaaaaaaaaaaa
-- 186:aaaaaaafaaaaaaafaaa1aaaf1aaa1a1fa1aa1a1fa1aaaaafaaaaaaafaaaaaaaf
-- 187:fff88998fff89888fff89898fff89898fff88898ffff8888ffffff88ffffffff
-- 188:5454544f4555454f5454544f5555554f5554554f5555f5fff5ffffffffffffff
-- 189:ffffffffffffff44ffff449cfff499c9ff49cc99f49c99994999898949989595
-- 190:449999999999999cc9c9c9999c99c999c9999998999998958989555559555555
-- 191:99884fff99994fffc9cc94ff9c99c94f99c99c9489898994559599845555954f
-- 192:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff33f3
-- 193:fffffffffffffffffffffffffffffffffffffffff3ffffff3d3fffffdd3fffff
-- 194:fffffffffffffffffffffffffffffffffffffffffffffffffffff333fffff301
-- 195:ffffffffffffffffffffffffffffffffffffffffffffffffff33ffff33dd3fff
-- 196:ffffffffffffffffffffffffffffffffffffffffffffff3ffffff3d3ffff3d13
-- 197:fffffffffffffffffffffffffffffffffffffffffffffffffffffffff333ffff
-- 198:fffffffffffffffffffffffffffffffffffffff3ffffff30fffff303ffff3103
-- 199:ffffffffffffffffffffffffffffffff3fffffff3fffffff33ffffff013fffff
-- 200:ffffffffffffffffffffffffaaaaa1aaaaaaaa1aaaaaaa1aaa1aaa11aaa1aaa1
-- 201:ffffffffffffffffffffffffaaaaaaaaaaa1aaa1a1a1aaa1a1a11aaaa1a11aaa
-- 202:ffffffffffffffffffffffffaa1aaaaaaaa1aa1aa1a11a11aa1a1a111a1a1aa1
-- 203:ffffffffffffffffffffffffaaaaaaaaaa1aaaaaaa11a1aaaaa1aa1aa1a11a11
-- 204:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 205:48955555f4555555f4554445f4545555f4554445f4544445f4544445f4544445
-- 206:55558885588889888989898889898988898989888989898889898988898888c8
-- 207:5555554f5445554f5555554f5555444f5555554f5555554f5555554f5544554f
-- 208:fff3003dffff300dfffff301fffff300ffffff30ffffff30ffffff30ffffffff
-- 209:1d3fffff1d3fffffd3ffffff3fffffff3fffffff3fffffff3fffffffffffffff
-- 210:ffffff30fffffff3ffffff30fffff300ffffff00fffffff0fffffff0ffffffff
-- 211:3d13ffff0d3fffff03ffffff3fffffff33ffffff0fffffff0fffffffffffffff
-- 212:ffff3d13fffff3d3ffffff30ffffff30ffffff30fffffff0fffffff0ffffffff
-- 213:3103ffff133fffff03ffffff3fffffff3fffffff03ffffff03ffffffffffffff
-- 214:ffff3030ffff3003fffff333ffffff30ffffff30ffffff00ffffffffffffffff
-- 215:3013ffff3013ffff0003ffff003fffff03ffffff0fffffff0fffffffffffffff
-- 216:aaa11aaaaaaa1aaaaaaaaaaaaaaaaaaaffffffffffffffffffffffffffffffff
-- 217:a1aa1a1aaaaaaa1aaaaaaaaaaaaaaaaaffffffffffffffffffffffffffffffff
-- 218:1aaaaaa111aaaaaaa1aaaaaaaaaaaaaaffffffffffffffffffffffffffffffff
-- 219:a1aa1a11aaaa1aa1aaaaaaaaaaaaaaaaffffffffffffffffffffffffffffffff
-- 220:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 221:f4555445f4555555f4554455f4555555f4555555a45555a5a4a5a5a5fafaa5aa
-- 222:888889988999988888888988898989888989898889898a8aaa8aafafffafffff
-- 223:5555554f5555554f5555554a555555af5a55a5af55a5aaffaafaffffffffffff
-- 224:fffffffffffffffffffffffffffffffffffff3ffffff313fffff0013ffff3301
-- 225:ffffffffffffffffffffffffffffffffffffffffffffffffffffffff3fffffff
-- 226:ffffffffffffffffffffffffffffffffffffffffffff33fffff3013fff330013
-- 227:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 228:fffffffffffffffffffffffffffffffffffffffffffff03fffff3003ffff3303
-- 229:ffffffffffffffffffffffffffffffffffffffffffffffff33ffffff113fffff
-- 230:fffffffffffffffffffffffffffffffffffffffffffff033ffff3001fffff330
-- 231:ffffffffffffffffffffffffffffffffffffffffffffffff33ffffff013fffff
-- 232:fffffffffffffffffffffffffffffffffffffffffffffffffffffffaaafafafa
-- 233:ffffffffffffffffffffffffffffffffffffffffffffafffffffaaffafaaaaaa
-- 234:fffffffffffffffffffffffffffffaffffaffaafffaafaaafaaaaaaaaaaaaaaa
-- 235:fffffffffffffffafafffffafaaffafaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 236:2222222222222222222222222222222222222222222222226222662266266662
-- 237:2222222222222222222222222266622266666662222222222222222222666222
-- 238:2222222222222222222222222222222222222222222222222222222222222226
-- 239:2222222222222222222222222222222222222222222226666666666666222226
-- 240:fffff301ffffff30ffffff30fffffff3fffffff3ffffff30ffffff30fffffff0
-- 241:03ffffff13ffffff103fffff003fffff003fffff003fffff03ffffff0fffffff
-- 242:ffff3001fffff300ffffff30ffffff30fffffff3fffffff3ffffff30fffffff0
-- 243:3fffffff13ffffff03ffffff003fffff103fffff103fffff003fffff0fffffff
-- 244:fffff331ffffff30fffff310fffff310fffff301fffff300ffffff30ffffff30
-- 245:0003ffff0303ffff303fffff33ffffff3fffffff03ffffff03ffffff0fffffff
-- 246:fffffff3fffffffffffffff3fffffff3ffffff30ffffff30ffffff30ffffffff
-- 247:3013ffff3003ffff0103ffff013fffff103fffff03ffffff003fffff003fffff
-- 248:ffffffffffffffffffffffffffffffffafffffffaaaffaffaaaaaaffaaaaaaaa
-- 249:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 250:ffffffffafffffffaaaffaffaaaaaafaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 251:fffffffffffffffffffffffffaffaffffaaaaaffaaaaaaaaaaaaaaaaaaaaaaaa
-- 252:2266666622222266666226666666666622266622622226666666666666666666
-- 253:2666666226666666622266666666666266666666666666666666666666666666
-- 254:2222222266226666666666662266666266222226666222666666666666666666
-- 255:2222666262266666662666666622666666666666666666666666666666666666
-- </TILES>

-- <SPRITES>
-- 000:ffffffffffffffffffffffffffffffffffffcffffffffcfffffffffcfffccfcc
-- 001:fffffffffffffffffffffffffcfffffffcfffffffffffcffbcffcfffcccfffff
-- 002:fffffffffffffffffffffffffffffffffffffffffffffff0ffffff0effffff00
-- 003:ffffffffffffffffffffffffffffffffffffffff0fffffffe0ffffffee0fffff
-- 004:fffffffffffffffffffff9fffffff9ffffffff9ffffffffffffffff7ffffff77
-- 005:ffffffff9fffffff9f9fffffff9ffffff739ffff787fffff877fffff8877ffff
-- 006:fffffffffffffffffffffffffffffffffffffffffffffff7ffffff7dfffff7dd
-- 007:ffffffffffffffffffffffffffffffffffffffff77f77fff9977ffff6997ffff
-- 008:dddddddddddddddddddddddddddddddddddddfffdddddfffdddddfddddddddfd
-- 009:ddddddddddddddddddddddddddddddddffffddddffffdddddddfddddddfddddd
-- 010:fffffffffffffffffffffffffff33fffff3a13ffff3aaa3fff3aa113fff3aa11
-- 011:ffffffffffffffffffffffffffffffffffffffffffffffff3fffffff133fffff
-- 012:ffffffffffffffffffff33fffff3113ffff3aa3ffff3aa13fff31a11fff311aa
-- 013:ffffffffffffffffffffffffffffffffffffffffffffffff3fffffff13ffffff
-- 014:fffffffffffffffffffff33fffff3a13ffff3a13ffff31aaffff31a1ffff3a1a
-- 015:ffffffffffffffffffffffffffffffffffffffff3fffffff3fffffff13ffffff
-- 016:ffffffcbffffffcbffffcffcfffcfffffffffffcfffffffcffffffffffffffff
-- 017:ccbfffffbccfccffccfffffffffcffffffffcfffffffffffffffffffffffffff
-- 018:fffff0e2ffff0e22ffff0eeefffff000ffffffffffffffffffffffffffffffff
-- 019:2ee0ffffeee0ffffee0fffff00ffffffffffffffffffffffffffffffffffffff
-- 020:ffffff78fffff778fffff787ffffff78fffffff7ffffffffffffffffffffffff
-- 021:77887fff88877fff77787fff8887ffff777fffffffffffffffffffffffffffff
-- 022:ffff7d66ffff7d6dffff7dddffff7dddffff7777ffffffffffffffffffffffff
-- 023:dd97ffffddd7ffffd67fffffd7ffffff7fffffffffffffffffffffffffffffff
-- 024:dddddddfddddddfddddddfd6dddddfffdddddfffdddddddddddddddddddddddd
-- 025:dfdddddd6dfddddd66dfddddffffddddffffdddddddddddddddddddddddddddd
-- 026:fff311aaffff3aa1fffff33afffffff3ffffffffffffffffffffffffffffffff
-- 027:1aa3ffffa1113fff111883ff301883fff3333fffffffffffffffffffffffffff
-- 028:ffff3a1affff30a1fffff301ffffff30fffffff3ffffffffffffffffffffffff
-- 029:1a3fffffa1a3ffff11113fff11883fff30883ffff333ffffffffffffffffffff
-- 030:ffff30aafffff311fffff31affffff31ffffff30fffffff3ffffffffffffffff
-- 031:13ffffffaa3fffff113fffff1113ffff1883ffff0883ffff333fffffffffffff
-- 032:ffffffffffffffffffffffffffffffffffffffffffffcffffffffcfcffffffcb
-- 033:ffffffffffffffffffffffffcfffffffcfffffffffffcfffccfcffffcbcfffff
-- 034:fffffffffffffffffffffffffffffffffffffff0fffffff0fffffff0ffffff0e
-- 035:ffffffffffffffffffffffffffffffff0fffffffe0ffffffee0fffff2e0fffff
-- 036:fffffffffffffff9fffff9ffffffff9ffffff9fffffffffffffffff7ffffff78
-- 037:ffffffffffffffff9f9ffffffff9ffffff9fffff7fffffff87ffffff77ffffff
-- 038:fffffffffffffffffffffffffffffffffffffffffffffff7ffffff7dfffff7dd
-- 039:ffffffffffffffffffffffffffffffffffffffff77f77fff9977ffffd997ffff
-- 040:ddddddddddddddddddddddddddddddddddddddddddddbbbdddddbbdbddddbbdd
-- 041:ddddddddddddddddddddddddddddddddddddddddddbbbddddbdbbdddbddbbddd
-- 042:ffffffffffffffffffffff33ffff33bbfff3bbb8ff3bbb88ff3bbbb8ff3bb66b
-- 043:ffffffffffffffff333fffffbaa3ffff111a3fff88bb3fffb8bbb3ffbbbbb3ff
-- 044:fffffffffffffffffffffff3fffff33bffff3bbbfff3b881fff3bbb8ff3bbbbb
-- 045:ffffffffffffffff333fffffaaa3ffff11bb3fff8bbbb3ffbbbbb3ffbbbbb3ff
-- 046:fffffffffffffffffffffff3ffffff3afffff31affff3b18ffff3b78fff3b88b
-- 047:ffffffffffffffff333fffffabb3ffffbbbb3fff8bbb3fffbbbb3fffbbbb3fff
-- 048:fffccfccffffffcbfffffcfcffffcfffffffffffffffffffffffffffffffffff
-- 049:cccfccffcbcfffffbcfcffffffffcfffcfffffffcfffffffffffffffffffffff
-- 050:fffff0e2fffff0e2fffff0e2ffffff0efffffff0ffffffffffffffffffffffff
-- 051:ee0fffffee0fffff2e0fffffe0ffffff0fffffffffffffffffffffffffffffff
-- 052:fffff778fffff787ffff7788ffff7877fffff788ffffff77ffffffffffffffff
-- 053:877fffff7887ffff8877ffff7787ffff887fffff77ffffffffffffffffffffff
-- 054:ffff7dddffff7dd6ffff7d66ffff7dddffff7777ffffffffffffffffffffffff
-- 055:d697ffff6dd7ffffdd7fffffd7ffffff7fffffffffffffffffffffffffffffff
-- 056:ddddbb6dddddbb66ddddbb6bddddbbbddddddddddddddddddddddddddddddddd
-- 057:dddbbdddbddbbddddbdbbdddddbbbddddddddddddddddddddddddddddddddddd
-- 058:ff3bb66bfff3bb6bfff38bbbffff388bfffff333ffffffffffffffffffffffff
-- 059:bbbbb3ffbbbb3fffbbbb3fffbb33ffff33ffffffffffffffffffffffffffffff
-- 060:ff3bb6bbff3bbb66fff3bb6bfff388bbffff3388ffffff33ffffffffffffffff
-- 061:bbbbb3ffbbbb3fffbbbb3fffbb83ffff883fffff33ffffffffffffffffffffff
-- 062:fff3b8bbfff3bbb6fff3bb66fff3bbbbffff38bbfffff333ffffffffffffffff
-- 063:bbbb3fff6bbb3fff6bb3ffffbb83ffffb83fffff33ffffffffffffffffffffff
-- 064:fffffffffffffffffffffffffffffffcfffffffcfffcffffffffcffcffffffcc
-- 065:ffffffffffffffffffffffffffffffffffffcffffffcffffbcffffffcccfccff
-- 066:fffffffffffffffffffffffffffffff0fffffff0fffffff0fffffff0ffffff0e
-- 067:ffffffffffffffffffffffff0fffffffe0ffffffe0ffffffe0ffffffe0ffffff
-- 068:ffffffffffffffffffffff9ffffff9fffffff9f7ffffff78fffff787ffff7788
-- 069:fffffffff9ffffff9ff9ffffff9fffffff9fffff7fffffff7fffffff77ffffff
-- 070:fffffffffffffffffffffffffffffffffffffffffffffff7ffffff76fffff76d
-- 071:ffffffffffffffffffffffffffffffffffffffff77f77fff9977ffffd997ffff
-- 072:dddddddddddddddddddddddddddddddddddddfffdddddfffdddddfddddddddf6
-- 073:ddddddddddddddddddddddddddddddddffffddddffffdddddddfdddd66fddddd
-- 074:ffffffffffffffffffffffffff33ff33ff3d33ccff3ddc9cfff3d99cff388999
-- 075:ffffffffffffffffffffffff33ffffffcc33ffffcccc3fff9c9c3fffc9c993ff
-- 076:ffffffffffffff33fffff3ddffff3dd3ffff3d9cfff38899fff3999cff399999
-- 077:ffffffff3fffffff3fffffff33ffffffcc33ffffcccc3fff9ccc3fffc9ccc3ff
-- 078:ffffffffffffffffffffffffffffff33ffff3389fff39988fff39999ff39bb99
-- 079:fffffffff333ffff3dd3ffffdd3fffffd933ffff9ccc3fffc9cc3fff9c9cc3ff
-- 080:ffffffbcfffccfccfffffffcfffffcffffffcfffffffffffffffffffffffffff
-- 081:cbcfffffbbcfffffccffcffffffffcfffcfffffffcffffffffffffffffffffff
-- 082:ffffff0effffff02fffff0e2fffff0e2ffffff0efffffff0ffffffffffffffff
-- 083:e0ffffffee0fffffee0fffffe0ffffffe0ffffff0fffffffffffffffffffffff
-- 084:ffff7877fff77888fff78777ffff7888fffff777ffffffffffffffffffffffff
-- 085:887fffff877fffff787fffff87ffffff7fffffffffffffffffffffffffffffff
-- 086:ffff76ddffff7dddffff7dd6ffff7dddffff7777ffffffffffffffffffffffff
-- 087:dd97ffffd6d7ffff6d7fffffd7ffffff7fffffffffffffffffffffffffffffff
-- 088:dddddddfddddddfddddddfdddddddfffdddddfffdddddddddddddddddddddddd
-- 089:6fddddddddfddddddddfddddffffddddffffdddddddddddddddddddddddddddd
-- 090:ff399999ff39bb9bfff3b9b9fff3bbbbffff339bffffff33ffffffffffffffff
-- 091:999993ff999993ffb9bb3fffbbb93fffbb33ffff33ffffffffffffffffffffff
-- 092:ff3999b9ff39bb9bfff3bbb9fff3bbbbffff33bbffffff33ffffffffffffffff
-- 093:9c9c93ff999993ffb9993fffb9b93fffb933ffff33ffffffffffffffffffffff
-- 094:ff3bb9bbff39bbb9fff3bbbbfff39bbbffff339bffffff33ffffffffffffffff
-- 095:99ccc3ffb999c3ff999c3fffbb993fffb933ffff33ffffffffffffffffffffff
-- 096:fffffffffffffffffffffffffffffffcfffffffcfffffffcfffffffcfffffffc
-- 097:ffffffffffffffffffffffffffffffffcfffffffcfffffffcfffffffcfffffff
-- 098:fffffffffffffff0fffffff0fffffff0fffffff0fffffff0fffffff0ffffff02
-- 099:ffffffffffffffffffffffff0fffffff0fffffffe0ffffffe0ffffffe0ffffff
-- 100:fffffffffffffffffffffff7ffffff77ffffff78ffffff78ffffff78fffff777
-- 101:ffffffffffffffff7fffffff87ffffff77ffffff87ffffff77ffffff87ffffff
-- 102:fffffffffffffffffffffffffffffffffffffff7ffffff77fffff799fffff7dd
-- 103:ffffffffffffffffffffffff7fffffffffffffff77ffffff997fffffdd7fffff
-- 104:ffffffffffffffffffffffffffffffffffff66f6fff66666ff666666ff666666
-- 105:fffffffffffffffffff66fff666666ff666666ff66666fff66666fff6666ffff
-- 106:fffffffffffffffffffffffffffffff3ffffff37fffff337ffff3bb7fff3bbbc
-- 107:ffffffffffffffff3fffffff733fffff7cd3ffff7ddd3fffcd6d3fffccdd3fff
-- 108:fffffffffffffffffffffffffffff333ffff3cbcfff3bbbbfff3bbbcfff3bcbc
-- 109:fffffffffffffffffffffffff33fffff3773ffff77c3ffff7ddd3fffcd6dd3ff
-- 110:ffffffffffffffffffffff33fffff3bbffff3bbcfff3bbbbfff3bbbbfff3bbcb
-- 111:ffffffffffffffff3fffffffc333ffffb8773fffb7773fffcbc3ffffbcdd3fff
-- 112:fffffffcfffffffcfffffffcfffffffcfffffffcffffffffffffffffffffffff
-- 113:cfffffffcfffffffcfffffffcfffffffcfffffffcfffffffffffffffffffffff
-- 114:ffffff02ffffff0efffff0e2fffff0eeffffff0efffffff0ffffffffffffffff
-- 115:e0ffffffee0fffffee0fffffee0fffffe0ffffff0fffffffffffffffffffffff
-- 116:fffff788fffff777fffff787ffffff78ffffff78fffffff7ffffffffffffffff
-- 117:87ffffff887fffff787fffff777fffff87ffffff7fffffffffffffffffffffff
-- 118:fffff76dfffff76dfffff7d6ffffff7dfffffff7ffffffffffffffffffffffff
-- 119:dd7fffffdd7fffffdd7fffffd7ffffff7fffffffffffffffffffffffffffffff
-- 120:ff666666fff66f66ff66ff66f6666f66f6666ff6ff66ffffffffffffffffffff
-- 121:6666ffff66666fff66666fff66666fff6666ffff666fffffffffffffffffffff
-- 122:fff3bbccfff3bbbbfff3bbcbfff38bb8ffff3888fffff333ffffffffffffffff
-- 123:bcdc3fffcbcd3fffbccc3fffbbc3ffffcb3fffff33ffffffffffffffffffffff
-- 124:fff3bcbcfff3bbbbfff38bbbfff3888bffff338bffffff33ffffffffffffffff
-- 125:ccdcd3ffccddc3ffbccc3fffccc3ffffbc3fffff33ffffffffffffffffffffff
-- 126:fff38bbbfff33cbcffff3bccffff38bcfffff3bbffffff33ffffffffffffffff
-- 127:cd6d3fffccdd3fffcdcd3fffccd3ffffcd3fffff33ffffffffffffffffffffff
-- 128:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 129:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffcfffffff
-- 130:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 131:ffffffffffffffffffffffffffffffffffffffffffffffffffffffff2fffffff
-- 132:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 133:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 134:fffffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffff77
-- 135:ffffffffffffffffffffffffffffffffffffffff7fffffffffffffff77ffffff
-- 136:fffffffffffffffffffffffffffffff3ffffff31fffff310ffff3101ffff3010
-- 137:ffffffffffffffffffffffffff3fffff3313ffff11013fff0013ffff0113ffff
-- 138:ffffffffffffffffffff33ffffff373fffff373fffff38c3ffff3c8cffff398c
-- 139:ffffffffffffffffffffffffffffffffffffffffffffffff3fffffffc3ffffff
-- 140:fffffffffffffffffffffffffffffffffff33ffffff373fffff3793fffff38c3
-- 141:ffffffffffffffffffffffffffffffffffffffffffffffffffffffff3fffffff
-- 142:ffffffffffffffffffffffffffffffffffffffffff33ffffff3733ffff379c33
-- 143:fffffffffffffffffffffffffffffffffffffffffffffffffff333ff333c73ff
-- 144:fffffffcfffffffcfffcfffcffffcffcffffccfcfffffffcffffffffffffffff
-- 145:cfffffffcfffffffcfffcfffcffcffffcfccffffcfffffffffffffffffffffff
-- 146:fffeeffffffeefefffffeeeefffffefefffffeeeffffffeeffffffffffffffff
-- 147:ffffffff2fefefff2efeeffffefeffffeeeeffffeeefffffffffffffffffffff
-- 148:ffffffffffffffffff888ffffff888fffffff888ff888888f8888ff8ffffff8f
-- 149:ffffffffffffffff8fff88ff8888ffff888f8fff888ff88ff888ffffff888fff
-- 150:fffff799fffff7ddfffff76dfffff777ffff77ffffffffffffffffffffffffff
-- 151:997fffffdd7fffffdd7fffffd77fffff7ff7ffffffffffffffffffffffffffff
-- 152:ffff3000ffff3001fffff300ffffff33ffffffffffffffffffffffffffffffff
-- 153:10103fff0003ffff003fffff33ffffffffffffffffffffffffffffffffffffff
-- 154:fffff3c8fffff39cffffff39fffffff3ffffffffffffffffffffffffffffffff
-- 155:cc3fffff88c33fffcc873fff9993ffff333fffffffffffffffffffffffffffff
-- 156:ffff3c8cffff39c8fffff39cffffff39fffffff3ffffffffffffffffffffffff
-- 157:c33333ffccc873ff888c3fffc993ffff333fffffffffffffffffffffffffffff
-- 158:fff398ccffff3c88ffff39ccfffff339fffffff3ffffffffffffffffffffffff
-- 159:ccc893ff88893fffcc93ffff993fffff33ffffffffffffffffffffffffffffff
-- 160:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 161:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 162:fffffffffffffffffffffffffffffffffffffffffffffffffffefffffffeefef
-- 163:ffffffffffffffffffffffffffffffffffffffff2fffffff2fefffffffffffff
-- 164:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 165:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 166:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 167:ffffffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffff
-- 168:fffff333fff33999ff399999f3933333f336603333364d063333dd163333d133
-- 169:33ffffff993fffff9993ffff99993fff39993fff63993fff463933ff6639783f
-- 170:ffffffffffffffffffffff33fffff311ffffff31ffffff39ffffff39fffff389
-- 171:ffffffff33ffffffa13fffff003fffff8aa3ffff933fffff83ffffff3fffffff
-- 172:fffffffffffffffffffffffffffffffffffffffffffffffffffffff3fffffff3
-- 173:ffffffffff3ffffff313fffff31a3ffff3013fff338aa3ff89933fff983fffff
-- 174:fffffffffffffffffffffffffffffffffffffffffffffffffffffff3fffff339
-- 175:ffffffffffffffffffffffffffff3fffff3313ff331013ff899a3fff9890a3ff
-- 176:fcffffffffcfcfffffffcffffffffcfcfffffffcfffffffcffffffffffffffff
-- 177:ffffffcffffffcfffffcfffffffcffffcfcfffffcfffffffffffffffffffffff
-- 178:ffffefffffffffffffffffffffffffeefffffeffffffffeeffffffffffffffff
-- 179:ffffeeffffffefffffffffffeeeffffffffeffffeeefffffffffffffffffffff
-- 180:ffffffffffffffffffffffffffff88ffffffff88fff88ff8fffffff8ffffffff
-- 181:fffffffffffffffffffffffff88fffff88ffffff888ff8ffff88ffffffff8fff
-- 182:fffffff7ffffff77fffff799fffff777ffff77ffffffffffffffffffffffffff
-- 183:ffffffff77ffffff997fffffd77fffff7ff7ffffffffffffffffffffffffffff
-- 184:f3333333ff398393ff399899f3999899f3999899ff331333f3bbb3f3f3bbb3f3
-- 185:333977833337777333977773999777739993773f133f33ffbbb3ffffbbb3ffff
-- 186:fffff398fffff399fffff393fffff393fffff33fffffffffffffffffffffffff
-- 187:3fffffff3fffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 188:ffffff38fffff389ffff3999fff39833fff333ffffffffffffffffffffffffff
-- 189:993fffff93ffffff3fffffffffffffffffffffffffffffffffffffffffffffff
-- 190:fff33899ff399989ff333333ffffffffffffffffffffffffffffffffffffffff
-- 191:8833a3ff33ff3fffffffffffffffffffffffffffffffffffffffffffffffffff
-- 192:fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffcffff
-- 193:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 194:ffffffffffffffffffffffffffffffffffffffffffeffffffffeffffffffffff
-- 195:ffffffffffffffffffffffffffffffff2fffffffffffffffffffffffffffffef
-- 196:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 197:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 198:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 199:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 200:fffff333fff33999ff399333f33333333336610033364d163333ddd6f333d133
-- 201:33ffffff993fffff3993ffff33993fff33393fff6339333f4639788366397773
-- 202:ffffffffffffffffffffff33fffff3ddffff3dd1fff3dd11fff3ddddfff3dd6d
-- 203:fffffffffffffffff33fffff39d3ffff91dd3fffddd6d3ffddddd3ffd6dd13ff
-- 204:fffffffffffffffffffffff3fffff33dffff3dddfff3ddd1fff3ddd1fff3d6dd
-- 205:ffffffffffffffff3fffffff1333ffff99d33fff1ddd63ffddddd3ffd6ddd3ff
-- 206:ffffffffffffffffffffff33fffff3ddffff31d1fff3ddddfff3d6ddfff3dddd
-- 207:ffffffffffffffff33ffffffd133ffff1993ffff11d13fffddddd3ffd6dd63ff
-- 208:ffffffffffffffffcfffffffffffffffffffffffffffffffffffffffffffffff
-- 209:ffffcffffffffffffffffffffffffffcffffffffffffffffffffffffffffffff
-- 210:fffffffffffffffffffffffeffffffffffffeffffffffefffffffffeffffffff
-- 211:ffffffffffffffffeefffffffffeffffffffefffffffffffefffffffffffffff
-- 212:fffffffffffffffffffffffffffffffffffffffffffffff8ffffffffffffffff
-- 213:ffffffffffffffffffffffffffffffff88ffffff88ffffffff88ffffffffffff
-- 214:fffffffffffffffffffffff7ffffff77fffff7ffffffffffffffffffffffffff
-- 215:ffffffff7fffffffffffffff7f7fffffffffffffffffffffffffffffffffffff
-- 216:ff333333ff398393ff399899f33998993bb998bb3bbbd3bbf38b3f38ff33fff3
-- 217:333977733397773f9993773f999933ff9993ffffb33fffffb3ffffff3fffffff
-- 218:fff3ddddfff3d1ddffff31ddfffff3ddffffff33ffffffffffffffffffffffff
-- 219:dddd13ff1ddd3fff11d3ffff333fffffffffffffffffffffffffffffffffffff
-- 220:fff31dddfff31dd1ffff3dd1fffff3d3ffffff33ffffffffffffffffffffffff
-- 221:dddd13ffddd13fffddd13fff3dd3fffff33fffffffffffffffffffffffffffff
-- 222:fff31dd1ffff3dd1ffff3dd1fffff333ffffffffffffffffffffffffffffffff
-- 223:ddddd3ffddd1d3ff1dd13fff3d13fffff33fffffffffffffffffffffffffffff
-- 224:fffff333fff33999ff399999f3933333f336603333364d063333dd163333d133
-- 225:3fffffff933fffff9993ffff99993fff39993fff63993fff463933ff6639783f
-- 226:ffffffffffff3333fff39999ff399999f3933333f336603333364d063333dd16
-- 227:ffffffff33ffffff993fffff9993ffff99993fff399933ff6399383f46393783
-- 228:fffff333fff33999ff399999f3933333f336603333364d063333dd163333d133
-- 229:3fffffff933fffff9993ffff99993fff39993fff63993fff463933ff6639783f
-- 230:ffffffffffff3333fff39999ff399999f3933333f336603333364d063333dd16
-- 231:ffffffff33ffffff993fffff9993ffff99993fff399933ff6399383f46393783
-- 232:ffff3333fff39999ff393333f3964611f33666ddf33330ddf3333333ff333333
-- 233:33f3f33f993d31d33393ddd364693d3f66633d3f03333d3f3333d3ff333d13ff
-- 234:fffffffffffffffffffffff3fffff330ffff30eefff3e00efff32e02ff3e0e0e
-- 235:ffffffffffffffff33ff3fffee3393ff000993ffee003fffe0e003ffeeee03ff
-- 236:fffffffffffffff3fffff330ffff300efff30e0efff3ee00fff302eeff3ee0ee
-- 237:ffffffff3fffffff0333ffffe0093fff2e993fff00003fffe0ee03ff00e003ff
-- 238:ffffffffffffff33fffff3eeffff30e2ffff3e0efff3ee00fff3e02eff3000ee
-- 239:fffffffff33fffff3993ffffe903ffff00e03fffee0e3fffe0003fff0ee3ffff
-- 240:f3333333ff398393ff399899f3999899f39999893883133338813ffff3883fff
-- 241:333977833337777333977773999777739993773fddbb33ff33bb3ffff3bb3fff
-- 242:3333d133f3333333ff398399f3999899f3999899ff333313fff38883fff38883
-- 243:6639777333397773333777739993773f999333ffbb3fffffbb3fffff33ffffff
-- 244:f3333333ff398393f3999899f3999899ff398999f3bb3d31f3bbd3f3ff3bb3ff
-- 245:333977833337777333977773999777739999773f188333ff3883ffff3883ffff
-- 246:3333d133f3333333ff398399f3999899f3999899ff3333d3fff3bbb3fff3bbb3
-- 247:6639777333397773333777739993773f999333ff883fffff883fffff33ffffff
-- 248:fff33377ff399877ff399877f3998877f3998873ff33313fff3bbb3fff3bbb3f
-- 249:3311783f7397773f7899773f788993ff788993ff31333fff3bbb3fff3bbb3fff
-- 250:ff30e00eff30e0e0ff300ee0fff30030ffff33f3ffffffffffffffffffffffff
-- 251:00e003ffee003fffee03ffff003fffff33ffffffffffffffffffffffffffffff
-- 252:ff30ee00fff300e0fff3e0eefff30000ffff3003fffff33fffffffffffffffff
-- 253:ee0e3fffee003fff0003ffffe003ffff003fffff33ffffffffffffffffffffff
-- 254:ff3eee00ff30ee0efff3000efff30e00ffff3300ffffff33ffffffffffffffff
-- 255:ee003fff00e03fffe003ffff003fffff33ffffffffffffffffffffffffffffff
-- </SPRITES>

-- <MAP>
-- 000:a3a3fe8898a8b8fea3a3a3a3a3a3a3a3a3a3a3a1b1a0b0c0d0e0f0cdcdcdcdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 001:8898fe8999a9b9a3a3a3fea3a3a3a3a3a3a3a3a2b2a1b1c1d1e1f1a4b4cdcccdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 002:8999a9b9a3a3a3a3a3a3a2b2fea3a3a3a3a3a3a3b3a2b2c2e1e2f2a5b5cdcdcdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 003:a3a3a3a3a3a3a3a3a3a3a3c3b2a3c3a3a3a3feffceceb3c3e3e3f3a0b0cdcdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 004:c2dea3a3a3a3a3a3a3a3a3a3a3a3a3a3feefefb7e3a8b8a3b3c3b9a1b1cdcdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccca2b2
-- 005:c3dfdea3a3a3a3a3cedeeefecedea3a3a3a3a3a3b9a9b9a3a3a3a3a2b2c2cdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccca3b3
-- 006:8989b9a3cedeeefecfdfefffcfa3a3a3cedea3a3a3a3a3a3a3a3a3a3b3c3cdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 007:a3a3cedecfdfefffcf98a8c398a8c3cfcfdfcedea3a3fea3fea3a3a3a3a3cdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 008:a3a3a3c3c398a8b88999a98999a9c398a8b8cfdfdfc3df98a8b8a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 009:a3a3a3a38999a9b9a3a3a3a3a3a38999a9b98898a8b88999a9b9a3fea3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 010:a3a3a3a3a3cedeeefecedeeefecedeeefecedeeefeb9a3a3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 011:a3a3a3a3a3cfdfefffcfdfefffcfdfefffcfdfefffeefea3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 012:a3a3a3a3a3a3a3cfdfefffcfdfefffcfdfefffcfdfefffa3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 013:a3a3a3a3a3a3a3a3cfdfefffcfdfefffcfdfefffa3a3a3a3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 014:a3a3a3a3a3a3a3a3cfdfefffcfdfefffa3a3a3a3a3a3a3a3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 015:a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 016:a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 017:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 018:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 019:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 020:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 021:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 022:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 023:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 024:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 025:cccccccccccccccccccccccccccccccccccccccccccccccccccccc9eaebecccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 026:afbf8fcccccccccccccccccccccccccccccccccccccccc9e9eaebe9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 027:9f9f9fafbf8fcccccccccccccccccccccccccccc9eaebe9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 028:9f9f9f9f9f9fafbf8f8f8e8e8e8ecc8e8e9eaebe9f9f9f9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 029:9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 030:9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 031:9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 032:9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 033:9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9f9fcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 034:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 035:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 036:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 037:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 038:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 039:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 040:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 041:ccccccccccccccccccccccccccccccccccccccccccccccccccccc7d7e7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 042:ccccccccccccccccccccccccccccccccccccccccccccccc7d7e7c8d8e8cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 043:ccccccccccccccccccccccccccccccccccccccccccccccc8d8e8c9d9e9cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 044:cc9acccccccccccccccccccccccccccccccccccccccc8ac9d9e9bcad8a9acccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 045:8b9b9acccc8accccccccccccccccccccccccccac8c9cacbc9daddaeafabccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 046:cccc8c9cacbccc9acc8acccc8c9cacbcccccccad8d8c9cacbc8cdbebfbabcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 047:cc9aac9dadbdcccc8c9cac9acccccccc8c9c9abcccccadbd8c8ddcecfccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 048:ccccccccccccccccccccccccccccccccccccccccccccccccccccddedfdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 049:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 050:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 051:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 052:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 053:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 054:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 055:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 056:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 057:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 058:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 059:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 060:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 061:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 062:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 063:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 064:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 065:cc60708090627282926272829262726272829264748494cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 066:cc61718191637383936373839363736373839365758595cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 067:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 068:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 069:cc00102030203020302030203020302030203020304050cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 070:cc01112131213121312131213121312131213121314151cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 071:cc02122232223222322232223222322232223222324252cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 072:cc03132131213121312131213121312131213121314353cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 073:cc02122232223222322232223222322232223222324252cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 074:cc03132131213121312131213121312131213121314353cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 075:cc02122232223222322232223222322232223222324252cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 076:cc03132131213121312131213121312131213121314353cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 077:cc02122232223222322232223222322232223222324252cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 078:cc03132131213121312131213121312131213121314353cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 079:cc02122232223222322232223222322232223222324252cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 080:cc03132131213121312131213121312131213121314353cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 081:cc04142232223222322232223222322232223222324454cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 082:cc05152535253525352535253525352535253525354555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 083:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 084:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 085:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 086:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 087:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 088:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 089:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 090:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 091:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 092:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 093:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 094:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 095:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 096:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 097:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 098:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 099:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 100:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 101:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 102:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 103:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 104:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 105:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 106:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 107:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 108:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 109:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 110:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 111:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 112:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 113:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 114:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 115:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 116:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 117:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 118:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 119:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 120:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 121:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 122:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 123:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 124:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 125:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 126:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 127:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 128:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 129:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 130:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 131:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 132:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 133:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 134:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- 135:cccccccccccccccccccccccccccccccccccccdcdcdcdcdcdcdcdcdcdcdcdcdcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
-- </MAP>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- 003:431101234befffeb732111123589aabb
-- 004:3333345679abcceffdccba9865432111
-- 008:000000ffffffffff000000ffffffffff
-- 009:fffffffffeeedddccbbaa98741000148
-- 010:00000000200000000000000000000077
-- 011:13456778888877766554443333333334
-- 012:00012469deefffffffffffeecb842000
-- 013:34567777777776655474444464445556
-- </WAVES>

-- <SFX>
-- 000:410f410e4f0e6f007f018f01af01bf01bf10cf1fdf1fef1eef1fef10ef11ef11ef11ef10ef10ef1fef2fef20ef20ef21c3c0d3c0e3c0e3c0e3c0f3c0c00000000000
-- 001:70b09fc0afc0bfc0cf80efd0e1e0f1b0f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100210033000000
-- 002:c108d10be102f1b7f101f102f104f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100f100300000000031
-- 003:d312c315b326a3449351837d639bf30af32af32cf320f320f320f320f340f340f340f340f340f340f340f340f340f340f340f340f340f340f340f34011500000000b
-- 004:04001430247034a044006430747084a194a2a4a2a4a3a4a1b4a0b4a0c4afc4afc4afd4a0d4a0d4a1d4a2d4a2e4a2e4a1e4a1e4a0e4aff4aef4aef4ae304000000000
-- 005:af80bf80cf80df80df70ef10ef00ef00ef00ef00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00500000000000
-- 006:a2c0a2c0b200b200b200c200c200c200d200d200d200d200e200e200e200e200e200f200f200f200f200f200f200f200f200f200f200f200f200f200385000002200
-- 048:61006100610061006100610061006100610061006100610061006100610061006100610061006100f100f100f100f100f100f100f100f100f100f100115000000008
-- 049:f800e800e800e800e800e800e800d800d800d800d800e800e800e800e800e800e800e800e800e800f800f800f800f800f800f800f800f800f800f800310000000000
-- 050:d200d201e201e201e201e201e20ff20ff200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200f200300000000008
-- 051:5900a900e900e900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900d900305000110000
-- 052:a900a900a900a900a900b900b900b900b900c900c900c900c900c900c900e900e900e900e900e900e900090009000900090009000900090009000900302000f60000
-- 053:c900c900c900c900c900d900d900d900d900d900d900d900d900e900e900e900e900e900e900e900e900e900e900e900e900e900e900e900f900f900302000f00000
-- 054:fa00ea00ca009a009a009a009a00aa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00fa00319000000000
-- 055:bd00bd00ad000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d000d0040a004030000
-- 059:11f041f07f009f00af00a1f0c1f0df00ef00ef00ef00ef00ef00ef00ef00ef00ef00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff005b0057575700
-- 060:ef20ef00ef00ef00ef00ef00ef00ef00ef00ef00ef00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00700000000000
-- 061:01727100d10ee10cf10bf10af109f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108f108a00000000000
-- 062:21f061f08f009f00bf00cf00df00ef00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff005b0000000000
-- 063:df20ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00700000000000
-- </SFX>

-- <PATTERNS>
-- 000:4008d50000004008cd4008f94008eb0000004008f94008d54008f90000004008cd4008fb4008eb4008fb4008f94008fb4008d50000004008d54008f94008eb0000004008f94008d54008f90000004008cd4008fb4008eb4008fb4008eb4008eb4008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f9000000
-- 001:900805000000700807100000000000000000000000900805000000000000000000700805000000000000600805100801900803000000000000900803900805d02c05e02c05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:d00805000000700807100000000000000000000000400805000000000000000000700805000000000000800805100801e00803000000000000900801900803d02c03e02c03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:900a27000000d36a17100000700a25000000900825d36a17900a27000000d36a17000000700a25000000900825000000d00827000000d16a17000000d00a27700829000000d16a17d00827000000d16a17000000700a29900a29000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:40082900000097aa17000000700a27000000b00a2797aa17700a2900000097aa17000000700a27600827000000e00827000000000000949a17e00a29000000000000700a29949a17000000600a29949a17000000e00a29000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:900837000000e00837400839100000700837700839900839d23e39000000000000000000900839100000100000400837403c39000000000000c00837100000000000900837100000903c39000000d00839000000424e39000000440c35000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:700837100000c23e37000000000000000000e00837700837100000000000d00837000000e00837000000400839000000e23e37000000000000100000600839400839e00837100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:700837100000c23e37000000000000000000e00837700839100000900839900839100000400839100000000000000000600839000000700839000000900839000000c00839000000d00839100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:e00839000000d00839000000700839100000700839903c39023600000000000000000000900839000000b00839000000d00839000000000831000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:000000000000b11effb11eff000000000000b11effb11eff000000000000b11effb11eff000000000000b11effb11eff000000000000b11effb11eff000000000000b11effb118eb411eff411effb118ebb11eff411effb118ebb118ebb11eff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:900841000000000000000000900843000000000000000000400843000000000000000000400845000000000000000000e00841000000000000000000e00843000000000000000000d00841000000000000000000d00843000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:600855000000700855000000d23e55000000000000000000e00853000000700855000000b23e55000000000000000000900855000000700855000000400855000000000000000000700855000000600855000000e00853000000000000000851000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:000000000000000000000000400857000000000851100000000000000000000000000000e00855000000000000100000000000000000600857000851700857000000000000100000000000000000000000000000900855000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:000000000000000000000000d0086940086bd0086940086bb00869e00869b00869e0086900000000000070086b000000900869000000000000000000700869900869700869900869400869700869400869700869000000000000400869700869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:000000000000000000000000900869d00869900869d00869700869b00869700869b00869000000000000400869000000d00867000000000000000000b00869c00869b00869c00869700869900869700869900869000861000000c00869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:900865000000000000000000400867100000400867100000e00865000000e00865000000000000000000e00865100000400867100000000000000000e00867000000400869000000e00867000000400869000000000000000000700867000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:900869000000000000000000900869000000c00869000000700869000000000000000000900869000000000000000000400869000000000000000000400869600869400869600869400869000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:d00867000000000000000000d00867000000e00867000000b00867000000000000000000700867000000000000000000b00867000000000000000000b00867e00867b00867e00867b00867000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:900869000000000000000000900869b00869c0086900000040086b70086b90086b00000040086b00000000000000000090086b000000000000000000d0086be0086bd0086be0086bd0086b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:400867000000000000000000400867000000400867000000400867000000000000000000400867000000000000000000400867000000000000000000400867000000400867000000400867000000000000000000000000000000400867000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:4008eb4008fd4008cd4008f94008eb4008fd4008f94008d54008f94008fd4008d54008d54008eb4008fb4008f94008fb4008d54008fd4008d54008f94008eb4008fd4008f94008d54008f94008fd4008cd4008fb4008eb4008fb4008bb0008f14008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f90000004008f9000000
-- 021:900879400879100000d23e79000000000000b02c79000000000000900879000000000000400879000000000000100871600879000000900879600879000871900879d23e77d00877000871000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:900879b00879d00879000000900879000000000000100000700879900879c00879900879000000000000000000100000700879100000700879100000900879100000900879100000c00879100871c00879100000d00879100000d00879100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:d00877e02c77400879000871d00877000000000000100000b00877d00877000000923e77000000000000000000100000900877100000900877100871b00877100000b00877100000d00877100000d00877100000b00877000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </PATTERNS>

-- <TRACKS>
-- 000:601240741340801240941340a01240a41340a01240a41340000000000000000000000000000000000000000000000000eb02ff
-- 001:043040043040c43b40c43b40c85b40c06b40c85b40cc5b45ec3055254455ec30552d4455000040000040000000000000c902ef
-- </TRACKS>

-- <SCREEN>
-- 000:22222222222222222222222222266666666666666666666666626622222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222662222222666666eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 001:22222222222222222222222222266666666666666666666666666662222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222622222222222666eeeeeeeeeeeeeeeeeeeee3433eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 002:222222222222222222222222222262222266666666666666666622622222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222666eeeeeeeeeeeeeee3433363663ee3333e3333e33e33e33333e33eeeeeeeeeeeeeeeeeeeee
-- 003:222222222222222222222222222222222222666666666666666222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222666eeeeeeeeeeeeee363636636663ee33ccc33ee33333e33eeee33eeeeeeeeeeeeeeeeeeeee
-- 004:222222222222222222222222222222666222266666666666662222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222666eeee66666eeee3663636636663cc3366633cc33333e3333eeeeeeeeeeeeeeeeeeeeeeeee
-- 005:222222222222222222222666222226666622226662222266662222222222266622222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222666ee6666666666e3663636663363663366633663c3e3e33eeee33eeeeeeeeeeeeeeeeeeeee
-- 006:222222222222222266666666222266222262226622222226222222226666666622222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222266226662666666666666636663366666636633663333636ce3e33333e33eeeeeeeeeeeeeeeeeeeee
-- 007:2222222222222222662222266666666622222226662222222222222266222226222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222266266626666222266666366666366663666666666666666ceeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 008:22266666664466662222222262266666222222666662222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222266666666222222266644366663333366666666666666666ceeeeeeeeeeeee33eeeeeeeeeeeeeee
-- 009:2226666664664666222222222222222262222666222666222666222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222266666222222222245643333ec666666666663336633663ee333ee3333eeeee3333eee333eeee
-- 010:22226222456664662244422222244422224446622264446266444222222444222244422222244422224442222224442222444222222444222244422222244422224442222224442222444222222444222244422622244422224555646eeec666666666633633633663c33e33e33ee3e33e33ee3e3ee33eee
-- 011:22222222456664662246642222466422264664622246646662466422224664222246642222466422224664222246642222466422224664222246642222466422224664222246642222466422224664222246642622466422224555646eec6666666666633366663336c333eee33ee3e33e33ee3e33333eee
-- 012:222222664566646622245642246542226224564224654662222456422465422222245642246542222224564224654222222456422465422222245642246542222224564224654222222456422465422222245642246542222245556466e44c44666666663336666366ce333ee33ee3e33633ee3eeee33eee
-- 013:2222266645666466222245644654222222224564465466222222456446542222222245644654222222224564465422222222456446542222222245644654222222224564465422222222456446542222222245644654222222455564664eecee4666666666666666666ceeeeee66ee666666eeeee333eeee
-- 014:2222662245666466666664564542222222222456454222222222245645422222222224564542222266666456454222222222245645422222222224564542222222222456454222222222245645422222266624564542222266455564664ecc6e46663336663336633633e3333666333663366eeeeeeeeeee
-- 015:666666664566642666222245642222222222264564222222222222456422222222222245642222226622224564222222222222456422222222222245642222222222224564222222222222456422222222266645642222222645556466ccccccc6633663633663633333e33ee3633263233666eeeeeeeeee
-- 016:6226666645666466666224445642222222222444564222222222244456422222222224445642222222222444564666662222244456422222222224445642222222222444564222222222244456422222222264445642222222455564224eccce46633666633663633333e3333e633223222266eeeeeeeeee
-- 017:2222222245646466222645444564222222224544456422222222454445642222222245444564222222224544456466662222454445642222222245444564222222224544456422222222454445642222222245444564222222454564624ecece46633663633663636363e33ee3e332232332666eeeeeeeee
-- 018:222222224566446222646542645642222224654224564222222465422456422222246542c456422222246542c456422622246542c456422222246542c4564222222465422456422222246542c4564222222465422456422222445564664ceeec46663336663336636663e3333eee33322336666eeeeeeeee
-- 019:222222224565646222465460024564222246542002456422224654200245642222465422c245642222465422c245642622465422c245642222465422c2456422224654200245642222465422c2456422224654222245642222455564666444446666666666666666666ceeeeeeeeee666226266eeeeeeeee
-- 020:222222224564564224654660e024564224654220e024564224654220e02456422465c2222224c6422465c2222224c6422465c2222224c6422465c2222224c64224654220e02456422465c2222224c64224654227772776422465456466222222666666663336666666ceeeeeeeeeeeeee6622266eeeeeeee
-- 021:222222224565456446546620ee02456446542220ee02456446542220ee02456446542c2ccc2c456446542c2ccc2c456446542c6ccc2c456446542c2ccc2c456446542220ee02456446542c2ccc2c45644654227d997745644654456466222222666666633633666666ceeeeeeeeeeeeeeee62266eeeeeeee
-- 022:22222222456654546542220e2e0224546542220e2e0224546542220e2e022454654222cbcbc22454654222cbcbc62454654666cbcbc22454654222cbcbc224546542220e2e022454654222cbcbc22454654227ddd99724546544556466222226666666633363666666ceeeeeeeeeeeeeeeee666eeeeeeeee
-- 023:2222222245665446542220e2ee022246542220e2ee022246542220e2ee022246542cc2ccccc2cc46542cc2ccccc6cc46542cc2ccccc2cc46542cc2ccccc2cc46542220e2ee022246542cc2ccccc2cc4654227dddd6972246544455646662222666666663366366666ceeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 024:2222222245666465444220e2ee022465444220e2ee022469444220e2ee022465444222cbcbc22469444222cbcbc66465444666cbcbc22465444666cbcbc22465444220e2ee022465444222cbcbc2646544427dd66dd72465444555646226666666666666333666666ceeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 025:2222222245664554445420e22e024654445420e22e024954949420e22e02465444542c2cbc2c495494942c2cbc2c465444546c6cbc2c465444546c6cbc2c4634445420e22e02465444542c2cbc2c465444547d66dd72465444545564222266666666666666666666ceeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
-- 026:22222222456465422456420ee0246542c456420ee02465922459420ee02465422456c2222224c5922459c2222224c5462456c2262224c542c456c2662224c3d32456420ee0246542c456c2226624c54624567dddd7246542245545642222226666633633663336633663e33333ee3333e33eeeeeeeeeeeee
-- 027:22222222456654222245642002465422c245642002465922229564200246542222456422c246592222956422c246542622456426c2465422c2456426c24653dd3245642002465422c2456422c64654600245777772465422224555642222222666633333633663633663633eeee333eee33eeeeeeeeeeeee
-- 028:2222222245654422222456422465c2222224c64224654222722456422465422777277642c465422272245642c465422777277642c465c2222224c646c46543d1332456422465c2222224c642c4654660e02456422465422222445564222222266663333363366363366363333eee33366eeeeeeeeeeeeeee
-- 029:22222222456454222222456446542c2ccc2c456446542227872245644654227d9977456446542227872245644654267d9977456446542c2ccc2c45644654233d3032456446542c2ccc2c456446546660ee024564465422222244456422222662666363236336632233366336ee6663336336eeeeeeeeeeee
-- 030:222222224565542222222456454222cbcbc224564542227877222456454227ddd99724564542227877222456454227ddd9972456454222cbcbc224564542310033032456454222cbcbc664564546660e2e0264564542662222444564222222226663222366333222232663333363333663366eeeeeeeeeee
-- 031:222222224566542222222245642cc2ccccc2cc45642227788772224564227dddd6972245642227788772224564227dddd6976645642cc2ccccc2cc456423103313032245642cc2ccccc2cc45646660e2ee06664564266662224455642222222266622222666222222222226666662222666666eeeeeeeeee
-- 032:222266664566642222222444564222cbcbc22444564227877887244456427dd66dd72444564227877887244456427dd66dd72444564222cbcbc224445643032230032449564222cbcbc22444564620e2ee066444564666666645556422222222222262233333666332222222662222222666666eeeeeeeee
-- 033:62666666456464222222454445642c2cbc2c4544456477888877454445647d66dd724544456477888877454445647d66dd72454445642c2cbc2c4544453303322332494495946c6cbc2c4544456420e22e064544456466666645456422222222222226222233663336662222622222222222666eeeeeeeee
-- 034:6666622645664422222465422456c2222224c5422456787777876542c4567dddd7246542c456787777876542c4567dddd72465422456c2222224c54223733303222465926459c6666664c5466456460ee06465466456466666445564222222222222222223322336362222222222222222222666eeeeeeee
-- 035:66622222456564222246542222456422c24654222245678888765422c245777772465422c245678888765422c24577777246542002456422c2465422337300032246592222956462c246546266456460064654600645646666455564222222222222222233222333332222222222222222222666eeeeeeee
-- 036:66222222456456422465423332245642c4654227772776777765c2222224c6422465c2222224c6777765c2222224c64224654220e0245642c46542233c8303322465422276245646c46542277767764264654660e064564664654564222777772222222332222226322222222222222222222666eeeeeeee
-- 037:662222224565456446542310032245644654227d9977456446542c2ccc2c456446542c2ccc2c456446542c2ccc2c456446542220ee02456446542233c8c3356446542667876245644654227d9977456446546620ee02456446544564227884887222222222222662222222222222222222222666eeeeeeee
-- 038:66222226456654546542310330322454654227ddd9972454654222cbcbc22454654222cbcbc22454654222cbcbc224546542220e2e0224546542223cc89324546546667877666454654667ddd99724546546220e2e02245465445564228888868223333323322323333323333222333363323633eeeeeeee
-- 039:6662222645665446542230303032224654227dddd6972246542cc2ccccc2cc46542cc2ccccc2cc46542cc2ccccc2cc46542220e2ee022246542223cc8c322246542227788776664654667dddd6972246546220e2ee02224654445564228888688223322223332323322223322323322223323633eeeeeeee
-- 040:6226666645666465444230330322246544427dd66dd72465444222cbcbc22465444222cbcbc22465444222cbcbc22469444220e2ee02246544433c88c9332465444227877887246544427dd66dd72465444220e2ee0224654445556422888888822333322333332333322332232332332333366622226666
-- 041:2222666645664554445423013333465444547d66dd72465444542c2cbc2c465444542c2cbc2c465444542c2cbc2c4954949420e22e024654445378cc93034654445477888877465444547d66dd724654445420e22e0646544454556422788888722332222332332332222333322332232233663362666666
-- 042:2222226645646546245642301104654224567dddd7246542c456c2222224c542c456c2222224c5422456c2222224c5922459420ee024654224563999303465422456787777876542c4567dddd72465426456420ee06465426455456422748884722333332332232333332332232233332233623366666226
-- 043:222222264566546222456423304654032245777772465422c2456422c2465422c2456422c246542002456422c2465922229564200246542233456333334654200245678888765422c24577777246542262456420024654666245556422277877222222222222222222222222222222222222222666622222
-- 044:22222226456544666664564224654301322456422465c2222224c642c465c2222224c642c4654660e0245642c465422272245642646546631034564224654220e02456777765c2222224c6422465422777277642246546622244556422222222222222223332233333222222222222222222222266222222
-- 045:222226624564546622224564465422301322456446542c2ccc2c456446542c2ccc2c456446542220ee0245644654266787224564465422310300456446542220ee02456446542c2ccc2c45644654227d99774564465466222244456422222222222222233222222233222222222222222222222266222222
-- 046:2222222245655466222224564542222303222456454222cbcbc22456454222cbcbc264564542220e2e022456454666787722645645422230333324564542220e2e022456454222cbcbc22456454227ddd9972456454222222244456422222222222222233332222332222222222222222666222666222226
-- 047:2222222245665466226662456422222303222245642cc2ccccc2cc45642cc2ccccc6cc45646660e2ee02224564222778877666456466631300322245642220e2ee022245642cc2ccccc2cc4564227dddd6972245642222222244556422222222222222233223223322222222222222222226666666622226
-- 048:6226666645666466222224445642223003233444564222cbcbc22444564222cbcbc66444564660e2ee02244456426787788764445642310030322444564220e2ee022444564222cbcbc2244956427dd66dd72444564222222245556422222222222222223332233222222222222222222222622262266666
-- 049:222222224564642226664544456422303231133445642c2cbc2c454445642c2cbc2c4544456460e22e02454445647788887745444564303000324544456420e22e02454445642c2cbc2c494495947d66dd724544456422222245456422222222222222222222222222222222222222222222262222226666
-- 050:222222224566442266246542c456423003003a132456c2222224c5422456c2226664c5466456460ee0646546645678777787654624564033332465422456420ee02465422456c2222224c59224597dddd7246542c45642222244556422222222222333332333322332232333323333223333233222222266
-- 051:222222224565642262465422c245642300463a1322456422c246542222456422c64654633645646002465fffffff6788887654662245643222465422233364200246542222456422c24659222295777772465422c24564222245556422222222222332222332232332232233222332233322233222222226
-- 052:22222222456456422465c2222224c642336531aa36645642c465422777277642c46546311364564664654fffffff56777765463332345642246542333ddd36422465422777677642c4654222722456422465c2222224c6422465456422222222222333322332232332232233222332223332222222222226
-- 053:222222224565456446542c2ccc2c4564465431a1322245644654227d99774564463333133136456446542f66666f4564465423011300456446542311dd1345644654227d99774564465422278722456446542c2ccc2c45644654456422222222222332222333322332232233222332222333233222222662
-- 054:2222222245665454654222cbcbc2245465423a1a13222454654227ddd997645463ddd30330366454654666f666f6645465463003013324546542313313322454654267ddd99724546542227877222454654222cbcbc224546544556422222222222332222332232233322333322332233332233222222222
-- 055:2222222245665446542cc2ccccc2cc46542630aa1366624654227dddd6972246543dd103633666465466666f6f6666465466303630322246542230323132224654267dddd69762465422277887722246542cc2ccccc2cc465444556422222222222222222222222222222222222222222222222222222222
-- 056:2222222245666465444222cbcbc2246544336311aa36646544427dd66dd764654443330136666465444666f662f664654446300330136465444630132336646544467dd66dd764654442278778872469444222cbcbc224654445556422222222222222223332222222222222222222222222222222222222
-- 057:222222224566455444542c2cbc2c46544311331a1136465444547d66dd764654445422301366465444546f66222f46544454630033003654445463033222465444547d66dd764654445477888877495494942c2cbc2c46544454556422222222222222233233222222222222222222222112222222222222
-- 058:22222222456465422456c2222224c542310033311113654664567dddd7246546645646633034654664564fffffff65462456463336306346345642310334654664567dddd7246546c4567877778765922459c2222224c5422455456422222222222222233323222222222222222222221981222222222222
-- 059:222222224566542222456422c246542230353030188354622333777776465466664564663036543366456fffffff5426224564666646313313356423003654666645777776465462c24567888876592222956422c24654222245556422222222222222233223222222222222222211111988122222222222
-- 060:222222224565442222245642c465466313345333088346333ddd3646646546677727764263654301366456462465422777277646646310110133564633654323332456426465c6662224c6777765466272245642c46542222244556422222222222222223332222222222222221199999988122222222222
-- 061:222222224564542222224564465422310300456433346311dd1345644654667d9977456446540030132245644654267d997745644654310010133564465400311032456446546c6ccc2c45644654222787224564465422222244456422222222222226662222222222222222119999c9c999122222222222
-- 062:22222222456554226222645645422230333364564546313313366456454667ddd99764564542333303222456454227ddd997245645423110010334564546331030036456454666cbcbc26456454222787722245645422222664445642222222266666666222222222222222199c99c9999cc912222222222
-- 063:2222222245665422662666456466631300366645646630363136664564667dddd6976645642223003132224564227dddd697224564230101000332456466630363036645646cc6ccccc6cc4564666778877222456422222266445564222222226622222622222222222222199c99c9999c99c91222222222
-- 064:2222222245666422222224445646310030366449564630136336644456427dd66dd76449564223030013244456467dd66dd7244456423000100364445646310330036344564266cbcbc66444564667877887644456466666264555646666666666666666666266222222219cc99c999989c99c9122222222
-- 065:2222222245646422222245444564303000324944959463033666454445647d66dd724944959423000303454445647d66dd7245444533330000324544456300330036313445646c6cbc2c454445647788887745444564666626454564666666666666666661166662222221c999999989598989912222222a
-- 066:2222222245664422222465422456403333246596245946310334654664567dddd7246592245946333304654224567dddd72465422373403333246546245603633363a1366456c2626664c546645678777787654624564266624455642266666666666666198122622222199898989555559599812a22222a
-- 067:222222224565642222465333224564362246592622956463003654666645777772465922269564622346546622457777764654623373646622465426334564666643103666456422c6465460064567888876546332456426664555642222666666661111198812222222198959555555555595112aa22a2a
-- 068:222222224564564224653100330456462465422672245646336540366624564224654222722456422465436333245642646546633c8356422465422310045646643aa83333245642c4654620e0645677776546311324564664654564622226666611999999881222222218555555588555555512aaaaaaaa
-- 069:22222222456545644653003011034564465426678722456446543013662245644654222787224564465400311032456446546633c8c345644654263103334564465339983132456446542660ee06456446546313313333644654456466222266119999c9c999122222222155555588985115551aaaaaaaaa
-- 070:2222222245665454654303230032245465422278776224546542230322222454654222787722245465423310300324546542263cc8932454654223103262245465422389331324546546660e2e06645465466303303ddd34654455642262226199c99c9999cc912222222155555898985555551aaaaaaaaa
-- 071:222222224566544654230033332222465422277887722246542223013222224654222778877226465422230323032246542223cc8c32224654222303333222465422239983032246546660e2ee06664654666336301dd34654445564222222199c99c9999c99c91222222155115898985555551aaaaaaaaa
-- 072:22222222456664654442300003322465444667877887246544332230322224654442278778872465444231033003246544433c88c93324654446300311d324654442233998332469444660e2ee0664654446666310333465444555642222219cc99c999989c99c9122222151115898985551151aaaaaaaaa
-- 073:a22222224566455444542333000346544454778888774654431136303666465444547788887746544453003300324654443378cc93034654445400323d1d36544454662399934954949460e22e064654445466310366465444545564622221c9999999895989899122222151115898885555551aaaaaaaaa
-- 074:aaa22a22456465422456422233046342345678777787654231003300362465422456787777876342345603233324654223733999303463423456433223dd354224564330338935922459420ee06465466456430336646542245545642222199898989555559599812a222151115888c85555551aaaaaaaaa
-- 075:aaaaaa2a456654222245642222463133134567888876546230353003624654222245678888763133134564222246542223736333334631331345642226335333224563003233392222956420024654663345630366465422224555642666198959555555555595112aa22155555899885555551aaaaaaaaa
-- 076:aaaaaaaa45654422a22456422463101101345677776546622334533224654227772776777763101101345642246542333c83564224631011013456426465310033045633246542227224564664654663103456366465422222445564622618555555588555555512aaaaa151155888985511551aaaaaaaaa
-- 077:aaaaaaaa456454aaaaa24564465431001013456446546666310345644654227d99774564465431001013456446542303c8c34564465331001013456446530030110345644654222787224564465422310300456446542222224445642222a155555588985115551aaaaaa15555589898555555aaaaaaaaaa
-- 078:aaaaaaaa456554aaaaaaa45645423110010324564542262230322456454227ddd997245645423110010324564542303cc8932456454331100103245645430323003224564542227877226456454222303333245645422222224445642222a155555898985555551aaaaaa155555898985a55a5aaaaaaaaaa
-- 079:aaaaaaaa456654aaaaaaaa456423010100032245642226631032224564227dddd69722456423010100032245642233cc8c32224564230101000322456423003333222245642227788776664564222313003222456422222222445564a2aaa155115898985555551aaaaaaa5a5a58a8a85aa5aaaaaaaaaaaa
-- 080:aaaaaaaa456664aaaaaaa4445642300010032444564222230322334456427dd66dd72444564230001003244456433c88c9332344564230001003243336423000033224445642278778872444564231003032244456422222aa455564aaaaa151115898985551151aaaaaaaaa1aaaaaa1aaaaaaaaaaaaaaaa
-- 081:aaaaaaaa456464a1aaaa45444364230000334544456422230323113445647d66dd7245444564330000324544456378cc9300313445642300003343dd35642333000345444564778888774544456430300032454445642222aa454564aaaaa151115898885555551aaaaaaaaa11aaaaaaaaaaaaaaaa1aaaa1
-- 082:aaaaaaaa456644a1aaa4654a3d364a3333046542245642230033001324567dddd72465422456403333246542245639993233a1322456423333043dd3335642223304634234567877778765422456403333246542c4564222aa445564aaaaa151115888c85555551aaaaaaaaaa1aaaaaaaaaaaaaaaa1a1aa1
-- 083:aaaaaaaa456564aaaa4654a3dd35642a2346543322456422300353332245777772465422234564322246542002456333224310322245642222463d9ccc3364222246313313356788887654223045643222465422c2456422aa455564aaaaa155555899885555551aaaaaaaaaaaaaaaaaaa1aa1a1aaaa1aaa
-- 084:aaaaaaaa4564564aa4654a331d34564a24654001322456426335400132245642246542223003564264654660e0245642243aa8333324564264638899cccc3642246310110133567777654663103456422465c22222a4c642a4654564aaaaa151155888985511551aaa1aaaaaaaaaaaaaaa1aa1aaaaaaaaaa
-- 085:aaaaaaaa456545644654a303d33a45644654a33003a245644654333013224564465426631033456446542220ee02456446533998303245644653999c9ccc3564465431001013356446542231032245644654ac6cccac456446544564aaaaa15555589898555555aaaa11a1aaaaaaaaaa1aaaaaaaaaaaaaaa
-- 086:aaaaaaaa45665454654a30330013a454654aaa3333aaa454654222230132245465466663032264546542220e2e022454654633893003645465399999c9ccc354654631100103345465422230322224546546aacbcbcaa45465445564aaaaa155555898985a55a5aaaaa1aa1aaaaaaaaaaaaaaaaaaaaaaaaa
-- 087:aaaaaaaa4566544654aa303133013a4654aaa300113aaa4654666333303222465422223136266646546660e2ee0222465422239983036646543999b99c9c93465423010100033646546662303222224654accacccccacc4654445564aaaaaa5a5a58a8a85aa5aaaaa1a11a11aaaaaaaaaaaaaaaaaaaaaaaa
-- 088:aaaaaaaa45666465444a3003aa303465444a30333013a46544463d11300324654442663133666465444660e2ee02246544423139983364654439bb9b9999936544423000100364654443363003222469444aaacbcbcaa46544455564aaaaaaaaa1aa1a1a1aaaaaa1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 089:aaaaaaaa456645544454a331a330365333343033330046544453d1d3630046544454663000324653345460e22e02465444530033999346544453bbb9b9993654445433000032465444311363032249549494acacbcac465444545564aaaaaaaaaaaaaa1a11aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 090:aaaaaaaa4564654aa4564aa13033633baaa343003a34654aa453dd36633465466456466330033331d336460ee064634634560363338935466453bbbbb9b935466456403333646546631000300364659aa459caaaaaa4c54aa4554564aaaaaaaaaaaaaaaaa1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 091:aaa1aaaa4566541aaa4564aa30003bbb11bb3433aa465433aa45336a2a4654336645646663033d99ddd36460024631331345646666333466664533bbb93354626345646666465333633064003a4659aaaa9564aaca4654aaaa45577777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 092:a1aa1a1a4565441aaaa4564aa333b8818bbbb34aa46540013aa4564a6465400136645646a436ddd11ddd36466463101101345646246546333634563333654226300356462465310033345633a4654a1a7aa4564ac4654aa1aa447884887aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa44aaaaaaa1aaaaa
-- 093:a1aa1aa1456454aaaaaa45644653bbb8bbbbb3644654333013aa45644654a33003a64564463ddddd1ddd3564465331001013456446542301130045644654226310334564465300301103456446541a1787aa45644654aaa1a14488888681a1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4984aaaaaa11a1aa
-- 094:aaaaaaa1456554aaaaaaa456453bbbbbbbbbb356454aaaa3013aa456454aaa3333aaa456453ddd6ddd6d345645433110010364564546300301336456454666630366645645430363003aa456454a1a78771aa45645411aaaaa4488886881aa1aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa49884aaaaaa1aa1a
-- 095:aaaaaaaa456654aaaaaaaa45643bb6bbbbbbb34564aaa333303aaa4564aaa300113aaa456431ddddddd13a456463010100036a45646a303a30366645646a6a313a6a6a4564a3003333aaaa45641a17788771aa4564a11aaa1a44888888811a11aaaaaaaaaaaaaaaaaaaaaaaaaa44444448884aaaa1a11a11
-- 096:aaaaaaaa456664aaaaaaa444563bbb66bbbb3444564a3d113003a444564a30333013a34456431ddd1dd13444564a30001003a433364a30033013a444564aaa3133aaa344564a3000033aa444564aa78778871449564aaaaaaa457888887aaaaaaaaaaaaaaaaaaaaaaaaaaaaa4499999999884aaaaaaaaaaa
-- 097:aaaaaaaa456464aaaaaa45444563bb6bbbbb35444563d1d3a3004544456430333300313445631ddd1dd345443564a300003343dd3564a300330035443564aa30003a31344564a3330003454445647788887749449594aaaaaa457488847aaaaaaaaaaaaaaaaaaaaaaaaaaa449999999c99994aaaaaaaaaaa
-- 098:aaaaaaaa456644aaaaa4634a345388bbbb83634a3453dd3aa334654aa45643003a33a13aa4563dd33d34654373364a3333043dd333564a333a30654373364aa33003a13aa4564aaa3304634a345678777787659aa4594aaaaa44577877aaaaaaaaaaaaaaaaaaaaaaaaaa449cc9c9c999c9cc94aaaaa1aaaa
-- 099:aaaaaaaa456564aaaa4631331345338888363133134533aaaa465433aa456433aa431033aa456331334654377cd364aaaa463d9ccc3364aaaa4654377cd364aaa3031033aa4564aaaa46313313456788887659aaaa9564aaaa455568aa1aaaaaaaaaaaaaaaaaa1aaaaa499c99c99c9999c99c94a1aaa1a1a
-- 100:aaaaaaaa4564564aa463101101345633336310110134564aa46540013aa4564aa43aa8333a14564aa46543377ddd364aa4638899cccc3641a46543377ddd364aa43aa8333aa4564aa46310110134567777654aaa7aa4564aa4654568aaa1aa1aaa1aaaaaaaaaaa1aaa49cc99c999999899c99c94a1aa1a1a
-- 101:aaaaaaaa45654564465431001013456446543100101345644654333013aa45644653399833aa456446543bb7cd6d35644653999c9ccc356446543bb7cd6d35644653399833aa456446543100101345644654aaa787aa456446544568a1a11a11aa11a1aaaaaaaa1aa49c99999999989589898994a1aaaaaa
-- 102:aaaaaaaa45665454654a311001031454654a31100103a454654aaaa3013aa454654aa38933aaa4546543bbbcccdd345465399999c9ccc3546543bbbcccdd3454654aa38933aaa454654a31100103a454654aaa78771aa45465445568aa1a1a11aaa1aa1aaa1aaa11499989898989555555959984aaaaaaaa
-- 103:aaaaaaaa4566544654a3010100031a465413010100031a4654aaa333303aaa4654aaa399833aaa4654a3bbccbcdc3a46543999b99c9c93465413bbccbcdc3a4654aaa399833aaa4654a301010003aa4654aaa7788771aa46544455681a1a1aa1a1a11a11aaa1aaa149989595595555555555954aaaaaaaaa
-- 104:aaaaaaaa45666465444a300010031465444a300010031465444a3d113003a465444a30399833a4654443bbbbcbcd34654439bb9b999993654443bbbbcbcd3465444a30399833a465444a30001003a465444aa7877887a46544455568a1aa1a11aaaaaaaaaaa11aaa48955555555588855555554aaaaaaaaa
-- 105:aaaaaaaa456645544454a300003346544454a300003346544453d1d3a300465444543033999346544453bbcbbccc33544453bbb9b99933544453bbcbbccc335444543033999346544454a30000000000000000088877465444545568aaaa1aa1aaaaaaaaaaaa1aaaa4555555588889885445554aaaaaaaaa
-- 106:aaaaaaaa45646541a4564a333304654aa4564a333304654aa453dd3aa334654aa45643003389354aa4538bb8bbc30131a453bbbbb9b9313aa4538bb8bbc3013aa45643003389354aa4564a333304654aa45678077787654aa4554568aaaaaaaaaaaaaaaaaaaaaaaaa4554445898989885555554aaaaaaaaa
-- 107:aaaaaaaa456654aaaa4564a3304654aaaa4564aaa34653aaaa4533aaaa4654aaaa456433aa3333aaaa453888cb36033aaa4533bbb933033aaa453888cb36033aaa456433aa3333aaaa4564aaa30654aaaa456708887654aaaa455568aaaaaaaaaaaaa1aaaaaaaaaaa4545555898989885555444aaaaaaaaa
-- 108:aaaaaaaa456544aaaaa4564aa465403aaaa4564aa465313aaaa4564aa46533aaaaa4564aa4653131aaa45333336533aaaaa456333365313aaaa453333365403aaaa4564aa4653131aaa4564aa4054033aaa4560777654aaaaa445568aaaaaaaaaaaaaa1aaaaaaaaaa4554445898989885555554aaaaaaaaa
-- 109:aaaaaaaa456454aaa1a145644654300333aa456446540013aaaa45644653013aaaaa456446540013a1a145644653013aaaaa456446540013aaaa45644654300333aa456446540013aaaa45644604300133aa45044654aaaaaa444568aaaaaaaaaaaaaa1aaaaaaaaaa4544445898989885555554aaaaaaaaa
-- 110:aaaaaaaa456554aaaa1a1456454a3303113aa456454a33013aaaa45645330013aa1aa456454133013a1a145645330013aaaaa456454a33013aaaa456454a3303113aa456454133013aaaa4564501a330013aa406454aaaaaaa444568aaaaaaaaaa1aaa11aaaaaaaaa4544445898989885555554aaaaaaaaa
-- 111:aaaaaaaa456654aa1a1a1a4564aaa3310003aa4564aaa30103aaaa4564aa30013aa1aa4564a11301031a1a4564aa30013aaaaa4564aaa30103aaaa4564aaa3310003aa4564a1130103aaaa4564011a133013aa0564aaaaaaaa445568aaaaaaaaaaa1aaa1aaaaaaaaa4544445898888c85544554aaaaaaaaa
-- 112:aaaaaaaa456654aaaaaaa444564aaa30030374445647aa3013aa74445647a30013aaa4445647aa3013aa74445647a30013aaa4445647aa3013aa74445647aa30030374445647aa3013aaa4445607777a3003a404564aaaaaaa445568aaaaaaaaaaaaaaaaaaaaaaaaa4555445888889985555554aaaaaaaaa
-- 113:aaaaaaaa456664aaaaaa45444564a3103037454445647730103745444564773003aa454445647730103745444564773003aa45444564773010374544456473103037454445647730103a45444504777301034504456477aaaa455568aaaaaaaaaaaaaaaaaaaaaaaaa4555555899998885555554aaaaaaaaa
-- 114:aaaaaa44c44664aaaaa46547a4564310338465477456477300346547745647300034654774564773003465477456473000346547745647730034654774564310337465477456477300346547740648730134650774564777aa455568aaaaaaaaaaaaaaaaaaaaaaaaa4554455888889885555554aaaaaaaaa
-- 115:aaaaa4eecee464a7774654887745630138465487774564730036547887456473103654777745647300365478874564731036547777456473003654787745630137465478874564730036547778056430103654077745647777455568aaaaaaaaaaaaaaaaaaaaaaaaa455555589898988555555aaaaaaaaaa
-- 116:aaaaa4ecc6e46777746547777774530003654777779456300035477777945643103548777794563000354777779456431035487777945630003547777794530003654777779456300035487777045630036547077874564777755568aaaaaaaaaaaaaaaaaaaaaaaaa4555555333339885a55a5aaaaaaaaaa
-- 117:aaaaaccccccc7777465477777777453003547777777745300354777777774530003477877777453003547777777745300034778777774530035477777777453003547777777745300354778777000000000000077777456488775568aaaaaaaaaaaaaaaaaaaaaaaaa45555339999938a55a5aaaaaaaaaaaa
-- 118:aaaaa4eccce47877777777777788773007777777777777700777777777777770077777777777777007777777777777700777777777777770077777777777773007777777777777700777777777777778003777877777777877787568aaaaaaaaaaaaaaaaaaaaaaaaa4a5a3999999993aaaaaaaaaaaaaaaaa
-- 119:aaaaa4ecece4777777778888777777777777777888888777777777777777777777777777888887777777777777777777777777778888877777777777888887777777777777777777777777778887778777777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa393333399993aaaaaaaaaaaaaaaa
-- 120:aaaaa4ceeec4777777787777887777777777778777777887777777888877777777777788777778877777778888777777777777887777788777777788777778877777778888777777777777887778777777777777778887777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa336603339993aaaaaaaaaaaaaaaa
-- 121:aaaaaa44444777787777777777883333333377777777333333338877778833333333777777773333333388777788333333337777777733333333887777773333333388777788333333337777777733333333777788777877777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa33364d0663993aaaaaaaaaaaaaaaa
-- 122:aaaaaaaaaaa777777777777777777777788777777777777777777777777777778777777777777777777777777777777787777777777777777777777777777777777777777777777787777777777777778887778777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3333dd16463933aaaaaaaaaaaaaaa
-- 123:aaaaaaaaaaaaaa777777779977777777777779777777777777877777777787777777777777777777778777777777877777777777777777777787777777777777778777777777877777777777777777777778777797777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3333d1336639783aaaaaaaaaaaaaa
-- 124:aaaaaaaaaaaaaaaaa77777777777777777777777777777777777777977777777777777777777777777777779777777777777777777777777777777797777777777777779777777777777777777777787777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa333333333397783aaaaaaaaaaaaa
-- 125:aaaaaaaaaaaaaaaaaaaa7777777777777777777777aaaa7777777777777777aaa777777777aaaa7777777777777777aaa777777777aaaa777777777777aaaa7777777777777777aaa7777777777777777aa7777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa39839333377773aaaaaaaaaaaaa
-- 126:aaaaaaaaaaaaaaaaaaaaaaaaaaa77777777aaaaaaaaaaaaaa7777777777aaaaaaaa7777aaaaaaaaaa7777777777aaaaaaaa7777aaaaaaaaaa7777777aaaaaaaaa7777777777aaaaaaaa7777aaa77777aaaaaa7777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa39989933977773aaaaaaaaaaaaa
-- 127:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777aaaaaaaaaaaaaaaaaaaaaaaaaa777777aaaaaaaaaaaaaaaaaaaaaaaaaa77777aaaaaaaaaaa777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa399989999977773aaaaaaaaaaaaa
-- 128:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa39998999993773aaaaaaaaaaaaaa
-- 129:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa331333133a33aaaaaaaaaaaaaaa
-- 130:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3bbb3a3bbb3aaaaaaaaaaaaaaaaa
-- 131:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa3bbb3a3bbb3aaaaaaaaaaaaaaaaa
-- 132:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 133:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 134:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 135:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- </SCREEN>

-- <PALETTE>
-- 000:006166009e8e7eeae623232e59718d73b5d8eee2d2663644b04643de7e527de39de65c32ffce5cbad93d4785ffe639e6
-- </PALETTE>


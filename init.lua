-- luacheck: read_globals core

local DEFAULT_RADIUS = 10
local world_path = core.get_worldpath()
local places_file = world_path .. "/places.json"

local player_hud = {}

-- Load places
local function load_places()
	local f = io.open(places_file, "r")
	if not f then
		return {}
	end
	local content = f:read("*all")
	f:close()

	local data = core.parse_json(content, nil, true)
	if type(data) == "table" then
		return data
	end
	return {}
end

local places = load_places()

core.register_privilege("place_edit", {
	description = "Allows adding, removing, or resizing named places",
	give_to_singleplayer = true,
})

-- Save places
local function save_places_json()
	local f = io.open(places_file, "w")
	if not f then
		core.log("error", "[placenames] Could not open file: " .. places_file)
		return
	end
	f:write(core.write_json(places, true))
	f:close()
end

-- 3D region match (cube: radius applies to x/y/z)
local function get_current_place(player)
	local pos = vector.round(player:get_pos())

	local best = nil
	local best_radius = math.huge
	local best_dist = math.huge

	for _, place in ipairs(places) do
		local dx = math.abs(pos.x - place.pos.x)
		local dy = math.abs(pos.y - place.pos.y)
		local dz = math.abs(pos.z - place.pos.z)

		if dx <= place.radius and dy <= place.radius and dz <= place.radius then
			local dist = vector.distance(pos, place.pos)

			if place.radius < best_radius or (place.radius == best_radius and dist < best_dist) then
				best = place
				best_radius = place.radius
				best_dist = dist
			end
		end
	end

	return best
end

-- Register place
local function register_place(name, pos)
	local place = {
		name = name,
		pos = vector.round(pos),
		radius = DEFAULT_RADIUS,
	}
	table.insert(places, place)
	save_places_json()
	return place
end

local function rename_current_place(player, new_name)
	local place = get_current_place(player)
	if not place then
		return nil
	end
	place.name = new_name
	save_places_json()
	return place
end

local function remove_current_place(player)
	local place = get_current_place(player)
	if not place then
		return false
	end

	for i = #places, 1, -1 do
		if places[i] == place then
			table.remove(places, i)
			save_places_json()
			return place
		end
	end
	return false
end

local function set_current_place_radius(player, radius)
	local place = get_current_place(player)
	if not place then
		return false
	end
	place.radius = radius
	save_places_json()
	return place
end

local function can_edit(playername)
	return core.check_player_privs(playername, { place_edit = true })
end

-- Commands

core.register_chatcommand("placeadd", {
	params = "<name>",
	description = "Add a place at your current position",
	func = function(playername, param)
		if not can_edit(playername) then
			return false, "No permission"
		end
		if param == "" then
			return false, "Missing name"
		end

		local player = core.get_player_by_name(playername)
		if not player then
			return false
		end

		register_place(param, player:get_pos())
		return true, "Added: " .. param
	end,
})

core.register_chatcommand("placeedit", {
	params = "<new name>",
	description = "Rename current place",
	func = function(playername, param)
		if not can_edit(playername) then
			return false, "No permission"
		end
		if param == "" then
			return false, "Usage: /placeedit <name>"
		end

		local player = core.get_player_by_name(playername)
		local place = rename_current_place(player, param)

		if not place then
			return false, "No place here"
		end
		return true, "Renamed to: " .. param
	end,
})

core.register_chatcommand("placeremove", {
	description = "Remove current place",
	func = function(playername)
		if not can_edit(playername) then
			return false, "No permission"
		end

		local player = core.get_player_by_name(playername)
		local place = remove_current_place(player)

		if not place then
			return false, "No place here"
		end
		return true, "Removed: " .. place.name
	end,
})

core.register_chatcommand("placepos", {
	description = "Move the center of the current place to your position",
	func = function(playername)
		if not can_edit(playername) then
			return false, "No permission"
		end

		local player = core.get_player_by_name(playername)
		if not player then
			return false
		end

		local place = get_current_place(player)
		if not place then
			return false, "You are not in any place"
		end

		place.pos = vector.round(player:get_pos())
		save_places_json()

		return true, "Center updated for: " .. place.name
	end,
})

core.register_chatcommand("placeradius", {
	params = "<radius>",
	description = "Change radius of current place",
	func = function(playername, param)
		if not can_edit(playername) then
			return false, "No permission"
		end

		local radius = tonumber(param)
		if not radius then
			return false, "Usage: /placeradius <radius>"
		end

		local player = core.get_player_by_name(playername)
		local place = set_current_place_radius(player, radius)

		if not place then
			return false, "No place here"
		end
		return true, "Radius set to " .. radius
	end,
})

-- HUD tracking
local player_prev_place = {}

core.register_globalstep(function()
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local current = get_current_place(player)
		local prev = player_prev_place[name]

		if current ~= prev then
			player_prev_place[name] = current
		end

		local hud_id = player_hud[name]
		if hud_id then
			local text = current and current.name or ""
			player:hud_change(hud_id, "text", text)
		end
	end
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()

	local id = player:hud_add({
		hud_elem_type = "text",
		position = { x = 0.5, y = 0.05 },
		text = "",
		alignment = { x = 0, y = 0 },
		number = 0xFFFFFF,
	})

	player_hud[name] = id
end)

-- ==== Place Overlay ====

local overlay_enabled = {}
local overlay_timer = 0
local OVERLAY_INTERVAL = 0.2
local OVERLAY_STEP = 2

local function draw_place_outline(place)
	if not place then
		return
	end

	local pos = place.pos
	local r = place.radius
	local tex = "default_mese_block.png^[colorize:#00FF00:150"

	-- top and bottom faces
	for x = -r, r, OVERLAY_STEP do
		for _, y in ipairs({ pos.y - r, pos.y + r }) do
			core.add_particle({
				pos = { x = pos.x + x, y = y, z = pos.z - r },
				velocity = { x = 0, y = 0, z = 0 },
				expirationtime = OVERLAY_INTERVAL + 0.05,
				size = 2,
				texture = tex,
				glow = 10,
			})
			core.add_particle({
				pos = { x = pos.x + x, y = y, z = pos.z + r },
				velocity = { x = 0, y = 0, z = 0 },
				expirationtime = OVERLAY_INTERVAL + 0.05,
				size = 2,
				texture = tex,
				glow = 10,
			})
		end
	end

	for z = -r, r, OVERLAY_STEP do
		for _, y in ipairs({ pos.y - r, pos.y + r }) do
			core.add_particle({
				pos = { x = pos.x - r, y = y, z = pos.z + z },
				velocity = { x = 0, y = 0, z = 0 },
				expirationtime = OVERLAY_INTERVAL + 0.05,
				size = 2,
				texture = tex,
				glow = 10,
			})
			core.add_particle({
				pos = { x = pos.x + r, y = y, z = pos.z + z },
				velocity = { x = 0, y = 0, z = 0 },
				expirationtime = OVERLAY_INTERVAL + 0.05,
				size = 2,
				texture = tex,
				glow = 10,
			})
		end
	end
end

core.register_chatcommand("placeoverlay", {
	description = "Toggle place boundary overlay",
	func = function(name)
		overlay_enabled[name] = not overlay_enabled[name]
		return true, "Overlay: " .. (overlay_enabled[name] and "ON" or "OFF")
	end,
})

core.register_globalstep(function(dtime)
	overlay_timer = overlay_timer + dtime
	if overlay_timer < OVERLAY_INTERVAL then
		return
	end
	overlay_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()

		if overlay_enabled[name] then
			local place = get_current_place(player)
			draw_place_outline(place)
		end
	end
end)

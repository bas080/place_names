local DEFAULT_RADIUS = 20
local CELL_SIZE = 50

local world_path = core.get_worldpath()
local places_file = world_path .. "/places.json"
local player_hud = {}
local up = vector.new(0, 1, 0)
local grid = {}
local places;

local function cell_key(x, y, z)
	return x .. ":" .. y .. ":" .. z
end

local function to_cell(pos)
	return math.floor(pos.x / CELL_SIZE),
	       math.floor(pos.y / CELL_SIZE),
	       math.floor(pos.z / CELL_SIZE)
end

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



local function get_min_max(a, b)
	return {
		x = math.min(a.x, b.x),
		y = math.min(a.y, b.y),
		z = math.min(a.z, b.z),
	}, {
		x = math.max(a.x, b.x),
		y = math.max(a.y, b.y),
		z = math.max(a.z, b.z),
	}
end

local function rebuild_grid()
	grid = {}

	for _, place in ipairs(places) do
		local a = place.min
		local b = place.max

		if not a then
			goto continue
		end

		local minp, maxp = get_min_max(a, b)

		local minx, miny, minz = to_cell(minp)
		local maxx, maxy, maxz = to_cell(maxp)

		for x = minx, maxx do
		for y = miny, maxy do
		for z = minz, maxz do
			local key = cell_key(x, y, z)
			grid[key] = grid[key] or {}
			grid[key][#grid[key] + 1] = place
		end
		end
		end

		::continue::
	end
end

local function init()
	places = load_places()
	rebuild_grid()
end

init()

local function save_places_json()
	local f = io.open(places_file, "w")
	if not f then
		core.log("error", "[placenames] Could not open file: " .. places_file)
		return
	end
	f:write(core.write_json(places, true))
	f:close()
	rebuild_grid()
end

local function get_current_place(pos)
	pos = vector.round(pos + up)
	local cx, cy, cz = to_cell(pos)

	for dx = -1, 1 do
	for dy = -1, 1 do
	for dz = -1, 1 do
		local cell = grid[cell_key(cx + dx, cy + dy, cz + dz)]
		if cell then
			for _, place in ipairs(cell) do
				local a = place.min
				local b = place.max
				if a then
					local minp, maxp = get_min_max(a, b)

					if pos.x >= minp.x and pos.x <= maxp.x
					and pos.y >= minp.y and pos.y <= maxp.y
					and pos.z >= minp.z and pos.z <= maxp.z then
						return place
					end
				end
			end
		end
	end
	end
	end

	return nil
end

core.register_privilege("place_edit", {
	description = "Allows adding, removing, or resizing named places",
	give_to_singleplayer = true,
})

local function can_edit(playername)
	return core.check_player_privs(playername, { place_edit = true })
end

local function get_bounds_from_raycast(pos, range)
	range = range or DEFAULT_RADIUS
	pos = pos + up

    local function cast(dir)
        local target = vector.add(pos, vector.multiply(dir, range))
        local ray = core.raycast(pos, target, false, false)

        for pointed in ray do
            if pointed.type == "node" then
                local hit = pointed.under
                local node = core.get_node(hit)
                local def = core.registered_nodes[node.name]

                if def and def.walkable then
                    return hit
                end
            end
        end

        return vector.round(target)
    end

    local px = cast({x=1,y=0,z=0})
    local nx = cast({x=-1,y=0,z=0})
    local pz = cast({x=0,y=0,z=1})
    local nz = cast({x=0,y=0,z=-1})
    local py = cast({x=0,y=1,z=0})
    local ny = cast({x=0,y=-1,z=0})

    local minp = {
        x = nx.x,
        y = ny.y,
        z = nz.z
    }

    local maxp = {
        x = px.x,
        y = py.y,
        z = pz.z
    }

    return minp, maxp
end

local function register_place(name, pos)
	local a, b = get_bounds_from_raycast(pos)

	local place = {
		name = name,
		min = a,
		max = b
	}

	places[#places + 1] = place
	save_places_json()
	return place
end

local function rename_current_place(player, new_name)
	local place = get_current_place(player:get_pos())
	if not place then return nil end

	place.name = new_name
	save_places_json()
	return place
end

local function remove_current_place(player)
	local place = get_current_place(player:get_pos())
	if not place then return false end

	for i = #places, 1, -1 do
		if places[i] == place then
			table.remove(places, i)
			save_places_json()
			return place
		end
	end

	return false
end

core.register_chatcommand("place_name", {
	params = "<name>",
	description = "Add a place at your current position",
	func = function(playername, param)
		if not can_edit(playername) then return false, "No permission" end
		if param == "" then return false, "Missing name" end

		local player = core.get_player_by_name(playername)
		if not player then return false end

		register_place(param, player:get_pos())
		return true, "Added: " .. param
	end,
})

core.register_chatcommand("place_move", {
	params = "<name>",
	description = "Add a place at your current position",
	func = function(playername, param)

		local pos = core.get_player_by_name(playername):get_pos()
		local minp, maxp = get_bounds_from_raycast(pos)
		local place = get_current_place(pos)

		if not place then return false, "No place here" end

		place.min = minp
		place.max = maxp

		save_places_json()

		return true, "Moved place " .. place.name .. " to: " .. vector.to_string(minp) .. vector.to_string(maxp)
	end
})

core.register_chatcommand("place_rename", {
	params = "<new name>",
	description = "Rename current place",
	func = function(playername, param)
		if not can_edit(playername) then return false, "No permission" end
		if param == "" then return false, "Usage: /placeedit <name>" end

		local player = core.get_player_by_name(playername)
		local place = rename_current_place(player, param)

		if not place then return false, "No place here" end
		return true, "Renamed to: " .. param
	end,
})

core.register_chatcommand("place_remove", {
	description = "Remove current place",
	func = function(playername)
		if not can_edit(playername) then return false, "No permission" end

		local player = core.get_player_by_name(playername)
		local place = remove_current_place(player)

		if not place then return false, "No place here" end
		return true, "Removed: " .. place.name
	end,
})

local player_last_pos = {}
local player_hud_id = {}

local hud_timer = 0
local HUD_INTERVAL = 0.5
local MOVE_THRESHOLD = 4

core.register_on_joinplayer(function(player)
	local id = player:hud_add({
		hud_elem_type = "text",
		position = { x = 0.5, y = 0.05 },
		text = "",
		alignment = { x = 0, y = 0 },
		number = 0xFFFFFF,
	})

	player_hud_id[player:get_player_name()] = id
end)

core.register_globalstep(function(dtime)
	hud_timer = hud_timer + dtime
	if hud_timer < HUD_INTERVAL then return end
	hud_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		-- local pos = vector.round(player:get_pos())

		-- local last = player_last_pos[name]
		-- if last then
		-- 	local dx = pos.x - last.x
		-- 	local dy = pos.y - last.y
		-- 	local dz = pos.z - last.z
		-- 	if dx*dx + dy*dy + dz*dz < MOVE_THRESHOLD * MOVE_THRESHOLD then
		-- 		goto continue
		-- 	end
		-- end

		-- player_last_pos[name] = pos

		local place = get_current_place(player:get_pos())
		local hud = player_hud_id[name]

		if hud then
			player:hud_change(hud, "text", place and place.name or "")
		end

		-- ::continue::
	end
end)

-- =========================
-- Overlay
-- =========================

local overlay_enabled = {}
local overlay_timer = 0
local OVERLAY_INTERVAL = 0.2
local OVERLAY_STEP = 2



local function draw_rect_outline(place)
    local minp = place.min
    local maxp = place.max

    local tex = "default_mese_block.png^[colorize:#00FF00:150"

    -- top/bottom faces (y = min/max)
    for x = minp.x, maxp.x, OVERLAY_STEP do
    for z = minp.z, maxp.z, OVERLAY_STEP do
        core.add_particle({
            pos = { x = x, y = minp.y, z = z },
            expirationtime = OVERLAY_INTERVAL,
            size = 2,
            texture = tex,
            glow = 10
        })

        core.add_particle({
            pos = { x = x, y = maxp.y, z = z },
            expirationtime = OVERLAY_INTERVAL,
            size = 2,
            texture = tex,
            glow = 10
        })
    end
    end

    -- front/back faces (z = min/max)
    for x = minp.x, maxp.x, OVERLAY_STEP do
    for y = minp.y, maxp.y, OVERLAY_STEP do
        core.add_particle({
            pos = { x = x, y = y, z = minp.z },
            expirationtime = OVERLAY_INTERVAL,
            size = 2,
            texture = tex,
            glow = 10
        })

        core.add_particle({
            pos = { x = x, y = y, z = maxp.z },
            expirationtime = OVERLAY_INTERVAL,
            size = 2,
            texture = tex,
            glow = 10
        })
    end
    end

    -- left/right faces (x = min/max)  <-- missing part added
    for z = minp.z, maxp.z, OVERLAY_STEP do
    for y = minp.y, maxp.y, OVERLAY_STEP do
        core.add_particle({
            pos = { x = minp.x, y = y, z = z },
            expirationtime = OVERLAY_INTERVAL,
            size = 2,
            texture = tex,
            glow = 10
        })

        core.add_particle({
            pos = { x = maxp.x, y = y, z = z },
            expirationtime = OVERLAY_INTERVAL,
            size = 2,
            texture = tex,
            glow = 10
        })
    end
    end
end

core.register_chatcommand("place_overlay", {
	description = "Toggle overlay",
	func = function(name)
		overlay_enabled[name] = not overlay_enabled[name]
		return true, "Overlay: " .. (overlay_enabled[name] and "ON" or "OFF")
	end,
})

core.register_globalstep(function(dtime)
	overlay_timer = overlay_timer + dtime
	if overlay_timer < OVERLAY_INTERVAL then return end
	overlay_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()

		if overlay_enabled[name] then
			local place = get_current_place(player:get_pos())

			if place then
				draw_rect_outline(place)
			end
		end
	end
end)

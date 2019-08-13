npcs = {
	tasks = {},
	active = {},
	activate_interval = 2,
}

npcs.names = { -- htps://www.fantasynamegenerators.com/
	"Aguth",
	"Awam",
	"Angash",
	"Mahang",
	"Zothos",
	"Phegar",
	"Niyelo",
	"Yezaddem",
	"Ayarris",
	"Suddahnihn",
	"Walehn",
	"Revrun",
	"Viwal",
	"Ihoth",
	"Sazas",
	"Gille",
	"Guwinush",
	"Kyithikun",
	"Therahno",
	"Kyabenru",
	"Misrol",
	"Oyoth",
	"Segyosh",
	"Vuddo",
	"Musu",
	"Egyirs",
	"Moshero",
	"Veseddan",
	"Umeso",
	"Thamoke",
}

dofile(minetest.get_modpath("npcs").."/nodes.lua")
dofile(minetest.get_modpath("npcs").."/functions.lua")

function npcs.pts(pos) -- Pos to string, also rounds pos
	return minetest.pos_to_string(vector.round(pos))
end

local function rand_rot()
	local rots = {0, 90, 180, 270}

	return(rots[math.random(1, 4)])
end

--
--- NPCS
--

npcs.register_task("find_tree", {
	info = "%s is searching for a tree",
	condition = function(pos)
		local enough_wood = minetest.get_meta(pos):get_inventory():contains_item("main", "nc_woodwork:plank 45")
		local tree = minetest.find_node_near(pos, 40, "nc_tree:root", false)

		return (tree and vector.distance(pos, tree) > 4 and not enough_wood)
	end,
	func = function(pos)
		npcs.move(pos, minetest.find_node_near(pos, 40, "nc_tree:root", false), {
			on_end = function(newpos)
				npcs.stop_task(newpos)
			end
		})
	end
})

npcs.register_task("dig_tree", {
	info = "%s is cutting down a tree",
	condition = function(pos)
		local enough_wood = minetest.get_meta(pos):get_inventory():contains_item("main", "nc_woodwork:plank 45")
		return (minetest.find_node_near(pos, 4.3, "nc_tree:root", false) ~= nil and not enough_wood)
	end,
	func = function(pos)
		local rootpos = minetest.find_node_near(pos, 4.3, "nc_tree:root", false)

		local obj = npcs.active[npcs.pts(pos)]
		local inv = minetest.get_meta(pos):get_inventory()

		if not rootpos then
			npcs.log("Couldn't find a root nearby")
			return
		end

		obj:set_animation(npcs.anim.mine, 40)
		obj:set_yaw(minetest.dir_to_yaw(vector.direction(pos, rootpos))*math.pi)

		minetest.after(3, function()
			nodecore.scan_flood(
				vector.new(rootpos.x, rootpos.y+1, rootpos.z),
				15,
				function(p)
					local name = minetest.get_node(p).name

					if name == "nc_tree:tree" or name == "nc_tree:leaves" then
						minetest.remove_node(p)

						if name == "nc_tree:tree" then
							inv:add_item("main", "nc_woodwork:plank 4")
						end

						return nil
					else
						return false
					end
				end
			)

			minetest.set_node(rootpos, {name = "nc_terrain:dirt"})
			obj:set_animation(npcs.anim.stand)
			npcs.set_task(pos, "plant_tree")
		end)

		return true
	end
})

npcs.register_task("plant_tree", {
	info = "%s is planting a tree",
	func = function(pos)
		local obj = npcs.active[npcs.pts(pos)]
		local eggc = minetest.find_node_near(pos, 5, "nc_tree:eggcorn_planted", false)
		local tree = minetest.find_node_near(pos, 4, "nc_tree:root", false)

		if tree or eggc or not obj then return end

		obj:set_animation(npcs.anim.mine)

		local soil_near = minetest.find_node_near(pos, 10, "group:soil", false)
		local node_near = minetest.find_node_near(pos, 2, "group:soil", false)

		if node_near then
			minetest.set_node(node_near, {name = "nc_tree:eggcorn_planted"})
		elseif soil_near then
			npcs.move(pos, soil_near, {})
			return
		end

		obj:set_animation(npcs.anim.stand)
	end
})

npcs.register_task("find_flat_area", {
	info = "%s is searching for a flat area",
	condition = function(pos)
		local no_house_near = minetest.find_node_near(pos, 40, "npcs:housemarker", false) == nil
		return (minetest.get_meta(pos):get_inventory():contains_item("main", "nc_woodwork:plank 45") and no_house_near)
	end,
	func = function(pos)
		local nodes = minetest.find_nodes_in_area_under_air(vector.add(pos, 25), vector.subtract(pos, 25), "group:soil")
		local whys = {} -- y positions

		for _, p in ipairs(nodes) do
			if not whys[p.y] then whys[p.y] = {} end
			table.insert(whys[p.y], p)
		end

		for y in pairs(whys) do
			if #whys[y] >= 45 then
				for _, spos in ipairs(whys[y]) do
					local mvect = vector.new(5, 5, 5)
					local area = minetest.find_nodes_in_area(spos, vector.add(spos, mvect),
					{"group:soil", "group:flammable", "group:green", "group:fire_fuel", "group:cracky", "group:npcs"})
					local midpos = vector.add(spos, vector.new(2, 2, 2))

					npcs.log(dump(minetest.get_node(midpos).name))

					if #area == 36 then
						minetest.place_schematic(
							vector.new(spos.x, spos.y+1, spos.z),
							minetest.get_modpath("npcs").."/houses/npcs_house.mts",
							rand_rot(), nil, false, nil
						)

						npcs.move(pos, midpos, {
							on_end = function(newpos)
								npcs.stop_task(newpos)
							end
						})

						return
					end
				end
			end
		end
	end
})

npcs.register_task("build_house", {
	info = "%s is building a house",
	condition = function(pos)
		local has_wood = minetest.get_meta(pos):get_inventory():contains_item("main", "nc_woodwork:plank")
		return (minetest.find_node_near(pos, 4, "npcs:placehere", false) ~= nil and has_wood)
	end,
	func = function(pos)
		local found_placehere = minetest.find_node_near(pos, 4, "npcs:placehere", false)
		local inv = minetest.get_meta(pos):get_inventory()
		local obj = npcs.active[npcs.pts(pos)]

		obj:set_animation(npcs.anim.mine)

		if found_placehere then
			minetest.after(0.5, function()
				obj:set_yaw(minetest.dir_to_yaw(vector.direction(pos, found_placehere))*math.pi)
				minetest.set_node(found_placehere, {name = "nc_woodwork:plank"})
				inv:remove_item("main", "nc_woodwork:plank")

				npcs.set_task(pos, "build_house")
			end)
			return true
		end

		obj:set_animation(npcs.anim.stand)

		npcs.stop_task(pos)
	end
})

npcs.register_task("sleep", {
	info = "%s is sleeping",
	condition = function()
		local time = minetest.get_timeofday()

		return (time < 0.25 or time > 0.75)
	end,
	on_step = function(pos)
		local time = minetest.get_timeofday()

		if time >= 0.245 and time <= 0.755 then
			npcs.stop_task(pos)
		end
	end,
	func = function(pos)
		local house_near = minetest.find_node_near(pos, 40, "npcs:housemarker", false)

		if house_near then
			npcs.move(pos, house_near, {
				on_end = function(np, s)
					local obj = npcs.active[npcs.pts(np)]

					npcs.log("Sleep: "..dump(s))

					if s then
						obj:set_animation(npcs.anim.lay)
					else
						npcs.stop_task(np)
					end
				end
			})
			return true
		end
	end
})

npcs.register_task("rest", {
	info = "%s is resting",
	func = function(pos)
		local obj = npcs.active[npcs.pts(pos)]

		obj:set_animation(npcs.anim.sit)

		minetest.after(math.random(7, 13), npcs.stop_task, pos)

		return true
	end
})

--
--- Mapgen and LBM/ABMs
--

minetest.register_ore({
	ore_type       = "blob",
	ore            = "npcs:spawner",
	wherein        = "nc_terrain:dirt_with_grass",
	clust_scarcity = 30 * 30 * 30,
	clust_num_ores = 1,
	clust_size     = 1,
	y_max          = 35,
	y_min          = 5,
})

minetest.register_lbm({
	label = "activate npcs",
	name = "npcs:spawner",
	nodenames = {"npcs:spawner"},
	run_at_every_load = true,
	action = function(pos)
		local pos_up = vector.new(pos.x, pos.y+1, pos.z)

		minetest.set_node(pos_up, {name = "npcs:npc"})
		minetest.set_node(pos, {name = "nc_terrain:dirt_with_grass"})
		npcs.activate_npc(pos_up)
	end,
})

minetest.register_lbm({
	label = "activate npcs",
	name = "npcs:activator",
	nodenames = {"npcs:npc"},
	run_at_every_load = true,
	action = function(pos)
		if not npcs.active[npcs.pts(pos)] then
			npcs.activate_npc(pos)
		end
	end,
})

minetest.register_abm({
	label = "activate npcs",
	name = "npcs:activator",
	nodenames = {"npcs:npc"},
	interval = 10,
	action = function(pos)
		if not npcs.active[npcs.pts(pos)] then
			npcs.activate_npc(pos)
		end
	end,
})

local deactivate_step = 0
local activate_step = 0
minetest.register_globalstep(function(dtime)
	if deactivate_step <= 20 then
		deactivate_step = deactivate_step + dtime
	else
		deactivate_step = 0

		for p in pairs(npcs.active) do
			p = minetest.string_to_pos(p)

			for _, player in ipairs(minetest.get_connected_players()) do
				if vector.distance(player:get_pos(), p) >= 50 then
					npcs.deactivate_npc(p)
				end
			end
		end
	end

	if activate_step <= npcs.activate_interval then
		activate_step = activate_step + dtime
	else
		activate_step = 0

		for p in pairs(npcs.active) do
			p = minetest.string_to_pos(p)
			local meta = minetest.get_meta(p)
			local p2 = vector.round(npcs.active[npcs.pts(p)]:get_pos())

			if not vector.equals(p, p2) then
				local metatable = meta:to_table()
				local pu = vector.new(p.x, p.y+1, p.z)

				minetest.remove_node(p)
				minetest.remove_node(pu)

				npcs.active[npcs.pts(p2)] = npcs.active[npcs.pts(p)]
				npcs.active[npcs.pts(p)] = nil
				p = p2
				minetest.set_node(p, {name = "npcs:npc"})
				minetest.set_node(vector.new(p.x, p.y+1, p.z), {name = "npcs:hidden"})
				meta = minetest.get_meta(p)

				meta:from_table(metatable)
			end

			if meta:get_int("busy") == 1 then
				local stepfunc = npcs.tasks[meta:get_string("task")].on_step

				if stepfunc then
					stepfunc(p)
				end
			else
				for tname, task in pairs(npcs.tasks) do
					if task.condition and task.condition(p) and tname ~= meta:get_string("task") then
						npcs.set_task(p, tname)
						npcs.log("Set task to "..tname)
						return
					end
				end

				npcs.set_task(p, "rest")
			end
		end
	end
end)

--
--- Entity
--

minetest.register_entity("npcs:npc_ent", {
	npc = true,
	physical = true,
	collide_with_objects = false,
	pointable = false,
	stepheight = 1.5,
	time = 0,
	visual = "mesh",
	mesh = "nc_player_model.b3d",
	static_save = false,
	textures = {"npcs_blockfoot.png"},
	collisionbox = {0.35, 1.5, 0.35, -0.35, 0, -0.35},
	nodemeta = {},
	on_step = function(self)
		if not self.gopos then return end

		local obj = self.object
		local dir = vector.direction(obj:get_pos(), self.gopos)

		local vel = vector.multiply(dir, 5)

		vel.y = -7

		obj:set_velocity(vel)
		obj:set_yaw(minetest.dir_to_yaw(dir))
	end,
	move = function(obj, pos1, pos2, path)
		local pos = obj:get_pos()
		local self = obj:get_luaentity()

		if not path then
			path = pathfinder.find(pos1, pos2, 555)
			self.gopos = vector.round(pos1)
		else
			if not path[1] then
				npcs.stop_move(obj, true)
				return
			end

			if minetest.registered_nodes[minetest.get_node(path[1]).name].walkable == false then
				if vector.equals(vector.round(pos), self.gopos) then
					self.gopos = vector.round(path[1])
					table.remove(path, 1)
				end
			else
				path = pathfinder.find(pos, pos2, 555)

				if path then
					if vector.equals(vector.round(pos), self.gopos) then
						self.gopos = vector.round(path[1])
						table.remove(path, 1)
					end
				else
					npcs.log("Failed to find path")
					npcs.stop_move(obj, false)
				end
			end
		end

		local gp_up = vector.new(self.gopos.x, self.gopos.y+1, self.gopos.z)
		if vector.distance(pos, pos2) > 1 and path and path[1] and minetest.get_node(gp_up).name == "air" then
			minetest.after(0.4, minetest.registered_entities["npcs:npc_ent"].move, obj, pos1, pos2, path)
		else
			obj:set_velocity(vector.new(0, -7, 0))
			obj:set_pos(vector.add(vector.round(pos), vector.new(0, -0.5, 0)))
			npcs.stop_move(obj, true)
		end
	end
})
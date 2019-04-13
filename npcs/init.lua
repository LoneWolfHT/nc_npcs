npcs = {
	tasks = {},
	active = {}
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

--
--- NPCS
--

npcs.register_task("wait", {
	info = "%s is planning their next move",
	func = function(pos)
		local tree = minetest.find_node_near(pos, 30, "nc_tree:root", false)
		local eggc = minetest.find_node_near(pos, 15, "nc_tree:eggcorn_planted", false)

		if tree and not eggc then
			npcs.move(pos, tree, {
				on_end = function()
					npcs.set_task(pos, "dig_tree")
				end
			})
		elseif eggc and vector.distance(pos, eggc) > 5 then
			npcs.move(pos, eggc, {
				on_end = function()
					npcs.set_task(pos, "wait_tree")
				end
			})
		elseif not eggc and not tree then
			local pos_down = vector.new(pos.x, pos.y-1, pos.z)
			local node_below = minetest.get_node(pos_down).name
			local node_near = minetest.find_node_near(pos, 3, "group:soil", false)

			if node_near then
				minetest.set_node(node_near, {name = "nc_tree:eggcorn_planted"})
				npcs.set_task(pos, "wait_tree")
			elseif minetest.registered_nodes[node_below].groups and minetest.registered_nodes[node_below].groups.soil then
				minetest.set_node(pos_down, {name = "nc_tree:eggcorn_planted"})
				npcs.set_task(pos, "wait_tree")
			end
		end
	end
})

npcs.register_task("dig_tree", {
	info = "%s is cutting down a tree",
	func = function(pos)
		local rootpos = minetest.find_node_near(pos, 4.3, "nc_tree:root", false)
		local treepos = minetest.find_node_near(pos, 4.3, "nc_tree:root", false)
		local leaves = minetest.find_node_near(pos, 5, "nc_tree:leaves", false)
		local num = 0
		local inv = minetest.get_meta(pos):get_inventory()

		treepos.y = treepos.y + 1

		while leaves do
			npcs.move(pos, leaves, {
				on_end = function()
					minetest.remove_node(leaves)
					leaves = minetest.find_node_near(pos, 5, "nc_tree:leaves", false)
				end
			})

			num = num + 5
		end

		while minetest.get_node(treepos).name == "nc_tree:tree" do
			minetest.remove_node(treepos)
			inv:add_item("main", "nc_woodwork:plank 4")
			treepos.y = treepos.y + 1
		end

		minetest.set_node(rootpos, {name = "nc_tree:eggcorn_planted"})
	end
})

--
--- Mapgen and (L/A)BMs
--

minetest.register_ore({
	ore_type       = "blob",
	ore            = "npcs:npc_spawner",
	wherein        = "nc_terrain:dirt_with_grass",
	clust_scarcity = 30 * 30 * 30,
	clust_num_ores = 1,
	clust_size     = 1,
	y_max          = 30,
	y_min          = 0,
})

minetest.register_lbm({
	label = "activate npcs",
	name = "npcs:spawner",
	nodenames = {"npcs:npc_spawner"},
	run_at_every_load = true,
	action = function(pos, node)
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
		pos = vector.round(pos)

		if not npcs.active[minetest.pos_to_string(pos)] then
			npcs.activate_npc(pos)
		end
	end,
})

local deactivate_step = 0
minetest.register_globalstep(function(dtime)
	if deactivate_step <= 20 then
		deactivate_step = deactivate_step + dtime
	else
		for _, p in ipairs(npcs.active) do
			for _, player in ipairs(minetest.get_connected_players()) do
				if vector.distance(player:get_pos(), p) >= 40 then
					npcs.deactivate_npc(p)
				end
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
	pointable = false,
	stepheight = 1.5,
	time = 0,
	visual = "mesh",
	mesh = "nc_player_model.b3d",
	static_save = false,
	textures = {"npcs_blockfoot.png"},
	collide_with_objects = false,
	collisionbox = {0.5, 1.5, 0.5, -0.5, -0.3, -0.5},
	nodemeta = {},
	move = function(obj, pos1, pos2, path)
		local pos = obj:get_pos()
		local ent_offset = vector.new(0, -0.5, 0)

		if not path then
			path = pathfinder.find(pos1, pos2, 350)
			obj:set_pos(vector.add(pos1, ent_offset), false)
		else
			if not path[1] then
				npcs.stop_move(obj, false)
				return
			end

			if minetest.get_node(path[1]).name == "air" then
				obj:set_pos(vector.add(path[1], ent_offset), false)
				table.remove(path, 1)
			else
				path = pathfinder.find(pos, pos2, 350)

				if path then
					obj:set_pos(vector.add(path[1], ent_offset), false)
					table.remove(path, 1)
				else
					npcs.stop_move(obj, false)
				end
			end
		end

		if vector.distance(pos, pos2) > 1 and path then
			minetest.after(0.5, minetest.registered_entities["npcs:npc_ent"].move, obj, pos1, pos2, path)
		else
			npcs.stop_move(obj, true)
		end
	end
})
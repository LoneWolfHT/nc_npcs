minetest.register_node("npcs:npc", {
	description = "You hacker you!!",
	drawtype = "airlike",
	paramtype = "light",
	diggable = false,
	light_source = 5,
	selection_box = {
		type = "fixed",
		fixed = {0.45, 1.5, 0.25, -0.45, -0.5, -0.25},
	},
	collision_box = {
		type = "fixed",
		fixed = {0.45, 1.5, 0.25, -0.45, -0.5, -0.25},
	},
	on_punch = function(pos, node, puncher, pointed_thing)
		npcs.log(minetest.serialize(minetest.get_meta(pos):to_table().fields))
	end,
	on_rightclick = function(pos, _, clicker)
		minetest.show_formspec(clicker:get_player_name(), "npcs:inv", getform(pos))
	end
})

function getform(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec =
		"size[8,9]" ..
		"list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]" ..
		"list[current_player;main;0,4.85;8,1;]" ..
		"list[current_player;main;0,6.08;8,3;8]" ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]"
	return formspec
end

minetest.register_node("npcs:hidden", {
	description = "You big hacker you!!",
	drawtype = "airlike",
	paramtype = "light",
	diggable = false,
	pointable = false,
})

minetest.register_node("npcs:npc_spawner", minetest.registered_nodes["nc_terrain:dirt_with_grass"])
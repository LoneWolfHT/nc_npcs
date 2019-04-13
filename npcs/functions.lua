local anim = {
	stand     = {x = 0,   y = 0},
	sit       = {x = 1,   y = 1},
	walk      = {x = 2,   y = 42},
}

function npcs.log(text)
	minetest.chat_send_all("[npcs] " .. text)
end

-- Tasks

function npcs.register_task(name, def)
	npcs.tasks[name] = def
end

function npcs.set_task(pos, name)
	local meta = minetest.get_meta(pos)
	local npcname = meta:get_string("name")

	meta:set_string("task", name)
	meta:set_string("infotext", string.format(npcs.tasks[name].info, npcname))
	npcs.tasks[name].func(pos)
end

-- Movement

function npcs.move(pos1, pos2, def)
	local obj = npcs.active[minetest.pos_to_string(vector.round(pos1))]
	local dist = vector.new(2, 2, 2)

	obj:get_luaentity().nodemeta = minetest.get_meta(pos1):to_table()
	obj:get_luaentity().def = def
	minetest.remove_node(pos1)
	minetest.remove_node(vector.new(pos1.x, pos1.y+1, pos1.z))

	pos2 = minetest.find_nodes_in_area(vector.add(pos2, dist), vector.subtract(pos2, dist), "air")

	if pos2 then
		for _, p in ipairs(pos2) do
			p.y = p.y + 1
			local p_up = vector.new(p.x, p.y+1, p.z)

			if minetest.get_node(p_up).name == "air" then
				pos2 = p
				break
			end
		end

		if not pos2.x then
			npcs.log("Couldn't find any air near destination")
			npcs.stop_move(obj, false)
			return
		else
			local pos_down = vector.new(pos2.x, pos2.y-1, pos2.z)

			while minetest.get_node(pos_down).name == "air" do
				pos2 = pos_down
				pos_down = vector.new(pos2.x, pos2.y-1, pos2.z)
			end
		end

		obj:set_animation(anim.walk, 40)
		obj:get_luaentity().move(obj, pos1, pos2)
	else
		npcs.log("Couldn't find any air near destination")
		npcs.stop_move(obj, false)
	end
end

function npcs.stop_move(obj, success)
	local pos = obj:get_pos()

	minetest.set_node(pos, {name = "npcs:npc"})
	minetest.set_node(vector.new(pos.x, pos.y+1, pos.z), {name = "npcs:hidden"})
	minetest.get_meta(pos):from_table(obj:get_luaentity().nodemeta)
	obj:set_animation(anim.stand)

	if success and obj:get_luaentity().def and obj:get_luaentity().def.on_end then
		obj:get_luaentity().def.on_end()
		obj:get_luaentity().def = nil
	end
end

--Activation

function npcs.activate_npc(pos)
	local meta = minetest.get_meta(pos)
	local pos_up = vector.new(pos.x, pos.y+1, pos.z)
	local entpos = vector.new(pos.x, pos.y-0.5, pos.z)
	local inv = meta:get_inventory()

	inv:set_size("main", 8)

	if meta:get_string("name") == "" then
		meta:set_string("name", npcs.names[math.random(1, #npcs.names)])
	end

	if minetest.get_node(pos_up).name ~= "npcs:hidden" then
		minetest.set_node(pos_up, {name = "npcs:hidden"})
	end

	npcs.active[minetest.pos_to_string(vector.round(pos))] = minetest.add_entity(entpos, "npcs:npc_ent")

	npcs.set_task(pos, "wait")
	npcs.log("Activated npc at "..minetest.pos_to_string(pos))
end

function npcs.deactivate_npc(pos)
	npcs.active[minetest.pos_to_string(vector.round(pos))] = nil
	npcs.log("Deactivated npc at "..minetest.pos_to_string(pos))
end
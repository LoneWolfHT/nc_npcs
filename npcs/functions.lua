npcs.anim = {
	stand     = {x = 0,   y = 0},
	sit       = {x = 1,   y = 1},
	walk      = {x = 2,   y = 42},
	mine      = {x = 43,  y = 57},
	lay       = {x = 58,  y = 58},
	walk_mine = {x = 59,  y = 103},
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

	if not npcs.tasks[name] then
		npcs.log("No such task: "..(name))
		return
	end

	meta:set_string("task", name)
	meta:set_int("busy", 1)
	meta:set_string("infotext", string.format(npcs.tasks[name].info, npcname))

	local r = npcs.tasks[name].func(pos)

	if not r then
		npcs.stop_task(pos)
	end
end

function npcs.stop_task(pos)
	local meta = minetest.get_meta(pos)
	local npcname = meta:get_string("name")

	meta:set_int("busy", 0)
	meta:set_string("infotext", npcname.." isn't doing anything at the moment")
end

-- Movement

function npcs.move(pos1, pos2, def)
	local obj = npcs.active[npcs.pts(pos1)]
	npcs.active[npcs.pts(pos1)] = nil

	obj:get_luaentity().nodemeta = minetest.get_meta(pos1):to_table()
	obj:get_luaentity().def = def
	minetest.remove_node(pos1)
	minetest.remove_node(vector.new(pos1.x, pos1.y+1, pos1.z))

	if vector.equals(pos1, pos2) then
		npcs.stop_move(obj, true)
		return
	end

	if pos2 then
		if minetest.get_node(pos2).name ~= "air" then
			pos2 = minetest.find_node_near(pos2, 5, "air", false)

			if not pos2 then
				npcs.log("Couldn't find any air near destination")
				npcs.stop_move(obj, false)
				return
			end
		end

		local pos_down = vector.new(pos2.x, pos2.y-1, pos2.z)

		while minetest.get_node(pos_down).name == "air" do
			pos2 = pos_down
			pos_down = vector.new(pos2.x, pos2.y-1, pos2.z)
		end

		obj:set_animation(npcs.anim.walk, 40)
		local _, s = pathfinder.find(pos1, pos2, 500)

		if s then
			obj:get_luaentity().move(obj, pos1, pos2)
		else
			npcs.log(dump(pos2))
			minetest.set_node(pos2, {name = "nc_optics:glass"})
			npcs.log("Couldn't find a path")
			npcs.stop_move(obj, false)
		end
	else
		npcs.log("Couldn't find any air near destination")
		npcs.stop_move(obj, false)
	end
end

function npcs.stop_move(obj, success)
	local pos = vector.round(obj:get_pos())

	minetest.set_node(pos, {name = "npcs:npc"})
	minetest.set_node(vector.new(pos.x, pos.y+1, pos.z), {name = "npcs:hidden"})
	minetest.get_meta(pos):from_table(obj:get_luaentity().nodemeta)
	obj:set_animation(npcs.anim.stand)
	npcs.active[npcs.pts(pos)] = obj

	if obj:get_luaentity().def and obj:get_luaentity().def.on_end then
		obj:get_luaentity().def.on_end(pos, success)
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
	meta:set_int("busy", 0)

	if meta:get_string("name") == "" then
		meta:set_string("name", npcs.names[math.random(1, #npcs.names)])
	end

	if minetest.get_node(pos_up).name ~= "npcs:hidden" then
		minetest.set_node(pos_up, {name = "npcs:hidden"})
	end

	npcs.active[npcs.pts(pos)] = minetest.add_entity(entpos, "npcs:npc_ent")
	npcs.log("Activated npc at "..minetest.pos_to_string(pos))
end

function npcs.deactivate_npc(pos)
	npcs.stop_task(pos)
	npcs.active[npcs.pts(pos)]:remove()
	npcs.active[npcs.pts(pos)] = nil
	npcs.log("Deactivated npc at "..minetest.pos_to_string(pos))
end

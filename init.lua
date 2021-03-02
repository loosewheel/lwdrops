local version = "0.1.3"
local mod_storage = minetest.get_mod_storage ()



lwdrops = { }



function lwdrops.version ()
	return version
end



local drops_folder = minetest.get_worldpath().."/lwdrops"
local time_to_live = tonumber (core.settings:get ("item_entity_ttl")) or 900


minetest.mkdir (drops_folder)


local drops_data = minetest.deserialize (mod_storage:get_string ("drops_data") or "")
if type (drops_data) ~= "table" then
	drops_data = { }
end



local function store_drops_data ()
	mod_storage:set_string ("drops_data",
				minetest.serialize (drops_data))
end



local function get_drops_data (itemstack)
	if itemstack and itemstack.get_count then
		local meta = itemstack:get_meta ()

		if meta then
			local id = meta:get_int ("_lwdrops_id")

			if id > 0 then
				local name = tostring (id)
				local entry = drops_data[name]

				if entry then
					local fields = { }

					for i = 1, #entry.fields do
						local path = drops_folder.."/drop_"..entry.fields[i].."_"..name
						local data = ""
						local file = io.open (path, "r")

						if file then
							data = file:read ("*a")
							file:close ()
						end

						fields[entry.fields[i]] = data
					end

					return fields
				end
			end
		end
	end

	return nil
end



local function remove_drops_data (id)
	if id > 0 then
		local name = tostring (id)
		local entry = drops_data[name]

		if entry then
			for i = 1, #entry.fields do
				local path = drops_folder.."/drop_"..entry.fields[i].."_"..name

				os.remove (path)
			end

			drops_data[name] = nil

			store_drops_data ()
		end
	end
end



local function check_drops_data ()
	local tm = os.time ()
	local expired = { }

	for k, v in pairs (drops_data) do
		if v.expire < tm then
			expired[#expired + 1] = k
		end
	end

	if #expired > 0 then
		for i = 1, #expired do
			local entry = drops_data[expired[i]]

			for i = 1, #entry.fields do
				local path = drops_folder.."/drop_"..entry.fields[i].."_"..expired[i]

				os.remove (path)
			end

			drops_data[expired[i]] = nil
		end

		store_drops_data ()
	end

	minetest.after (time_to_live, check_drops_data)
end



local function find_item_def (name)
	local def = minetest.registered_items[name]

	if not def then
		def = minetest.registered_craftitems[name]
	end

	if not def then
		def = minetest.registered_nodes[name]
	end

	if not def then
		def = minetest.registered_tools[name]
	end

	return def
end



local function remove_meta_key (meta, key)
	if meta:contains (key) then
		local raw = meta:to_table ()

		if raw then
			raw.fields[key] = nil

			meta:from_table (raw)
		end
	end

	return meta
end



function lwdrops.store (itemstack, ... )
	local fields = { ... }

	if itemstack and itemstack.get_count and itemstack:get_count () > 0 then
		local meta = itemstack:get_meta ()

		if meta then
			local id = math.random (1000000)
			local name = tostring (id)

			meta:set_int ("_lwdrops_id", id)

			for i = 1, #fields do
				local path = drops_folder.."/drop_"..fields[i].."_"..name
				local file = io.open (path, "w")

				if file then
					file:write (meta:get_string (fields[i]))
					file:close ()
				else
					minetest.log ("warning", "lwdrops.store - could store field '"..fields[i].."'")
				end

				meta:set_string (fields[i], "")
			end

			drops_data[name] =
			{
				expire = os.time () + time_to_live + 10,
				fields = fields
			}

			store_drops_data ()

			return itemstack
		end
	end

	return nil
end



function lwdrops.on_destroy (itemstack)
	local stack = ItemStack (itemstack)

	if stack and stack:get_count () > 0 then
		local def = find_item_def (stack:get_name ())

		if def and def.on_destroy then
			def.on_destroy (stack)
		end
	end
end



-- hook dropped items entity
local __builtin_item = minetest.registered_entities["__builtin:item"]
if not __builtin_item then
	minetest.log ("error", "lwdrops could not find '__builtin:item'")

else
	local item =
	{
		on_punch = function (self, hitter)
			local name = (self.itemstring or ""):match ("[%S]+")
			local def = find_item_def (name)

			if def and hitter then
				local inv = hitter:get_inventory()
				local stack = ItemStack (self.itemstring)

				if inv and stack then
					local meta = stack:get_meta ()

					if meta then
						local id = meta:get_int ("_lwdrops_id")

						if id > 0 then
							local fields = get_drops_data (stack)

							if fields then
								local count = stack:get_count ()

								while stack:get_count () > 0 do
									if inv:room_for_item ("main", stack) then
										break
									else
										stack:set_count (stack:get_count () - 1)
									end
								end

								if stack:get_count () > 0 then
									meta = remove_meta_key (meta, "_lwdrops_id")

									if def.on_pickup then
										stack = def.on_pickup (stack, fields)
									else
										for k, v in pairs (fields) do
											meta:set_string (k, v)
										end
									end

									if stack:get_count () > 0 then
										inv:add_item ("main", stack)
									end
								end

								if stack:get_count () < count then
									local left = ItemStack (self.itemstring)

									if left then
										left:set_count (count - stack:get_count ())
										self:set_item (left)

										return
									end
								end

								remove_drops_data (id)

								self.itemstring = ""
								self.object:remove()

								return
							end
						end
					end
				end
			end

			__builtin_item.on_punch (self, hitter)
		end,


		on_step = function (self, dtime, moveresult)
			local age = self.age + dtime

			if time_to_live > 0 and age > time_to_live then
				local stack = ItemStack (self.itemstring)

				if stack and stack:get_count () > 0 then
					lwdrops.on_destroy (stack)

					local meta = stack:get_meta ()

					if meta then
						local id = meta:get_int ("_lwdrops_id")

						if id > 0 then
							remove_drops_data (id)
						end
					end
				end
			end

			__builtin_item.on_step (self, dtime, moveresult)
		end
	}


	-- set defined item as new __builtin:item, with the old one as fallback table
	setmetatable(item, __builtin_item)
	minetest.register_entity(":__builtin:item", item)
end



-- hook pulverize command
local pulverize = minetest.registered_chatcommands["pulverize"]
if not pulverize then
	minetest.log ("error", "lwdrops could not find 'pulverize' command")

else
	local pulverize_func = pulverize.func

	minetest.override_chatcommand ("pulverize", {
		func = function (name, param)
			local player = minetest.get_player_by_name (name)

			if player then
				local item = player:get_wielded_item ()

				if item and not item:is_empty () then
					lwdrops.on_destroy (item)
				end
			end

			return pulverize_func (name, param)
		end
	})
end



-- hook default creative trash
local creative_trash_inv = minetest.detached_inventories["creative_trash"]

if creative_trash_inv then
	local creative_trash_inv_on_put = creative_trash_inv.on_put

	creative_trash_inv.on_put = function (inv, listname, index, stack, player)

		if stack then
			lwdrops.on_destroy (stack)
		end

		if creative_trash_inv_on_put then
			creative_trash_inv_on_put (inv, listname, index, stack, player)
		end
	end

end



-- hook unified_inventory trash
local trash_inv = minetest.detached_inventories["trash"]

if trash_inv then
	local trash_inv_on_put = trash_inv.on_put

	trash_inv.on_put = function (inv, listname, index, stack, player)

		if stack then
			lwdrops.on_destroy (stack)
		end

		if trash_inv_on_put then
			trash_inv_on_put (inv, listname, index, stack, player)
		end
	end

end



-- hook unified_inventory Clear inventory
if minetest.global_exists ("unified_inventory") then
	local buttons = unified_inventory.buttons

	if buttons then
		for i = 1, #buttons do
			if buttons[i].name and buttons[i].name == "clear_inv" then
				local action = buttons[i].action

				if action then
					buttons[i].action = function (player)
						local player_name = player:get_player_name ()

						if unified_inventory.is_creative(player_name) then
							local inv = player:get_inventory ()

							if inv then
								local slots = inv:get_size ("main")

								for i = 1, slots do
									local stack = inv:get_stack ("main", i)

									if stack then
										lwdrops.on_destroy (stack)
									end
								end
							end
						end

						action (player)
					end
				end
			end
		end
	end
end



minetest.after (time_to_live, check_drops_data)



--

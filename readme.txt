LWDrops
	by loosewheel


Licence
=======
Code licence:
LGPL 2.1


Version
=======
0.1.7


Minetest Version
================
This mod was developed on version 5.3.0


Dependencies
============


Optional Dependencies
=====================
default
creative
unified_inventory
i3


Installation
============
Copy the 'lwdrops' folder to your mods folder.


Bug Report
==========
https://forum.minetest.net/viewtopic.php?f=9&t=26331&p=390894#p390894


Description
===========
Utility to store large item metadata strings to file/s when dropped, which
usually causes a server crash "String too long for serializeString".

An on_destroy handler is also supported, called when:
*	a dropped item is about to be destroyed (permanently removed from the world)
*	when the pulverize command is used.
*	when an item is destroyed with Minetest Game creative inventory trash.
*	when an item is destroyed with unified_inventory trash.
*	when the unified_inventory Clear inventory is used.
*	when an item is destroyed with i3 inventory trash.
*	when the i3 inventory Clear inventory is used.

Storage can be implemented with a single function call, and an optional
handler. The data is stored in the world save folder, and cleanup of
redundant stored data is handled automatically.

*	The mod uses os.time () for time stamping. In common platforms this
returns a seconds count from an epoch. Lua documentation is ambiguous about
less common platforms.

While this mod is game agnostic, each game should be checked for
functionality.

Known to work with:
Minetest Game
Dream Builder Game

Known to not work with:
MineClone2



Functions:

lwdrops.store (itemstack, ... )

	Stores and nullify the relevant itemstack metadata fields. Returns the
	nullified itemstack, which should be the dropped itemstack. Returns nil
	if the given itemstack is invalid or has a count of zero. If a file error
	occurs writing out the data, the call succeeds and logs an error message.

	itemstack: the itemstack containing the item/s.

	... : series of (or one) metadata string field names to store. These are
		the string fields that are nullified (set to "").

	Call this from the on_drop handler of the item.

	*	the meta string names must be file name compatible.



lwdrops.item_pickup (entity, cleanup)

	Returns an ItemStack of the items in the given entity, and optionally
	removes the entity and any stored data. On failure nil is returned.
	This provides for custom pickup of dropped items that cooperates with
	the lwdrops data system.

	entity: this should be a "__builtin:item" entity, but is checked for
			  internally and returns nil if not.
	cleanup: if not false, and the call succeeds, the entity is removed
				and any stored drop data is deleted.

	*	this function can be called first with cleanup as false to check the
		item, and if suitable called again with cleanup as nil or true to
		remove the entity and any data.



lwdrops.item_drop (itemstack, dropper, pos)

	Drops the item using the item's on_drop handler if it has one, or
	minetest.item_drop if not. Returns the leftover itemstack.

	itemstack: the item/s to drop.
	dropper: the player dropping the item/s.
	pos: the world position the item/s is dropped.



lwdrops.on_destroy (itemstack)
	Calls the on_destroy handler for the item, if one exists. When trashing
	an item, calling this function allows the item definition to do any
	cleanup work.
	itemstack: an itemstack of the item being destroyed.



Handlers:
	Handlers are defined in the item definition, passed to the various
	minetest.register_?? functions.


on_pickup (itemstack, fields)

	Called to deal with loading the stored data back into the itemstack.
	Should return the modified itemstack, which is placed in the player's
	inventory.

	itemstack: the itemstack picked up. The itemstack is checked/reduced to
		fit in the player's inventory.

	fields: key and value table of the field data. The key is the metadata
		field's name and the value is the string data.

	*	This handler is optional. If missing the data is loaded back into
		the itemstack's metadata.



on_destroy (itemstack)
	Called when the dropped item is about to be destroyed (permanently
	removed from the world). No return value is used.

	itemstack: itemstack of the item/s about to be destroyed. This is for
		querying, changing it has no effect.



Implementation:

------------------------------------------------------------------------

function itemdef.on_drop (itemstack, dropper, pos)
	-- one or more string fields
	local drops = lwdrops.store (itemstack, "fieldname_1", "fieldname_2")

	if drops then
		return minetest.item_drop (drops, dropper, pos)
	end

	-- itemstack is empty

	return itemstack
end



-- optional, if missing this is the default action
function itemdef.on_pickup (itemstack, fields)
	local meta = itemstack:get_meta ()

	if meta then
		for k, v in pairs (fields) do
			meta:set_string (k, v)
		end
	end

	-- this itemstack is the one placed into the player's inventory
	return itemstack
end



function itemdef.on_destroy (itemstack)
	-- do any cleanup work for the item
end



-- custom pickup example
local function custom_pickup (pos)
	local list = minetest.get_objects_inside_radius (pos, 2)

	for i = 1, #list do
		if list[i].get_luaentity then
			-- get stack to check
			local stack = lwdrops.item_pickup (list[i]:get_luaentity (), false)

			if stack then
				local inv = minetest.get_meta (pos):get_inventory ()

				if inv:room_for_item ("main", stack) then
					inv:add_item ("main", stack)

					-- cleanup
					lwdrops.item_pickup (list[i]:get_luaentity ())
				end
			end
		end
	end
end

------------------------------------------------------------------------

LWDrops
	by loosewheel


Licence
=======
Code licence:
LGPL 2.1


Version
=======
0.1.3


Minetest Version
================
This mod was developed on version 5.3.0


Dependencies
============
default


Optional Dependencies
=====================
creative
unified_inventory


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
*	when an item is destroyed with creative inventory trash.
*	when an item is destroyed with unified_inventory trash.
*	when the unified_inventory Clear inventory is used.

Storage can be implemented with a single function call, and an optional
handler. The data is stored in the world save folder, and cleanup of
redundant stored data is handled automatically.

*	The mod uses os.time () for time stamping. In common platforms this
returns a seconds count from an epoch. Lua documentation is ambiguous about
less common platforms.



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



------------------------------------------------------------------------

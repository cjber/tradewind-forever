-- Run from the repository root: luajit tests/store_spec.lua
-- Defaults, migration, and a save from a newer addon that is read and never written.
local H = dofile("tests/helpers.lua")
local check = H.check
local ns = H.load(H.namespace(), "Core/Store.lua")
local Store = ns.Store

-- A fresh save gets every default, and each default table is its own copy.
local db = {}
Store.Init(db)
check(db.schema == Store.SCHEMA and type(db.characters) == "table" and type(db.vendorBuy) == "table", "defaults filled")
check(db.characters ~= Store.DEFAULTS.characters, "defaults are copied, not shared")
check(Store.Writable(), "a fresh save is writable")
local record = Store.Character("A-R")
check(record and db.characters["A-R"] == record and next(record.recipes) == nil, "a character is created in the save")

-- Existing values survive and only missing keys fill.
local kept = { characters = { ["B-R"] = { name = "B" } }, schema = 1 }
Store.Init(kept)
check(kept.characters["B-R"].name == "B" and kept.vendorBuy ~= nil, "existing data kept, gaps filled")

-- Migration steps run in order from the saved schema to the target.
local trail = {}
local old = { schema = 1 }
check(
	Store.Migrate(old, {
		[1] = function(d)
			trail[#trail + 1] = 1
			d.a = true
		end,
		[2] = function()
			trail[#trail + 1] = 2
		end,
	}, 3),
	"an older save migrates"
)
check(trail[1] == 1 and trail[2] == 2 and old.schema == 3 and old.a, "steps run once each, in order")
check(Store.Migrate({}, nil, 1), "a save with no schema is current")

-- A newer schema is read, never written: nothing is filled and no character is created.
local future = { schema = Store.SCHEMA + 1, characters = { ["Z-R"] = { name = "Z" } } }
Store.Init(future)
check(not Store.Writable(), "a newer save is read-only")
check(future.schema == Store.SCHEMA + 1 and future.vendorBuy == nil, "a newer save is left as found")
check(Store.Get().characters["Z-R"].name == "Z", "a newer save still reads")
check(Store.Get().vendorBuy ~= nil, "a missing key reads as its default")
check(Store.Character("New-R") == nil and future.characters["New-R"] == nil, "no character is written to it")

-- A character record missing its nested tables is completed, in a writable save and in a read-only view.
check(
	type(kept.characters["B-R"].professions) == "table" and type(kept.characters["B-R"].recipes) == "table",
	"partial record completed"
)
local viewOnly = { schema = Store.SCHEMA + 1, characters = { ["Y-R"] = { name = "Y" } } }
Store.Init(viewOnly)
check(type(Store.Get().characters["Y-R"].recipes) == "table", "a read-only view completes a partial record")
check(viewOnly.characters["Y-R"].recipes == nil, "and leaves the newer save as found")
Store.Get().characters["Y-R"].name = "Changed"
check(viewOnly.characters["Y-R"].name == "Y", "the read-only view shares no table with the save")

print("store_spec ok")

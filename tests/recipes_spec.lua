-- Run from the repository root: luajit tests/recipes_spec.lua
-- Recipes: recorded one at a time from the open window, from the spellbook without one, never from a linked or guild
-- window, and keyed by the canonical skill line whatever ID the client reports.
local H = dofile("tests/helpers.lua")
local check = H.check
local ns = H.namespace()
ns.RecipeData = {
	[100] = { skillLine = 171, reagents = { { itemID = 10, qty = 1 } }, output = { itemID = 20, qty = 1 } },
	[101] = { skillLine = 171, reagents = { { itemID = 11, qty = 1 } }, output = { itemID = 21, qty = 1 } },
	[200] = { skillLine = 164, reagents = { { itemID = 12, qty = 1 } }, output = { itemID = 22, qty = 1 } },
}
local now = 500
rawset(_G, "GetServerTime", function()
	return now
end)
rawset(_G, "UnitName", function()
	return "Barry"
end)
rawset(_G, "UnitClass", function()
	return "Hunter", "HUNTER"
end)
rawset(_G, "GetNormalizedRealmName", function()
	return "Realm"
end)
rawset(_G, "GetRealmName", function()
	return "Realm"
end)
local professions = { { "Alchemy", nil, 20, 75, nil, nil, 8167 } }
rawset(_G, "GetProfessions", function()
	local out = {}
	for i = 1, #professions do
		out[i] = i
	end
	return unpack(out, 1, #professions)
end)
rawset(_G, "GetProfessionInfo", function(i)
	return unpack(professions[i], 1, 7)
end)
local window = { linked = false, guild = false, ids = { 100, 101, 200 }, learned = { [100] = true, [101] = false } }
rawset(_G, "C_TradeSkillUI", {
	IsTradeSkillLinked = function()
		return window.linked
	end,
	IsTradeSkillGuild = function()
		return window.guild
	end,
	GetAllRecipeIDs = function()
		return window.ids
	end,
	GetRecipeInfo = function(id)
		return { learned = window.learned[id] }
	end,
	GetBaseProfessionInfo = function()
		return { professionName = "Alquimia", professionID = 171 }
	end,
})
local known = {}
local asked = 0
rawset(_G, "C_SpellBook", {
	IsSpellKnown = function(id)
		asked = asked + 1
		return known[id] == true
	end,
})
H.load(ns, "Core/Store.lua", "Core/Professions.lua", "Core/Recipes.lua")
ns.Store.Init({})
local Recipes = ns.Recipes

-- Canonical mapping: the name wins over the reported ID (Forever reports 8167 for Alchemy), and a learned local name
-- maps too.
check(ns.Professions.Canonical("Alchemy", 8167) == 171, "name over reported id")
check(ns.Professions.Canonical("Unheard", 164) == 164, "a canonical reported id is accepted")
check(ns.Professions.Canonical("Unheard", 8167) == nil, "an unknown profession maps to nothing")
ns.Professions.NoteWindow()
check(ns.Professions.Canonical("Alquimia", 1) == 171, "a name seen at an open window is learned")
check(Recipes.CurrentKey() == "Barry-Realm", "character key")

-- Forever realms have no name; the second UnitFullName value is a surname that characters on one realm can share.
rawset(_G, "UnitGUID", function()
	return "Player-6941-006325F9"
end)
rawset(_G, "UnitFullName", function()
	return "Barry", "Guns"
end)
rawset(_G, "GetNormalizedRealmName", function()
	return ""
end)
rawset(_G, "GetRealmName", function()
	return ""
end)
local foreverKey, foreverName, foreverRealm = Recipes.CurrentKey()
check(
	foreverKey == "Barry Guns-6941" and foreverName == "Barry Guns" and foreverRealm == "",
	"a realm without a name keys by full name and server id"
)
rawset(_G, "UnitFullName", function()
	return "Barry", "Neville"
end)
check(Recipes.CurrentKey() == "Barry Neville-6941", "characters sharing a first name on one realm stay apart")
rawset(_G, "UnitGUID", function()
	return nil
end)
check(Recipes.CurrentKey() == nil, "no key before the client has a GUID")
rawset(_G, "GetNormalizedRealmName", function()
	return "Realm"
end)
rawset(_G, "GetRealmName", function()
	return "Realm"
end)

-- The character record: identity and canonical professions.
local record, changed = Recipes.RecordCharacter()
check(changed and record.name == "Barry" and record.realm == "Realm" and record.class == "HUNTER", "identity recorded")
check(
	record.professions[171].rank == 20 and record.professions[171].reportedId == 8167,
	"canonical profession keyed by line"
)
check(select(2, Recipes.RecordCharacter()) == false, "an unchanged record reports no change")

-- A window records each recipe on its own: learned adds, unlearned removes, others untouched.
record.recipes[101] = true
check(Recipes.ScanWindow(), "window scanned")
check(record.recipes[100] and not record.recipes[101] and record.scannedAt == 500, "per-recipe update")
check(not Recipes.ScanWindow(), "the same window changes nothing")
-- Burst coalescing: repeated scans of one window are idempotent and cheap.
for _ = 1, 5 do
	check(not Recipes.ScanWindow(), "a burst changes nothing more")
end
-- A recipe the bundled data does not cover is not recorded.
window.ids[#window.ids + 1] = 999
window.learned[999] = true
Recipes.ScanWindow()
check(record.recipes[999] == nil, "uncovered recipes are ignored")

-- Linked and guild windows are someone else's recipes.
window.learned[101] = true
window.linked = true
check(not Recipes.ScanWindow() and not record.recipes[101], "a linked window is never recorded")
window.linked, window.guild = false, true
check(not Recipes.ScanWindow() and not record.recipes[101], "a guild window is never recorded")
window.guild = false

-- The spellbook: add-only, and only for professions the character has (Blacksmithing is not one).
known[101], known[200] = true, true
check(Recipes.ProbeKnown(), "probe finds a known recipe")
check(record.recipes[101] and not record.recipes[200], "only recipes of the character's professions")
known[100] = false
Recipes.ProbeKnown()
check(record.recipes[100], "the probe never removes")

-- The probe asks once per profession per session, and a learned recipe is asked about by itself.
asked = 0
check(not Recipes.ProbeKnown() and asked == 0, "a probed profession is not asked about again")
known[102] = true
ns.RecipeData[102] = { skillLine = 171, reagents = { { itemID = 13, qty = 1 } }, output = { itemID = 23, qty = 1 } }
check(Recipes.ProbeKnown(102) and asked == 1 and record.recipes[102], "a learned recipe is asked about alone")

-- Dropping a profession removes its recipes; an empty profession list at login drops nothing.
record.recipes[200] = true
professions = {}
Recipes.RecordCharacter()
check(record.recipes[100] and record.professions[171], "no professions yet is not all dropped")
professions = { { "Mining", nil, 1, 75, nil, nil, 186 } }
Recipes.RecordCharacter()
check(
	record.professions[171] == nil and record.recipes[100] == nil and record.professions[186],
	"a dropped profession takes its recipes"
)

-- A profession the client reports but cannot map yet (another language, window never opened) makes the list
-- incomplete: nothing is dropped for being absent from it.
professions = { { "Bergbau", nil, 1, 75, nil, nil, 8186 }, { "Mining", nil, 1, 75, nil, nil, 186 } }
record.recipes[200] = true
record.professions[164] = { name = "Schmiedekunst", rank = 5, max = 75 }
Recipes.RecordCharacter()
check(record.professions[164] and record.recipes[200], "an unmapped profession is not pruned")
professions = { { "Mining", nil, 1, 75, nil, nil, 186 } }
Recipes.RecordCharacter()
check(record.professions[164] == nil and record.recipes[200] == nil, "a fully mapped list prunes")

-- Tracked items and the reagent set come from the generated data.
record.recipes[100] = true
check(Recipes.TrackedItems(record)[10] and not Recipes.TrackedItems(record)[11], "tracked items follow known recipes")
check(Recipes.ReagentSet()[12] and Recipes.ReagentSet()[10], "the reagent set covers every recipe")

-- A read-only save records nothing.
ns.Store.Init({ schema = ns.Store.SCHEMA + 1 })
check(not Recipes.ScanWindow() and not Recipes.ProbeKnown(), "read-only save")

-- A newer save is never rewritten by recording the character.
local newer = { schema = ns.Store.SCHEMA + 1, characters = { ["Barry-Realm"] = { name = "Old", lastSeen = 1 } } }
ns.Store.Init(newer)
check(Recipes.RecordCharacter() == nil, "no record is made for a read-only save")
check(
	newer.characters["Barry-Realm"].name == "Old" and newer.characters["Barry-Realm"].lastSeen == 1,
	"newer save untouched"
)

print("recipes_spec ok")

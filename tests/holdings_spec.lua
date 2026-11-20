-- Run from the repository root: luajit tests/holdings_spec.lua
-- Holdings: bags and bank recorded as observed scopes, a scope never observed or read secretly stays unknown, and a
-- character has exactly one source, Syndicator's or the addon's own.
local H = dofile("tests/helpers.lua")
local check = H.check
local ns = H.namespace()
ns.RecipeData = {
	[1] = {
		skillLine = 171,
		reagents = { { itemID = 10, qty = 1 }, { itemID = 11, qty = 1 } },
		output = { itemID = 20, qty = 1 },
	},
}
local now = 1000
rawset(_G, "GetServerTime", function()
	return now
end)
local bags, withBank = { [10] = 3, [11] = 0 }, { [10] = 5, [11] = 2 }
local secret = false
rawset(_G, "C_Item", {
	GetItemCount = function(id, includeBank, _, includeReagentBank)
		assert(includeBank == includeReagentBank, "the reagent bank counts with the bank")
		if secret then
			return nil
		end
		return (includeBank and withBank or bags)[id]
	end,
})
rawset(_G, "Syndicator", nil)
H.load(ns, "Core/Store.lua", "Core/Recipes.lua", "Integrations/Syndicator.lua", "Core/Holdings.lua")
ns.Store.Init({})
local Holdings = ns.Holdings
local record = ns.Store.Character("A-R")
record.recipes[1] = true
Holdings.BeginPass()

-- Nothing observed yet: unknown, not zero.
check(Holdings.Count("A-R", 10) == nil, "no record is unknown")
-- Bags only: the bank was never observed, so the total is still unknown.
check(Holdings.Record(record, false), "bags recorded")
local held, bagsOnly = Holdings.Count("A-R", 10)
check(record.bank == nil and held == 3 and bagsOnly == true, "a bank never observed counts the bags alone, flagged")
check(select(2, Holdings.Count("A-R", 11)) == true and Holdings.Count("A-R", 11) == 0, "bags-only zero is flagged too")
-- The bank window open: its scope is the count with the bank less the bags, observed now.
now = 1100
check(Holdings.Record(record, true), "bank recorded")
check(record.bank.counts[10] == 2 and record.bank.counts[11] == 2 and record.bank.observedAt == 1100, "bank scope")
check(Holdings.Count("A-R", 10) == 5 and Holdings.Count("A-R", 11) == 2, "bags plus bank")
check(select(2, Holdings.Count("A-R", 10)) == false, "a seen bank is not bags-only")
check(Holdings.Count("A-R", 12) == 0, "an item held in neither is a known zero")
-- Bank closed later: recounted from the client's cache, observation time kept.
now = 1200
withBank[10] = 6
Holdings.Record(record, false)
check(
	record.bank.counts[10] == 3 and record.bank.observedAt == 1100 and record.bags.observedAt == 1200,
	"bank cache recount keeps its age"
)
-- A secret read replaces nothing.
secret = true
check(not Holdings.Record(record, true) and record.bags.observedAt == 1200, "a secret read keeps the last snapshot")
secret = false
-- Unchanged counts report no change.
check(not Holdings.Record(record, false), "no change is no change")
-- Read-only save writes nothing.
local future = { schema = ns.Store.SCHEMA + 1 }
ns.Store.Init(future)
check(not Holdings.Record(record, true), "a read-only save records nothing")
ns.Store.Init({})
ns.Store.Get().characters["A-R"] = record

-- Syndicator: one source per character for the whole pass.
rawset(_G, "Syndicator", {
	API = {
		IsReady = function()
			return true
		end,
		GetInventoryInfoByItemID = function(id)
			if id == 10 then
				return {
					characters = {
						{ character = "A", realmNormalized = "R", bags = 1, bank = 4 },
						{ character = "B", realmNormalized = "R", bags = 2, bank = 0, mail = 9 },
					},
				}
			end
			return { characters = { { character = "A", realmNormalized = "R", bags = 0, bank = 0 } } }
		end,
	},
})
Holdings.BeginPass()
Holdings.Prefetch(10)
Holdings.Prefetch(11)
check(Holdings.Source("A-R") == "syndicator" and Holdings.Source("C-R") == "own", "source per character")
check(Holdings.Count("A-R", 10) == 5 and Holdings.Count("B-R", 10) == 2, "Syndicator bags plus bank, mail ignored")
check(Holdings.Count("B-R", 11) == 0, "a Syndicator character missing from an item holds none of it")
check(Holdings.Count("C-R", 10) == nil, "an unlisted character with no record of its own is unknown")
-- Malformed answers are no answer.
rawset(_G, "Syndicator", {
	API = {
		IsReady = function()
			return true
		end,
		GetInventoryInfoByItemID = function()
			return { characters = { { character = "A" } } }
		end,
	},
})
check(next(ns.AccountBags.Item(10)) == nil, "a malformed entry is dropped")
rawset(_G, "Syndicator", {
	API = {
		IsReady = function()
			return false
		end,
		GetInventoryInfoByItemID = function()
			error("no")
		end,
	},
})
check(ns.AccountBags.Item(10) == nil and not ns.AccountBags.Ready(), "not ready is no answer")

print("holdings_spec ok")

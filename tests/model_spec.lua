-- Run from the repository root: luajit tests/model_spec.lua
-- The pure model: craftable counts, the outlet a sale is valued at, rounding, sort, footer, shopping, and the rule
-- that a reagent which is itself craftable is priced as a plain item.
local H = dofile("tests/helpers.lua")
local check = H.check
local ns = H.load(H.namespace(), "Core/Model.lua")
local Model = ns.Model

-- Craftable: the smallest whole batch the holdings cover, unknown unless one reagent settles it at zero.
check(
	Model.Craftable({ { itemID = 1, qty = 2, held = 7 }, { itemID = 2, qty = 1, held = 9 } }) == 3,
	"min over reagents"
)
check(
	Model.Craftable({ { itemID = 1, qty = 2, held = 7 }, { itemID = 2, qty = 1 } }) == nil,
	"unknown holding is unknown"
)
check(
	Model.Craftable({ { itemID = 1, qty = 2, held = 1 }, { itemID = 2, qty = 1 } }) == 0,
	"one short reagent settles it"
)
check(Model.Craftable({}) == nil, "no reagents is unknown")

-- Value: the better of the auction after its cut and the vendor, with the outlet named.
local value, outlet = Model.Value({ auction = 1000, sellBack = 100 })
check(value == 950 and outlet == "auction", "auction after the 5% cut")
value, outlet = Model.Value({ auction = 100, sellBack = 500 })
check(value == 500 and outlet == "vendor", "vendor when it pays more")
check(Model.Value({}) == nil and Model.Value(nil) == nil, "nothing known is nil")
check(Model.Value({ auction = 0, sellBack = 0 }) == 0, "a real zero is a value")
check(Model.Value({ auction = 0 / 0 }) == nil, "nan is not a price")

local PRICES = {
	[10] = { auction = 100, sellBack = 10 },
	[11] = { sellBack = 7 },
	[20] = { auction = 1000, sellBack = 20, soldPerDay = 4 },
	[21] = { auction = 400, sellBack = 5 },
	[22] = {},
}
local HELD = { ["A-R"] = { [10] = 6, [11] = 10, [30] = 3 }, ["B-R"] = { [10] = 2, [11] = 1 } }
local RECIPES = {
	[1] = {
		skillLine = 171,
		reagents = { { itemID = 10, qty = 2 }, { itemID = 11, qty = 1 } },
		output = { itemID = 20, qty = 1.5 },
	},
	[2] = { skillLine = 171, reagents = { { itemID = 10, qty = 1 } }, output = { itemID = 21, qty = 1 } },
	[3] = { skillLine = 171, reagents = { { itemID = 10, qty = 1 } }, output = { itemID = 22, qty = 1 } },
	-- Reagent 30 is itself craftable (recipe 9) but is priced as an item, never expanded.
	[4] = { skillLine = 171, reagents = { { itemID = 30, qty = 1 } }, output = { itemID = 20, qty = 1 } },
	[9] = { skillLine = 171, reagents = { { itemID = 10, qty = 5 } }, output = { itemID = 30, qty = 1 } },
	[5] = { skillLine = 333, reagents = { { itemID = 10, qty = 1 } }, output = { itemID = 20, qty = 1 } },
}
local function input(extra)
	local base = {
		characters = {
			{
				key = "A-R",
				name = "A",
				realm = "R",
				professions = { [171] = {} },
				recipes = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true },
			},
			{
				key = "B-R",
				name = "B",
				realm = "R",
				professions = { [171] = {} },
				recipes = { [1] = true, [2] = true },
			},
		},
		recipes = RECIPES,
		item = function(id)
			return PRICES[id] or {}
		end,
		count = function(key, id)
			local held = HELD[key]
			return held and (held[id] or 0) or nil
		end,
	}
	for k, v in pairs(extra or {}) do
		base[k] = v
	end
	return base
end

local result = Model.Compute(input())
local byKey = {}
for _, row in ipairs(result.rows) do
	byKey[row.characterKey .. ":" .. row.spellID] = row
end
-- A makes recipe 1 three times (6 of 10 at 2 each); mats 2*100*.95 + 7 = 197 vs sale round(1.5 * 950) = 1425.
local one = byKey["A-R:1"]
check(one.craftable == 3 and one.matsWorth == 197 and one.sale == 1425 and one.profit == 1228, "row maths")
check(one.saleOutlet == "auction" and one.soldPerDay == 4, "outlet and sold per day")
-- Rows with nothing priced keep nil rather than zero.
local nothing = byKey["A-R:3"]
check(nothing.sale == nil and nothing.profit == nil and nothing.matsWorth ~= nil, "unknown sale is unknown profit")
-- The profession gate: recipe 5 is another profession.
check(byKey["A-R:5"] == nil, "a recipe outside the character's professions is not a row")
-- No chain: 30 is held (3) and priced as an item with no price, so the cost is unknown rather than expanded.
local chained = byKey["A-R:4"]
check(chained and chained.craftable == 3 and chained.matsWorth == nil and chained.profit == nil, "no chain expansion")
-- B holds 2 of item 10 and so cannot make recipe 2 beyond that; recipe 1 needs 1 of 11 and it holds 1.
check(byKey["B-R:1"].craftable == 1 and byKey["B-R:2"].craftable == 2, "per-character holdings")

-- Sort: known profit first, descending, unknown last; ties by character, name then spell ID.
local order = {}
for _, row in ipairs(result.rows) do
	order[#order + 1] = row.profit
end
local seenUnknown = false
local last = math.huge
for _, profit in ipairs(order) do
	if profit == nil then
		seenUnknown = true
	else
		check(not seenUnknown, "unknown profit sorts last")
		check(profit <= last, "profit descends")
		last = profit
	end
end
local tied = {
	{ characterKey = "B", character = "B", itemID = 1, spellID = 2, profit = 5 },
	{ characterKey = "A", character = "A", itemID = 2, spellID = 9, profit = 5 },
	{ characterKey = "A", character = "A", itemID = 1, spellID = 8, profit = 5 },
	{ characterKey = "A", character = "A", itemID = 1, spellID = 3, profit = 5 },
}
Model.Sort(tied, function(id)
	return id == 1 and "Apple" or "Zed"
end)
check(tied[1].spellID == 3 and tied[2].spellID == 8 and tied[3].spellID == 9 and tied[4].character == "B", "tie order")

-- Footer: craftable x profit over known profitable rows; unknown rows counted, losses add nothing.
local total, unknown = Model.Footer({
	{ profit = 10, craftable = 3 },
	{ profit = -50, craftable = 2 },
	{ profit = nil, craftable = 1 },
	{ profit = 5, craftable = nil },
	{ profit = 7, craftable = 1, holdingsUnknown = true },
})
check(total == 30 and unknown == 3, "footer sums known profit and counts the rest")
check(result.total >= 1228 * 3 and result.unknown >= 1, "result carries the footer")

-- The sliced job gives the same answer as the whole one and yields before the end under a tiny budget.
local ticks = 0
local job = Model.NewJob(input({
	clock = function()
		ticks = ticks + 1
		return ticks
	end,
}))
local steps = 0
while not job:Step(2) do
	steps = steps + 1
	check(steps < 1000, "the job finishes")
end
check(steps > 0, "a small budget slices the work")
check(#job.result.rows == #result.rows and job.result.total == result.total, "sliced equals whole")

-- Nothing is gathered before the first step, and rows with unknown holdings rank below every craftable row.
local lazy = Model.NewJob(input({}))
check(#lazy.work == 0 and #lazy.items == 0, "a new job has gathered nothing")
local ranked = {
	{ profit = 900, holdingsUnknown = true, character = "A", itemID = 1, spellID = 1 },
	{ profit = 5, holdingsUnknown = false, character = "A", itemID = 2, spellID = 2 },
	{ profit = nil, holdingsUnknown = false, character = "A", itemID = 3, spellID = 3 },
}
Model.Sort(ranked, function()
	return ""
end)
check(ranked[1].spellID == 2 and ranked[2].spellID == 3 and ranked[3].spellID == 1, "unknown holdings rank last")

-- Shopping: reagents missing for the best rows, aggregated, priced at acquisition, unknown kept unknown.
local lines = Model.Shopping({
	{
		characterKey = "A",
		profit = 100,
		craftable = 2,
		holdingsUnknown = false,
		reagents = { { itemID = 10, qty = 2, held = 4 }, { itemID = 11, qty = 1, held = 9 } },
	},
	{
		characterKey = "A",
		profit = 50,
		craftable = 1,
		holdingsUnknown = false,
		reagents = { { itemID = 10, qty = 1, held = 4 } },
	},
	{
		characterKey = "A",
		profit = nil,
		craftable = 1,
		holdingsUnknown = false,
		reagents = { { itemID = 12, qty = 1, held = 0 } },
	},
	{
		characterKey = "A",
		profit = 90,
		craftable = nil,
		holdingsUnknown = true,
		reagents = { { itemID = 13, qty = 1 } },
	},
	{
		characterKey = "A",
		profit = -5,
		craftable = 1,
		holdingsUnknown = false,
		reagents = { { itemID = 14, qty = 1, held = 0 } },
	},
}, function(id)
	if id == 10 then
		return { buy = 100, buySource = "auction", days = 9 }
	end
	return {}
end)
check(lines.rows == 2, "only known profitable rows with known holdings count")
local byItem = {}
for _, line in ipairs(lines.lines) do
	byItem[line.itemID] = line
end
check(byItem[10] and byItem[10].qty == 5, "a second batch of 4 and 1 is bought after the held 4 went into the first")
check(byItem[10].cost == 500 and byItem[10].stale == true, "priced at acquisition, flagged stale at a week old")
check(byItem[11] == nil, "a covered reagent is not listed")
check(lines.total == 500 and lines.stale == 1, "total and stale count")
check(byItem[12] == nil and byItem[13] == nil and byItem[14] == nil, "excluded rows add no lines")

-- Summary: a record's counts and ages, never invented.
local summary = Model.Summary({
	name = "A",
	realm = "R",
	professions = { [171] = { name = "Alchemy", rank = 5, max = 100 } },
	recipes = { [1] = true, [2] = true },
	bags = { counts = {}, observedAt = 900 },
}, 1000)
check(
	summary.recipes == 2 and summary.scanned == false and summary.bagsAge == 100 and summary.bankAge == nil,
	"summary"
)
check(
	Model.Summary({ name = "A", realm = "R", professions = {}, recipes = {}, scannedAt = 5 }, 10).scanned == true,
	"scanned"
)

print("model_spec ok")

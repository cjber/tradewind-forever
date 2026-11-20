-- Run from the repository root: luajit tests/api_spec.lua
-- TradewindForever.API against a stubbed list, with ForeverCore's own API kit loaded from the checkout FOREVER_CORE
-- names (tests/forever_core.lua finds it), as the client loads it before this addon.
local H = dofile("tests/helpers.lua")
local check = H.check
local core = dofile("tests/forever_core.lua")

local kitNamespace = {
	SafeCallFor = function()
		return {
			SafeCall = function(_, _, callback, ...)
				return callback(...)
			end,
		}
	end,
}
local kitChunk = assert(loadfile(core.directory() .. "/Core/APIKit.lua"))
setfenv(kitChunk, setmetatable({}, { __index = _G }))
kitChunk("ForeverCore", kitNamespace)
local kit = assert(kitNamespace.APIKit)
local published = {}
local realPublish = kit.Publish
kit.Publish = function(name, api)
	published[name] = api
	return realPublish(name, api)
end
rawset(_G, "ForeverCore", { APIKit = kit })

local timers = {}
rawset(_G, "C_Timer", {
	After = function(_, callback)
		timers[#timers + 1] = callback
	end,
})
local function nextFrame()
	local due = timers
	timers = {}
	for _, callback in ipairs(due) do
		callback()
	end
end

local ns = H.namespace()
ns.Started = false
local rows = {
	{
		characterKey = "A-R",
		character = "A",
		profession = 171,
		spellID = 1,
		itemID = 20,
		outputQty = 1.5,
		craftable = 3,
		holdingsUnknown = false,
		reagents = { { itemID = 10, qty = 2, held = 6 } },
		matsWorth = 200,
		sale = 1400,
		saleOutlet = "auction",
		profit = 1200,
		soldPerDay = 4,
	},
	{
		characterKey = "A-R",
		character = "A",
		profession = 171,
		spellID = 2,
		itemID = 21,
		outputQty = 1,
		craftable = nil,
		holdingsUnknown = true,
		reagents = { { itemID = 11, qty = 1 } },
	},
}
local built = { rows = rows, total = 3600, unknown = 1, characters = 1 }
ns.Result = function()
	return built
end
ns.Prices = {
	Item = function(id)
		return id == 11 and { buy = 50, buySource = "merchant" } or {}
	end,
}
ns.CharacterList = function()
	return {
		{
			key = "A-R",
			name = "A",
			realm = "R",
			professions = { { skillLineId = 171, name = "Alchemy", rank = 20, max = 75 } },
			scanned = true,
			recipes = 4,
		},
	}
end
H.load(ns, "Core/Model.lua")
local API = assert(loadfile("Core/API.lua"))("TradewindForever", ns)

check(API.version == 1 and API.minor == 0, "version 1, minor 0")
check(
	_G.TradewindForever.API == API and ns.API == API and published.TradewindForever == API,
	"published on the global and the suite list"
)

-- Before the addon starts there is nothing to answer, in the kit's shape.
for _, name in ipairs({ "Rows", "Shopping", "Characters" }) do
	local value, reason = API[name]()
	check(value == nil and reason == "loading", name .. " is not ready before login")
end

ns.Started = true
local list = API.Rows()
check(
	#list == 2 and list[1].characterKey == "A-R" and list[1].professionId == 171 and list[1].recipeId == 1,
	"row identity"
)
check(
	list[1].itemId == 20 and list[1].outputCount == 1.5 and list[1].craftable == 3 and list[1].holdingsKnown,
	"row output and holdings"
)
check(
	list[1].cost == 200 and list[1].sale == 1400 and list[1].saleOutlet == "auction" and list[1].profit == 1200,
	"row money"
)
check(
	list[2].craftable == nil and list[2].holdingsKnown == false and list[2].profit == nil,
	"unknown stays nil, never 0"
)
list[1].profit = 0
check(API.Rows()[1].profit == 1200, "a caller's changes do not reach the next read")

local shopping = API.Shopping()
check(
	#shopping.lines == 1 and shopping.lines[1].itemId == 10 and shopping.lines[1].count == 6,
	"the profitable known row's second batch"
)
check(
	shopping.lines[1].unitPrice == nil
		and shopping.lines[1].cost == nil
		and shopping.total == 0
		and shopping.unknown == 1,
	"an unpriced line stays unknown and out of the total"
)
local chars = API.Characters()
check(
	#chars == 1 and chars[1].key == "A-R" and chars[1].professions[1].rank == 20 and chars[1].recipes == 4,
	"characters"
)

-- Subscribe: one dispatch on the next frame, only the channels that changed, none when nothing did.
local seen = {}
local off = API.Subscribe(function(changes)
	seen[#seen + 1] = changes
end)
check(type(off) == "function", "Subscribe returns an unsubscribe function")
ns.APIChanged()
nextFrame()
check(#seen == 0, "a rebuild that changes nothing sends nothing")
rows[1].profit = 1300
ns.APIChanged()
nextFrame()
check(#seen == 1 and seen[1].rows == true and seen[1].characters == nil, "a changed row reports the rows channel")
off()
off()
rows[1].profit = 1400
ns.APIChanged()
nextFrame()
check(#seen == 1, "an unsubscribed callback hears nothing, and unsubscribing twice is safe")

print("api_spec ok")

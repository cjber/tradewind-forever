---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

-- The shared shape every Forever addon's public API follows (ForeverCore's docs/api-conventions.md): a read with
-- nothing to answer returns nil and a reason from the kit. Core/Require.lua stops the addon before this file on a
-- ForeverCore too old to have the kit, so it is always here.
local APIKit = assert(ForeverCore.APIKit)

-- Public read-only answers (docs/api.md). `version` rises when a member breaks and `minor` with each addition; a
-- caller checks a member before using it. Every read is fresh: it computes the list for the current inputs and returns
-- tables the caller may keep or change. Nothing here acts: Tradewind Forever never crafts, buys or posts.
local API = { version = 1, minor = 0 }

---@return TWResult?, ForeverCoreAPIReason?
local function Ready()
	if not ns.Started then
		return APIKit.NotReady("loading")
	end
	return ns.Result()
end

-- The Craft now list as the window shows it: each row one recipe for one character that character can make now (or
-- cannot yet be ruled out). Copper amounts are per craft; nil is unknown, never 0.
---@return TWAPIRow[]?, ForeverCoreAPIReason?
function API.Rows()
	local built, reason = Ready()
	if not built then
		return nil, reason
	end
	local rows = {}
	for index, row in ipairs(built.rows) do
		rows[index] = {
			characterKey = row.characterKey,
			character = row.character,
			professionId = row.profession,
			recipeId = row.spellID,
			itemId = row.itemID,
			outputCount = row.outputQty,
			craftable = row.craftable,
			holdingsKnown = not row.holdingsUnknown,
			cost = row.matsWorth,
			sale = row.sale,
			saleOutlet = row.saleOutlet,
			profit = row.profit,
			soldPerDay = row.soldPerDay,
		}
	end
	return rows
end

-- The shopping list: the reagents to buy to make the best rows again, priced where they are bought. A line whose price
-- is unknown has a nil `unitPrice` and `cost` and is left out of `total`.
---@return TWAPIShopping?, ForeverCoreAPIReason?
function API.Shopping()
	local built, reason = Ready()
	if not built then
		return nil, reason
	end
	local shopping = ns.Model.Shopping(built.rows, ns.Prices.Item)
	local lines = {}
	for index, line in ipairs(shopping.lines) do
		lines[index] = {
			itemId = line.itemID,
			count = line.qty,
			unitPrice = line.unit,
			cost = line.cost,
			source = line.source,
			stale = line.stale,
		}
	end
	return { lines = lines, total = shopping.total, unknown = shopping.unknown }
end

-- Every character this addon has recorded: its professions, how many recipes it knows, and how old its bag and bank
-- records are in seconds (nil when never observed).
---@return TWAPICharacter[]?, ForeverCoreAPIReason?
function API.Characters()
	if not ns.Started then
		return APIKit.NotReady("loading")
	end
	return ns.CharacterList()
end

-- Subscribe's hub (ForeverCore.APIKit): each channel compares a key of what a rebuild produced, so an event that
-- changes nothing sends nothing. Ready is the addon's start: before it no list exists.
---@param build fun(result: TWResult): string[]
---@return fun(): string|false
local function Key(build)
	return function()
		if not ns.Started then
			return false
		end
		return table.concat(build(ns.Result()), "\2")
	end
end

local function Num(value)
	return value == nil and "-" or tostring(value)
end

local hub = APIKit.Hub("TradewindForever", {
	rows = Key(function(built)
		local parts = {}
		for index, row in ipairs(built.rows) do
			parts[index] = table.concat({
				row.characterKey,
				row.spellID,
				Num(row.craftable),
				Num(row.profit),
				Num(row.sale),
				Num(row.matsWorth),
				tostring(row.holdingsUnknown),
			}, "\1")
		end
		return parts
	end),
	shopping = Key(function(built)
		local shopping = ns.Model.Shopping(built.rows, ns.Prices.Item)
		local parts = {}
		for index, line in ipairs(shopping.lines) do
			parts[index] = table.concat({ line.itemID, line.qty, Num(line.cost) }, "\1")
		end
		return parts
	end),
	characters = function()
		if not ns.Started then
			return false
		end
		local parts = {}
		for index, character in ipairs(ns.CharacterList()) do
			local lines = {}
			for _, profession in ipairs(character.professions) do
				lines[#lines + 1] = profession.skillLineId .. ":" .. profession.rank
			end
			parts[index] = table.concat({
				character.key,
				character.recipes,
				tostring(character.scanned),
				table.concat(lines, ","),
			}, "\1")
		end
		return table.concat(parts, "\2")
	end,
}, function()
	return ns.Started == true
end)

-- Core's rebuilds say that a frame may have something to report. The hub compares its keys and sends nothing when the
-- rebuild changed none of them.
function ns.APIChanged()
	hub.Queue()
end

-- Calls `callback(changes)` on the frame after the rows, shopping list or characters it names changed, and returns a
-- function that unsubscribes.
API.Subscribe = hub.Subscribe

_G.TradewindForever = _G.TradewindForever or {}
_G.TradewindForever.API = API --[[@as TWPublicAPI]]
ns.API = API --[[@as TWPublicAPI]]

-- The suite lists every Forever addon's API through ForeverCore.APIKit.Addons() (docs/api.md).
ForeverCore.APIKit.Publish("TradewindForever", API)

return API

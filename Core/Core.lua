---@type string, TWNamespace
local addonName, ns = ...

if ns.broken then
	return
end

-- The one client icon every in-game identity surface draws: the Professions side tab. The TOC declares it once, and
-- the drawn media/Icon stays the addon list, compartment and store identity.
ns.ICON = C_AddOns.GetAddOnMetadata(addonName, "X-Forever-Icon") --[[@as string]]

-- The shared services, registered once: the report window's title, this addon's own report lines, and the journal and
-- log that live in TradewindForeverDB.
ns.core = ForeverCore.Register(addonName, {
	title = ns.ReportTitle,
	lines = ns.ReportLines,
})

-- Hands the generated player credits to the shared Thanks page (WFA-31).
ns.core.SafeCall("credits", ForeverCore.Credits.Register, "Tradewind Forever", ns.Credits)

local addon = CreateFrame("Frame")
ns.Addon = addon

-- A slice of the list's computation costs a frame at most this long (milliseconds).
local BUDGET_MS = 3

-- Input changes bump `generation`; a result is current while it equals the generation it was built at. The list is only
-- computed while a window shows it, in slices; a public API read computes it whole, once per generation.
local generation = 0
local result ---@type TWResult?
local resultGeneration = -1
local job ---@type TWJob?
local jobGeneration = -1
local flags = {} ---@type table<string, boolean>
local scheduled = false
local pricesPending = false -- a price arrived while a job ran
local bankOpen = false
local learned = {} ---@type table<integer, true> recipes learned since the last flush
ns.Started = false

---@return TWModelInput
local function Input()
	local characters = {}
	for key, record in pairs(ns.Store.Get().characters) do
		characters[#characters + 1] = {
			key = key,
			name = record.name,
			realm = record.realm,
			professions = record.professions,
			recipes = record.recipes,
		}
	end
	table.sort(characters, function(a, b)
		return a.key < b.key
	end)
	return {
		characters = characters,
		recipes = ns.RecipeData or {},
		item = ns.Prices.Item,
		count = ns.Holdings.Count,
		itemName = ns.ItemName,
		prefetch = function(itemID)
			ns.Holdings.Prefetch(itemID)
			ns.Prices.Item(itemID)
		end,
	}
end

-- The item's name, from the client's cache. A name not cached yet asks the client once and reads as nil.
---@type table<integer, boolean>
local nameRequested = {}
-- Names asked for and not yet delivered: the only arrivals that change what a shown row says.
---@type table<integer, true>
local namePending = {}
---@param itemID integer
---@return string?
function ns.ItemName(itemID)
	local name = C_Item.GetItemNameByID(itemID)
	if name == nil and not nameRequested[itemID] then
		nameRequested[itemID], namePending[itemID] = true, true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return ns.Readable(name)
end

-- Starts the memos a pass reads: prices and Syndicator's answers last for one computation.
local function BeginPass()
	ns.Prices.Reset()
	ns.Holdings.BeginPass()
end

-- The current result, computed whole when stale. Used by the public API and the slash report; the window uses the
-- sliced job instead.
---@return TWResult
function ns.Result()
	if result and resultGeneration == generation then
		return result
	end
	BeginPass()
	job = nil
	local built = ns.Model.Compute(Input())
	result, resultGeneration = built, generation
	return built
end

---@return boolean current whether the last result matches the inputs
function ns.ResultCurrent()
	return result ~= nil and resultGeneration == generation
end

---@return TWResult?
function ns.LastResult()
	return result
end

local function Slice()
	local running = job
	if not running then
		return
	end
	if jobGeneration ~= generation then
		-- The inputs changed under it: restart rather than finish a stale answer.
		BeginPass()
		job, jobGeneration = ns.Model.NewJob(Input()), generation
		running = job
	end
	if running:Step(BUDGET_MS) then
		job = nil
		result, resultGeneration = running.result, jobGeneration
		if pricesPending then
			ns.Invalidate("prices")
		end
		if ns.Window then
			ns.Window.Refresh()
		end
		ns.APIChanged()
	else
		C_Timer.After(0, Slice)
	end
end

-- Builds the list in slices when a window is showing it. Does nothing while the list is current or a job is running.
function ns.Build()
	if ns.ResultCurrent() or job then
		return
	end
	BeginPass()
	job, jobGeneration = ns.Model.NewJob(Input()), generation
	C_Timer.After(0, Slice)
end

local function Flush()
	scheduled = false
	local changed = false
	if flags.professions or flags.window or flags.probe then
		local _, professionsChanged = ns.Recipes.RecordCharacter()
		changed = professionsChanged or changed
	end
	if flags.window then
		ns.Professions.NoteWindow()
		if ns.Recipes.ScanWindow() then
			flags.holdings, changed = true, true
		end
	end
	if flags.probe then
		-- A learned recipe is asked about by itself; a profession not yet probed this session is asked about in full.
		for spellID in pairs(learned) do
			if ns.Recipes.ProbeKnown(spellID) then
				flags.holdings, changed = true, true
			end
		end
		learned = {}
		if ns.Recipes.ProbeKnown() then
			flags.holdings, changed = true, true
		end
	end
	if flags.bags or flags.bank or flags.holdings then
		local key = ns.Recipes.CurrentKey()
		local record = key and ns.Store.Get().characters[key]
		if record and ns.Holdings.Record(record, bankOpen) then
			changed = true
		end
	end
	if flags.merchant and ns.Merchant.Record() > 0 then
		changed = true
	end
	-- A price that arrives while the list is being built waits for that build to end: restarting it for every arrival
	-- would never let it finish on a cold item cache.
	if flags.prices then
		pricesPending = true
	end
	if pricesPending and not job then
		pricesPending, changed = false, true
	end
	flags = {}
	if changed then
		generation = generation + 1
		if ns.Window and ns.Window.IsShown() then
			ns.Build()
		else
			ns.APIChanged()
		end
	end
end

-- Says what changed ("bags", "bank", "window", "probe", "professions", "holdings", "merchant", "prices"): one timer
-- covers a burst of events.
---@param kind string
function ns.Invalidate(kind)
	flags[kind] = true
	if not scheduled and ns.Started then
		scheduled = true
		C_Timer.After(0, Flush)
	end
end

-- Every recorded character as the Characters tab and the public API show them, by name.
---@return TWAPICharacter[]
function ns.CharacterList()
	local now = GetServerTime()
	local list = {}
	for key, record in pairs(ns.Store.Get().characters) do
		local summary = ns.Model.Summary(record, now)
		---@cast summary TWAPICharacter
		summary.key = key
		list[#list + 1] = summary
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.key < b.key
	end)
	return list
end

-- The addon's one entry point, shared by the slash command and the addon compartment.
function ns.Open()
	if ns.Window then
		ns.Window.Toggle()
	end
end

local EVENTS = {
	BAG_UPDATE_DELAYED = function()
		ns.Invalidate("bags")
	end,
	BANKFRAME_OPENED = function()
		bankOpen = true
		ns.Invalidate("bank")
	end,
	BANKFRAME_CLOSED = function()
		if bankOpen then
			-- The bank window is still open when this event fires, so read it now rather than a frame later.
			flags.bank = true
			Flush()
		end
		bankOpen = false
	end,
	PLAYERBANKSLOTS_CHANGED = function()
		if bankOpen then
			ns.Invalidate("bank")
		end
	end,
	PLAYER_LOGOUT = function()
		bankOpen = false
		flags.bags = true
		Flush()
	end,
	TRADE_SKILL_SHOW = function()
		ns.Invalidate("window")
	end,
	TRADE_SKILL_LIST_UPDATE = function()
		ns.Invalidate("window")
	end,
	TRADE_SKILL_DATA_SOURCE_CHANGED = function()
		ns.Invalidate("window")
	end,
	NEW_RECIPE_LEARNED = function(spellID)
		if type(spellID) == "number" then
			learned[spellID] = true
		end
		ns.Invalidate("probe")
	end,
	SKILL_LINES_CHANGED = function()
		ns.Invalidate("professions")
		ns.Invalidate("probe")
	end,
	MERCHANT_SHOW = function()
		ns.Invalidate("merchant")
	end,
	MERCHANT_UPDATE = function()
		ns.Invalidate("merchant")
	end,
	MERCHANT_CLOSED = function()
		ns.Merchant.Closed()
	end,
	GET_ITEM_INFO_RECEIVED = function(itemID)
		if ns.Prices.Arrived(itemID) then
			ns.Invalidate("prices")
		end
		if namePending[itemID] then
			namePending[itemID] = nil
			if ns.Window then
				ns.Window.ItemArrived()
			end
		end
	end,
}

local started = false
function ns.Start()
	if started then
		return
	end
	started = true
	-- The slash command goes in first, so a startup error below still leaves /tradewind answering.
	_G.SLASH_TRADEWINDFOREVER1 = "/tradewind"
	_G.SLASH_TRADEWINDFOREVER2 = "/tw"
	SlashCmdList.TRADEWINDFOREVER = function(message)
		local command = (message or ""):lower():match("^%s*(.-)%s*$")
		if ns.core.Report.Command(command) then
			return
		end
		ns.Open()
	end
	TradewindForeverDB = type(TradewindForeverDB) == "table" and TradewindForeverDB or {}
	ns.Store.Init(TradewindForeverDB)
	-- ForeverCore adds its own journal fields to what it is given: a newer save is never handed over.
	ns.core.Attach(ns.Store.Writable() and TradewindForeverDB or {})
	ns.Started = true
	for event in pairs(EVENTS) do
		addon:RegisterEvent(event)
	end
	ns.Prices.Listen(function()
		ns.Invalidate("prices")
	end)
	flags.professions, flags.probe, flags.holdings = true, true, true
	generation = generation + 1
	ns.Invalidate("probe")
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		ns.Start()
	elseif EVENTS[event] then
		EVENTS[event](...)
	end
end)

_G.TradewindForever_OnAddonCompartmentClick = function()
	ns.Open()
end

return addonName

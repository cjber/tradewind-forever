---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Format = ns.Format

---@class TWWindow
---@field lines TWLine[]
local Window = {}
ns.Window = Window

---@class TWScrollFrame : ScrollFrame
---@field ScrollBar { SetHideIfUnscrollable: fun(self: Frame, hide: boolean) }

local ProfessionTabs = assert(ForeverCore.ProfessionTabs, "ForeverCore has no shared Professions tabs")
-- The client's normal font colour, as plain numbers: a Blizzard colour object's methods are never called (WFA-38).
local GOLD = { r = 1, g = 0.82, b = 0 }
local ROW_HEIGHT = 30
-- The list's 584-wide scroll child plus the page's 4 either side, the inset's 14 either side and the scroll frame's 4
-- and 30. The shared tab owner keeps the window at one width for every profession and tab, raised for this page.
local LIST_WIDTH = 584
local WINDOW_WIDTH = LIST_WIDTH + 70
local COLUMNS = 6
local TABS = {
	{ key = "craft", label = L["Craft now"], tab = ns.CraftNow },
	{ key = "shopping", label = L["Shopping"], tab = ns.ShoppingTab },
	{ key = "characters", label = L["Characters"], tab = ns.CharactersTab },
}
local page ---@type Frame?
local selected = TABS[1]
local pendingOpen = false -- a command during combat, retried when combat ends
local pendingPage = false -- a command's page, waiting for the player to open their profession

-- Frame strata, lowest first: the documented FrameStrata enum order (Wowpedia, "API FrameStrata").
local STRATA = {
	BACKGROUND = 1,
	LOW = 2,
	MEDIUM = 3,
	HIGH = 4,
	DIALOG = 5,
	FULLSCREEN = 6,
	FULLSCREEN_DIALOG = 7,
	TOOLTIP = 8,
}

-- The highest strata among the shown frames of either native page, so this page sits above every frame that draws
-- there and takes their input. Hidden frames draw nothing.
local function NativePagesStrata()
	local function walk(frame, best)
		local strata = frame:GetFrameStrata()
		local level = frame:GetFrameLevel()
		local rank = STRATA[strata] or 0
		if not best or rank > (STRATA[best.strata] or 0) then
			best = { strata = strata, level = level }
		elseif strata == best.strata and level > best.level then
			best.level = level
		end
		for _, child in ipairs({ frame:GetChildren() }) do
			if child:IsShown() then
				best = walk(child, best)
			end
		end
		return best
	end
	local best = { strata = ProfessionsFrame:GetFrameStrata(), level = ProfessionsFrame:GetFrameLevel() }
	for _, native in ipairs({ ProfessionsFrame.CraftingPage, ProfessionsFrame.BookPage }) do
		if native and native:IsShown() then
			best = walk(native, best)
		end
	end
	return best.strata, best.level
end

local function RaiseAboveNativePages()
	if not page then
		return
	end
	local strata, level = NativePagesStrata()
	page:SetFrameStrata(strata)
	page:SetFrameLevel(level + 1)
end

local function SelectPage()
	ProfessionTabs.Select("tradewind")
end

local function Text(parent, font, x, y, width)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	text:SetPoint("TOPLEFT", x, y)
	text:SetWidth(width)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

local function Line(index)
	local line = Window.lines[index]
	if not line then
		line = CreateFrame("Button", nil, Window.list) --[[@as TWLine]]
		line:SetPoint("TOPLEFT", 4, -(index - 1) * ROW_HEIGHT)
		line:SetPoint("TOPRIGHT", -4, -(index - 1) * ROW_HEIGHT)
		line:SetHeight(ROW_HEIGHT)
		line.background = ns.RowArt.RowAtlas(line, "common-button-list-large", "BACKGROUND")
		line.hover = ns.RowArt.RowAtlas(line, "common-button-list-large-hover", "HIGHLIGHT", "ADD")
		-- art-ok: the highlight is the row's own RowArt texture, already fitted at its native aspect.
		line:SetHighlightTexture(line.hover, "ADD")
		line.icon = line:CreateTexture(nil, "ARTWORK")
		line.icon:SetSize(24, 24)
		line.icon:SetPoint("LEFT", 4, 0)
		line.cols = {}
		for index2 = 1, COLUMNS do
			line.cols[index2] = Text(line, "GameFontHighlight", 0, -8, 40)
		end
		line:SetScript("OnEnter", function(self)
			selected.tab.Tooltip(self)
		end)
		line:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		Window.lines[index] = line
	end
	return line
end

-- How far the columns stretch: a tab declares them for the 584-wide list, and the list fills the scroll frame, which
-- the profession window can make wider.
local function Stretch()
	return math.max(1, Window.list:GetWidth() / LIST_WIDTH)
end

-- Places a line's columns where the selected tab declares them, stretched across the list.
local function Layout(line)
	local columns = selected.tab.columns
	local stretch = Stretch()
	for index, text in ipairs(line.cols) do
		local column = columns[index]
		text:ClearAllPoints()
		if column then
			text:SetPoint("TOPLEFT", column[2] * stretch, -8)
			text:SetWidth(column[3] * stretch)
			text:SetJustifyH(column[4])
			text:Show()
		else
			text:Hide()
		end
	end
end

local function Headers()
	local columns = selected.tab.columns
	local stretch = Stretch()
	for index, label in ipairs(Window.headers) do
		local column = columns[index]
		label:ClearAllPoints()
		if column then
			label:SetPoint("TOPLEFT", column[2] * stretch + 4, -10)
			label:SetWidth(column[3] * stretch)
			label:SetJustifyH(column[4])
			label:SetText(column[1])
			label:Show()
		else
			label:Hide()
		end
	end
end

-- The header line: characters counted, and where the prices come from with how old the oldest one is.
---@param result TWResult
---@return string
local function Summary(result)
	local days
	for _, row in ipairs(result.rows) do
		-- priceDays is the oldest of the row's reagent and output prices.
		if type(row.priceDays) == "number" and (not days or row.priceDays > days) then
			days = row.priceDays
		end
	end
	return L["%d characters counted"]:format(result.characters)
		.. "  -  "
		.. Format.PriceSource(ns.Prices.PrimarySource(), days)
end

function Window.IsShown()
	return page ~= nil and page:IsShown()
end

-- A name the client has now: only a shown row's text changes, so redraw, at most once per REDRAW_SECONDS however many
-- names arrive in that time.
local REDRAW_SECONDS = 0.25
local redrawQueued = false
function Window.ItemArrived()
	if redrawQueued or not Window.IsShown() then
		return
	end
	redrawQueued = true
	C_Timer.After(REDRAW_SECONDS, function()
		redrawQueued = false
		Window.Refresh()
	end)
end

function Window.Refresh()
	if not page or not page:IsShown() then
		return
	end
	local result = ns.LastResult()
	if not ns.ResultCurrent() then
		ns.Build()
	end
	local tab = selected.tab
	Headers()
	for _, line in ipairs(Window.lines) do
		line:Hide()
	end
	if not result then
		Window.empty:SetText(L["Counting what your characters can make"])
		Window.empty:Show()
		Window.summary:SetText("")
		Window.footer:SetText("")
		Window.list:SetHeight(1)
		return
	end
	local entries = tab.Entries(result, ForeverCore.Text.Fold(Window.search:GetText()))
	for index, entry in ipairs(entries) do
		local line = Line(index)
		Layout(line)
		line.icon:SetShown(tab.icons)
		if line.overlay then
			line.overlay:SetShown(tab.icons)
		end
		tab.Fill(line, entry)
		line:Show()
	end
	Window.list:SetHeight(math.max(1, #entries * ROW_HEIGHT))
	Window.empty:SetText(tab.empty)
	Window.empty:SetShown(#entries == 0)
	Window.summary:SetText(Summary(result))
	Window.footer:SetText(tab.Footer(result))
	Window.shoppingButton:SetShown(selected == TABS[1])
end

local function Choose(entry)
	PanelTemplates_DeselectTab(selected.button)
	selected = entry
	PanelTemplates_SelectTab(selected.button)
	Window.Refresh()
end

local function Attach()
	if page or not ProfessionsFrame or not ProfessionsFrame.CraftingPage or not ProfessionsFrame.BookPage then
		return
	end
	page = CreateFrame("Frame", nil, ProfessionsFrame)
	page:SetPoint("TOPLEFT", 4, -28)
	page:SetPoint("BOTTOMRIGHT", -4, 4)
	RaiseAboveNativePages()
	page:HookScript("OnShow", RaiseAboveNativePages)
	local surface = page:CreateTexture(nil, "BACKGROUND")
	-- art-ok: the host's own overview surface fills the page above the native page it covers.
	surface:SetAtlas("Profession-Background-Overview")
	surface:SetAllPoints()
	page:EnableMouse(true)
	page:Hide()
	Window.page = page
	Text(page, "GameFontNormalLarge", 74, -12, 300):SetText(L["Tradewind Forever"])
	Window.summary = Text(page, "GameFontHighlightSmall", 0, 0, 340)
	Window.summary:ClearAllPoints()
	Window.summary:SetPoint("TOPRIGHT", -22, -16)
	Window.summary:SetJustifyH("RIGHT")
	Window.search = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
	Window.search:SetSize(200, 20)
	Window.search:SetPoint("TOPLEFT", 22, -48)
	Window.search:SetAutoFocus(false)
	Window.search:HookScript("OnTextChanged", Window.Refresh)
	local inset = CreateFrame("Frame", nil, page)
	inset:SetPoint("TOPLEFT", 14, -78)
	inset:SetPoint("BOTTOMRIGHT", -14, 44)
	Window.inset = inset
	local previous
	for _, entry in ipairs(TABS) do
		local button = CreateFrame("Button", nil, page, "PanelTopTabButtonTemplate")
		if previous then
			button:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", 3, 0)
		else
			button:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 222, -2)
		end
		button:SetText(entry.label)
		if entry == selected then
			PanelTemplates_SelectTab(button)
		else
			PanelTemplates_DeselectTab(button)
		end
		button:SetScript("OnClick", function()
			Choose(entry)
		end)
		entry.button = button
		previous = button
	end
	local background = inset:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", 2, -2)
	background:SetPoint("BOTTOMRIGHT", -2, 2)
	-- art-ok: common-insideframe is a nine-slice, so the client keeps its 53px corners (WhoList.xml:86).
	background:SetAtlas("common-insideframe")
	Window.headers = {}
	for index = 1, COLUMNS do
		Window.headers[index] = Text(inset, "GameFontNormalSmall", 0, -10, 40)
	end
	local scroll = CreateFrame("ScrollFrame", nil, inset, "ScrollFrameTemplate") --[[@as TWScrollFrame]]
	scroll.ScrollBar:SetHideIfUnscrollable(true)
	Window.scroll = scroll
	Window.scroll:SetPoint("TOPLEFT", 4, -32)
	Window.scroll:SetPoint("BOTTOMRIGHT", -30, 4)
	Window.list = CreateFrame("Frame", nil, Window.scroll)
	Window.list:SetSize(LIST_WIDTH, 1)
	Window.scroll:SetScrollChild(Window.list)
	-- The list fills the scroll frame's width, and the columns follow it.
	Window.scroll:HookScript("OnSizeChanged", function(_, width)
		Window.list:SetWidth(math.max(LIST_WIDTH, width))
		if page and page:IsShown() then
			Window.Refresh()
		end
	end)
	Window.lines = {}
	Window.empty = Text(inset, "GameFontDisableSmall", 12, -42, 560)
	Window.footer = Text(page, "GameFontHighlight", 22, -0, 400)
	Window.footer:ClearAllPoints()
	Window.footer:SetPoint("BOTTOMLEFT", 22, 16)
	local shopping = CreateFrame("Button", nil, page, "SharedButtonSmallTemplate")
	shopping:SetSize(150, 24)
	shopping:SetPoint("BOTTOMRIGHT", -14, 10)
	shopping:SetText(L["Shopping list"])
	shopping:SetScript("OnClick", function()
		Choose(TABS[2])
	end)
	Window.shoppingButton = shopping
	Window.tab = ProfessionTabs.Register("tradewind", {
		icon = ns.ICON,
		tooltip = L["Tradewind Forever"],
		page = page,
		minWidth = WINDOW_WIDTH,
		onSelect = Window.Refresh,
		safeCall = ns.core.SafeCall,
	})
	page:HookScript("OnShow", function()
		ns.Build()
		Window.Refresh()
	end)
	-- A command asked for the page while the window was closed: the player opens the window with their own control,
	-- and the page appears with it.
	ProfessionsFrame:HookScript("OnShow", function()
		if pendingPage then
			SelectPage()
		end
	end)
	local function NativePageShown()
		if pendingPage then
			pendingPage = false
			SelectPage()
		end
	end
	ProfessionsFrame.CraftingPage:HookScript("OnShow", NativePageShown)
	ProfessionsFrame.BookPage:HookScript("OnShow", NativePageShown)
	ProfessionsFrame:HookScript("OnHide", function()
		pendingPage = false
		ProfessionTabs.ShowNative()
	end)
end

-- The client refuses C_TradeSkillUI.OpenTradeSkill from addon code, so the player opens the Professions window
-- themselves and the page waits for it. One on-screen line says so, never a chat line.
local function Open()
	Attach()
	if page and ProfessionsFrame and ProfessionsFrame:IsShown() then
		pendingPage = false
		SelectPage()
		return
	end
	-- GetProfessions leaves nil gaps for empty slots (a player with only Cooking has none in the first), so any value
	-- counts.
	local learnedAny = false
	for i = 1, select("#", GetProfessions()) do
		if select(i, GetProfessions()) then
			learnedAny = true
		end
	end
	if not learnedAny then
		UIErrorsFrame:AddMessage(
			L["Tradewind opens in the Professions window. Learn a profession to use it."],
			GOLD.r,
			GOLD.g,
			GOLD.b
		)
		return
	end
	pendingPage = true
	UIErrorsFrame:AddMessage(
		L["Tradewind opens in the Professions window. Open it from your spellbook."],
		GOLD.r,
		GOLD.g,
		GOLD.b
	)
end

function Window.Toggle()
	if InCombatLockdown() then
		pendingOpen = true
		UIErrorsFrame:AddMessage(L["Tradewind opens when combat ends."], GOLD.r, GOLD.g, GOLD.b)
		return
	end
	if page and page:IsShown() and ProfessionsFrame:IsShown() then
		C_TradeSkillUI.CloseTradeSkill()
		ProfessionTabs.ShowNative()
		return
	end
	Open()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == "Blizzard_Professions" then
		Attach()
	elseif event == "PLAYER_REGEN_ENABLED" and pendingOpen then
		pendingOpen = false
		Open()
	end
end)
Attach()
return Window

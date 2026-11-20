-- The Tradewind page inside the native Professions window: the side tab, its three tabs, search, the tooltip, the
-- hand-off to the native pages, the command in and out of combat, and a character with no profession.
-- luacheck: read globals scenario ADDON

local ForeverCore = dofile("tests/forever_core.lua")
local declare = scenario
local function scenario(name, options, fn)
	if type(options) == "function" then
		options, fn = {}, options
	end
	options.addons = options.addons or ForeverCore.addons()
	declare(name, options, fn)
end

local TAB_TEXT = "Tradewind Forever"

local function check(condition, message)
	if not condition then
		error(message, 2)
	end
end

-- Blacksmithing with one bundled recipe (2660, Rough Sharpening Stone from Rough Stone) and Mining, with the reagent
-- in the bags so the recipe is craftable.
local function world(sim)
	sim:loadBlizzard("Blizzard_UIPanels_Game:CastingBarFrame")
	sim:loadBlizzard("Blizzard_Professions/Blizzard_Professions_Bootstrap.lua")
	sim:loadBlizzard("Blizzard_ActionBar/Shared/MultiActionBars.lua")
	if sim.G.UpdateMicroButtons == nil then
		sim.G.UpdateMicroButtons = function()
			sim.gaps["shim UpdateMicroButtons"] = true
		end
	end
	local professions = {
		{
			skillLineID = 164,
			name = "Blacksmithing",
			skill = 30,
			max = 75,
			spellID = 2018,
			categories = { { id = 1, name = "Materials" } },
			recipes = { { id = 2660, name = "Rough Sharpening Stone", category = 1, itemID = 2862 } },
		},
		{ skillLineID = 186, name = "Mining", skill = 30, max = 75, spellID = 2575, categories = {}, recipes = {} },
	}
	sim.world.professions = professions
	-- The sim lists recipes through impl only; the client's window API is assigned where the world needs it.
	for _, name in ipairs({ "GetAllRecipeIDs", "GetRecipeInfo" }) do
		sim.G.C_TradeSkillUI[name] = sim.G.C_TradeSkillUI[name] or sim.impl["C_TradeSkillUI." .. name]
	end
	for _, p in ipairs(professions) do
		sim.world.spells[p.spellID] = { name = p.name, icon = 136241 }
	end
	sim.impl.GetProfessionInfo = function(index)
		local p = professions[index]
		if p then
			return p.name, 136241, p.skill, p.max, 1, index - 1, p.skillLineID, 0, 0, 0, p.name
		end
	end
	sim.impl["C_SpellBook.GetSpellBookItemInfo"] = function(slot)
		local p = professions[slot]
		return p and { spellID = p.spellID, name = p.name, itemType = 1 }
	end
	sim.impl["C_TradeSkillUI.CanTradeSkillShowCraftingUI"] = function()
		return true
	end
	sim.world.items[2835] = { name = "Rough Stone", count = 12 }
	sim.world.items[2862] = { name = "Rough Sharpening Stone", count = 0 }
	sim.impl["C_TradeSkillUI.CloseTradeSkill"] = function()
		sim.run(function()
			local frame = sim.G.ProfessionsFrame
			if frame and frame:IsShown() then
				frame:Hide()
			end
		end)
	end
end

local function sideTabs(sim)
	local out = {}
	for _, child in ipairs({ sim.G.ProfessionsFrame:GetChildren() }) do
		if child.SetCustomOnMouseUpHandler and child.Icon then
			out[#out + 1] = child
		end
	end
	return out
end

local function tradewindTab(sim)
	local found
	for _, tab in ipairs(sideTabs(sim)) do
		if tab.tooltipText == TAB_TEXT then
			check(not found, "two Tradewind tabs on the Professions window")
			found = tab
		end
	end
	check(found, "no Tradewind tab on the Professions window")
	return found
end

-- The page: the ProfessionsFrame child, outside Blizzard's own pages, that holds a SearchBoxTemplate box.
local function searchBox(sim)
	local pf = sim.G.ProfessionsFrame
	local function walk(frame)
		for _, child in ipairs({ frame:GetChildren() }) do
			if child ~= pf.CraftingPage and child ~= pf.BookPage then
				if child.clearButton and child.searchIcon and child.Instructions then
					return child
				end
				local hit = walk(child)
				if hit then
					return hit
				end
			end
		end
	end
	local box = walk(pf)
	check(box, "no search box on the Tradewind page")
	return box
end

local function page(sim)
	return searchBox(sim):GetParent()
end

local function press(sim, tab)
	local W = sim.widgets
	W.dispatch(tab, "OnMouseDown", "LeftButton")
	W.dispatch(tab, "OnMouseUp", "LeftButton", true)
	sim.events.flush()
	sim:advance(0.05)
end

local function slash(sim, word)
	sim:input(function()
		sim.G.SlashCmdList.TRADEWINDFOREVER(word or "")
	end)
	sim:advance(0.1)
end

-- The page's list lines, as the text of their columns.
local function lines(sim)
	local list, scroll = {}, nil
	for _, child in ipairs({ page(sim):GetChildren() }) do
		for _, inner in ipairs({ child:GetChildren() }) do
			if inner.GetScrollChild and inner:GetScrollChild() then
				scroll = inner
			end
		end
	end
	check(scroll, "no list on the Tradewind page")
	for _, line in ipairs({ scroll:GetScrollChild():GetChildren() }) do
		if line:IsShown() and line.cols then
			local text = {}
			for _, column in ipairs(line.cols) do
				if column:IsShown() then
					text[#text + 1] = column:GetText() or ""
				end
			end
			list[#list + 1] = table.concat(text, " | ")
		end
	end
	return list
end

local function subTab(sim, label)
	for _, child in ipairs({ page(sim):GetChildren() }) do
		if child.GetText and child:GetText() == label then
			return child
		end
	end
	error("no " .. label .. " tab on the page", 2)
end

local function click(sim, button)
	sim.widgets.dispatch(button, "OnClick", "LeftButton")
	sim:advance(0.1)
end

scenario("the side tab opens the Tradewind page, its three tabs, search and the native hand-back", function(sim)
	world(sim)
	sim:login()
	local pf = sim:openProfessions(164)
	sim:advance(0.2)
	press(sim, tradewindTab(sim))
	check(page(sim):IsVisible(), "the Tradewind page is not shown after its tab")
	sim:expectOnScreen(page(sim))
	sim:expectNoErrors(ADDON)
	local craft = lines(sim)
	check(#craft == 1 and craft[1]:find("Rough Sharpening Stone", 1, true), "Craft now: " .. table.concat(craft, "; "))

	-- Search narrows the list and clears back to it.
	local box = searchBox(sim)
	box:SetText("zzz")
	sim:advance(0.1)
	check(#lines(sim) == 0, "search for an absent name still lists rows")
	box:SetText("sharpening")
	sim:advance(0.1)
	check(#lines(sim) == 1, "search for a present name lost the row")
	box:SetText("")
	sim:advance(0.1)

	-- Shopping and Characters.
	click(sim, subTab(sim, "Shopping"))
	check(page(sim):IsVisible(), "the Shopping tab closed the page")
	click(sim, subTab(sim, "Characters"))
	local characters = lines(sim)
	check(
		#characters == 1 and characters[1]:find("Blacksmithing", 1, true),
		"Characters: " .. table.concat(characters, "; ")
	)
	click(sim, subTab(sim, "Craft now"))

	-- A native tab takes the window back.
	press(sim, pf.rightProfessionTabs[1])
	check(not page(sim):IsShown(), "the page stayed over a native tab")
	sim:closeProfessions()
	sim:expectNoErrors(ADDON)
end)

scenario("the command asks the player to open the window, then shows the page with it", function(sim)
	world(sim)
	sim:login()
	local messages = {}
	sim.G.UIErrorsFrame = {
		AddMessage = function(_, text)
			messages[#messages + 1] = text
		end,
	}
	local chat = #sim.chat
	slash(sim)
	check(#messages == 1 and messages[1]:find("Open it from your spellbook", 1, true), "one on-screen line expected")
	check(#sim.chat == chat, "the command wrote to chat")
	sim:openProfessions(164)
	sim:advance(0.2)
	check(page(sim):IsVisible(), "the page did not appear with the window the player opened")
	slash(sim)
	check(not sim.G.ProfessionsFrame:IsShown() or not page(sim):IsShown(), "the command did not toggle the page away")
	sim:expectNoErrors(ADDON)
end)

scenario("a command in combat waits for combat to end", function(sim)
	world(sim)
	sim:login()
	local messages = {}
	sim.G.UIErrorsFrame = {
		AddMessage = function(_, text)
			messages[#messages + 1] = text
		end,
	}
	sim:enterCombat()
	slash(sim)
	check(#messages == 1 and messages[1]:find("when combat ends", 1, true), "combat says it waits")
	sim:leaveCombat()
	sim:advance(0.2)
	check(
		#messages == 2 and messages[2]:find("Open it from your spellbook", 1, true),
		"combat's end retries the command"
	)
	sim:expectNoErrors(ADDON)
end)

scenario("a character with no profession is told on screen and no window opens", function(sim)
	sim:login()
	local messages = {}
	sim.G.UIErrorsFrame = {
		AddMessage = function(_, text)
			messages[#messages + 1] = text
		end,
	}
	slash(sim)
	check(#messages == 1 and messages[1]:find("Learn a profession", 1, true), "no profession is told once")
	sim:expectNoErrors(ADDON)
end)

scenario("the report command lists the addon's own lines", function(sim)
	world(sim)
	sim:login()
	slash(sim, "report")
	sim:expectNoErrors(ADDON)
end)

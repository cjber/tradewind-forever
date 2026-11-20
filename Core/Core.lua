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

-- The addon's one entry point, shared by the slash command and the addon compartment. A placeholder until the
-- Professions page lands.
function ns.Open() end

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
	ns.core.Attach(TradewindForeverDB)
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function()
	ns.Start()
end)

_G.TradewindForever_OnAddonCompartmentClick = function()
	ns.Open()
end

return addonName

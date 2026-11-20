---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Format = ns.Format

-- The Characters tab: what each recorded character has told the addon, and how old it is.
---@class TWCharactersTab: TWTab
local CharactersTab = {}
ns.CharactersTab = CharactersTab

CharactersTab.columns = {
	{ L["Character"], 8, 130, "LEFT" },
	{ L["Professions"], 142, 220, "LEFT" },
	{ L["Recipes"], 366, 80, "LEFT" },
	{ L["Bags"], 450, 62, "LEFT" },
	{ L["Bank"], 516, 62, "LEFT" },
}
CharactersTab.empty = L["No character recorded yet"]
CharactersTab.icons = false

---@param _ TWResult
---@param query string folded (ForeverCore.Text.Fold)
---@return TWAPICharacter[]
function CharactersTab.Entries(_, query)
	local shown = {}
	for _, summary in ipairs(ns.CharacterList()) do
		if ForeverCore.Text.Rank(ForeverCore.Text.Fold(summary.name), query) then
			shown[#shown + 1] = summary
		end
	end
	return shown
end

---@param line TWLine
---@param summary TWAPICharacter
function CharactersTab.Fill(line, summary)
	line.itemID = nil
	line.icon:Hide()
	local professions = {}
	for _, profession in ipairs(summary.professions) do
		local name = profession.name or ns.Professions.Name(profession.skillLineId)
		professions[#professions + 1] = ("%s %d"):format(name, profession.rank)
	end
	local values = {
		summary.name,
		#professions > 0 and table.concat(professions, ", ") or "-",
		summary.scanned and tostring(summary.recipes) or L["not scanned"],
		Format.Age(summary.bagsAge),
		Format.Age(summary.bankAge),
	}
	for index, text in ipairs(values) do
		line.cols[index]:SetText(text)
	end
	line.entry = summary
end

---@param line TWLine
function CharactersTab.Tooltip(line)
	local summary = line.entry
	---@cast summary TWAPICharacter
	GameTooltip:SetOwner(line, "ANCHOR_RIGHT")
	GameTooltip:AddLine(summary.name, 1, 1, 1)
	GameTooltip:AddLine(summary.realm, 0.7, 0.7, 0.7)
	if not summary.scanned then
		GameTooltip:AddLine(L["Open this character's professions to record its recipes."], 1, 0.82, 0, true)
	end
	GameTooltip:Show()
end

---@return string
function CharactersTab.Footer()
	return L["Holdings age is how long ago the bags or bank were last seen."]
end

return CharactersTab

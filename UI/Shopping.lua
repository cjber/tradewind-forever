---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Format = ns.Format

-- The Shopping tab: the reagents to buy to make the best rows again, summed per reagent.
---@class TWShoppingTab: TWTab
local ShoppingTab = {}
ns.ShoppingTab = ShoppingTab

ShoppingTab.columns = {
	{ L["Reagent"], 36, 230, "LEFT" },
	{ L["To buy"], 270, 60, "RIGHT" },
	{ L["Each"], 336, 100, "RIGHT" },
	{ L["Cost"], 442, 100, "RIGHT" },
	{ L["From"], 546, 38, "LEFT" },
}
ShoppingTab.empty = L["Nothing to buy for the best rows"]
ShoppingTab.icons = true

---@param result TWResult
---@param query string folded (ForeverCore.Text.Fold)
---@return TWShoppingLine[]
function ShoppingTab.Entries(result, query)
	local list = ns.Model.Shopping(result.rows, ns.Prices.Item)
	ShoppingTab.last = list
	local shown = {}
	for _, line in ipairs(list.lines) do
		if ForeverCore.Text.Rank(ForeverCore.Text.Fold(Format.ItemName(line.itemID)), query) then
			shown[#shown + 1] = line
		end
	end
	return shown
end

---@param line Button
---@param entry TWShoppingLine
function ShoppingTab.Fill(line, entry)
	line.itemID = entry.itemID
	line.icon:Show()
	ns.RowArt.ItemIcon(line, entry.itemID)
	local from = entry.source == "merchant" and L["Shop"] or entry.source == "auction" and L["AH"] or "?"
	local values = {
		Format.ItemName(entry.itemID),
		tostring(entry.qty),
		entry.unit and Format.Money(entry.unit) or "?",
		entry.cost and Format.Money(entry.cost) or "?",
		from,
	}
	for index, text in ipairs(values) do
		line.cols[index]:SetText(text)
	end
	line.entry = entry
end

---@param line Button
function ShoppingTab.Tooltip(line)
	ns.Tooltip.Shopping(line, line.entry)
end

---@return string
function ShoppingTab.Footer()
	local list = ShoppingTab.last
	if not list then
		return ""
	end
	local text = L["Total to buy"] .. ": " .. Format.Money(list.total)
	if list.unknown > 0 then
		text = text .. "  " .. L["%d unknown"]:format(list.unknown)
	end
	if list.stale > 0 then
		text = text .. "  " .. L["%d old prices"]:format(list.stale)
	end
	return text
end

return ShoppingTab

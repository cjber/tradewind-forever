---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Format = ns.Format

-- The Craft now tab: every row a character can make from what it holds, best profit first.
---@class TWTab
local CraftNow = {}
ns.CraftNow = CraftNow

CraftNow.columns = {
	{ L["Craft"], 36, 190, "LEFT" },
	{ L["Character"], 232, 100, "LEFT" },
	{ L["Make"], 336, 44, "RIGHT" },
	{ L["Cost"], 388, 78, "RIGHT" },
	{ L["Profit"], 470, 58, "RIGHT" },
	{ L["Sold/day"], 532, 52, "RIGHT" },
}
CraftNow.empty = L["Nothing to craft from what your characters hold"]
CraftNow.icons = true

---@param result TWResult
---@param query string folded (ForeverCore.Text.Fold)
---@return TWRow[]
function CraftNow.Entries(result, query)
	local shown = {}
	for _, row in ipairs(result.rows) do
		if row.holdingsUnknown or (row.craftable or 0) > 0 then
			local fold = ForeverCore.Text.Fold
			if
				ForeverCore.Text.Rank(fold(Format.ItemName(row.itemID)), query)
				or ForeverCore.Text.Rank(fold(row.character), query)
			then
				shown[#shown + 1] = row
			end
		end
	end
	return shown
end

---@param line TWLine
---@param row TWRow
function CraftNow.Fill(line, row)
	line.itemID = row.itemID
	line.icon:Show()
	ns.RowArt.ItemIcon(line, row.itemID)
	local sold = row.soldPerDay and tostring(math.floor(row.soldPerDay + 0.5)) or "-"
	local values = {
		Format.ItemName(row.itemID),
		row.character,
		row.craftable and (row.craftable .. (row.bagsOnly and "+" or "")) or "?",
		row.matsWorth and Format.Money(row.matsWorth) or "?",
		Format.Profit(row.profit),
		sold,
	}
	for index, text in ipairs(values) do
		line.cols[index]:SetText(text)
	end
	line.entry = row
end

---@param line TWLine
function CraftNow.Tooltip(line)
	local row = line.entry
	---@cast row TWRow
	ns.Tooltip.Craft(line, row)
end

-- The footer: what making every profitable row is worth, and how many rows could not be priced.
---@param result TWResult
---@return string
function CraftNow.Footer(result)
	local text = L["Craft every profitable row"] .. ": " .. Format.Profit(result.total)
	if result.unknown > 0 then
		text = text .. "  " .. L["%d unknown"]:format(result.unknown)
	end
	return text
end

return CraftNow

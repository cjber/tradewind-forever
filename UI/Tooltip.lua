---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L
local Format = ns.Format

---@class TWTooltip
local Tooltip = {}
ns.Tooltip = Tooltip

local GOLD = { 1, 0.82, 0 }
local GREEN = { 0.13, 1, 0.13 }
local GREY = { 0.7, 0.7, 0.7 }

---@param reagent TWRowReagent
---@return string
local function Holding(reagent)
	if reagent.held == nil then
		return L["holding unknown"]
	end
	return L["%d held"]:format(reagent.held)
end

-- One craft row's breakdown: each reagent with what the character holds and what it is worth, what the mats are worth
-- together, where the crafted item sells best, and the profit per craft. Everything is this addon's own data; a value
-- it does not have reads "?".
---@param owner Frame
---@param row TWRow
function Tooltip.Craft(owner, row)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Format.ItemName(row.itemID), 1, 1, 1)
	GameTooltip:AddLine(
		L["%s, %s %d"]:format(row.character, ns.Professions.Name(row.profession), Tooltip.Skill(row)),
		GREY[1],
		GREY[2],
		GREY[3]
	)
	GameTooltip:AddLine(" ")
	for _, reagent in ipairs(row.reagents) do
		local value = reagent.unit and Format.Money(reagent.unit * reagent.qty) or "?"
		GameTooltip:AddDoubleLine(
			("%d %s (%s)"):format(reagent.qty, Format.ItemName(reagent.itemID), Holding(reagent)),
			value,
			1,
			1,
			1,
			1,
			1,
			1
		)
	end
	if row.bagsOnly then
		GameTooltip:AddLine(
			L["Counted from bags only. Open your bank once to count it too."],
			GREY[1],
			GREY[2],
			GREY[3],
			true
		)
	end
	GameTooltip:AddDoubleLine(
		L["Mats worth"],
		row.matsWorth and Format.Money(row.matsWorth) or "?",
		GOLD[1],
		GOLD[2],
		GOLD[3],
		1,
		1,
		1
	)
	GameTooltip:AddLine(" ")
	local view = ns.Prices.Item(row.itemID)
	local qty = row.outputQty
	if view.auction then
		GameTooltip:AddDoubleLine(
			L["Auction, after the 5% cut"],
			Format.Money(view.auction * qty * (1 - ns.Model.AUCTION_CUT)),
			1,
			1,
			1,
			1,
			1,
			1
		)
	end
	if view.sellBack then
		GameTooltip:AddDoubleLine(L["Vendor"], Format.Money(view.sellBack * qty), 1, 1, 1, 1, 1, 1)
	end
	if not view.auction and not view.sellBack then
		GameTooltip:AddLine(L["No price known for this item"], GREY[1], GREY[2], GREY[3])
	end
	GameTooltip:AddDoubleLine(L["Profit per craft"], Format.Profit(row.profit), GREEN[1], GREEN[2], GREEN[3], 1, 1, 1)
	if row.soldPerDay then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Sold %d a day"]:format(math.floor(row.soldPerDay + 0.5)), GREY[1], GREY[2], GREY[3])
	end
	GameTooltip:Show()
end

-- The character's recorded rank in the recipe's profession, 0 when none.
---@param row TWRow
---@return integer
function Tooltip.Skill(row)
	local key = row.characterKey
	local record = ns.Store.Get().characters[key]
	local info = record and record.professions[row.profession]
	return info and info.rank or 0
end

-- A shopping line: what to buy, how many, and the price it was read at.
---@param owner Frame
---@param line TWShoppingLine
function Tooltip.Shopping(owner, line)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Format.ItemName(line.itemID), 1, 1, 1)
	GameTooltip:AddDoubleLine(L["To buy"], tostring(line.qty), 1, 1, 1, 1, 1, 1)
	if line.unit then
		local where = line.source == "merchant" and L["Merchant"] or L["Auction"]
		GameTooltip:AddDoubleLine(where, Format.Money(line.unit) .. " " .. L["each"], 1, 1, 1, 1, 1, 1)
	else
		GameTooltip:AddLine(L["No buying price known"], GREY[1], GREY[2], GREY[3])
	end
	if line.stale then
		GameTooltip:AddLine(L["The auction price is a week old or more."], GREY[1], GREY[2], GREY[3])
	end
	GameTooltip:Show()
end

return Tooltip

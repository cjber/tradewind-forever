---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWMerchant
local Merchant = {}
ns.Merchant = Merchant

-- Acquisition prices are recorded only where the player sees them: at an open merchant window. Each price is per unit,
-- plain money only (an offer with an extended cost, a stack that does not divide the price, or an unreadable field
-- is skipped), keyed by the merchant's NPC ID because the same item costs different amounts at different vendors.
-- A price never seen is unknown: no catalogue of vendor prices is bundled.

---@param value any
---@param minimum integer
---@return boolean
local function Whole(value, minimum)
	return type(value) == "number" and value == value and value < math.huge and value >= minimum and value % 1 == 0
end

-- The NPC ID in a creature or vehicle GUID, nil for anything else.
---@param guid any
---@return integer?
function Merchant.NpcID(guid)
	if type(guid) ~= "string" then
		return nil
	end
	local id = guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)") or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	return id and tonumber(id) or nil
end

-- One offer's per-unit price, or nil when it is not plain money for a whole stack.
---@param index integer
---@return integer? itemID
---@return number? unit
local function Offer(index)
	local okId, itemID = pcall(GetMerchantItemID, index)
	itemID = okId and ns.Readable(itemID) or nil
	if not Whole(itemID, 1) then
		return nil
	end
	local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local price, stack = ns.Readable(info.price), ns.Readable(info.stackCount)
	if not (Whole(price, 0) and Whole(stack, 1) and price % stack == 0) then
		return nil
	end
	if info.hasExtendedCost ~= false or info.isPurchasable == false then
		return nil
	end
	local okCost, costs = pcall(GetMerchantItemCostInfo, index)
	if not okCost or ns.Readable(costs) ~= 0 then
		return nil
	end
	return itemID, price / stack
end

-- The last window's signature per merchant, so a MERCHANT_UPDATE that changed nothing costs one string compare.
local lastSignature ---@type string?

-- Records the open merchant's reagent prices. Returns how many it wrote.
---@return integer
function Merchant.Record()
	if not ns.Store.Writable() then
		return 0
	end
	local okGuid, guid = pcall(UnitGUID, "npc")
	local npcID = okGuid and Merchant.NpcID(ns.Readable(guid)) or nil
	if not npcID then
		return 0
	end
	local okCount, total = pcall(GetMerchantNumItems)
	total = okCount and ns.Readable(total) or nil
	if not Whole(total, 0) then
		return 0
	end
	local wanted = ns.Recipes.ReagentSet()
	local offers, parts = {}, { tostring(npcID) }
	for index = 1, total do
		local itemID, unit = Offer(index)
		if itemID and unit and wanted[itemID] then
			offers[#offers + 1] = { itemID, unit }
			parts[#parts + 1] = itemID .. ":" .. unit
		end
	end
	local signature = table.concat(parts, ",")
	if signature == lastSignature then
		return 0
	end
	lastSignature = signature
	local key = "npc:" .. npcID
	local vendorBuy = ns.Store.Get().vendorBuy
	local written = 0
	for _, offer in ipairs(offers) do
		local byMerchant = vendorBuy[offer[1]]
		if not byMerchant then
			byMerchant = {}
			vendorBuy[offer[1]] = byMerchant
		end
		if byMerchant[key] ~= offer[2] then
			byMerchant[key] = offer[2]
			written = written + 1
		end
	end
	return written
end

-- Forgets the window signature when the merchant closes, so reopening the same vendor re-reads it.
function Merchant.Closed()
	lastSignature = nil
end

-- The cheapest recorded merchant price for an item and the merchant that charged it.
---@param itemID integer
---@return number? copper
---@return string? merchantKey
function Merchant.Best(itemID)
	local byMerchant = ns.Store.Get().vendorBuy[itemID]
	local best, bestKey
	if type(byMerchant) == "table" then
		for key, price in pairs(byMerchant) do
			if
				type(price) == "number"
				and price >= 0
				and (not best or price < best or (price == best and key < bestKey))
			then
				best, bestKey = price, key
			end
		end
	end
	return best, bestKey
end

return Merchant

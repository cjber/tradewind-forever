---@type string, TWNamespace
local addonName, ns = ...

if ns.broken then
	return
end

---@class TWPrices
local Prices = {}
ns.Prices = Prices

-- Where a price comes from, in order: Auctionator's public API, TradeSkillMaster's, then the vendor's own buy-back for
-- an item no auction price covers. No scanner, no other addon's saved variables. Every read goes through pcall with the
-- global looked up at call time, so a missing, half-loaded or erroring addon answers nil, never 0.

-- AuctionDB's snapshot: the latest scan's recent value, else its lowest buyout. Both are listing prices, so the auction
-- cut applies to them. DBMarket is a 14-day market value and DBRegionSaleAvg is already net of the cut, so neither
-- is a listing price and neither is read.
local TSM_PRICE = "first(DBRecent, DBMinBuyout)"
local TSM_VOLUME = "DBRegionSoldPerDay"

---@param value any
---@return boolean
local function Positive(value)
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local function AuctionatorAPI()
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	return api and api.GetAuctionPriceByItemID and api or nil
end

local function TSMReady()
	return TSM_API ~= nil and type(TSM_API.GetCustomPriceValue) == "function"
end

---@return {auctionator: boolean, tsm: boolean}
function Prices.Sources()
	return { auctionator = AuctionatorAPI() ~= nil, tsm = TSMReady() }
end

-- Auctionator's latest recorded buyout and the age of that observation in days (nil when it has none). An old price
-- stays a price: the model flags one a week old or more as stale instead of dropping it.
---@param itemID integer
---@return {copper: number, source: "auctionator", days: number?}?
local function Auctionator_(itemID)
	local api = AuctionatorAPI()
	if not api then
		return nil
	end
	local ok, copper = pcall(api.GetAuctionPriceByItemID, addonName, itemID)
	if not (ok and Positive(copper)) then
		return nil
	end
	local days
	if api.GetAuctionAgeByItemID then
		local okAge, age = pcall(api.GetAuctionAgeByItemID, addonName, itemID)
		if okAge and type(age) == "number" and age == age and age >= 0 then
			days = age
		end
	end
	return { copper = copper, source = "auctionator", days = days }
end

---@param itemID integer
---@return {copper: number, source: "tsm"}?
local function TSM(itemID)
	if not TSMReady() then
		return nil
	end
	local ok, copper = pcall(TSM_API.GetCustomPriceValue, TSM_PRICE, "i:" .. itemID)
	if not (ok and Positive(copper)) then
		return nil
	end
	return { copper = copper, source = "tsm" }
end

---@param itemID integer
---@return number?
local function SoldPerDay(itemID)
	if not TSMReady() then
		return nil
	end
	local ok, value = pcall(TSM_API.GetCustomPriceValue, TSM_VOLUME, "i:" .. itemID)
	if ok and type(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	return nil
end

-- Items whose data was asked for and has not arrived: the value used meanwhile is the bundled one or none.
---@type table<integer, boolean>
local awaiting = {}
---@type table<integer, boolean>
local requested = {}

-- True once, when `itemID`'s data arrives after a price was made without it: the caller reprices.
---@param itemID integer
---@return boolean
function Prices.Arrived(itemID)
	if awaiting[itemID] then
		awaiting[itemID] = nil
		return true
	end
	return false
end

-- The vendor's buy-back price. The client's live value wins, a real 0 included; the bundled one covers an item whose
-- data has not arrived, and its arrival refreshes the list.
---@param itemID integer
---@return number?
function Prices.SellBack(itemID)
	local live = ns.Readable((select(11, C_Item.GetItemInfo(itemID))))
	if type(live) == "number" then
		return live
	end
	if not requested[itemID] then
		requested[itemID], awaiting[itemID] = true, true
		C_Item.RequestLoadItemDataByID(itemID)
	end
	local bundled = ns.ItemSellPrices and ns.ItemSellPrices[itemID]
	return type(bundled) == "number" and bundled or nil
end

-- One item's prices for the model. A pass reads each item once.
---@type table<integer, TWItemView>
local memo = {}

-- Drops the pass's memo; the next read asks the price addons again.
function Prices.Reset()
	memo = {}
end

---@param itemID integer
---@return TWItemView
function Prices.Item(itemID)
	local view = memo[itemID]
	if view then
		return view
	end
	local auction = Auctionator_(itemID) or TSM(itemID)
	view = {
		auction = auction and auction.copper,
		source = auction and auction.source,
		days = auction and auction.days,
		sellBack = Prices.SellBack(itemID),
		soldPerDay = SoldPerDay(itemID),
	}
	-- Buying is a different price from selling: the auction price as listed, or the cheapest merchant price seen.
	local merchant, key = ns.Merchant.Best(itemID)
	if merchant and (not view.auction or merchant < view.auction) then
		view.buy, view.buySource, view.merchant = merchant, "merchant", key
	elseif view.auction then
		view.buy, view.buySource = view.auction, "auction"
	end
	memo[itemID] = view
	return view
end

-- The price header's source line: which addon the prices come from, or none.
---@return "auctionator"|"tsm"|nil
function Prices.PrimarySource()
	local sources = Prices.Sources()
	return (sources.auctionator and "auctionator") or (sources.tsm and "tsm") or nil
end

-- Calls `callback` when Auctionator files new prices, so an open list is repriced. TSM has no such signal; its data
-- changes when the player's app syncs, at a reload.
---@param callback fun()
function Prices.Listen(callback)
	local api = AuctionatorAPI()
	if api and api.RegisterForDBUpdate then
		pcall(api.RegisterForDBUpdate, addonName, callback)
	end
end

return Prices

-- Run from the repository root: luajit tests/prices_spec.lua
-- Price sources in order, and every way one can be absent or wrong answering nil rather than 0.
local H = dofile("tests/helpers.lua")
local check = H.check
local ns = H.namespace()
ns.ItemSellPrices = { [1] = 5 }
local info, requested = {}, {}
rawset(_G, "C_Item", {
	GetItemInfo = function(id)
		local sell = info[id]
		return "n", nil, nil, nil, nil, nil, nil, nil, nil, nil, sell
	end,
	RequestLoadItemDataByID = function(id)
		requested[#requested + 1] = id
	end,
})
H.load(ns, "Core/Store.lua")
ns.Store.Init({})
ns.Merchant = { Best = function() end }
H.load(ns, "Integrations/Prices.lua")
local Prices = ns.Prices

local function reset()
	Prices.Reset()
	rawset(_G, "Auctionator", nil)
	rawset(_G, "TSM_API", nil)
end

-- No price addon: only the vendor, and the source line says none.
reset()
check(Prices.Item(1).auction == nil and Prices.Item(1).sellBack == 5, "no addon: bundled sell-back, no auction")
check(Prices.PrimarySource() == nil, "no source")

-- Auctionator first, with the age of the observation in days.
reset()
rawset(_G, "Auctionator", {
	API = {
		v1 = {
			GetAuctionPriceByItemID = function(_, id)
				return id == 2 and 1000 or nil
			end,
			GetAuctionAgeByItemID = function()
				return 3
			end,
		},
	},
})
rawset(_G, "TSM_API", {
	GetCustomPriceValue = function()
		return 50
	end,
})
local view = Prices.Item(2)
check(view.auction == 1000 and view.source == "auctionator" and view.days == 3, "Auctionator wins over TSM")
check(Prices.PrimarySource() == "auctionator", "primary source")
check(Prices.Item(3).source == "tsm" and Prices.Item(3).auction == 50, "TSM fills what Auctionator lacks")

-- Absent, erroring, zero, stale and malformed answers are all unknown, never zero.
reset()
rawset(_G, "Auctionator", { API = { v1 = {
	GetAuctionPriceByItemID = function()
		error("boom")
	end,
} } })
check(Prices.Item(4).auction == nil, "an erroring addon answers nil")
reset()
rawset(_G, "Auctionator", { API = { v1 = {
	GetAuctionPriceByItemID = function()
		return 0
	end,
} } })
check(Prices.Item(4).auction == nil, "a zero price is no price")
reset()
rawset(_G, "Auctionator", { API = { v1 = {
	GetAuctionPriceByItemID = function()
		return "x"
	end,
} } })
check(Prices.Item(4).auction == nil, "a non-number is no price")
reset()
rawset(_G, "Auctionator", {
	API = {
		v1 = {
			GetAuctionPriceByItemID = function()
				return 100
			end,
			GetAuctionAgeByItemID = function()
				return 40
			end,
		},
	},
})
check(
	Prices.Item(4).auction == 100 and Prices.Item(4).days == 40,
	"an old price is kept with its age, for the stale flag"
)

-- TSM: the expression reads the recent value or lowest buyout; DBMarket and DBRegionSaleAvg are never asked.
reset()
local asked = {}
rawset(_G, "TSM_API", {
	GetCustomPriceValue = function(expression, item)
		asked[#asked + 1] = expression .. "|" .. item
		return expression:find("DBRegionSoldPerDay") and 7.5 or 200
	end,
})
view = Prices.Item(9)
check(view.auction == 200 and view.soldPerDay == 7.5, "TSM price and volume")
for _, text in ipairs(asked) do
	check(not text:find("DBMarket") and not text:find("DBRegionSaleAvg"), "no market or net-of-cut price is read")
	check(text:find("i:9", 1, true), "the item string")
end
reset()
rawset(_G, "TSM_API", {
	GetCustomPriceValue = function()
		error("no data")
	end,
})
check(Prices.Item(9).auction == nil and Prices.Item(9).soldPerDay == nil, "a TSM error is unknown")

-- Sell-back: the live value wins, including a real 0; unknown data is requested once and the bundled value covers it.
reset()
info[7] = 0
check(Prices.SellBack(7) == 0, "a live zero is a price")
ns.ItemSellPrices[8] = 6
local before = #requested
check(
	Prices.SellBack(8) == 6 and #requested == before + 1 and requested[#requested] == 8,
	"bundled value, data requested"
)
Prices.SellBack(8)
check(#requested == before + 1, "data is requested once")
check(Prices.Arrived(8) and not Prices.Arrived(8), "arrival is reported once")
check(Prices.SellBack(99) == nil, "no live and no bundled value is unknown")

-- Merchant prices are acquisition prices, separate from the sale value.
reset()
ns.Merchant.Best = function(id)
	return id == 2 and 300 or nil, "npc:1"
end
rawset(_G, "Auctionator", { API = { v1 = {
	GetAuctionPriceByItemID = function()
		return 1000
	end,
} } })
view = Prices.Item(2)
check(view.buy == 300 and view.buySource == "merchant", "the cheaper merchant price is the buying price")

print("prices_spec ok")

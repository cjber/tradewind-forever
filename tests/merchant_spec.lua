-- Run from the repository root: luajit tests/merchant_spec.lua
-- Merchant prices: plain money per unit only, recorded per merchant, a window that did not change costs nothing.
local H = dofile("tests/helpers.lua")
local check = H.check
local ns = H.namespace()
ns.RecipeData = {
	[1] = {
		skillLine = 171,
		reagents = { { itemID = 10, qty = 1 }, { itemID = 11, qty = 1 }, { itemID = 12, qty = 1 } },
		output = { itemID = 20, qty = 1 },
	},
}
H.load(ns, "Core/Store.lua", "Core/Recipes.lua")
ns.Store.Init({})

local npc = "Creature-0-1-2-3-555-0000ABCD"
local offers = {}
rawset(_G, "UnitGUID", function()
	return npc
end)
rawset(_G, "GetMerchantNumItems", function()
	return #offers
end)
rawset(_G, "GetMerchantItemID", function(i)
	return offers[i].id
end)
rawset(_G, "GetMerchantItemCostInfo", function(i)
	return offers[i].costs or 0
end)
rawset(_G, "C_MerchantFrame", {
	GetItemInfo = function(i)
		local o = offers[i]
		return {
			price = o.price,
			stackCount = o.stack or 1,
			hasExtendedCost = o.extended or false,
			isPurchasable = true,
		}
	end,
})
H.load(ns, "Integrations/Merchant.lua")
local Merchant = ns.Merchant

check(
	Merchant.NpcID(npc) == 555 and Merchant.NpcID("Player-1-2") == nil and Merchant.NpcID(nil) == nil,
	"NPC id from a GUID"
)

offers = {
	{ id = 10, price = 300, stack = 5 }, -- per unit 60
	{ id = 11, price = 100, extended = true }, -- extended cost: skipped
	{ id = 12, price = 7, stack = 2 }, -- does not divide: skipped
	{ id = 99, price = 1 }, -- not a reagent of any recipe: skipped
}
check(Merchant.Record() == 1, "one plain offer recorded")
local buy = ns.Store.Get().vendorBuy
check(
	buy[10]["npc:555"] == 60 and buy[11] == nil and buy[12] == nil and buy[99] == nil,
	"per-unit price, others skipped"
)
check(Merchant.Record() == 0, "an unchanged window records nothing")

-- The same item at another merchant is its own price; the cheapest is reported with its merchant.
npc = "Creature-0-1-2-3-777-0000ABCD"
offers = { { id = 10, price = 40 } }
check(Merchant.Record() == 1 and buy[10]["npc:777"] == 40 and buy[10]["npc:555"] == 60, "per-merchant prices")
local price, key = Merchant.Best(10)
check(price == 40 and key == "npc:777", "cheapest merchant")
check(Merchant.Best(11) == nil, "never seen is unknown")

-- A price change at the same merchant is recorded; closing the window forgets the signature.
offers = { { id = 10, price = 45 } }
check(Merchant.Record() == 1 and buy[10]["npc:777"] == 45, "a changed price is recorded")
Merchant.Closed()
check(Merchant.Record() == 0, "reopened with the same price changes nothing")

-- Secret or malformed reads record nothing.
ns.Readable = function()
	return nil
end
offers = { { id = 10, price = 1 } }
Merchant.Closed()
npc = "Creature-0-1-2-3-888-0000ABCD"
check(Merchant.Record() == 0 and buy[10]["npc:888"] == nil, "a secret read is skipped")

print("merchant_spec ok")

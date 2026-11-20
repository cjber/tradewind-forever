local _, ns = ...

---@type table<string, string | boolean>
ns.L = {
	["Tradewind Forever"] = true,

	-- The shared report window's title; ForeverCore owns its other phrases.
	["Tradewind Forever report"] = true,

	-- The shared out-of-date warning (Core/ForeverRequire.lua).
	["%s needs ForeverCore. Install it from CurseForge, or choose Reinstall on ForeverCore in the CurseForge app."] = true,
	["%s: ForeverCore is turned off. Enable it in the AddOns list to fix this."] = true,
	["%s: the installed ForeverCore is another addon (%s). Remove it and install ForeverCore from CurseForge."] = true,
	["%s: %s is out of date. Update it to fix this."] = true,
	["%s: %s are out of date. Update them to fix this."] = true,
	["%s could not start. Reinstall %s to fix this."] = true,

	-- Tradewind's own phrases.
	["%d characters counted"] = true,
	["%d d"] = true,
	["%d h"] = true,
	["%d held"] = true,
	["%d min"] = true,
	["%d old prices"] = true,
	["%d unknown"] = true,
	["%s, %s %d"] = true,
	["AH"] = true,
	["Auction"] = true,
	["Auction, after the 5% cut"] = true,
	["Auctionator"] = true,
	["Auctionator, %d days old"] = true,
	["Auctionator, 1 day old"] = true,
	["Bags"] = true,
	["Bank"] = true,
	["Character"] = true,
	["Characters"] = true,
	["Cost"] = true,
	["Counting what your characters can make"] = true,
	["Craft"] = true,
	["Craft every profitable row"] = true,
	["Craft now"] = true,
	["Each"] = true,
	["From"] = true,
	["Holdings age is how long ago the bags or bank were last seen."] = true,
	["Item %d"] = true,
	["Make"] = true,
	["Mats worth"] = true,
	["Merchant"] = true,
	["No buying price known"] = true,
	["No character recorded yet"] = true,
	["No price known for this item"] = true,
	["Nothing to buy for the best rows"] = true,
	["Nothing to craft from what your characters hold"] = true,
	["Open this character's professions to record its recipes."] = true,
	["Professions"] = true,
	["Profit"] = true,
	["Profit per craft"] = true,
	["Reagent"] = true,
	["Recipes"] = true,
	["Shop"] = true,
	["Shopping"] = true,
	["Shopping list"] = true,
	["Sold %d a day"] = true,
	["Sold/day"] = true,
	["The auction price is a week old or more."] = true,
	["To buy"] = true,
	["Total to buy"] = true,
	["TradeSkillMaster"] = true,
	["Tradewind opens in the Professions window. Learn a profession to use it."] = true,
	["Tradewind opens in the Professions window. Open it from your spellbook."] = true,
	["Tradewind opens when combat ends."] = true,
	["Vendor"] = true,
	["each"] = true,
	["holding unknown"] = true,
	["never"] = true,
	["no price addon, vendor prices only"] = true,
	["not scanned"] = true,
}

-- `true` marks a phrase that reads as its own English key.
for key, value in pairs(ns.L) do
	if value == true then
		ns.L[key] = key
	end
end

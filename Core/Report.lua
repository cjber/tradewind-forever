---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

-- Tradewind Forever's own lines in /tradewind report, so a bug report says what state the addon was in. English
-- throughout, like the other shared report lines.

ns.ReportTitle = ns.L["Tradewind Forever report"]

---@return string[]
function ns.ReportLines()
	if not ns.Started then
		return { "Not started" }
	end
	local store = ns.Store.Get()
	local scanned, characters = 0, 0
	for _, record in pairs(store.characters) do
		characters = characters + 1
		if record.scannedAt then
			scanned = scanned + 1
		end
	end
	local prices = ns.Prices.Sources()
	local lines = {
		("Characters recorded: %d (%d with recipes scanned)"):format(characters, scanned),
		("Prices: %s, vendor sell-back always"):format(ns.Prices.PrimarySource() or "no price addon"),
		("Price addons: auctionator %s, tsm %s"):format(
			tostring(prices.auctionator == true),
			tostring(prices.tsm == true)
		),
		("Account bags: %s"):format(ns.AccountBags.Ready() and "ready" or "not ready or absent"),
		("Store: schema %s, %s"):format(tostring(store.schema), ns.Store.Writable() and "writable" or "read-only"),
	}
	local result = ns.LastResult()
	if result then
		lines[#lines + 1] = ("Rows: %d, unknown %d, characters counted %d"):format(
			#result.rows,
			result.unknown,
			result.characters
		)
	else
		lines[#lines + 1] = "Rows: not computed yet"
	end
	return lines
end

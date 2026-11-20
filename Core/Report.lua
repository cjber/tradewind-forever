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
	return {
		("Characters recorded: %d"):format(0),
	}
end

-- Run from the repository root: luajit tests/error_journal_spec.lua
-- The shared error journal (ForeverCore's Core/SafeCall.lua) and debug log (ForeverCore's Core/Log.lua) live in
-- TradewindForeverDB, attached by Core/Core.lua once the saved variables are in, so the report lists earlier
-- sessions' errors and the lines that led to them after a /reload.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

-- Every frame Core/Core.lua or ForeverCore makes, so PLAYER_LOGIN reaches the addon's own handler.
local Toc = dofile("tests/toc.lua")
Toc.install(_G, "TradewindForever")
local frames = {}
_G.CreateFrame = function()
	local frame = {
		RegisterEvent = function() end,
	}
	frame.SetScript = function(self, event, handler)
		self[event] = handler
	end
	frames[#frames + 1] = frame
	return frame
end
_G.SlashCmdList = {}
-- The client defines the error handler, strtrim and date ForeverCore's journal and log read.
_G.geterrorhandler = function()
	return error
end
_G.seterrorhandler = function() end
_G.strtrim = function(text)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
_G.date = function()
	return "2026-11-08 12:00:00"
end
_G.GetTime = function()
	return 1.5
end
-- The addon's rebuilds wait on a timer this spec never fires.
_G.C_Timer = {
	After = function() end,
}

-- ForeverCore, then the addon's own files, as the client loads a required dependency first.
local core = dofile("tests/forever_core.lua")
core.install(_G, {
	"Core/SafeCall.lua",
	"Core/Log.lua",
	"Core/Text.lua",
	"Core/APIKit.lua",
	"Core/API.lua",
	"UI/Art.lua",
	"UI/MapCanvas.lua",
	"UI/Report.lua",
	"Data/Credits.lua",
	"UI/Credits.lua",
	"Expose.lua",
})

local ns = {}
assert(loadfile("Locales/enUS.lua"))("TradewindForever", ns)
assert(loadfile("Core/Report.lua"))("TradewindForever", ns)
for _, path in ipairs({
	"Core/Readable.lua",
	"Core/Professions.lua",
	"Core/Store.lua",
	"Core/Recipes.lua",
	"Core/Holdings.lua",
	"Core/Model.lua",
	"Integrations/Prices.lua",
	"Integrations/Merchant.lua",
	"Integrations/Syndicator.lua",
	"Core/Report.lua",
	"Core/Core.lua",
}) do
	assert(loadfile(path))("TradewindForever", ns)
end

-- An older save's journal and log under the same keys core reads.
TradewindForeverDB = {
	errors = {
		{
			kind = "error",
			message = "from an earlier session",
			signature = "earlier session",
			stack = "",
			count = 1,
			firstSeen = 1,
			lastSeen = 1,
		},
	},
	log = { lines = { "an earlier line" }, pinned = false },
}
for _, frame in ipairs(frames) do
	if frame.OnEvent then
		frame.OnEvent(frame, "PLAYER_LOGIN")
	end
end

check(type(TradewindForeverDB.errors) == "table", "PLAYER_LOGIN keeps the error journal table")
check(
	type(TradewindForeverDB.log) == "table" and type(TradewindForeverDB.log.lines) == "table",
	"PLAYER_LOGIN keeps the debug log ring"
)
local earlier
for _, entry in ipairs(TradewindForeverDB.errors) do
	if entry.message == "from an earlier session" then
		earlier = entry
	end
end
check(earlier ~= nil, "the attached journal keeps an earlier session's errors")

-- An error caught by the addon's own SafeCall is recorded in the saved journal.
local ok = ns.core.SafeCall("error journal spec", function()
	error("error journal spec failure")
end)
check(ok == false, "the failure was not caught")
local entry
for _, candidate in ipairs(TradewindForeverDB.errors) do
	if candidate.message:find("error journal spec failure", 1, true) then
		entry = candidate
	end
end
check(entry ~= nil, "the caught error did not reach the saved journal")
check(entry and entry.kind == "error", "the journal entry is recorded as an error")

-- A log line lands in the same saved table.
ns.core.Log("info", "spec", "logged before a reload")
local logged
for _, line in ipairs(TradewindForeverDB.log.lines) do
	if line:find("logged before a reload", 1, true) then
		logged = line
	end
end
check(logged ~= nil, "a log line is kept in the saved ring")

-- /tradewind report goes to the shared report before the addon's own commands.
local reported, toggled
ns.core.Report.Command = function(command)
	reported = command
	return command == "report"
end
ns.Open = function()
	toggled = true
end
SlashCmdList.TRADEWINDFOREVER("report")
check(reported == "report", "/tradewind report is handled by ns.core.Report.Command")
check(not toggled, "/tradewind report does not fall through to the addon's command")

-- Any other word opens the addon, and neither word writes a chat line.
local chatted = false
local realPrint = print
_G.print = function()
	chatted = true
end
_G.DEFAULT_CHAT_FRAME = {
	AddMessage = function()
		chatted = true
	end,
}
SlashCmdList.TRADEWINDFOREVER("")
SlashCmdList.TRADEWINDFOREVER("report")
_G.print = realPrint
_G.DEFAULT_CHAT_FRAME = nil
check(toggled == true, "an empty /tradewind opens the addon")
check(chatted == false, "the slash command writes nothing to chat")
check(_G.SLASH_TRADEWINDFOREVER1 == "/tradewind" and _G.SLASH_TRADEWINDFOREVER2 == "/tw", "both slash words are set")

print(("error_journal_spec: %d checks passed"):format(checks))

std = "lua51"
max_line_length = 120
exclude_files = { "forever-core/**", "tools/.cache/**", ".release/**", ".types/**", "types/**", ".claude/**" }
ignore = { "212/_.*" } -- unused args prefixed with _
globals = {
	"SLASH_TRADEWINDFOREVER1",
	"SLASH_TRADEWINDFOREVER2",
	"SlashCmdList",
	"TradewindForever",
	"TradewindForever_OnAddonCompartmentClick",
	"TradewindForeverDB",
}
read_globals = {
	"C_AddOns",
	"CreateFrame",
	"ForeverCore",
}

-- A translation's lines are as long as its phrases.
files["Locales/*.lua"] = { max_line_length = false }

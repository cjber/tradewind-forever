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
	"Auctionator",
	"C_CurrencyInfo",
	"C_Item",
	"C_MerchantFrame",
	"C_SpellBook",
	"C_Timer",
	"C_TradeSkillUI",
	"GameTooltip",
	"GetMerchantItemCostInfo",
	"GetMerchantItemID",
	"GetMerchantNumItems",
	"GetNormalizedRealmName",
	"GetProfessionInfo",
	"GetProfessions",
	"GetRealmName",
	"GetServerTime",
	"InCombatLockdown",
	"ProfessionsFrame",
	"Syndicator",
	"TSM_API",
	"UIErrorsFrame",
	"UnitClass",
	"UnitGUID",
	"UnitName",
	"debugprofilestop",
	"issecretvalue",
}

-- A translation's lines are as long as its phrases.
files["Locales/*.lua"] = { max_line_length = false }

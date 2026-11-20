---@type string, TWNamespace
local _, ns = ...

-- The game still loads this addon when the ForeverCore it finds is out of date. ForeverCore's API version stays at 1 as
-- it adds members, so a core is out of date when a member this addon calls is missing, never because of a version
-- comparison. Every post-API-1 member the addon calls is checked here, so an out-of-date core stops the addon's own
-- files at this point and the shared warning says which addon to update.
--
-- Register and Credits.Register are the shared services (the report window and the Thanks page). ProfessionTabs
-- carries the Professions side tab: Register arrived in ForeverCore 1.4.0 and minor 2 (1.8.1) hides the client's own
-- page beneath the addon's, so an older module would draw the two pages over each other. APIKit (1.1.0) builds this
-- addon's public API: Hub, NotReady, Invalid and, from minor 2, Publish. Art.Icon and Art.CooldownIcon draw the item
-- icons with the Cooldown Manager's mask, and Text.Fold and Text.Rank rank the search box's matches.
--
-- The warning itself is Core/ForeverRequire.lua, shared by every Forever addon: one line on screen, never a chat
-- message, naming the addon to update and never ForeverCore.
local core = ForeverCore
local tabs = core ~= nil and core.ProfessionTabs or nil
local kit = core ~= nil and core.APIKit or nil
local ready = core ~= nil
	and type(core.Register) == "function"
	and type(core.Credits) == "table"
	and type(core.Credits.Register) == "function"
	and type(tabs) == "table"
	and type(tabs.Register) == "function"
	and (tonumber(tabs.minor) or 0) >= 2
	and type(kit) == "table"
	and type(kit.Hub) == "function"
	and type(kit.NotReady) == "function"
	and type(kit.Invalid) == "function"
	and type(kit.Publish) == "function"
	and (tonumber(kit.minor) or 0) >= 2
	and type(core.Art) == "table"
	and type(core.Art.Icon) == "function"
	and type(core.Art.CooldownIcon) == "function"
	and type(core.Text) == "table"
	and type(core.Text.Fold) == "function"
	and type(core.Text.Rank) == "function"

-- Core/Core.lua's slash words; the pin gate (forever_tools.require_slash) keeps the two lists equal. A stopped addon
-- still answers them with the line that names the fix, as its addon compartment entry does.
ns.Slash = { key = "TRADEWINDFOREVER", "/tradewind", "/tw" }

ns.ForeverRequire(ready, ns.Slash)

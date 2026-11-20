-- Run from the repository root: luajit tests/core_dependency_spec.lua
-- Core/Require.lua computes whether the loaded ForeverCore has every member this addon calls, and hands the warning
-- to Core/ForeverRequire.lua. The shared warning's own cases are ForeverCore's tests/forever_require_spec.lua; this
-- checks the two sides meet: a core missing a member stops here, and a complete one loads on.
local checks = 0
local function check(condition, label)
	checks = checks + 1
	assert(condition, label)
end

local messages = {}
local addons = {
	{ name = "TradewindForever", title = "Tradewind Forever", tag = "v1.5.0", loaded = true, enabled = 2 },
	{ name = "OtherForever", title = "Other Forever", tag = "v1.4.1", loaded = true, enabled = 2 },
	{
		name = "ForeverCore",
		title = "ForeverCore",
		website = "https://github.com/cjber/forever-core",
		loaded = true,
		enabled = 2,
	},
}

_G.C_AddOns = {
	GetNumAddOns = function()
		return #addons
	end,
	GetAddOnInfo = function(index)
		return addons[index] and addons[index].name
	end,
	GetAddOnMetadata = function(target, field)
		local item = type(target) == "number" and addons[target] or nil
		if type(target) == "string" then
			for _, addon in ipairs(addons) do
				if addon.name == target then
					item = addon
					break
				end
			end
		end
		if not item then
			return nil
		end
		if field == "X-Website" then
			return item.website
		end
		if field == "Title" then
			return item.title
		end
		if field == "X-Forever-Core" then
			return item.tag
		end
		return nil
	end,
	IsAddOnLoaded = function(index)
		return addons[index] and addons[index].loaded
	end,
	GetAddOnEnableState = function(index)
		return addons[index] and addons[index].enabled
	end,
	-- The client answers one return per dependency, never a table.
	GetAddOnDependencies = function()
		return "ForeverCore" -- multi-value: one return per dependency
	end,
}
_G.UnitName = function(unit)
	assert(unit == "player", "asks about the player")
	return "Tester"
end
_G.UIErrorsFrame = {
	AddMessage = function(_, text)
		messages[#messages + 1] = text
	end,
}

-- Loads the shared file first, as the TOC does, then this addon's ready check.
local function Run(core)
	messages = {}
	_G.ForeverCore = core
	local ns = {}
	assert(loadfile("Core/ForeverRequire.lua"))("TradewindForever", ns)
	assert(loadfile("Core/Require.lua"))("TradewindForever", ns)
	return ns
end

-- Every member Core/Require.lua checks, as a complete core carries it.
local function Complete()
	return {
		Register = function() end,
		Credits = { Register = function() end },
		ProfessionTabs = { Register = function() end, minor = 2 },
		APIKit = {
			Hub = function() end,
			NotReady = function() end,
			Invalid = function() end,
			Publish = function() end,
			minor = 2,
		},
		Art = { Icon = function() end, CooldownIcon = function() end },
		Text = { Fold = function() end, Rank = function() end },
	}
end

-- A core missing any one member, or carrying an older module minor, stops the addon before its files load.
local function Without(change)
	local core = Complete()
	change(core)
	return core
end
local gaps = {
	Register = function(core)
		core.Register = nil
	end,
	["Credits.Register"] = function(core)
		core.Credits = {}
	end,
	["ProfessionTabs.Register"] = function(core)
		core.ProfessionTabs.Register = nil
	end,
	["ProfessionTabs minor 1"] = function(core)
		core.ProfessionTabs.minor = 1
	end,
	["unversioned ProfessionTabs"] = function(core)
		core.ProfessionTabs.minor = nil
	end,
	["APIKit.Hub"] = function(core)
		core.APIKit.Hub = nil
	end,
	["APIKit.NotReady"] = function(core)
		core.APIKit.NotReady = nil
	end,
	["APIKit.Invalid"] = function(core)
		core.APIKit.Invalid = nil
	end,
	["APIKit.Publish"] = function(core)
		core.APIKit.Publish = nil
	end,
	["APIKit minor 1"] = function(core)
		core.APIKit.minor = 1
	end,
	["Art.Icon"] = function(core)
		core.Art.Icon = nil
	end,
	["Art.CooldownIcon"] = function(core)
		core.Art.CooldownIcon = nil
	end,
	["Text.Fold"] = function(core)
		core.Text.Fold = nil
	end,
	["Text.Rank"] = function(core)
		core.Text.Rank = nil
	end,
}
for label, change in pairs(gaps) do
	local broken = Run(Without(change))
	check(broken.broken == true, "a core without " .. label .. " marks the addon broken")
	check(#messages == 1, "and shows exactly one line for " .. label)
	check(
		messages[1] and messages[1]:find("Other Forever", 1, true) ~= nil,
		"the line names the other addon whose download brings this core"
	)
end

-- A core with every member this addon calls: the addon loads and nothing is shown.
local complete = Run(Complete())
check(complete.broken == nil, "a complete core leaves the addon unbroken")
check(#messages == 0, "a complete core shows nothing")
check(complete.Slash.key == "TRADEWINDFOREVER", "the slash key is named after the folder")

-- Installation and enablement have distinct recovery instructions.
local coreAddon = table.remove(addons)
local missing = Run(nil)
check(missing.broken == true, "a missing core marks the addon broken")
check(#messages == 1, "a missing core shows exactly one line")
check(
	messages[1]
		== (
			"Tradewind Forever needs ForeverCore. Install it from CurseForge, "
			.. "or choose Reinstall on ForeverCore in the CurseForge app."
		),
	"a missing core asks to install ForeverCore and names Tradewind Forever"
)

coreAddon.loaded = false
coreAddon.enabled = 0
addons[#addons + 1] = coreAddon
local disabled = Run(nil)
check(disabled.broken == true, "a disabled core marks the addon broken")
check(#messages == 1, "a disabled core shows exactly one line")
check(
	messages[1] == "Tradewind Forever: ForeverCore is turned off. Enable it in the AddOns list to fix this.",
	"a disabled core asks to enable ForeverCore"
)

print(("core_dependency_spec: %d checks passed"):format(checks))

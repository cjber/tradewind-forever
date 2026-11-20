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
}

-- `true` marks a phrase that reads as its own English key.
for key, value in pairs(ns.L) do
	if value == true then
		ns.L[key] = key
	end
end

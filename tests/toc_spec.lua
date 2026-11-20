-- Run from the repository root: luajit tests/toc_spec.lua
-- The TOC fields every Forever addon declares, and the ones that tie it to its files: the embedded ForeverCore pin,
-- the slash words Core/Require.lua and Core/Core.lua share, and the files the TOC loads.
local Toc = dofile("tests/toc.lua")
local THIS = "TradewindForever"

local function read(path)
	local file = assert(io.open(path, "r"), path)
	local text = file:read("*a")
	file:close()
	return text
end

assert(Toc.get(THIS, "Interface") == "16001", "Interface 16001")
assert(Toc.get(THIS, "X-Forever-Core-Embed") == "1", "ForeverCore is embedded")
assert(Toc.get(THIS, "X-Forever-Core") == read("tools/forever-core.txt"):match("%S+"), "the TOC names the pinned core")
assert(Toc.get(THIS, "SavedVariables") == "TradewindForeverDB", "one account saved variable")
assert(Toc.get(THIS, "Dependencies") == nil and Toc.get(THIS, "RequiredDeps") == nil, "nothing is required")
local optional = Toc.get(THIS, "OptionalDeps") or ""
for _, name in ipairs({ "Auctionator", "TradeSkillMaster", "Syndicator", "ForeverCore" }) do
	assert(optional:find(name, 1, true), name .. " is an optional dependency")
end
assert(Toc.get(THIS, "X-Forever-Icon"), "the in-game icon is declared once")
assert(Toc.get(THIS, "AddonCompartmentFunc") == "TradewindForever_OnAddonCompartmentClick", "compartment entry")

-- Every file the TOC lists exists, and a Lua file is listed once.
local seen = {}
for line in io.lines(THIS .. ".toc") do
	line = line:gsub("\r$", "")
	if line ~= "" and not line:find("^#") then
		assert(not seen[line], line .. " is listed once")
		seen[line] = true
		local file = assert(io.open((line:gsub("\\", "/")), "r"), line .. " exists")
		file:close()
	end
end

-- Core/Require.lua and Core/Core.lua name the same slash words.
local require_text, core_text = read("Core/Require.lua"), read("Core/Core.lua")
local words = require_text:match('ns%.Slash = { key = "TRADEWINDFOREVER", ([^}]*)}')
assert(words, "Core/Require.lua declares the slash words")
for word in words:gmatch('"(/[^"]+)"') do
	assert(core_text:find('"' .. word .. '"', 1, true), word .. " is assigned in Core/Core.lua")
end

print("toc_spec: ok")

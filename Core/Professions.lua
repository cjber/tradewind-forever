---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWProfessions
local Professions = {}
ns.Professions = Professions

-- Profession name (enUS) to the skill line recipe data uses. Forever's profession APIs report other IDs
-- (GetProfessionInfo gave 8167, 8175, ...), so the name is the key, with the pairing seen at an open profession window
-- for a client in another language. The names and lines are SkillUp Forever's own map.
---@type table<string, integer>
Professions.SKILL_LINES = {
	["Alchemy"] = 171,
	["Blacksmithing"] = 164,
	["Cooking"] = 185,
	["Enchanting"] = 333,
	["Engineering"] = 202,
	["First Aid"] = 129,
	["Fishing"] = 356,
	["Herbalism"] = 182,
	["Leatherworking"] = 165,
	["Mining"] = 186,
	["Skinning"] = 393,
	["Tailoring"] = 197,
}

---@type table<integer, string>
local NAMES = {}
for name, skillLine in pairs(Professions.SKILL_LINES) do
	NAMES[skillLine] = name
end

-- The canonical skill line for a profession's name, else for the ID the client reported when that is itself a
-- canonical one. Nil for a profession the recipe data does not cover (Fishing and the gathering skills have no
-- recipes here but are still known lines).
---@param name string?
---@param reported integer?
---@return integer?
function Professions.Canonical(name, reported)
	local learned = ns.Store and ns.Store.Get().professionNames or {}
	local line = Professions.SKILL_LINES[name] or learned[name]
	if line then
		return line
	end
	if NAMES[reported] then
		return reported
	end
	return nil
end

-- The English name of a canonical skill line; the player's own profession name is shown where one was recorded.
---@param skillLine integer
---@return string
function Professions.Name(skillLine)
	return ns.L[NAMES[skillLine] or ""] or NAMES[skillLine] or tostring(skillLine)
end

-- A non-English client has no bundled profession name; the open window pairs its name with the canonical ID.
function Professions.NoteWindow()
	if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
		return
	end
	local base = C_TradeSkillUI.GetBaseProfessionInfo()
	local name = base and ns.Readable(base.professionName)
	local line = base and ns.Readable(base.professionID)
	if type(name) == "string" and name ~= "" and NAMES[line] and ns.Store.Writable() then
		ns.Store.Get().professionNames[name] = line
	end
end

---@param professions table<integer, TWProfession>
---@return integer unresolved professions the client reported that map to no canonical skill line
local function Add(professions, ...)
	local unresolved = 0
	for i = 1, select("#", ...) do
		local index = (select(i, ...))
		if index then
			local name, _, rank, max, _, _, reported = GetProfessionInfo(index)
			local line = Professions.Canonical(ns.Readable(name), ns.Readable(reported))
			if line then
				professions[line] = {
					name = ns.Readable(name),
					reportedId = ns.Readable(reported),
					rank = ns.Readable(rank) or 0,
					max = ns.Readable(max) or 0,
				}
			else
				unresolved = unresolved + 1
			end
		end
	end
	return unresolved
end

-- The player's professions by canonical skill line. GetProfessions leaves nil gaps for empty slots, so Add walks its
-- full return count.
-- The second result counts reported professions that could not be mapped (a non-English client before that
-- profession's window was opened): the list is then incomplete, so nothing is dropped for being absent from it.
---@return table<integer, TWProfession>
---@return integer unresolved
function Professions.Current()
	local professions = {}
	local unresolved = Add(professions, GetProfessions())
	return professions, unresolved
end

return Professions

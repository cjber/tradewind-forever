---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWRecipes
local Recipes = {}
ns.Recipes = Recipes

-- Which recipes each character knows, recorded one recipe at a time. The open profession window says whether each of
-- its recipes is learned; the client's own spellbook answers for the logged-in character without a window
-- (C_SpellBook.IsSpellKnown, SkillUp Forever's production path), at login and when a recipe is learned. A window of a
-- linked or guild profession shows someone else's recipes and is never recorded. An alt that has never logged in with
-- this addon has no record, so it is absent rather than empty.

-- This character's key in the saved variables, "Name-Realm"; nil while the client has no name or realm yet.
---@return string?
function Recipes.CurrentKey()
	local name = UnitName("player")
	local realm = GetNormalizedRealmName()
	if not realm or realm == "" then
		realm = ((GetRealmName() or ""):gsub("[%s%-]", ""))
	end
	if not name or name == "" or realm == "" then
		return nil
	end
	return name .. "-" .. realm, realm
end

-- Every reagent item any recipe uses, built once from the generated data.
---@type table<integer, true>?
local reagentSet

---@return table<integer, true>
function Recipes.ReagentSet()
	if not reagentSet then
		reagentSet = {}
		for _, recipe in pairs(ns.RecipeData or {}) do
			for _, reagent in ipairs(recipe.reagents) do
				reagentSet[reagent.itemID] = true
			end
		end
	end
	return reagentSet
end

-- The reagent items of the recipes `record` knows: what its holdings are recorded for.
---@param record TWCharacter
---@return table<integer, true>
function Recipes.TrackedItems(record)
	local items = {}
	for spellID in pairs(record.recipes) do
		local recipe = ns.RecipeData and ns.RecipeData[spellID]
		if recipe then
			for _, reagent in ipairs(recipe.reagents) do
				items[reagent.itemID] = true
			end
		end
	end
	return items
end

-- Updates the record's identity and professions. A profession the character dropped takes its recipes with it, unless
-- the client has none yet (skill lines can arrive empty at login, and that is not every profession dropped) or reports
-- one that cannot be mapped yet (then the list is incomplete, and absence from it proves nothing).
---@return TWCharacter? record
---@return boolean changed
function Recipes.RecordCharacter()
	local key, realm = Recipes.CurrentKey()
	if not key or not ns.Store.Writable() then
		return nil, false
	end
	local record = ns.Store.Character(key)
	if not record then
		return nil, false
	end
	local changed = false
	local name = UnitName("player")
	local _, class = UnitClass("player")
	if record.name ~= name or record.realm ~= realm then
		record.name, record.realm, changed = name, realm, true
	end
	record.class = ns.Readable(class) or record.class
	record.lastSeen = GetServerTime()
	local professions, unresolved = ns.Professions.Current()
	if next(professions) then
		if unresolved == 0 then
			for line in pairs(record.professions) do
				if not professions[line] then
					record.professions[line], changed = nil, true
				end
			end
		end
		for line, info in pairs(professions) do
			local old = record.professions[line]
			if not old or old.rank ~= info.rank or old.max ~= info.max or old.name ~= info.name then
				record.professions[line], changed = info, true
			end
		end
		if unresolved == 0 then
			for spellID in pairs(record.recipes) do
				local recipe = ns.RecipeData and ns.RecipeData[spellID]
				if recipe and not professions[recipe.skillLine] then
					record.recipes[spellID], changed = nil, true
				end
			end
		end
	end
	return record, changed
end

-- One recipe's learned state, set only when it differs.
---@param record TWCharacter
---@param spellID integer
---@param learned boolean
---@return boolean changed
local function Note(record, spellID, learned)
	if learned then
		if not record.recipes[spellID] then
			record.recipes[spellID] = true
			return true
		end
	elseif record.recipes[spellID] then
		record.recipes[spellID] = nil
		return true
	end
	return false
end

-- Reads the open profession window: each of its recipes updates by itself. A window that is not this character's own,
-- or that cannot list recipes, records nothing.
---@return boolean changed
function Recipes.ScanWindow()
	if not ns.Store.Writable() then
		return false
	end
	if
		C_TradeSkillUI.IsTradeSkillLinked()
		or C_TradeSkillUI.IsTradeSkillGuild()
		or not C_TradeSkillUI.GetAllRecipeIDs
	then
		return false
	end
	local record = Recipes.RecordCharacter()
	if not record then
		return false
	end
	local changed = false
	for _, spellID in ipairs(C_TradeSkillUI.GetAllRecipeIDs()) do
		-- Only recipes the bundled data covers have anything to price.
		if ns.RecipeData and ns.RecipeData[spellID] then
			local info = C_TradeSkillUI.GetRecipeInfo(spellID)
			if info and type(ns.Readable(info.learned)) == "boolean" then
				changed = Note(record, spellID, info.learned) or changed
			end
		end
	end
	record.scannedAt = GetServerTime()
	return changed
end

-- The bundled recipe IDs of each skill line, built once, so a probe walks only the lines the character has.
---@type table<integer, integer[]>?
local byLine

---@return table<integer, integer[]>
local function RecipesByLine()
	if not byLine then
		byLine = {}
		for spellID, recipe in pairs(ns.RecipeData or {}) do
			local list = byLine[recipe.skillLine]
			if not list then
				list = {}
				byLine[recipe.skillLine] = list
			end
			list[#list + 1] = spellID
		end
	end
	return byLine
end

-- The skill lines already probed in full this session, per character: a later pass asks only about a newly learned
-- recipe or a newly gained profession, never the whole data set again.
---@type table<string, table<integer, true>>
local probed = {}

---@param record TWCharacter
---@param spellID integer
---@return boolean changed
local function Probe(record, spellID)
	if record.recipes[spellID] then
		return false
	end
	local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
	if ok and ns.Readable(known) == true then
		record.recipes[spellID] = true
		return true
	end
	return false
end

-- The logged-in character's recipes from the spellbook, for the professions it has: no profession window needed. A
-- recipe is only ever added here; the window is what removes one. With `spellID` (NEW_RECIPE_LEARNED) only that recipe
-- is asked about; without it, each profession not yet probed this session is asked about in full.
---@param spellID? integer
---@return boolean changed
function Recipes.ProbeKnown(spellID)
	if not ns.Store.Writable() or not C_SpellBook or not C_SpellBook.IsSpellKnown then
		return false
	end
	local record = Recipes.RecordCharacter()
	if not record then
		return false
	end
	local changed = false
	local data = ns.RecipeData or {}
	if spellID and data[spellID] then
		if record.professions[data[spellID].skillLine] then
			changed = Probe(record, spellID)
		end
	else
		local key = Recipes.CurrentKey() --[[@as string]]
		local done = probed[key]
		if not done then
			done = {}
			probed[key] = done
		end
		for line, list in pairs(RecipesByLine()) do
			if not record.professions[line] then
				-- A dropped profession that is learned again is probed again.
				done[line] = nil
			elseif not done[line] then
				done[line] = true
				for _, id in ipairs(list) do
					changed = Probe(record, id) or changed
				end
			end
		end
	end
	record.scannedAt = GetServerTime()
	return changed
end

return Recipes

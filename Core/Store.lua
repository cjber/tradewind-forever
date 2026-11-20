---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWStore
local Store = {}
ns.Store = Store

-- The saved variable's layout version. A save written by a newer addon is read but never written (a downgrade must not
-- destroy it); an older one is migrated forward one step at a time.
Store.SCHEMA = 1

-- Every saved key and its default, in one place (WFA-14). A character record is made by Store.Character:
-- { name, realm, class, lastSeen, scannedAt?, professions = { [canonical] = { reportedId, name, rank, max } },
--   recipes = { [spellID] = true }, bags = { counts, observedAt }?, bank = { counts, observedAt }? }.
-- The bank is nil until the bank window is observed open: a never-observed scope is unknown, never empty.
local DEFAULTS = {
	schema = Store.SCHEMA,
	characters = {},
	-- vendorBuy[itemID][merchantKey] = copper per unit, as last seen at that merchant.
	vendorBuy = {},
	-- [localized profession name] = canonical skill line, seen with the profession open.
	professionNames = {},
}
Store.DEFAULTS = DEFAULTS

---@param value any
---@return any
local function Copy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = Copy(inner)
	end
	return copy
end

-- Migrations, keyed by the schema they upgrade from. None yet: schema 1 is the first.
---@type table<integer, fun(db: table)>
local MIGRATIONS = {}

-- Brings `db` to `target`, one step at a time, and returns whether it may be written. A save from a newer schema is
-- left exactly as found.
---@param db table
---@param steps? table<integer, fun(db: table)>
---@param target? integer
---@return boolean writable
function Store.Migrate(db, steps, target)
	steps, target = steps or MIGRATIONS, target or Store.SCHEMA
	local schema = tonumber(db.schema) or target
	if schema > target then
		return false
	end
	while schema < target do
		local step = steps[schema]
		if step then
			step(db)
		end
		schema = schema + 1
		db.schema = schema
	end
	db.schema = target
	return true
end

local current ---@type table
local writable = true

-- A character record's nested tables, made when a save lacks them (a hand edit or a partial write) so every reader
-- can index them.
---@param record table
local function Normalize(record)
	for _, field in ipairs({ "professions", "recipes" }) do
		if type(record[field]) ~= "table" then
			record[field] = {}
		end
	end
end

---@param characters table
local function NormalizeAll(characters)
	for key, record in pairs(characters) do
		if type(record) == "table" then
			Normalize(record)
		else
			characters[key] = nil
		end
	end
end

-- Attaches the saved variable: migrates it, then fills each missing key from DEFAULTS and each character's nested
-- tables. A read-only save is read through a deep copy, so nothing done to what is read can reach the newer save.
---@param db table
---@return table
function Store.Init(db)
	writable = Store.Migrate(db)
	if writable then
		for key, value in pairs(DEFAULTS) do
			if db[key] == nil then
				db[key] = Copy(value)
			end
		end
		if type(db.characters) ~= "table" then
			db.characters = {}
		end
		NormalizeAll(db.characters)
		current = db
	else
		local view = Copy(db)
		for key, value in pairs(DEFAULTS) do
			if view[key] == nil then
				view[key] = Copy(value)
			end
		end
		if type(view.characters) ~= "table" then
			view.characters = {}
		end
		NormalizeAll(view.characters)
		current = view
	end
	return current
end

---@return table
function Store.Get()
	return current or Copy(DEFAULTS)
end

---@return boolean
function Store.Writable()
	return writable and current ~= nil
end

-- The record for `key` ("Name-Realm"), made when absent and the save is writable. Nil for a read-only save with no
-- such character.
---@param key string
---@return TWCharacter?
function Store.Character(key)
	local characters = Store.Get().characters
	local record = characters[key]
	if not record and Store.Writable() then
		record = { name = "", realm = "", lastSeen = 0, professions = {}, recipes = {} }
		characters[key] = record
	end
	return record
end

return Store

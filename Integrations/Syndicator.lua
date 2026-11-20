---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWSyndicator
local Syndicator_ = {}
ns.AccountBags = Syndicator_

-- The only file that names Syndicator (tools/repo_rules.py). Its inventory read is SkillUp Forever's verified call:
-- API.IsReady() then API.GetInventoryInfoByItemID(itemID, sameConnectedRealm, sameFaction), a list of characters with
-- bags and bank counts (its mail count is ignored: the product is bags and bank). Everything is pcall'd and checked, so
-- an absent, not-ready or malformed Syndicator answers nil.

---@param value any
---@return boolean
local function Count(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge and value % 1 == 0
end

---@return boolean
function Syndicator_.Ready()
	local api = Syndicator and Syndicator.API
	if not (api and type(api.IsReady) == "function" and type(api.GetInventoryInfoByItemID) == "function") then
		return false
	end
	local ok, ready = pcall(api.IsReady)
	return ok and ready == true
end

-- Every account character's bags and bank for one item, by "Name-Realm". A malformed entry is dropped alone; nil when
-- Syndicator cannot answer at all.
---@param itemID integer
---@return table<string, {bags: integer, bank: integer}>?
function Syndicator_.Item(itemID)
	if not Syndicator_.Ready() then
		return nil
	end
	local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, itemID, false, false)
	if not ok or type(info) ~= "table" or type(info.characters) ~= "table" then
		return nil
	end
	local found = {}
	for _, character in ipairs(info.characters) do
		if
			type(character) == "table"
			and type(character.character) == "string"
			and type(character.realmNormalized) == "string"
			and Count(character.bags)
			and Count(character.bank)
		then
			found[character.character .. "-" .. character.realmNormalized] =
				{ bags = character.bags, bank = character.bank }
		end
	end
	return found
end

return Syndicator_

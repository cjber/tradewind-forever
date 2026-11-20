---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWHoldings
local Holdings = {}
ns.Holdings = Holdings

-- What each character holds of the reagents its recipes use, bags and bank separately.
--
-- A character has ONE source for its holdings, chosen per pass, never merged (so nothing counts twice): Syndicator when
-- it knows that character, else this addon's own record. A scope that was never observed, or whose read was secret, is
-- unknown, not zero: the row built from it is shown as unknown and left out of the totals.

-- Counts for `items` in one scope. includeBank counts the bank too (the reagent bank included), so the bank scope is
-- that count less the bags.
-- Nil when any read is secret or fails, so a half-read scope never replaces the last good snapshot.
---@param items table<integer, true>
---@param includeBank boolean
---@return table<integer, integer>?
local function Read(items, includeBank)
	local counts = {}
	for itemID in pairs(items) do
		local ok, count = pcall(C_Item.GetItemCount, itemID, includeBank, false, includeBank, false)
		count = ok and ns.Readable(count) or nil
		if type(count) ~= "number" then
			return nil
		end
		counts[itemID] = count
	end
	return counts
end

---@param record TWCharacter
---@param scope "bags"|"bank"
---@param counts table<integer, integer>
---@param observe boolean true when the player's own window was open, so the scope is observed now
---@return boolean changed whether the counts differ from the last snapshot
local function Save(record, scope, counts, observe)
	local old = record[scope]
	local kept = {}
	for itemID, count in pairs(counts) do
		if count > 0 then
			kept[itemID] = count
		end
	end
	local changed = old == nil
	if old then
		for itemID, count in pairs(kept) do
			if old.counts[itemID] ~= count then
				changed = true
			end
		end
		for itemID in pairs(old.counts) do
			if kept[itemID] == nil then
				changed = true
			end
		end
	end
	record[scope] = { counts = kept, observedAt = observe and GetServerTime() or (old and old.observedAt) or nil }
	return changed
end

-- Records this character's bags (always observable) and, when `bank` is true, its bank. A bank scope is observed only
-- while the bank window is open; otherwise it is recounted from the client's cached bank contents and keeps its
-- observation time, and a character that never opened its bank keeps no bank scope at all.
---@param record TWCharacter
---@param bank boolean the bank window is open
---@return boolean changed
function Holdings.Record(record, bank)
	if not ns.Store.Writable() then
		return false
	end
	local items = ns.Recipes.TrackedItems(record)
	local bags = Read(items, false)
	if not bags then
		return false
	end
	local changed = Save(record, "bags", bags, true)
	if bank or record.bank then
		local withBank = Read(items, true)
		if withBank then
			local counts = {}
			for itemID, count in pairs(withBank) do
				counts[itemID] = math.max(0, count - (bags[itemID] or 0))
			end
			changed = Save(record, "bank", counts, bank) or changed
		end
	end
	return changed
end

-- Per pass: Syndicator's answers by item, and the characters it has answered for in this pass.
---@type table<integer, table<string, {bags: integer, bank: integer}>|false>
local syndicator = {}
---@type table<string, true>
local known = {}

function Holdings.BeginPass()
	syndicator, known = {}, {}
end

-- Asks Syndicator about an item once per pass. Every character it lists for any item is a Syndicator character for the
-- whole pass, so a character never switches source between its items.
---@param itemID integer
function Holdings.Prefetch(itemID)
	if syndicator[itemID] ~= nil then
		return
	end
	local info = ns.AccountBags.Item(itemID)
	syndicator[itemID] = info or false
	for key in pairs(info or {}) do
		known[key] = true
	end
end

-- Which source answers for a character this pass.
---@param characterKey string
---@return "syndicator"|"own"
function Holdings.Source(characterKey)
	return known[characterKey] and "syndicator" or "own"
end

-- The count of `itemID` a character holds in bags and bank, or nil when unknown. A character whose bank was never
-- observed counts its bags alone, flagged as bags-only: the true count is at least that, and a character that never
-- visits a bank still gets counts.
---@param characterKey string
---@param itemID integer
---@return integer?
---@return boolean? bagsOnly
function Holdings.Count(characterKey, itemID)
	if known[characterKey] then
		local info = syndicator[itemID]
		if info == nil then
			Holdings.Prefetch(itemID)
			info = syndicator[itemID]
		end
		if not info then
			return nil
		end
		local entry = info[characterKey]
		return entry and (entry.bags + entry.bank) or 0
	end
	local record = ns.Store.Get().characters[characterKey]
	local bags = record and record.bags
	if not bags or not bags.observedAt then
		return nil
	end
	local bank = record.bank
	if not bank or not bank.observedAt then
		return bags.counts[itemID] or 0, true
	end
	return (bags.counts[itemID] or 0) + (bank.counts[itemID] or 0), false
end

return Holdings

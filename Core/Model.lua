---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

---@class TWModel
local Model = {}
ns.Model = Model

-- Pure: no client calls and no saved variables. Everything it reads comes in through the input table, so the specs run
-- it without a game.
--
-- Unknown is never zero. A price the addon does not have, a holding it has not observed and a result built from either
-- stay nil and are excluded from every total, never counted as 0. A real 0 (a vendor that pays nothing) stays 0.

-- The auction house keeps 5% of a sale (SkillUp Forever's constant; not re-verified on Forever). It applies to the
-- auction outlet only: a vendor buys back at its full price.
Model.AUCTION_CUT = 0.05
-- A price this many days old or older is flagged on the shopping list. Auctionator reports its age in whole days.
Model.STALE_DAYS = 7
-- The shopping list's size: the best rows by profit.
Model.SHOPPING_ROWS = 10

---@param value number
---@return integer
local function Round(value)
	return math.floor(value + 0.5)
end

---@param value any
---@return boolean
local function Money(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

-- The age in days of an auction price, nil when the item has none.
---@param view TWItemView?
---@return number?
local function PriceDays(view)
	if view and Money(view.auction) and type(view.days) == "number" then
		return view.days
	end
	return nil
end

---@param a number?
---@param b number?
---@return number?
local function Older(a, b)
	if a and b then
		return math.max(a, b)
	end
	return a or b
end

-- What one unit brings if sold: the auction price after the cut, or the vendor's buy-back, whichever pays more.
-- Nil when neither is known; the outlet names the one used.
---@param view TWItemView?
---@return number? copper
---@return ("auction"|"vendor")? outlet
function Model.Value(view)
	if not view then
		return nil
	end
	local auction = Money(view.auction) and view.auction * (1 - Model.AUCTION_CUT) or nil
	local vendor = Money(view.sellBack) and view.sellBack or nil
	if auction and (not vendor or auction >= vendor) then
		return auction, "auction"
	end
	if vendor then
		return vendor, "vendor"
	end
	return nil
end

-- How many crafts the holdings cover, and whether the answer is known. One reagent known to be short settles it at
-- 0 whatever the unknown ones hold; otherwise any unknown holding leaves it unknown.
---@param reagents {itemID: integer, qty: integer, held: integer?}[]
---@return integer? crafts
function Model.Craftable(reagents)
	local crafts, unknown = math.huge, false
	for _, reagent in ipairs(reagents) do
		if reagent.held == nil then
			unknown = true
		else
			crafts = math.min(crafts, math.floor(reagent.held / reagent.qty))
		end
	end
	if crafts == 0 then
		return 0
	end
	if unknown or crafts == math.huge then
		return nil
	end
	return crafts
end

---@class TWModelInput
---@field characters TWModelCharacter[] in display order
---@field recipes table<integer, TWRecipe>
---@field item fun(itemID: integer): TWItemView? prices for one item
---@field count fun(characterKey: string, itemID: integer): integer? nil when the holding is unknown
---@field itemName? fun(itemID: integer): string? for the sort's tie-break only
---@field prefetch? fun(itemID: integer) called once per distinct item before rows are built
---@field clock? fun(): number milliseconds, for the time budget

-- One recipe row for one character, or nil when the character cannot make it now. A row whose holdings or prices are
-- unknown is still returned, with nil where it does not know.
---@param input TWModelInput
---@param character TWModelCharacter
---@param spellID integer
---@param recipe TWRecipe
---@return TWRow?
function Model.Row(input, character, spellID, recipe)
	local output = recipe.output
	-- A recipe with no output item has nothing to sell, and a profession the character dropped is not theirs.
	if not output or not character.professions[recipe.skillLine] then
		return nil
	end
	local reagents, worth, holdingsUnknown, oldest = {}, 0, false, nil
	local worthKnown = true
	for index, reagent in ipairs(recipe.reagents) do
		local itemID, qty = reagent.itemID, reagent.qty
		local held = input.count(character.key, itemID)
		local view = input.item(itemID)
		-- A reagent that is itself craftable is priced as a plain item: no intermediate crafts.
		local unit, outlet = Model.Value(view)
		reagents[index] = { itemID = itemID, qty = qty, held = held, unit = unit, outlet = outlet }
		if held == nil then
			holdingsUnknown = true
		end
		if unit then
			worth = worth + qty * unit
		else
			worthKnown = false
		end
		oldest = Older(oldest, PriceDays(view))
	end
	local crafts = Model.Craftable(reagents)
	if crafts == 0 then
		return nil
	end
	local outView = input.item(output.itemID)
	local unit, outlet = Model.Value(outView)
	local sale = unit and Round(output.qty * unit) or nil
	local mats = worthKnown and Round(worth) or nil
	oldest = Older(oldest, PriceDays(outView))
	---@type TWRow
	local row = {
		characterKey = character.key,
		character = character.name,
		profession = recipe.skillLine,
		spellID = spellID,
		itemID = output.itemID,
		outputQty = output.qty,
		craftable = crafts,
		holdingsUnknown = holdingsUnknown,
		reagents = reagents,
		matsWorth = mats,
		sale = sale,
		saleOutlet = outlet,
		profit = (sale and mats) and (sale - mats) or nil,
		soldPerDay = outView and outView.soldPerDay or nil,
		priceDays = oldest,
	}
	return row
end

---@param a TWRow
---@param b TWRow
---@param name fun(itemID: integer): string
---@return boolean
local function Before(a, b, name)
	-- Rows whose holdings were never observed rank below every row known to be craftable: nobody has checked they can
	-- be made.
	if a.holdingsUnknown ~= b.holdingsUnknown then
		return not a.holdingsUnknown
	end
	-- A known profit before an unknown one, larger first; ties by character, recipe name, then spell ID.
	if (a.profit ~= nil) ~= (b.profit ~= nil) then
		return a.profit ~= nil
	end
	if a.profit ~= b.profit then
		return a.profit > b.profit
	end
	if a.character ~= b.character then
		return a.character < b.character
	end
	local an, bn = name(a.itemID), name(b.itemID)
	if an ~= bn then
		return an < bn
	end
	return a.spellID < b.spellID
end

-- Rows ordered as the list shows them: profit descending, losses sinking, unknown last.
---@param rows TWRow[]
---@param itemName? fun(itemID: integer): string?
function Model.Sort(rows, itemName)
	local cache = {}
	local function name(itemID)
		local cached = cache[itemID]
		if cached == nil then
			cached = ((itemName and itemName(itemID)) or ""):lower()
			cache[itemID] = cached
		end
		return cached
	end
	table.sort(rows, function(a, b)
		return Before(a, b, name)
	end)
end

-- The footer: what crafting every profitable row's batch brings, and how many rows it could not count.
---@param rows TWRow[]
---@return integer total copper
---@return integer unknown rows left out because a price or a holding is unknown
function Model.Footer(rows)
	local total, unknown = 0, 0
	for _, row in ipairs(rows) do
		if row.profit == nil or row.holdingsUnknown or row.craftable == nil then
			unknown = unknown + 1
		elseif row.profit > 0 then
			total = total + row.craftable * row.profit
		end
	end
	return total, unknown
end

---@class TWJob
---@field input TWModelInput
---@field work {[1]: TWModelCharacter, [2]: integer, [3]: TWRecipe}[] one entry per recipe a character can gather
---@field items integer[] the distinct items the work touches, in first-seen order
---@field seen table<integer, true> the items already in `items`
---@field characterAt integer
---@field ids integer[]? the current character's spell ids, sorted
---@field idAt integer
---@field itemAt integer
---@field workAt integer
---@field rows TWRow[]
---@field done boolean
---@field result TWResult?
local Job = {}
Job.__index = Job

local function Now()
	return debugprofilestop and debugprofilestop() or os.clock() * 1000
end

-- A computation that runs in slices, so a long list never costs a frame more than its budget. Phase 1 finds each
-- character's work and the distinct items it touches, phase 2 prefetches each item once (a hook for the price memo and
-- the inventory), phase 3 builds the rows, phase 4 sorts. Nothing is gathered before the first budgeted step.
---@param input TWModelInput
---@return TWJob
function Model.NewJob(input)
	return setmetatable({
		input = input,
		work = {},
		items = {},
		seen = {},
		characterAt = 1,
		ids = nil,
		idAt = 1,
		itemAt = 1,
		workAt = 1,
		rows = {},
		done = false,
	}, Job)
end

-- Adds one recipe's work and the items it touches.
---@param character TWModelCharacter
---@param spellID integer
function Job:Gather(character, spellID)
	local recipe = self.input.recipes[spellID]
	if not (recipe and recipe.output) then
		return
	end
	local work, seen, items = self.work, self.seen, self.items
	work[#work + 1] = { character, spellID, recipe }
	for _, reagent in ipairs(recipe.reagents) do
		if not seen[reagent.itemID] then
			seen[reagent.itemID] = true
			items[#items + 1] = reagent.itemID
		end
	end
	if not seen[recipe.output.itemID] then
		seen[recipe.output.itemID] = true
		items[#items + 1] = recipe.output.itemID
	end
end

-- Runs until the budget (milliseconds) is spent or the work is done; true when done. A budget of nil runs to the end.
---@param budget number?
---@return boolean done
function Job:Step(budget)
	if self.done then
		return true
	end
	local clock = self.input.clock or Now
	local stop = budget and clock() + budget or nil
	local input = self.input
	local characters = input.characters
	while self.characterAt <= #characters do
		local character = characters[self.characterAt]
		if not self.ids then
			local ids = {}
			for spellID in pairs(character.recipes) do
				ids[#ids + 1] = spellID
			end
			table.sort(ids)
			self.ids, self.idAt = ids, 1
		end
		while self.idAt <= #self.ids do
			self:Gather(character, self.ids[self.idAt])
			self.idAt = self.idAt + 1
			if stop and clock() >= stop then
				return false
			end
		end
		self.ids, self.characterAt = nil, self.characterAt + 1
		if stop and clock() >= stop then
			return false
		end
	end
	while self.itemAt <= #self.items do
		if input.prefetch then
			input.prefetch(self.items[self.itemAt])
		end
		self.itemAt = self.itemAt + 1
		if stop and clock() >= stop then
			return false
		end
	end
	while self.workAt <= #self.work do
		local entry = self.work[self.workAt]
		local row = Model.Row(input, entry[1], entry[2], entry[3])
		if row then
			self.rows[#self.rows + 1] = row
		end
		self.workAt = self.workAt + 1
		if stop and clock() >= stop then
			return false
		end
	end
	Model.Sort(self.rows, input.itemName)
	local total, unknown = Model.Footer(self.rows)
	self.result = { rows = self.rows, total = total, unknown = unknown, characters = #characters }
	self.done = true
	return true
end

-- The whole computation at once.
---@param input TWModelInput
---@return TWResult
function Model.Compute(input)
	local job = Model.NewJob(input)
	job:Step(nil)
	return job.result --[[@as TWResult]]
end

-- The reagents to buy to make the best rows again. Rows are taken in list order, known profitable ones with known
-- holdings only, at most SHOPPING_ROWS. A row's batch is its craftable count, made again: each reagent needs
-- qty x crafts, less what the character still holds after the batch they could make now. A reagent two rows share
-- draws on the same holding once. Lines are summed per reagent and priced at acquisition (`buy`: the auction price or
-- a recorded merchant price); a reagent with no acquisition price stays unknown and out of the total.
---@param rows TWRow[]
---@param item fun(itemID: integer): TWItemView?
---@param limit? integer
---@return TWShopping
function Model.Shopping(rows, item, limit)
	limit = limit or Model.SHOPPING_ROWS
	local remaining = {}
	local lines, order = {}, {}
	local used = 0
	for _, row in ipairs(rows) do
		if used >= limit then
			break
		end
		if row.profit and row.profit > 0 and not row.holdingsUnknown and row.craftable and row.craftable > 0 then
			used = used + 1
			for _, reagent in ipairs(row.reagents) do
				local key = row.characterKey .. "\1" .. reagent.itemID
				local held = remaining[key]
				if held == nil then
					held = reagent.held or 0
				end
				local batch = reagent.qty * row.craftable
				-- The batch they could make now comes out of the holding first, then the batch to make again.
				held = math.max(0, held - batch)
				local take = math.min(held, batch)
				remaining[key] = held - take
				local missing = batch - take
				if missing > 0 then
					local line = lines[reagent.itemID]
					if not line then
						line = { itemID = reagent.itemID, qty = 0 }
						lines[reagent.itemID] = line
						order[#order + 1] = line
					end
					line.qty = line.qty + missing
				end
			end
		end
	end
	local total, unknown, stale = 0, 0, 0
	for _, line in ipairs(order) do
		local view = item(line.itemID)
		line.unit, line.source = view and view.buy, view and view.buySource
		line.days = view and view.days
		line.stale = type(line.days) == "number" and line.source == "auction" and line.days >= Model.STALE_DAYS
		if Money(line.unit) then
			line.cost = Round(line.unit * line.qty)
			total = total + line.cost
		else
			line.unit = nil
			unknown = unknown + 1
		end
		if line.stale then
			stale = stale + 1
		end
	end
	table.sort(order, function(a, b)
		local ac, bc = a.cost or -1, b.cost or -1
		if ac ~= bc then
			return ac > bc
		end
		return a.itemID < b.itemID
	end)
	return { lines = order, total = total, unknown = unknown, stale = stale, rows = used }
end

-- One character's summary line for the Characters tab, from its saved record.
---@param record TWCharacter
---@param now integer server time
---@return TWCharacterSummary
function Model.Summary(record, now)
	local professions = {}
	for skillLine, info in pairs(record.professions) do
		professions[#professions + 1] = { skillLineId = skillLine, name = info.name, rank = info.rank, max = info.max }
	end
	table.sort(professions, function(a, b)
		return a.skillLineId < b.skillLineId
	end)
	local recipes = 0
	for _ in pairs(record.recipes) do
		recipes = recipes + 1
	end
	local function Age(scope)
		local at = scope and scope.observedAt
		return type(at) == "number" and math.max(0, now - at) or nil
	end
	return {
		name = record.name,
		realm = record.realm,
		class = record.class,
		professions = professions,
		scanned = record.scannedAt ~= nil,
		recipes = recipes,
		bagsAge = Age(record.bags),
		bankAge = Age(record.bank),
	}
end

return Model

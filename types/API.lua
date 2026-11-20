---@meta

-- TradewindForever.API, version 1, minor 0: the contract other addons read (docs/api.md). Core/API.lua implements it,
-- and these declarations never load in the client.

-- The channel names Subscribe reports (docs/api.md): "rows" follows a change to the Craft now list, "shopping" one
-- to the shopping list and "characters" one to a recorded character.
---@alias TWAPIChannel "rows"|"shopping"|"characters"

---@alias TWAPIChanges table<TWAPIChannel, true>

---@class TWAPIRow
---@field characterKey string "Name-Realm"
---@field character string
---@field professionId integer the canonical profession skill line
---@field recipeId integer
---@field itemId integer the crafted item
---@field outputCount number items one craft makes, on average
---@field craftable? integer crafts the character's own bags and bank cover, nil when its holdings are unknown
---@field holdingsKnown boolean
---@field cost? integer copper: what the held reagents are worth at resale, nil when any is unpriced
---@field sale? integer copper: the best outlet's value of one craft
---@field saleOutlet? "auction"|"vendor"
---@field profit? integer copper per craft, nil when unknown
---@field soldPerDay? number

---@class TWAPIShoppingLine
---@field itemId integer
---@field count integer
---@field unitPrice? integer copper, nil when no buying price is known
---@field cost? integer copper
---@field source? "auction"|"merchant"
---@field stale boolean the auction price is a week old or more

---@class TWAPIShopping
---@field lines TWAPIShoppingLine[]
---@field total integer copper over the priced lines
---@field unknown integer lines with no price

---@class TWAPICharacter : TWCharacterSummary
---@field key string "Name-Realm"

---@class TWPublicAPI
---@field version 1
---@field minor 0
---@field Rows fun(): TWAPIRow[]?, ForeverCoreAPIReason?
---@field Shopping fun(): TWAPIShopping?, ForeverCoreAPIReason?
---@field Characters fun(): TWAPICharacter[]?, ForeverCoreAPIReason?
---@field Subscribe fun(callback: fun(changes: TWAPIChanges)): fun() unsubscribes, safe to call twice

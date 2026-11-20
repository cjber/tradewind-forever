---@meta

---@class TWProfession
---@field name? string
---@field reportedId integer the id the client reported for the profession
---@field rank integer
---@field max integer

---@class TWScope
---@field counts table<integer, integer>
---@field observedAt integer

---@class TWCharacter
---@field name string
---@field realm string
---@field class? string
---@field lastSeen integer
---@field scannedAt? integer
---@field professions table<integer, TWProfession> keyed by canonical skill line
---@field recipes table<integer, true> spell ids the character knows
---@field bags? TWScope
---@field bank? TWScope

---@class TWRecipe
---@field skillLine integer
---@field reagents {itemID: integer, qty: integer}[]
---@field output {itemID: integer, qty: number}|false the crafted item and its mean yield

---@class TWModelCharacter
---@field key string
---@field name string
---@field realm string
---@field professions table<integer, TWProfession>
---@field recipes table<integer, true>

---@class TWItemView
---@field auction? number copper
---@field source? "auctionator"|"tsm"
---@field days? number age of the auction price in days
---@field sellBack? number copper a vendor pays
---@field soldPerDay? number
---@field buy? number copper to acquire one
---@field buySource? "auction"|"merchant"
---@field merchant? string the key of the merchant that charged `buy`

---@class TWRowReagent
---@field itemID integer
---@field qty integer
---@field held? integer
---@field unit? number
---@field outlet? "auction"|"vendor"

---@class TWRow
---@field characterKey string
---@field character string
---@field profession integer
---@field spellID integer
---@field itemID integer
---@field outputQty number
---@field craftable? integer
---@field holdingsUnknown boolean
---@field reagents TWRowReagent[]
---@field matsWorth? integer
---@field sale? integer
---@field saleOutlet? "auction"|"vendor"
---@field profit? integer
---@field soldPerDay? number
---@field priceDays? number

---@class TWResult
---@field rows TWRow[]
---@field total integer
---@field unknown integer
---@field characters integer

---@class TWShoppingLine
---@field itemID integer
---@field qty integer
---@field unit? number
---@field source? "auction"|"merchant"
---@field days? number
---@field stale boolean
---@field cost? integer

---@class TWShopping
---@field lines TWShoppingLine[]
---@field total integer
---@field unknown integer
---@field stale integer
---@field rows integer

---@class TWCharacterSummary
---@field name string
---@field realm string
---@field class? string
---@field professions {skillLineId: integer, name?: string, rank: integer, max: integer}[]
---@field scanned boolean the character's recipes were recorded
---@field recipes integer recipes recorded
---@field bagsAge? integer seconds since the bags were last seen
---@field bankAge? integer seconds since the bank was last seen

-- A list row: the Button the window builds once and each tab fills with its own entry.
---@class TWLine : Button
---@field background Texture
---@field hover Texture
---@field icon Texture
---@field overlay? Texture the item icon's Cooldown Manager overlay
---@field cols FontString[]
---@field itemID? integer
---@field entry? TWRow|TWShoppingLine|TWAPICharacter what the tab last filled the row with

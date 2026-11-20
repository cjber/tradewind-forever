# TradewindForever.API

Other addons read Tradewind Forever's Craft now list, its shopping list and the characters it has recorded through the
global `TradewindForever.API`. It is version 1, minor 0. On ForeverCore 1.3.2 or later it is also listed by
`ForeverCore.APIKit.Addons()`. The full types are in [`types/API.lua`](../types/API.lua).

Every read returns a fresh table that you may keep or change. Nothing here acts: Tradewind Forever never crafts, buys
or posts. Copper amounts are per craft, and a missing value is `nil`, never `0`.

`version` changes only when a published member's arguments, result shape or meaning breaks. An addition keeps `version`
and raises `minor`, so check that the member you want exists before calling it:

```lua
local api = TradewindForever and TradewindForever.API
if not (api and api.version == 1) then
	return
end
local rows, reason = api.Rows()
if rows then
	for _, row in ipairs(rows) do
		print(("%s can make %s for %s copper"):format(row.character, row.itemId, tostring(row.profit)))
	end
elseif reason == "loading" then
	-- ask again after Subscribe reports a change
end
```

## Version history

- `version` 1, `minor` 0: `Rows`, `Shopping`, `Characters` and `Subscribe`.

## Functions

- `Rows()` returns the Craft now list: one row per recipe per character that can make it now, with `craftable`,
  `cost`, `sale`, `saleOutlet`, `profit` and `soldPerDay`, or `nil, reason`.
- `Shopping()` returns the reagents to buy to make the best rows again, `{ lines, total, unknown }`, or
  `nil, reason`. A line with no price has a `nil` `unitPrice` and `cost` and is left out of `total`.
- `Characters()` returns every recorded character with its professions, recipe count and the age of its bag and bank
  records, or `nil, reason`.
- `Subscribe(callback)` calls `callback(changes)` on the frame after the `rows`, `shopping` or `characters` channel
  changed, and returns an unsubscribe function.

## Not ready

A read with nothing to answer returns `nil, reason`, the shape every Forever addon uses
(`ForeverCore.APIKit.NotReady`). Tradewind Forever answers `loading` until it has started. Treat any other reason as
"ask again later".

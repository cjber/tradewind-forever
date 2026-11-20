---@type string, TWNamespace
local _, ns = ...

if ns.broken then
	return
end

local L = ns.L

---@class TWFormat
local Format = {}
ns.Format = Format

-- Copper as the client's own gold, silver and copper icons.
---@param copper number
---@return string
function Format.Money(copper)
	return C_CurrencyInfo.GetCoinTextureString(math.floor(math.abs(copper) + 0.5))
end

-- A profit with its sign: green plus, red minus, plain zero. Unknown is a question mark, never a number.
---@param copper number?
---@return string
function Format.Profit(copper)
	if copper == nil then
		return "?"
	end
	if copper > 0 then
		return "|cff20ff20+|r " .. Format.Money(copper)
	elseif copper < 0 then
		return "|cffff4040-|r " .. Format.Money(copper)
	end
	return Format.Money(0)
end

-- How long ago an observation was, in the largest whole unit; "never" for one that was not made.
---@param seconds number?
---@return string
function Format.Age(seconds)
	if seconds == nil then
		return L["never"]
	end
	if seconds < 3600 then
		return L["%d min"]:format(math.floor(seconds / 60))
	elseif seconds < 86400 then
		return L["%d h"]:format(math.floor(seconds / 3600))
	end
	return L["%d d"]:format(math.floor(seconds / 86400))
end

-- The price header's source and age: which addon the prices come from and how old the oldest one is.
---@param source "auctionator"|"tsm"|nil
---@param days number?
---@return string
function Format.PriceSource(source, days)
	if source == "auctionator" then
		if days == nil then
			return L["Auctionator"]
		elseif days == 1 then
			return L["Auctionator, 1 day old"]
		end
		return L["Auctionator, %d days old"]:format(days)
	elseif source == "tsm" then
		return L["TradeSkillMaster"]
	end
	return L["no price addon, vendor prices only"]
end

-- An item's name, or a placeholder until the client has it.
---@param itemID integer
---@return string
function Format.ItemName(itemID)
	return ns.ItemName(itemID) or L["Item %d"]:format(itemID)
end

return Format

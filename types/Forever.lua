---@meta

-- The saved variable, declared in TradewindForever.toc. Plain data only.
---@type table?
TradewindForeverDB = nil

-- The addon compartment entry the TOC names.
---@type fun()
TradewindForever_OnAddonCompartmentClick = nil

-- Optional addons own these APIs; callers test availability before using them.

---@type {API: {v1: table}}?
Auctionator = nil

---@type {GetCustomPriceValue: fun(expression: string, itemString: string): number?}?
TSM_API = nil

---@type {API: table}?
Syndicator = nil

-- The client's Professions window, as ForeverCore's shared types describe it (CraftingPage, BookPage and the tabs).
---@class TWProfessionsWindow : ForeverProfessionsWindow
---@field PortraitContainer Frame?

---@type TWProfessionsWindow
ProfessionsFrame = nil

---@param tab Button
function PanelTemplates_SelectTab(tab) end

---@param tab Button
function PanelTemplates_DeselectTab(tab) end

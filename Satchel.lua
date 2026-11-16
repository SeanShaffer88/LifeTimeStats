-- LifeTimeStats - the satchel: items used from your bags, quest items used, everything carried
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, On, Tally, Unique = ns.Add, ns.Max, ns.On, ns.Tally, ns.Unique
local S, Bad = ns.IsSecret, ns.BadNumber

local function Num(v) if type(v) == "number" and not S(v) and not Bad(v) then return v end end
local function Str(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end

-- A right-click on a bag item only "uses" it when no trading window is open; with a vendor,
-- bank, mailbox, trade or auction window it sells, stores or attaches the item instead.
local BUSY = { "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "AuctionFrame", "AuctionHouseFrame", "GuildBankFrame" }
local function Busy()
    for _, name in ipairs(BUSY) do
        local f = _G[name]
        if type(f) == "table" and type(f.IsShown) == "function" then
            local ok, shown = pcall(f.IsShown, f)
            if ok and shown == true then return true end
        end
    end
    return false
end

local function NameFromLink(link)
    link = Str(link)
    return link and link:match("%[(.-)%]")
end

local function Equippable(item)
    local fn = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
    if type(fn) ~= "function" or item == nil then return false end
    local ok, yes = pcall(fn, item)
    return ok and yes == true
end

-- What sits in a bag slot: name and item ID, or nil.
function ns.BagSlotItem(bag, slot)
    local get = C_Container and C_Container.GetContainerItemInfo
    if type(get) ~= "function" then return end
    local ok, info = pcall(get, bag, slot)
    if not ok or type(info) ~= "table" then return end
    local id = Num(info.itemID)
    local name = Str(info.itemName) or NameFromLink(info.hyperlink)
    if not id and not name then return end
    return name, id
end

local function Used(name, id)
    if Busy() then return end
    if Equippable(id or name) then return end -- equipping is counted with your gear
    Add("items_used")
    if name then Tally("itemsused", name) end
end

function ns.OnUseContainerItem(bag, slot)
    if not Num(bag) or not Num(slot) then return end
    -- The hook runs after the call, but a used item stays in its slot until the cast ends.
    local name, id = ns.BagSlotItem(bag, slot)
    if name or id then Used(name, id) end
end
ns.OnUseContainerItem = ns.Guard and ns.Guard("item use", ns.OnUseContainerItem) or ns.OnUseContainerItem

local function OnUseByName(item)
    local name = NameFromLink(item) or Str(item)
    if name then Used(name, nil) end
end

-- ------------------------------------------------------------ what you carry
local BAGS = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
local lastScan = -10
function ns.ScanSatchel(force)
    if not ns.char then return end
    local now = GetTime()
    if not force and now - lastScan < 2 then return end
    lastScan = now
    local slotsFn = C_Container and C_Container.GetContainerNumSlots
    if type(slotsFn) ~= "function" then return end
    local total, filled = 0, 0
    for bag = 0, BAGS do
        local ok, n = pcall(slotsFn, bag)
        n = ok and Num(n)
        if n then
            total = total + n
            for slot = 1, n do
                local name, id = ns.BagSlotItem(bag, slot)
                if name or id then
                    filled = filled + 1
                    Unique("itemsheld", id or name)
                end
            end
        end
    end
    if total > 0 then
        ns.quietRecords = true -- bag sizes creep up one bag at a time; no Journal line each time
        Max("bag_slots_max", total)
        Max("bag_filled_max", filled)
        ns.quietRecords = nil
    end
end
ns.ScanSatchel = ns.Guard and ns.Guard("bag scan", ns.ScanSatchel) or ns.ScanSatchel
On("BAG_UPDATE_DELAYED", function() ns.ScanSatchel() end)

On("PLAYER_LOGIN", function()
    local function Hook(tbl, name, fn)
        if tbl then
            if type(tbl) == "table" and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) end
        elseif type(_G[name]) == "function" then
            hooksecurefunc(name, fn)
        end
    end
    -- Only one of the two exists on a given client; hooking both never counts twice.
    if C_Container and type(C_Container.UseContainerItem) == "function" then
        Hook(C_Container, "UseContainerItem", ns.OnUseContainerItem)
    else
        Hook(nil, "UseContainerItem", ns.OnUseContainerItem)
    end
    if C_Item and type(C_Item.UseItemByName) == "function" then
        Hook(C_Item, "UseItemByName", OnUseByName)
    else
        Hook(nil, "UseItemByName", OnUseByName)
    end
    Hook(nil, "UseQuestLogSpecialItem", function() Add("quest_items_used") end)
    if C_Timer and C_Timer.After then C_Timer.After(5, function() ns.ScanSatchel(true) end) end
end)

-- ------------------------------------------------------------ catalog
local tip = "Right-clicks and /use on items in your bags, not counting gear you equip or items sold, banked, mailed or traded."
table.insert(ns.STATS.life, { label = "Items used from your bags", fmt = "int", key = "items_used", tip = tip })
table.insert(ns.STATS.life, { label = "Quest items used", fmt = "int", key = "quest_items_used", tip = "Items used from the quest tracker or quest log." })
table.insert(ns.STATS.records, { label = "Most bag space", fmt = "int", rec = "bag_slots_max", tip = "Bag slots across your backpack and equipped bags." })
table.insert(ns.STATS.records, { label = "Most bag slots filled", fmt = "int", rec = "bag_filled_max" })
table.insert(ns.UNIQUES, { set = "itemsheld", label = "Different items carried" })
table.insert(ns.LISTS, { id = "itemsused", name = "Items used most", fmt = "int" })
ns.SATCHEL_STAT_COUNT = 6

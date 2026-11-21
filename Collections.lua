-- LifeTimeStats - Collections: reputation history, currencies, an item log with sources,
-- gathering rates, and mail and trade partners. Ideas from AutoBiographer, Tally, Exlist,
-- Haul and Warbandeer: Characters (public descriptions only, no code). Nothing is sent anywhere.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Tally, Unique, On = ns.Add, ns.Max, ns.Tally, ns.Unique, ns.On
local S = ns.IsSecret

local ITEM_CAP = 1000
ns.ITEM_LOG_CAP = ITEM_CAP
ns.STANDINGS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

local function N(v) if type(v) == "number" and not S(v) and v == v and v ~= math.huge and v ~= -math.huge then return v end end
local function Str(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end
local function B(v) return ns.Bool(v) end
local function Zone() return Str(GetRealZoneText and GetRealZoneText()) or "Unknown" end
local function Level() return N(UnitLevel("player")) or 0 end

-- ------------------------------------------------------------ reputation history
-- rec.reps[faction] = { s = standing 1-8, c = progress in it, m = size of it, f = first seen,
-- u = last change, h = { [standing] = time first reached } }
function ns.ScanFactions(onStandings)
    local ch = ns.char
    if not ch or not C_Reputation or not C_Reputation.GetNumFactions or not C_Reputation.GetFactionDataByIndex then return 0 end
    ch.reps = ch.reps or {}
    local ok, n = pcall(C_Reputation.GetNumFactions)
    if not ok or not N(n) then return 0 end
    local seen, now = 0, time()
    local counts = onStandings and { [5] = 0, [6] = 0, [7] = 0, [8] = 0 }
    for i = 1, n do
        local okI, d = pcall(C_Reputation.GetFactionDataByIndex, i)
        if okI and type(d) == "table" and not S(d) and not (B(d.isHeader) and not B(d.isHeaderWithRep)) then
            local s = N(d.reaction)
            if counts and s then
                for level = 5, 8 do if s >= level then counts[level] = counts[level] + 1 end end
            end
            if Str(d.name) and s and s >= 1 and s <= 8 then
                seen = seen + 1
                local r = ch.reps[d.name]
                if not r then
                    r = { s = s, f = now, h = {} }
                    ch.reps[d.name] = r
                    r.h[s] = now
                    Add("factions_met")
                elseif s > (r.s or 0) then
                    for lvl = (r.s or 0) + 1, s do
                        if not r.h[lvl] then
                            r.h[lvl] = now
                            Add("rep_levels_gained")
                            if lvl >= 6 then Add("rep_levels_" .. lvl) end
                            if ns.Journal and lvl >= 5 then
                                ns.Journal("Reached " .. ns.STANDINGS[lvl] .. " with " .. d.name, "first")
                            end
                        end
                    end
                    r.u = now
                elseif s < (r.s or 0) then
                    Add("rep_levels_lost")
                    r.u = now
                end
                r.s = s
                local cur, lo, hi = N(d.currentStanding), N(d.currentReactionThreshold), N(d.nextReactionThreshold)
                if cur and lo and hi and hi > lo then r.c, r.m = cur - lo, hi - lo end
                if B(d.atWarWith) then r.war = true else r.war = nil end
            end
        end
    end
    if onStandings then onStandings(counts, n) end
    return seen, true
end
-- Coalesce faction bursts. A world-entry refresh can be superseded by an
-- earlier update; the old timer then exits without walking the faction list.
local factionGeneration, factionDue = 0, nil
local function QueueFactions(delay)
    if not C_Timer or not C_Timer.After then return end
    local due = GetTime() + delay
    if factionDue and factionDue <= due then return end
    factionGeneration = factionGeneration + 1
    local generation = factionGeneration
    factionDue = due
    C_Timer.After(delay, function()
        if generation ~= factionGeneration then return end
        factionDue = nil
        local ok, count, scanned = pcall(ns.ScanFactions, ns.OnFactionStandings)
        if not ok then ns.LogError("factions", count) end
        if (not ok or not scanned) and ns.ScanCharacterReputation then
            ns.Guard("reputation", ns.ScanCharacterReputation)()
        end
    end)
end
On("UPDATE_FACTION", function() QueueFactions(0.5) end)
On("PLAYER_ENTERING_WORLD", function() QueueFactions(5) end)

-- ------------------------------------------------------------ currencies
-- Kept on the snapshot (rebuilt every login): rec.snap.cur = { { n, q, m, icon } ... }
function ns.ScanCurrencies()
    local ch = ns.char
    local ci = C_CurrencyInfo
    if not ch or not ci or not ci.GetCurrencyListSize or not ci.GetCurrencyListInfo then return 0 end
    local ok, n = pcall(ci.GetCurrencyListSize)
    if not ok or not N(n) then return 0 end
    local list = {}
    for i = 1, n do
        local okI, d = pcall(ci.GetCurrencyListInfo, i)
        if okI and type(d) == "table" and not S(d) and not d.isHeader and Str(d.name) then
            local q = N(d.quantity) or 0
            list[#list + 1] = { n = d.name, q = q, m = N(d.maxQuantity), icon = N(d.iconFileID) }
            Max("max_cur_" .. d.name, q)
        end
    end
    ch.snap = ch.snap or {}
    ch.snap.cur = list
    return #list
end
On("CURRENCY_DISPLAY_UPDATE", function() pcall(ns.ScanCurrencies) end)
On("PLAYER_ENTERING_WORLD", function() if C_Timer then C_Timer.After(6, function() pcall(ns.ScanCurrencies) end) end end)

-- Every currency across the account: { name, total, { [character] = amount } }
function ns.AccountCurrencies()
    local byName, list = {}, {}
    for _, c in ipairs(ns.RosterCharacters and ns.RosterCharacters() or {}) do
        for _, cur in ipairs((c.snap and c.snap.cur) or {}) do
            local e = byName[cur.n]
            if not e then e = { name = cur.n, total = 0, by = {}, icon = cur.icon }; byName[cur.n] = e; list[#list + 1] = e end
            e.total = e.total + (cur.q or 0)
            e.by[c.name] = cur.q
        end
    end
    table.sort(list, function(a, b) if a.total ~= b.total then return a.total > b.total end return a.name < b.name end)
    return list
end

-- ------------------------------------------------------------ item log
-- rec.items = { { t, n name, id, q quality, src, z zone, l level, il item level, c count } ... }
-- Items of uncommon (green) quality or better, with where they came from.
local lastQuestTurnIn = -100
On("QUEST_TURNED_IN", function() lastQuestTurnIn = GetTime() end)

local function Source()
    local ctx = ns.ctx or {}
    local now = GetTime()
    local boss = ns.GuideLastBoss and ns.GuideLastBoss()
    if boss and now - boss.t <= 180 then return "boss", boss.label end
    if now - lastQuestTurnIn <= 3 then return "quest" end
    if ctx.merchant then return "vendor" end
    if ctx.mail then return "mail" end
    if ctx.trade then return "trade" end
    if ctx.ah then return "auction" end
    local g = ns.lastGather
    if g and now - g[2] < 8 then return "gathered" end
    if IsFishingLoot and B(IsFishingLoot()) then return "fishing" end
    return "loot"
end
ns.ItemSource = Source

local SOURCE_LABEL = { boss = "Boss", quest = "Quest reward", vendor = "Bought", mail = "Mail", trade = "Trade",
    auction = "Auction", gathered = "Gathered", fishing = "Fishing", loot = "Looted", crafted = "Crafted" }
ns.ITEM_SOURCE_LABEL = SOURCE_LABEL

function ns.LogItem(link, qty, quality, src, from)
    local ch = ns.char
    if not ch or type(link) ~= "string" or S(link) then return end
    if type(quality) ~= "number" then quality = ns.LinkQuality and ns.LinkQuality(link) end
    qty = tonumber(qty) or 1
    if not src then src, from = Source() end
    Tally("itemsources", SOURCE_LABEL[src] or src, qty)
    if type(quality) ~= "number" or quality < 2 then return end
    local name = link:match("%[(.-)%]") or link
    local id = tonumber(link:match("item:(%d+)"))
    local il
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok then il = N(v) end
    end
    ch.items = ch.items or {}
    local log = ch.items
    log[#log + 1] = { t = time(), n = name, id = id, q = quality, src = src, from = from, z = Zone(), l = Level(), il = il, c = qty > 1 and qty or nil }
    while #log > ITEM_CAP do if ns.Retention then ns.Retention.Mark(ns.char, "h", "items") end; table.remove(log, 1) end
    Add("items_logged")
    Add("items_logged_q" .. math.min(quality, 5))
    if il then Max("max_item_level_found", il, name) end
    Tally("itemsrc_good", SOURCE_LABEL[src] or src)
    if from then Tally("itemsfrom", from) end
    -- The very first epic already gets a "First epic item" Journal line; later ones get this one.
    if quality >= 4 and ns.Journal and ch.first and ch.first.epic then ns.Journal("Epic item: " .. name .. " (" .. (SOURCE_LABEL[src] or src) .. ")", "first") end
end

local lootHook = ns.OnLootItem
function ns.OnLootItem(link, qty, quality)
    if lootHook then lootHook(link, qty, quality) end
    pcall(ns.LogItem, link, qty, quality)
    -- gathering: what each gathered stack was, and where
    local g = ns.lastGather
    if g and GetTime() - g[2] < 8 then
        Add("gathered_items", tonumber(qty) or 1)
        Tally("gatheritems_zone", Zone(), tonumber(qty) or 1)
    end
end
function ns.OnCreateItem(link, qty)
    pcall(ns.LogItem, link, qty, nil, "crafted")
end

-- ------------------------------------------------------------ mail and trades
local mailTo, mailMoney
local function HookMail()
    if type(SendMail) == "function" and hooksecurefunc then
        hooksecurefunc("SendMail", function(recipient)
            mailTo = Str(recipient)
            mailMoney = N(GetSendMailMoney and GetSendMailMoney()) or 0
        end)
    end
    if type(TakeInboxMoney) == "function" and hooksecurefunc then
        hooksecurefunc("TakeInboxMoney", function(index)
            if not ns.char or not GetInboxHeaderInfo then return end
            local ok, _, _, sender, _, money = pcall(GetInboxHeaderInfo, index)
            sender, money = ok and Str(sender), ok and N(money)
            if sender and money and money > 0 then
                Tally("mailgold_from", sender, money)
                Tally("mailfrom", sender)
            end
        end)
    end
    if type(TakeInboxItem) == "function" and hooksecurefunc then
        hooksecurefunc("TakeInboxItem", function(index)
            if not ns.char or not GetInboxHeaderInfo then return end
            local ok, _, _, sender = pcall(GetInboxHeaderInfo, index)
            sender = ok and Str(sender)
            if sender then Tally("mailfrom", sender); Add("mail_items_taken") end
        end)
    end
end
function ns.InstallCollectionHooks() pcall(HookMail) end
On("PLAYER_LOGIN", function() ns.InstallCollectionHooks() end)
On("MAIL_SEND_SUCCESS", function()
    if not ns.char or not mailTo then return end
    Tally("mailto", mailTo)
    if mailMoney and mailMoney > 0 then Tally("mailgold_to", mailTo, mailMoney); Add("mail_gold_sent", mailMoney) end
    Unique("mail_partners", mailTo)
    mailTo, mailMoney = nil, nil
end)

local trade -- { who, give, get, giveItems, getItems }
On("TRADE_SHOW", function()
    local who = Str(UnitName("NPC"))
    trade = { who = who or "?", give = 0, get = 0, giveItems = 0, getItems = 0 }
end)
local function TradeSnapshot()
    if not trade then return end
    trade.give = N(GetPlayerTradeMoney and GetPlayerTradeMoney()) or trade.give
    trade.get = N(GetTargetTradeMoney and GetTargetTradeMoney()) or trade.get
    local gi, ti = 0, 0
    for i = 1, 7 do
        if GetTradePlayerItemLink and Str(GetTradePlayerItemLink(i)) then gi = gi + 1 end
        if GetTradeTargetItemLink and Str(GetTradeTargetItemLink(i)) then ti = ti + 1 end
    end
    trade.giveItems, trade.getItems = gi, ti
end
On("TRADE_ACCEPT_UPDATE", TradeSnapshot)
On("TRADE_MONEY_CHANGED", TradeSnapshot)
On("TRADE_PLAYER_ITEM_CHANGED", TradeSnapshot)
On("TRADE_TARGET_ITEM_CHANGED", TradeSnapshot)
-- Trackers counts the trade on the "Trade complete." system line; this adds who and what.
function ns.OnTradeComplete()
    if not trade or not ns.char then return end
    local t = trade
    trade = nil
    Tally("tradewith", t.who)
    Unique("trade_partners", t.who)
    if t.give > 0 then Tally("tradegold_to", t.who, t.give); Add("trade_gold_given", t.give) end
    if t.get > 0 then Tally("tradegold_from", t.who, t.get); Add("trade_gold_received", t.get) end
    if t.giveItems > 0 then Add("trade_items_given", t.giveItems) end
    if t.getItems > 0 then Add("trade_items_received", t.getItems) end
end

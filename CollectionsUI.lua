-- LifeTimeStats - Characters page sections for the collections: reputation, currencies,
-- item log, gathering, mail and trades, goals and trends. Registered into the Characters
-- page (RosterUI.lua) before its page is built.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local function Int(n) return ns.FormatInt(math.floor((n or 0) + 0.5)) end
local function Money(n) return ns.FormatMoney(math.floor(n or 0)) end
local function Time(n) return ns.FormatTime(n or 0) end
local function Day(t) return type(t) == "number" and t > 0 and date("%b %d, %Y", t) or "—" end
local DIM = "|cff8a8a8a"
local function F(fmt) return (ns.FMT and ns.FMT[fmt]) or Int end
local function Head(text) return { "", "|cffffb238" .. text:upper() .. "|r", nil, "", "", head = true } end
local function Records() return ns.GuideRecords and ns.GuideRecords() or { { rec = ns.char, name = "" } } end
local function Multi() return #Records() > 1 end

local function QualityColor(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.hex then return c.hex end
    local hex = { [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }
    return hex[q] or "|cffffffff"
end

local function Top(map, n)
    local list = {}
    for k, v in pairs(map or {}) do if type(v) == "number" then list[#list + 1] = { k, v } end end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return tostring(a[1]) < tostring(b[1]) end)
    if n then for i = #list, n + 1, -1 do list[i] = nil end end
    return list
end

-- Sum the named tallies across the shown characters.
local function Tallies(name)
    local out = {}
    for _, r in ipairs(Records()) do
        for k, v in pairs(((r.rec and r.rec.t) or {})[name] or {}) do
            if type(v) == "number" then out[k] = (out[k] or 0) + v end
        end
    end
    return out
end

local R = ns.RosterBuilders
local SECTIONS = ns.ROSTER_SECTIONS

-- ------------------------------------------------------------ reputation
function R.reputation()
    local rows, best = {}, {}
    for _, r in ipairs(Records()) do
        for name, rep in pairs((r.rec and r.rec.reps) or {}) do
            if type(rep) == "table" and type(rep.s) == "number" then
                local b = best[name]
                local better = not b or rep.s > b.rep.s or (rep.s == b.rep.s and (rep.c or 0) > (b.rep.c or 0))
                if better then best[name] = { rep = rep, who = r.name } end
            end
        end
    end
    local list = {}
    for name, b in pairs(best) do list[#list + 1] = { name, b.rep, b.who } end
    table.sort(list, function(a, b) if a[2].s ~= b[2].s then return a[2].s > b[2].s end return a[1] < b[1] end)
    for i, x in ipairs(list) do
        local rep = x[2]
        local standing = ns.STANDINGS[rep.s] or tostring(rep.s)
        local since = rep.h and rep.h[rep.s]
        local reached = {}
        for lvl = 5, 8 do if rep.h and rep.h[lvl] then reached[#reached + 1] = ns.STANDINGS[lvl] .. " " .. Day(rep.h[lvl]) end end
        rows[#rows + 1] = { tostring(i), x[1] .. (rep.war and (DIM .. "  at war|r") or ""),
            (rep.m and rep.m > 0) and (rep.c or 0) / rep.m or (rep.s >= 8 and 1 or 0), standing,
            (rep.m and rep.m > 0) and (Int(rep.c) .. " / " .. Int(rep.m)) or "",
            tip = (Multi() and ("Best: " .. x[3] .. "\n") or "") .. (since and ("Since " .. Day(since)) or "")
                .. (#reached > 0 and ("\n" .. table.concat(reached, "\n")) or "") }
    end
    if #rows == 0 then rows[1] = { "", DIM .. "Factions appear after the reputation panel has been read (a few seconds after login).|r", nil, "", "" } end
    return rows
end

-- ------------------------------------------------------------ currencies
function R.currencies()
    local rows = {}
    local list
    if Multi() then list = ns.AccountCurrencies()
    else
        list = {}
        for _, c in ipairs((ns.char and ns.char.snap and ns.char.snap.cur) or {}) do list[#list + 1] = { name = c.n, total = c.q, max = c.m } end
        table.sort(list, function(a, b) return a.total > b.total end)
    end
    local most = list[1] and list[1].total or 0
    for i, e in ipairs(list) do
        local parts = {}
        for who, q in pairs(e.by or {}) do parts[#parts + 1] = who .. " " .. Int(q) end
        table.sort(parts)
        rows[#rows + 1] = { tostring(i), e.name, most > 0 and e.total / most or 0, Int(e.total),
            (e.max and e.max > 0) and ("max " .. Int(e.max)) or table.concat(parts, " · "), tip = #parts > 0 and table.concat(parts, "\n") or nil }
    end
    if #rows == 0 then rows[1] = { "", DIM .. "No currencies yet (each character's list is read at login).|r", nil, "", "" } end
    return rows
end

-- ------------------------------------------------------------ item log
function R.items()
    local rows, list = {}, {}
    for _, r in ipairs(Records()) do
        for _, e in ipairs((r.rec and r.rec.items) or {}) do
            if type(e) == "table" and type(e.t) == "number" then list[#list + 1] = { e = e, who = r.name } end
        end
    end
    table.sort(list, function(a, b) return a.e.t > b.e.t end)
    local counts = {}
    for _, x in ipairs(list) do counts[x.e.q or 2] = (counts[x.e.q or 2] or 0) + 1 end
    rows[#rows + 1] = { "", string.format("%s green · %s blue · %s purple · %s orange", Int(counts[2]), Int(counts[3]), Int(counts[4]), Int(counts[5])), nil,
        Int(#list), "items logged", head = true }
    local multi = Multi()
    for i, x in ipairs(list) do
        if i > 300 then break end
        local e = x.e
        local src = (ns.ITEM_SOURCE_LABEL and ns.ITEM_SOURCE_LABEL[e.src]) or e.src or "?"
        rows[#rows + 1] = { tostring(i), QualityColor(e.q) .. (e.n or "?") .. "|r" .. (e.c and (" x" .. e.c) or ""), nil,
            e.il and ("ilvl " .. e.il) or "",
            src .. (e.from and (": " .. e.from) or "") .. " · " .. (e.z or "?"),
            tip = date("%b %d, %Y %H:%M", e.t) .. " · level " .. (e.l or "?") .. (multi and ("\n" .. x.who) or "") }
    end
    return rows
end

-- ------------------------------------------------------------ gathering
function R.gathering()
    local rows = {}
    local herbs, ores, fish, items = Tallies("herbzones"), Tallies("orezones"), Tallies("fishzones"), Tallies("gatheritems_zone")
    local zones = {}
    for _, m in ipairs({ herbs, ores, fish, items }) do for z in pairs(m) do zones[z] = true end end
    local list = {}
    for z in pairs(zones) do list[#list + 1] = { z, (herbs[z] or 0) + (ores[z] or 0) + (fish[z] or 0) } end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    local totals = { herb = 0, mine = 0, skin = 0, fish = 0, items = 0 }
    for _, r in ipairs(Records()) do
        local c = (r.rec and r.rec.c) or {}
        totals.herb, totals.mine, totals.skin = totals.herb + (c.gather_herb or 0), totals.mine + (c.gather_mine or 0), totals.skin + (c.gather_skin or 0)
        totals.fish, totals.items = totals.fish + (c.fish or 0), totals.items + (c.gathered_items or 0)
    end
    rows[#rows + 1] = { "", string.format("Herbs %s · ore %s · skins %s · fish %s", Int(totals.herb), Int(totals.mine), Int(totals.skin), Int(totals.fish)),
        nil, Int(totals.items), "items gathered", head = true }
    if #list > 0 then
        rows[#rows + 1] = Head("By zone")
        local most = list[1][2]
        for i, x in ipairs(list) do
            local z = x[1]
            rows[#rows + 1] = { tostring(i), z, most > 0 and x[2] / most or 0, Int(x[2]),
                Int(herbs[z]) .. " herbs · " .. Int(ores[z]) .. " ore · " .. Int(fish[z]) .. " fish · " .. Int(items[z]) .. " items" }
        end
    end
    local sessions = {}
    for _, r in ipairs(Records()) do
        for _, e in ipairs((r.rec and r.rec.sessionlog) or {}) do
            local rate = ns.SessionRates and ns.SessionRates(e) or {}
            if (e.gh or 0) > 0 and (rate.active or 0) >= 300 then sessions[#sessions + 1] = { e = e, perHour = (e.gh or 0) / (rate.active / 3600), who = r.name } end
        end
    end
    table.sort(sessions, function(a, b) return a.perHour > b.perHour end)
    if #sessions > 0 then
        rows[#rows + 1] = Head("Best gathering sessions")
        local best = sessions[1].perHour
        for i, x in ipairs(sessions) do
            if i > 30 then break end
            rows[#rows + 1] = { tostring(i), date("%b %d %H:%M", x.e.s or 0) .. "  " .. DIM .. (x.e.z or "") .. (Multi() and (" · " .. x.who) or "") .. "|r",
                best > 0 and x.perHour / best or 0, Int(x.perHour) .. "/h", Int(x.e.gh) .. " gathered" }
        end
    end
    return rows
end

-- ------------------------------------------------------------ mail and trades
function R.mail()
    local rows = {}
    local function Block(title, counts, gold, goldLabel)
        local list = Top(counts)
        if #list == 0 then return end
        rows[#rows + 1] = Head(title)
        local most = list[1][2]
        for i, x in ipairs(list) do
            if i > 50 then break end
            local g = gold and gold[x[1]]
            rows[#rows + 1] = { tostring(i), x[1], most > 0 and x[2] / most or 0, Int(x[2]), g and (goldLabel .. " " .. Money(g)) or "" }
        end
    end
    Block("Mail sent to", Tallies("mailto"), Tallies("mailgold_to"), "gold sent")
    Block("Mail received from", Tallies("mailfrom"), Tallies("mailgold_from"), "gold received")
    local given, got = Tallies("tradegold_to"), Tallies("tradegold_from")
    local trades = Top(Tallies("tradewith"))
    if #trades > 0 then
        rows[#rows + 1] = Head("Traded with")
        local most = trades[1][2]
        for i, x in ipairs(trades) do
            if i > 50 then break end
            rows[#rows + 1] = { tostring(i), x[1], most > 0 and x[2] / most or 0, Int(x[2]),
                "gave " .. Money(given[x[1]] or 0) .. " · got " .. Money(got[x[1]] or 0) }
        end
    end
    if #rows == 0 then rows[1] = { "", DIM .. "Nothing mailed or traded since 1.19.|r", nil, "", "" } end
    return rows
end

-- ------------------------------------------------------------ goals
function R.goals()
    local rows = {}
    local goals = (ns.char and ns.char.goals) or {}
    for i, g in ipairs(goals) do
        local v, entry = ns.GoalValue(g)
        v = v or 0
        local fmt = entry and entry.stat.fmt or "int"
        rows[#rows + 1] = { tostring(i), entry and entry.stat.label or g.id, math.min(1, v / g.target),
            F(fmt)(v) .. " / " .. F(fmt)(g.target),
            g.done and ("reached " .. Day(g.done)) or (string.format("%.0f%%", math.min(99.9, v * 100 / g.target)) .. " · set " .. Day(g.t)),
            tip = "Remove with /lts goal remove " .. i }
    end
    rows[#rows + 1] = { "", DIM .. "Add a goal: /lts goal <statistic words> <target>, e.g. /lts goal steps 1000000 · /lts goal list · /lts goal remove 2|r", nil, "", "" }
    return rows
end

-- ------------------------------------------------------------ trends
local function Change(a, b)
    if b == 0 then return a > 0 and "new" or "—" end
    local p = (a - b) * 100 / b
    return (p >= 0 and "+" or "") .. string.format("%.0f%%", p)
end
function R.trends()
    local rows = { { "", DIM .. "This week = last 7 days incl. today · this month so far, compared with all of last month.|r", nil, "", "" } }
    local view = (ns.settings and ns.settings.scope == "account" and ns.GetView) and ns.GetView("account", "lifetime") or ns.char
    for i, t in ipairs(ns.Trends(view)) do
        local f = F(t.fmt)
        local top = math.max(t.w0, t.w1)
        rows[#rows + 1] = { tostring(i), t.label, top > 0 and t.w0 / top or 0, f(t.w0),
            "last week " .. f(t.w1) .. " (" .. Change(t.w0, t.w1) .. ") · month " .. f(t.m0) .. " vs " .. f(t.m1),
            tip = "This month " .. f(t.m0) .. ", last month " .. f(t.m1) .. " (" .. Change(t.m0, t.m1) .. ")" }
    end
    return rows
end

-- Register the sections (after People and Farming, before the page is built).
local add = {
    { id = "reputation", name = "Reputation", tip = "Every faction you have met, its standing and progress, and the date each standing from Friendly to Exalted was reached." },
    { id = "currencies", name = "Currencies", tip = "Every currency per character, with the account total." },
    { id = "items",      name = "Item log",   tip = "Every green-or-better item you got since 1.19: when, where, at what level, and from what (boss, quest, vendor, crafted, mail, trade, gathered, looted)." },
    { id = "gathering",  name = "Gathering",  tip = "Herbs, ore, skins and fish by zone, items gathered, and your best gathering sessions per hour." },
    { id = "mail",       name = "Mail & trades", tip = "Who you mailed and traded with, and how much gold went each way." },
    { id = "goals",      name = "Goals",      tip = "Targets for any statistic. Add one with /lts goal <words> <target>." },
    { id = "trends",     name = "Trends",     tip = "This week against last week, and this month against last month." },
}
for _, s in ipairs(add) do SECTIONS[#SECTIONS + 1] = s end

-- LifeTimeStats - Characters page sections for the history: quests, levels, professions,
-- deaths with their map positions, and when you play.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local L = ns.L

local function Int(n) return ns.FormatInt(math.floor((n or 0) + 0.5)) end
local function Money(n) return ns.FormatMoney(math.floor(n or 0)) end
local function Time(n) return ns.FormatTime(n or 0) end
local function Day(t) return type(t) == "number" and t > 0 and date("%b %d, %Y", t) or "—" end
local DIM = "|cff8a8a8a"
local function Head(text) return { "", "|cffffb238" .. text:upper() .. "|r", nil, "", "", head = true } end
local function Records() return ns.GuideRecords and ns.GuideRecords() or { { rec = ns.char, name = "" } } end
local function Multi() return #Records() > 1 end
local function Empty(text) return { { "", DIM .. text .. "|r", nil, "", "" } } end

local R = ns.RosterBuilders
local SECTIONS = ns.ROSTER_SECTIONS

local function Gather(field)
    local list = {}
    for _, r in ipairs(Records()) do
        for _, e in ipairs((r.rec and r.rec[field]) or {}) do
            if type(e) == "table" and type(e.t) == "number" then list[#list + 1] = { e = e, who = r.name } end
        end
    end
    table.sort(list, function(a, b) return a.e.t > b.e.t end)
    return list
end

function R.quests()
    local list = Gather("quests")
    if #list == 0 then return Empty("Quests you turn in from 1.20 on are listed here.") end
    local rows, xp, gold = {}, 0, 0
    for _, x in ipairs(list) do xp, gold = xp + (x.e.xp or 0), gold + (x.e.g or 0) end
    rows[1] = { "", Int(#list) .. " quests · " .. Int(xp) .. " XP · " .. Money(gold), nil, "", "", head = true }
    local multi = Multi()
    for i, x in ipairs(list) do
        if i > 300 then break end
        local e = x.e
        rows[#rows + 1] = { tostring(i), e.n or "?", nil, e.xp and (Int(e.xp) .. " XP") or "",
            (e.d and ("in " .. Time(e.d) .. " · ") or "") .. (e.z or "?") .. " · level " .. (e.l or "?"),
            tip = date("%b %d, %Y %H:%M", e.t) .. (e.g and e.g > 0 and ("\nReward " .. Money(e.g)) or "") .. (multi and ("\n" .. x.who) or "") }
    end
    return rows
end

function R.levels()
    local ch = ns.char
    local snaps = (ch and ch.lvlsnap) or {}
    local levels = {}
    for k in pairs(snaps) do if tonumber(k) then levels[#levels + 1] = tonumber(k) end end
    table.sort(levels, function(a, b) return a > b end)
    if #levels == 0 then return Empty("A snapshot is taken at every level-up.") end
    local rows = {}
    local longest = 1
    for i, lv in ipairs(levels) do
        local s, prev = snaps[tostring(lv)], snaps[tostring(lv - 1)]
        if s.t and prev and prev.t and not prev.partial then longest = math.max(longest, s.t - prev.t) end
        _ = i
    end
    for i, lv in ipairs(levels) do
        local s, prev = snaps[tostring(lv)], snaps[tostring(lv - 1)]
        local took = (s.t and prev and prev.t) and (s.t - prev.t) or nil
        local parts = {}
        if s.gold then parts[#parts + 1] = Money(s.gold) end
        if s.il then parts[#parts + 1] = "ilvl " .. s.il end
        if s.str then parts[#parts + 1] = string.format("str %d agi %d sta %d int %d spi %d", s.str or 0, s.agi or 0, s.sta or 0, s.int or 0, s.spi or 0) end
        rows[#rows + 1] = { tostring(i), "Level " .. lv .. (s.partial and (DIM .. "  (since install)|r") or "") .. (s.zone and (DIM .. "  " .. s.zone .. "|r") or ""),
            took and (took / longest) or nil, took and Time(took) or "—", table.concat(parts, " · "),
            tip = "Reached " .. Day(s.t) .. (s.played and ("\n/played " .. Time(s.played)) or "")
                .. "\nTotals then: " .. Int((s.dist_foot or 0) * (ns.YARDS_TO_STEPS or 1)) .. " steps · " .. Int(s.kills_npc) .. " kills · " .. Int(s.deaths) .. " deaths · " .. Int(s.quests_done) .. " quests" }
    end
    return rows
end

function R.skills()
    local rows = {}
    for _, r in ipairs(Records()) do
        local list = {}
        for name, sk in pairs((r.rec and r.rec.skills) or {}) do if type(sk) == "table" then list[#list + 1] = { name, sk } end end
        table.sort(list, function(a, b) return (a[2].r or 0) > (b[2].r or 0) end)
        if #list > 0 then
            if Multi() then rows[#rows + 1] = Head(r.name) end
            for i, x in ipairs(list) do
                local sk = x[2]
                local spans = {}
                for _, pair in ipairs({ { 1, 75 }, { 75, 150 }, { 150, 225 }, { 225, 300 } }) do
                    local d = ns.SkillSpan(sk, pair[1], pair[2])
                    if d then spans[#spans + 1] = pair[1] .. "-" .. pair[2] .. " in " .. Time(d) end
                end
                rows[#rows + 1] = { tostring(i), x[1], math.min(1, (sk.r or 0) / 300), Int(sk.r),
                    #spans > 0 and table.concat(spans, " · ") or ("since " .. Day(sk.f)) }
            end
        end
    end
    if #rows == 0 then return Empty("Each skill-up is dated from 1.20 on.") end
    return rows
end

function R.deathmap()
    local list = Gather("deathlog")
    if #list == 0 then return Empty("Deaths from 1.20 on are listed here and shown as skulls on the world map.") end
    local rows = { { "", DIM .. "Each death with a known position is a skull on the world map (hover it). /lts deathpins turns them off.|r", nil, "", "" } }
    local multi = Multi()
    for i, x in ipairs(list) do
        if i > 300 then break end
        local e = x.e
        rows[#rows + 1] = { tostring(i), e.c or "Unknown", nil, e.x and string.format("%.1f, %.1f", e.x * 100, e.y * 100) or "—",
            (e.z or "?") .. " · level " .. (e.l or "?") .. " · " .. Day(e.t) .. (multi and (" · " .. x.who) or "") }
    end
    return rows
end

function R.habits()
    local hours, days = {}, {}
    for _, r in ipairs(Records()) do
        local t = (r.rec and r.rec.t) or {}
        for k, v in pairs(t.playhours or {}) do if type(v) == "number" then hours[k] = (hours[k] or 0) + v end end
        for k, v in pairs(t.playweekdays or {}) do if type(v) == "number" then days[k] = (days[k] or 0) + v end end
    end
    if not next(days) then return Empty("Time online by weekday and hour is counted from 1.20 on.") end
    local rows = { Head("By weekday") }
    local most = 0
    for d = 0, 6 do most = math.max(most, days[tostring(d)] or 0) end
    for d = 1, 7 do
        local wd = d % 7 -- Monday first
        local v = days[tostring(wd)] or 0
        local bestH, bestV = nil, 0
        for h = 0, 23 do
            local hv = hours[string.format("%d-%02d", wd, h)] or 0
            if hv > bestV then bestH, bestV = h, hv end
        end
        rows[#rows + 1] = { tostring(d), ns.WEEKDAYS[wd], most > 0 and v / most or 0, Time(v), bestH and string.format("most at %02d:00", bestH) or "" }
    end
    rows[#rows + 1] = Head("By hour of day")
    local byHour, mostH = {}, 0
    for h = 0, 23 do
        local v = 0
        for wd = 0, 6 do v = v + (hours[string.format("%d-%02d", wd, h)] or 0) end
        byHour[h] = v
        mostH = math.max(mostH, v)
    end
    for h = 0, 23 do
        rows[#rows + 1] = { string.format("%02d", h), string.format("%02d:00 - %02d:59", h, h), mostH > 0 and byHour[h] / mostH or 0, Time(byHour[h]), "" }
    end
    return rows
end

for _, s in ipairs({
    { id = "quests",   name = L["Quest history"], tip = "Every quest you turned in: when, where, at what level, the XP and gold it gave, and how long it took from accepting it." },
    { id = "levels",   name = L["Level history"], tip = "A snapshot at each level: time it took, gold, item level, base stats, zone and your totals then." },
    { id = "skills",   name = L["Professions"],   tip = "Each profession and secondary skill with its rank and how long 1-75, 75-150, 150-225 and 225-300 took." },
    { id = "deathmap", name = L["Death map"],     tip = "Every death with its cause, place and map position. Deaths also show as skulls on the world map." },
    { id = "habits",   name = L["Play habits"],   tip = "When you play: time online by weekday and by hour." },
}) do SECTIONS[#SECTIONS + 1] = s end

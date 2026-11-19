-- LifeTimeStats - the story of one statistic: its last 30 days, best day, days active, the value
-- on each of your characters and, for records, every time it was beaten. Shown when a row of a
-- stat page is clicked (the card itself is drawn in UI.lua).
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local function Num(v) return (type(v) == "number" and v == v) and v or 0 end

local function SafeValue(st, view)
    local ok, v, what = pcall(ns.StatValue, st, view)
    if not ok then return 0 end
    return Num(v), what
end

-- Which page and section a stat lives on, e.g. "Battles › Crowd control".
function ns.StatHome(st)
    for cat, list in pairs(ns.STATS) do
        for _, s in ipairs(list) do
            if s == st then
                local name = cat
                for _, c in ipairs(ns.CATEGORIES or {}) do if c.id == cat then name = c.name end end
                if ns.Notebook and ns.Notebook() and ns.NOTEBOOK_PAGE_NAMES and ns.NOTEBOOK_PAGE_NAMES[cat] then name = ns.NOTEBOOK_PAGE_NAMES[cat] end
                local sec = ns.StatSection and ns.StatSection(cat, st)
                return sec and (name .. " › " .. sec) or name, cat
            end
        end
    end
end

-- The next round number above v, in the statistic's own unit: 10, 25, 50, 100, 250, 500,
-- 1,000 ... of the thing itself, of hours for times, of gold for money, of miles for distances.
local NICE = { 1, 2.5, 5 }
local UNIT = { time = 3600, money = 10000, yards = 1760 }
function ns.NextMilestone(v, fmt)
    local unit = UNIT[fmt] or 1
    local x = (v or 0) / unit
    local p = 1
    while true do
        for _, m in ipairs(NICE) do
            local target = m * p
            if target >= 10 or unit > 1 then
                if target > x + 1e-9 then return target * unit end
            end
        end
        p = p * 10
        if p > 1e15 then return nil end
    end
end

-- At the pace of the last 30 days, when does a counter reach its next round number?
-- Returns { rate = per day, target, days, at = timestamp } or nil when there is no pace.
function ns.StatPace(st, h)
    if not st.key or not h or not h.series or (h.value or 0) < 0 then return nil end
    local rate = (h.last30 or 0) / #h.series
    if rate <= 0 then return { rate = 0 } end
    local target = ns.NextMilestone(h.value, st.fmt)
    if not target then return { rate = rate } end
    local days = math.ceil((target - h.value) / rate)
    return { rate = rate, target = target, days = days, at = time() + days * 86400 }
end

-- A statistic definition by its key, record key or label (the Dashboard tiles use these).
function ns.FindStat(id)
    if type(id) ~= "string" then return nil end
    local key = id:match("^%a+:(.+)$") or id
    for _, list in pairs(ns.STATS) do
        for _, st in ipairs(list) do
            if st.key == key or st.rec == key then return st end
        end
    end
    for _, list in pairs(ns.STATS) do
        for _, st in ipairs(list) do if st.label == id then return st end end
    end
end

-- Describe only sources verified for this statistic. Session diagnostics
-- do not establish how a lifetime value from older sessions was collected.
function ns.StatSource(st)
    local key, src = st.key, ns.src
    if key == "dist_foot" or key == "dist_total" or key == "dist_mounted" then
        if src.speedReadable or (src.posDistance or 0) > 0 then return "Sampled movement; a readable source was seen this session." end
        return "Sampled movement; no readable source seen yet this session."
    end
    if key == "items_looted" then
        if (src.loot or 0) > 0 then return "Self-loot chat; matching messages were seen this session." end
        return "Self-loot chat; no matching messages seen yet this session."
    end
    if key == "quests_done" or key == "quests_accepted" then
        if (src.questChat or 0) > 0 then return "Quest events and chat fallback; a fallback was used this session." end
        if (src.questEvents or 0) > 0 then return "Quest events; an event was seen this session." end
        return "Quest events and chat fallback; neither was seen yet this session."
    end
    if key == "money_in" then
        if (src.moneyChat or 0) > 0 then return "Money changes and loot chat fallback; a fallback was used this session." end
        if (src.moneyEvents or 0) > 0 then return "Money changes; an event was seen this session." end
        return "Money changes and loot chat fallback; neither was seen yet this session."
    end
    if key == "time_online" then return "Sampled elapsed time; long gaps are capped." end
end

-- Everything the detail card shows, for one statistic and one character record.
function ns.StatHistory(st, rec, n)
    rec = rec or ns.char
    n = n or 30
    local h = { stat = st, kind = st.rec and "record" or (st.key and "counter" or "computed") }
    h.value, h.what = SafeValue(st, rec)
    h.home = ns.StatHome(st)
    h.source = ns.StatSource(st)
    if ns.session then h.session = SafeValue(st, ns.session) end

    -- daily history: counters are kept per day for the last 40 days
    if st.key then
        h.series = ns.DaySeries(rec, st.key, n)
        local today = h.series[#h.series]
        h.today = today and Num(today.v) or 0
        h.last7, h.last30, h.daysActive = 0, 0, 0
        for i, e in ipairs(h.series) do
            local v = Num(e.v)
            if v ~= 0 then h.daysActive = h.daysActive + 1 end
            h.last30 = h.last30 + v
            if i > #h.series - 7 then h.last7 = h.last7 + v end
            if not h.best or v > h.best.v then h.best = { v = v, d = e.d } end
        end
        if h.best and h.best.v <= 0 then h.best = nil end
        -- every day on file, not just the chart's 30
        local best, active = h.best, 0
        for d, day in pairs(rec.days or {}) do
            local v = Num(day[st.key])
            if v ~= 0 then active = active + 1 end
            if v > 0 and (not best or v > best.v) then best = { v = v, d = d } end
        end
        h.bestEver, h.daysOnFile = best, active
    end

    -- records: every time it was beaten, newest first
    if st.rec then
        h.history = {}
        for _, e in ipairs(rec.rh or {}) do
            if type(e) == "table" and e.k == st.rec and type(e.v) == "number" then table.insert(h.history, 1, e) end
        end
        while #h.history > 50 do table.remove(h.history) end
    end

    -- the same statistic on every character of the account
    h.chars = {}
    for key, r in pairs((ns.db and ns.db.chars) or {}) do
        if type(r) == "table" and r.c then
            local v = SafeValue(st, r)
            local m = r.meta or {}
            table.insert(h.chars, { key = key, name = m.name or key, class = m.class, v = v, me = r == rec })
        end
    end
    table.sort(h.chars, function(a, b)
        if a.v == b.v then return tostring(a.name) < tostring(b.name) end
        return a.v > b.v
    end)
    return h
end

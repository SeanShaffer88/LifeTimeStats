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

-- Everything the detail card shows, for one statistic and one character record.
function ns.StatHistory(st, rec, n)
    rec = rec or ns.char
    n = n or 30
    local h = { stat = st, kind = st.rec and "record" or (st.key and "counter" or "computed") }
    h.value, h.what = SafeValue(st, rec)
    h.home = ns.StatHome(st)
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

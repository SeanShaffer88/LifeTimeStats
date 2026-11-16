-- LifeTimeStats - the overview page of the framed skins.
--   Lifetime Stats: the hero, four headline counters, a lifetime activity line, recent
--     milestones, highlights (your best moments) and recent activity, a page at a time.
--   Stats Explorer: the lifetime score with its motto, recent activity, a card for each part of
--     the adventure (combat, exploration, progression, collections) and pinned statistics.
-- The data helpers below are plain functions (tested offline); the builders take the page
-- helpers from UI.lua.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local ICON = "Interface\\Icons\\"
local function N(v) return (type(v) == "number" and v == v) and v or 0 end
local function c(v, k) return N(v and v.c and v.c[k]) end
local function r(v, k) return N(v and v.r and v.r[k]) end

-- "2m ago", "5h ago", "3 days ago"
function ns.Ago(t, now)
    if type(t) ~= "number" then return "" end
    local d = (now or time()) - t
    if d < 60 then return "just now" end
    if d < 3600 then return math.floor(d / 60) .. "m ago" end
    if d < 86400 then return math.floor(d / 3600) .. "h ago" end
    local days = math.floor(d / 86400)
    return days == 1 and "1 day ago" or (days .. " days ago")
end

-- ------------------------------------------------------------ milestones (the Journal)
local function JournalIcon(e)
    local text = type(e[2]) == "string" and e[2] or ""
    if text:find("^Reached level") then return ICON .. "Spell_Holy_SurgeOfLight" end
    if e.kind == "boss" then return ICON .. "INV_Misc_Head_Dragon_01" end
    if e.kind == "death" then return ICON .. "INV_Misc_Bone_HumanSkull_01" end
    if e.kind == "personalBest" then return ICON .. "INV_Misc_Gem_Pearl_04" end
    if e.kind == "first" then return ICON .. "INV_Misc_Map_01" end
    return ICON .. "INV_Misc_Book_09"
end
local function JournalSub(e)
    local parts = {}
    if type(e.zone) == "string" and e.zone ~= "" then parts[#parts + 1] = e.zone end
    if N(e[3]) > 0 then parts[#parts + 1] = "level " .. e[3] end
    return table.concat(parts, " · ")
end

-- The newest Journal moments: { at, title, sub, icon }.
function ns.OverviewMilestones(rec, n)
    rec = rec or ns.char
    local out = {}
    local j = (rec and rec.journal) or {}
    for i = #j, 1, -1 do
        local e = j[i]
        if type(e) == "table" and type(e[1]) == "number" and type(e[2]) == "string" then
            out[#out + 1] = { at = e[1], title = e[2], sub = JournalSub(e), icon = JournalIcon(e) }
            if #out >= (n or 50) then break end
        end
    end
    return out
end

-- Everything lately, newest first: quests turned in, good items, level-ups and Journal moments.
local QUALITY_ICON = { [2] = "INV_Misc_Bag_10", [3] = "INV_Misc_Gem_Sapphire_02", [4] = "INV_Misc_Gem_Amethyst_02", [5] = "INV_Misc_Gem_Topaz_01" }
function ns.OverviewActivity(rec, n)
    rec = rec or ns.char
    local out = {}
    for _, q in ipairs((rec and rec.quests) or {}) do
        if type(q) == "table" and type(q.t) == "number" then
            out[#out + 1] = { at = q.t, title = "Completed a quest", sub = tostring(q.n or "?"), icon = ICON .. "INV_Misc_Note_01" }
        end
    end
    for _, it in ipairs((rec and rec.items) or {}) do
        if type(it) == "table" and type(it.t) == "number" and N(it.q) >= 2 then
            out[#out + 1] = { at = it.t, title = "Obtained " .. tostring(it.n or "an item"), sub = tostring(it.src or ""), icon = ICON .. (QUALITY_ICON[it.q] or QUALITY_ICON[2]) }
        end
    end
    for _, m in ipairs(ns.OverviewMilestones(rec, 200)) do out[#out + 1] = m end
    table.sort(out, function(a, b) return a.at > b.at end)
    while #out > (n or 60) do table.remove(out) end
    return out
end

-- ------------------------------------------------------------ highlights: your best moments
local function RecordDate(rec, key)
    local best
    for _, e in ipairs((rec and rec.rh) or {}) do
        if type(e) == "table" and e.k == key and type(e.at) == "number" then best = e end
    end
    return best and best.at
end
local function BestDay(rec, key)
    local best
    for d, day in pairs((rec and rec.days) or {}) do
        local v = N(day[key])
        if v > 0 and (not best or v > best.v) then best = { v = v, d = d } end
    end
    return best
end
local function DayTime(d)
    if type(d) ~= "string" or #d ~= 8 then return nil end
    return time({ year = tonumber(d:sub(1, 4)), month = tonumber(d:sub(5, 6)), day = tonumber(d:sub(7, 8)), hour = 12 })
end

-- Up to n of: biggest hit, best boss DPS, most gold in a day, most kills in a fight, most
-- quests in a day, longest kill streak, longest life. Only ones you have.
function ns.OverviewHighlights(rec, n)
    rec = rec or ns.char
    local Int, Money, Time = ns.FormatInt, ns.FormatMoney, ns.FormatTime
    local out = {}
    local function Add(label, value, text, source, at, icon)
        if N(value) > 0 then out[#out + 1] = { label = label, value = text, source = source or "", at = at, icon = ICON .. icon } end
    end
    Add("Biggest hit", r(rec, "max_hit"), Int(r(rec, "max_hit")), rec.r and rec.r.max_hit_what, RecordDate(rec, "max_hit"), "INV_Sword_04")
    Add("Best DPS on a boss", r(rec, "best_boss_dps"), Int(r(rec, "best_boss_dps")), rec.r and rec.r.best_boss_dps_what, RecordDate(rec, "best_boss_dps"), "Spell_Fire_FlameBolt")
    local gold = BestDay(rec, "money_in")
    if gold then Add("Most gold in a day", gold.v, Money(gold.v), "Gold earned", DayTime(gold.d), "INV_Misc_Coin_02") end
    Add("Most kills in one fight", r(rec, "max_fight_kills"), Int(r(rec, "max_fight_kills")), rec.r and rec.r.max_fight_kills_what, RecordDate(rec, "max_fight_kills"), "Ability_Warrior_Cleave")
    local quests = BestDay(rec, "quests_done")
    if quests then Add("Most quests in a day", quests.v, Int(quests.v), "Quests turned in", DayTime(quests.d), "INV_Misc_Note_01") end
    Add("Longest kill streak", r(rec, "max_streak"), Int(r(rec, "max_streak")), "kills without dying", RecordDate(rec, "max_streak"), "Ability_Warrior_Charge")
    Add("Longest life", r(rec, "max_alive"), Time(r(rec, "max_alive")), "online between deaths", RecordDate(rec, "max_alive"), "Spell_Holy_Renew")
    while #out > (n or 5) do table.remove(out) end
    return out
end

-- ------------------------------------------------------------ the lifetime line
-- A running total over the last n days that ends at today's lifetime value.
function ns.CumulativeSeries(rec, valueFn, total, n)
    local days = ns.DaySeries(rec, function(d) return valueFn(d) end, n or 30)
    local after = 0
    for i = #days, 1, -1 do
        days[i].total = N(total) - after
        after = after + N(days[i].v)
    end
    return days
end

-- ------------------------------------------------------------ Stats Explorer: the score's motto
local MOTTOS = {
    { 0, "Every road starts with a single step." },
    { 500, "The road calls, and you answer." },
    { 2000, "A long road, well traveled." },
    { 6000, "Tales of you are told in the taverns." },
    { 15000, "A legend, written one step at a time." },
}
function ns.ScoreMotto(score)
    local m = MOTTOS[1][2]
    for _, e in ipairs(MOTTOS) do if N(score) >= e[1] then m = e[2] end end
    return m
end

-- The four cards of Stats Explorer: { id, title, page, icon, color, stats = { { value, label } x3 } }
function ns.ExplorerCards(view)
    local Int = ns.FormatInt
    local profs = 0
    local st = ns.FindStat and ns.FindStat("Professions learned")
    if st then profs = N((ns.StatValue(st, view))) end
    local level = UnitLevel and UnitLevel("player") or 0
    return {
        { id = "combat", title = "Combat", page = "combat", icon = "combat", color = { 0.55, 0.18, 0.12 },
          stats = { { Int(c(view, "dmg_done")), "Total damage" }, { Int(ns.Kills and ns.Kills(view) or 0), "Enemies slain" }, { Int(r(view, "max_hit")), "Highest hit" } } },
        { id = "exploration", title = "Exploration", page = "travel", icon = "travel", color = { 0.17, 0.38, 0.32 },
          stats = { { Int(c(view, "zones_discovered")), "Zones discovered" }, { Int(c(view, "quests_done")), "Quests completed" }, { Int(r(view, "flightpaths_known")), "Flight paths" } } },
        { id = "progression", title = "Progression", page = "adventure", icon = "crown", color = { 0.55, 0.42, 0.14 },
          stats = { { "Level " .. Int(math.max(N(level), r(view, "max_level"))), "Level" }, { Int(r(view, "max_exalted")), "Factions exalted" }, { Int(profs), "Professions" } } },
        { id = "collections", title = "Collections", page = "life", icon = "chest", color = { 0.36, 0.22, 0.48 },
          stats = { { Int(r(view, "mounts_owned")), "Mounts" }, { Int(r(view, "pets_owned")), "Pets" }, { Int(N(view.un and view.un.itemsheld)), "Items carried" } } },
    }
end

-- ============================================================ widgets
local function Ink(fs) return fs end

-- A list of rows: icon, title, sub line and a right-hand note (e.g. "3 days ago").
local function RowList(body, bw, bh, n, timeline)
    local W, T = ns.W, ns.THEME
    local o = { rows = {} }
    local rh = math.floor(bh / n)
    local left = timeline and 22 or 0
    if timeline then
        local spine = W.Fill(body, T.edge, "BORDER"); spine:SetPoint("TOPLEFT", 6, -rh / 2); spine:SetSize(1, math.max(1, bh - rh)); spine:SetAlpha(0.5)
    end
    for i = 1, n do
        local row = CreateFrame("Frame", nil, body)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rh); row:SetSize(bw, rh)
        if timeline then
            row.dot = row:CreateTexture(nil, "ARTWORK"); row.dot:SetSize(9, 9); row.dot:SetPoint("LEFT", 2, 0)
            row.dot:SetTexture(W.MEDIA .. "dot"); row.dot:SetVertexColor(T.amber[1], T.amber[2], T.amber[3])
        end
        local isz = math.min(34, rh - 8)
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(isz, isz); row.icon:SetPoint("LEFT", left, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.frame = W.Panel(row, { 0, 0, 0, 0 }, T.edge); row.frame:SetPoint("TOPLEFT", row.icon, -1, 1); row.frame:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)
        row.title = W.Text(row, 12, T.text); row.title:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1); row.title:SetPoint("RIGHT", -84, 0); row.title:SetJustifyH("LEFT")
        if ns.Paper() then ns.W.Bold(row.title) end
        row.sub = W.Text(row, 10, T.dim); row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 1); row.sub:SetPoint("RIGHT", -84, 0); row.sub:SetJustifyH("LEFT")
        row.note = W.Text(row, 10, T.dim, nil, "RIGHT"); row.note:SetPoint("RIGHT", -4, 0); row.note:SetWidth(80)
        if i < n then local l = W.Line(row); l:SetPoint("BOTTOMLEFT", left, 0); l:SetPoint("BOTTOMRIGHT"); l:SetHeight(1); l:SetAlpha(0.35) end
        o.rows[i] = row
    end
    o.empty = W.Text(body, 11, T.dim); o.empty:SetPoint("TOP", 0, -12)
    function o:Set(list, emptyText)
        for i, row in ipairs(self.rows) do
            local e = list[i]
            row:SetShown(e ~= nil)
            if e then
                row.icon:SetTexture(e.icon)
                row.title:SetText(e.title)
                row.sub:SetText(e.sub or "")
                row.note:SetText(e.note or ns.Ago(e.at))
            end
        end
        self.empty:SetText(emptyText or "Nothing yet")
        self.empty:SetShown(#list == 0)
    end
    return o
end

-- A line chart with a soft fill under it, for the running total.
local function LineChart(body, bw, bh, n)
    local W, T = ns.W, ns.THEME
    local o = { n = n, lines = {}, fills = {}, dots = {} }
    local axisW, axisH = 46, 16
    local plot = CreateFrame("Frame", nil, body)
    plot:SetPoint("TOPLEFT", axisW, -4); plot:SetSize(bw - axisW - 6, bh - axisH - 8)
    o.plot = plot
    local pw, ph = bw - axisW - 6, bh - axisH - 8
    o.pw, o.ph = pw, ph
    for i = 0, 2 do
        local g = W.Line(plot); g:SetPoint("BOTTOMLEFT", 0, ph * i / 2); g:SetSize(pw, 1); g:SetAlpha(0.25)
    end
    o.ylab = {}
    for i = 0, 2 do
        local t = W.Text(body, 10, T.dim, W.NUM, "RIGHT"); t:SetPoint("RIGHT", plot, "BOTTOMLEFT", -6, ph * i / 2); t:SetWidth(axisW - 6)
        o.ylab[i] = t
    end
    o.xlab = {}
    for i, a in ipairs({ { "BOTTOMLEFT", "LEFT" }, { "BOTTOM", "CENTER" }, { "BOTTOMRIGHT", "RIGHT" } }) do
        local t = W.Text(body, 10, T.dim, nil, a[2]); t:SetPoint("TOP", plot, a[1], 0, -3)
        o.xlab[i] = t
    end
    local col = T.teal or T.amber
    local step = pw / math.max(1, n - 1)
    for i = 1, n do
        local f = plot:CreateTexture(nil, "BACKGROUND")
        f:SetColorTexture(col[1], col[2], col[3], 0.18)
        f:SetWidth(math.max(1, step)); f:SetPoint("BOTTOM", plot, "BOTTOMLEFT", (i - 1) * step, 0)
        o.fills[i] = f
        local d = plot:CreateTexture(nil, "OVERLAY"); d:SetSize(6, 6); d:SetTexture(W.MEDIA .. "dot"); d:SetVertexColor(col[1], col[2], col[3])
        o.dots[i] = d
        if i < n and plot.CreateLine then
            local ln = plot:CreateLine(nil, "ARTWORK")
            if ln.SetThickness then ln:SetThickness(2) end
            ln:SetColorTexture(col[1], col[2], col[3], 1)
            o.lines[i] = ln
        end
    end
    function o:Set(values, labels, fmt)
        fmt = fmt or ns.FormatInt
        local lo, hi
        for _, v in ipairs(values) do lo = lo and math.min(lo, v) or v; hi = hi and math.max(hi, v) or v end
        lo, hi = lo or 0, hi or 1
        if hi <= lo then hi = lo + 1 end
        local function Y(v) return (v - lo) / (hi - lo) * (self.ph - 4) + 2 end
        for i = 1, self.n do
            local v = values[i] or lo
            local x, y = (i - 1) * step, Y(v)
            self.fills[i]:SetHeight(math.max(1, y))
            self.dots[i]:ClearAllPoints(); self.dots[i]:SetPoint("CENTER", self.plot, "BOTTOMLEFT", x, y)
            local ln = self.lines[i]
            if ln and values[i + 1] then
                ln:SetStartPoint("BOTTOMLEFT", self.plot, x, y)
                ln:SetEndPoint("BOTTOMLEFT", self.plot, x + step, Y(values[i + 1]))
            end
        end
        self.ylab[0]:SetText(fmt(lo)); self.ylab[1]:SetText(fmt((lo + hi) / 2)); self.ylab[2]:SetText(fmt(hi))
        self.xlab[1]:SetText(labels[1] or ""); self.xlab[2]:SetText(labels[math.floor(#labels / 2) + 1] or ""); self.xlab[3]:SetText("Today")
    end
    return o
end

-- A small "View all ->" link in a card's title bar.
local function Link(card, text, onClick)
    local W, T = ns.W, ns.THEME
    local b = CreateFrame("Button", nil, card)
    b:SetSize(120, 20); b:SetPoint("TOPRIGHT", -10, -6)
    b.text = W.Text(b, 11, T.amber, nil, "RIGHT"); b.text:SetPoint("RIGHT"); b.text:SetText(text .. "  >")
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function() b.text:SetTextColor(T.text[1], T.text[2], T.text[3]) end)
    b:SetScript("OnLeave", function() b.text:SetTextColor(T.amber[1], T.amber[2], T.amber[3]) end)
    return b
end

-- ============================================================ Lifetime Stats overview
local function BuildLedger(ctx)
    local W, T = ns.W, ns.THEME
    local Int, Money = ns.FormatInt, ns.FormatMoney
    local CW, CH, GAP = ctx.CW, ctx.CH, ctx.GAP
    local p = ctx.NewPage("dashboard")
    local lw = math.floor((CW - GAP) * 0.63)
    local rw = CW - lw - GAP
    local rx = lw + GAP

    -- the hero
    local hero = W.Panel(p, T.tile, T.edge)
    hero:SetPoint("TOPLEFT", 0, 0); hero:SetSize(lw, 84)
    p.portrait = hero:CreateTexture(nil, "ARTWORK"); p.portrait:SetSize(64, 64); p.portrait:SetPoint("LEFT", 10, 0)
    local pf = W.Panel(hero, { 0, 0, 0, 0 }, T.edge); pf:SetPoint("TOPLEFT", p.portrait, -2, 2); pf:SetPoint("BOTTOMRIGHT", p.portrait, 2, -2)
    p.heroName = W.Text(hero, 22, T.text); p.heroName:SetPoint("TOPLEFT", p.portrait, "TOPRIGHT", 14, -6)
    if ns.Paper() then W.Bold(p.heroName) end
    p.heroLine = W.Text(hero, 12, T.dim); p.heroLine:SetPoint("TOPLEFT", p.heroName, "BOTTOMLEFT", 0, -6)
    p.heroScore = W.Text(hero, 12, T.amber, nil, "RIGHT"); p.heroScore:SetPoint("RIGHT", -14, 0)

    -- four headline counters
    local tiles = {
        { label = "Total kills", icon = "sword", stat = "computed:kills", value = function(v) return Int(ns.Kills(v)) end },
        { label = "Quests completed", icon = "scroll", stat = "counter:quests_done", value = function(v) return Int(c(v, "quests_done")) end },
        { label = "Achievement points", icon = "trophy", value = function(v) local _, _, pts = ns.AchTotals(v) return Int(pts) end, page = "achievements" },
        { label = "Gold earned", icon = "coin", stat = "counter:money_in", value = function(v) return Money(c(v, "money_in")) end },
    }
    local tw = (lw - GAP * 3) / 4
    p.tiles = {}
    for i, d in ipairs(tiles) do
        local t = CreateFrame("Button", nil, p)
        t:SetPoint("TOPLEFT", (i - 1) * (tw + GAP), -(84 + GAP)); t:SetSize(tw, 92)
        local card = W.Panel(t, T.tile, T.edge); card:SetAllPoints()
        t.icon = W.Icon(t, d.icon, 26, T.amber); t.icon:SetPoint("TOP", 0, -8)
        t.label = W.Text(t, 11, T.text, nil, "CENTER"); t.label:SetPoint("TOP", t.icon, "BOTTOM", 0, -4); t.label:SetWidth(tw - 10); t.label:SetText(d.label)
        t.value = W.Text(t, 20, T.text, W.NUM, "CENTER"); t.value:SetPoint("TOP", t.label, "BOTTOM", 0, -3); t.value:SetWidth(tw - 10)
        if ns.Paper() then W.Bold(t.value) end
        t.sub = W.Text(t, 10, T.dim, nil, "CENTER"); t.sub:SetPoint("BOTTOM", 0, 6)
        t.def = d
        t.stat = d.stat and ns.FindStat(d.stat == "computed:kills" and "Enemies killed" or d.stat)
        t:SetScript("OnClick", function(self)
            if self.stat then ns.ShowStatDetail(self.stat) elseif d.page then ns.ShowPage(d.page) end
        end)
        W.Tip(t, d.label, d.page and "Click to open the Achievements page." or "Click for its last 30 days, best day and every character.")
        p.tiles[i] = t
    end

    -- the lifetime line
    local y = 84 + GAP + 92 + GAP
    local chartH = math.floor((CH - y - GAP) * 0.52)
    local act = ctx.Panel(p, "Lifetime activity", "timeline", 0, y, lw, chartH, "Your total kills over the last 30 days, ending at today's lifetime total.")
    p.line = LineChart(act.body, act.bw, act.bh, 30)
    p.killStat = ns.FindStat("Enemies killed")
    Link(act, "View details", function() if p.killStat then ns.ShowStatDetail(p.killStat) end end)

    -- recent milestones
    local my = y + chartH + GAP
    local ms = ctx.Panel(p, "Recent milestones", "trophy", 0, my, lw, CH - my, "Your latest Journal moments: first kills, bosses, levels and personal bests.")
    p.milestones = RowList(ms.body, ms.bw, ms.bh, math.max(3, math.floor(ms.bh / 42)))
    Link(ms, "View all", function() ns.ShowPage("journal") end)

    -- highlights and recent activity
    local hh = math.floor((CH - GAP) * 0.56)
    local hl = ctx.Panel(p, "Highlights", "star", rx, 0, rw, hh, "Your best moments: records and best days.")
    p.highlights = RowList(hl.body, hl.bw, hl.bh, math.max(3, math.min(6, math.floor(hl.bh / 54))))
    Link(hl, "Records", function() ns.ShowPage("records") end)
    local ra = ctx.Panel(p, "Recent activity", "clock", rx, hh + GAP, rw, CH - hh - GAP, "Quests, items, levels and Journal moments, newest first.")
    local per = math.max(3, math.floor((ra.bh - 30) / 44))
    p.activity = RowList(ra.body, ra.bw, ra.bh - 30, per)
    p.page, p.per = 1, per
    local prev = W.FlatButton(ra.body, "<", 28, 22, "Newer", "Newer entries.")
    prev:SetPoint("BOTTOMLEFT", 4, 2)
    local nextB = W.FlatButton(ra.body, ">", 28, 22, "Older", "Older entries.")
    nextB:SetPoint("BOTTOMRIGHT", -4, 2)
    p.pageText = W.Text(ra.body, 11, T.text, nil, "CENTER"); p.pageText:SetPoint("BOTTOM", 0, 6)
    prev:SetScript("OnClick", function() p.page = math.max(1, p.page - 1); ns.RefreshWindow() end)
    nextB:SetScript("OnClick", function() p.page = p.page + 1; ns.RefreshWindow() end)

    function p:Update(view, base, sess)
        local ch = ns.char
        if SetPortraitTexture then pcall(SetPortraitTexture, self.portrait, "player") end
        self.heroName:SetText(UnitName("player") or "")
        local className = UnitClass and select(1, UnitClass("player")) or ""
        local faction = UnitFactionGroup and select(1, UnitFactionGroup("player")) or ""
        self.heroLine:SetText(string.format("Level %d  ·  %s  ·  %s", N(UnitLevel("player")), tostring(className or ""), tostring(faction or "")))
        self.heroScore:SetText("Adventurer score  " .. Int((ns.Score(ch))))
        for _, t in ipairs(self.tiles) do
            t.value:SetText(t.def.value(view))
            t.sub:SetText(ctx.RangeName())
        end
        local series = ns.CumulativeSeries(ch, function(d) return N(d.kills_npc) + N(d.kills_pvp) end, ns.Kills(ch), 30)
        local vals, labels = {}, {}
        for i, e in ipairs(series) do vals[i] = e.total; labels[i] = ctx.DayLabel(e.d) end
        self.line:Set(vals, labels, Int)
        self.milestones:Set(ns.OverviewMilestones(ch, #self.milestones.rows), "Your Journal fills in as you play.")
        local hl = {}
        for _, h in ipairs(ns.OverviewHighlights(ch, #self.highlights.rows)) do
            hl[#hl + 1] = { icon = h.icon, title = h.label .. ":  " .. h.value, sub = h.source, at = h.at, note = h.at and date("%b %d, %Y", h.at) or "" }
        end
        self.highlights:Set(hl, "Records appear here as you set them.")
        local all = ns.OverviewActivity(ch, 200)
        local pages = math.max(1, math.ceil(#all / self.per))
        self.page = math.min(self.page, pages)
        local slice = {}
        for i = (self.page - 1) * self.per + 1, math.min(#all, self.page * self.per) do slice[#slice + 1] = all[i] end
        self.activity:Set(slice, "Quests, items and levels appear here as you play.")
        self.pageText:SetText(self.page .. " / " .. pages)
    end
    return p
end

-- ============================================================ Stats Explorer overview
local function BuildExplorer(ctx)
    local W, T = ns.W, ns.THEME
    local Int = ns.FormatInt
    local M = W.MEDIA .. "framed\\"
    local CW, CH, GAP = ctx.CW, ctx.CH, ctx.GAP
    local p = ctx.NewPage("dashboard")
    local pinH = 56
    local bodyH = CH - pinH - GAP
    local lw = math.floor((CW - GAP) * 0.5)
    local rw = CW - lw - GAP
    local rx = lw + GAP

    -- the lifetime score
    local sh = math.min(210, math.floor(bodyH * 0.42))
    local sc = ctx.Panel(p, "Total lifetime score", "star", 0, 0, lw, sh, "Your Adventurer score: levels, kills, quests, bosses, exploration and more. /lts score shows how it is made.")
    p.emblem = sc.body:CreateTexture(nil, "ARTWORK"); p.emblem:SetSize(96, 96); p.emblem:SetPoint("LEFT", 10, 12); p.emblem:SetTexture(M .. "emblem")
    p.score = W.Text(sc.body, 40, T.text, W.NUM); p.score:SetPoint("LEFT", p.emblem, "RIGHT", 18, 10)
    if ns.Paper() then W.Bold(p.score) end
    p.scoreSub = W.Text(sc.body, 15, T.dim); p.scoreSub:SetPoint("TOPLEFT", p.score, "BOTTOMLEFT", 2, -4)
    p.motto = W.Text(sc.body, 13, T.text, nil, "CENTER"); p.motto:SetPoint("BOTTOM", 0, 10); p.motto:SetWidth(sc.bw - 40)
    local dv = sc.body:CreateTexture(nil, "ARTWORK"); dv:SetSize(sc.bw - 60, 9); dv:SetPoint("BOTTOM", 0, 2); dv:SetTexture(M .. "divider")
    dv:SetVertexColor(T.edge[1], T.edge[2], T.edge[3], 0.7)
    sc.body:EnableMouse(true)
    sc.body:SetScript("OnMouseUp", function() local st = ns.FindStat("Adventurer score") if st then ns.ShowStatDetail(st) end end)

    -- recent activity, as a timeline
    local ra = ctx.Panel(p, "Recent activity", "clock", 0, sh + GAP, lw, bodyH - sh - GAP, "Quests, items, levels and Journal moments, newest first.")
    p.activity = RowList(ra.body, ra.bw, ra.bh, math.max(3, math.floor(ra.bh / 48)), true)
    Link(ra, "View all", function() ns.ShowPage("journal") end)

    -- a card for each part of the adventure
    local ch4 = math.floor((bodyH - GAP * 3) / 4)
    p.cards = {}
    for i = 1, 4 do
        local cy = (i - 1) * (ch4 + GAP)
        local b = CreateFrame("Button", nil, p)
        b:SetPoint("TOPLEFT", rx, -cy); b:SetSize(rw, ch4)
        local bg = W.Panel(b, T.tile, T.edge); bg:SetAllPoints()
        b.crest = b:CreateTexture(nil, "ARTWORK"); b.crest:SetSize(46, 46); b.crest:SetPoint("TOPLEFT", 12, -8); b.crest:SetTexture(M .. "crest")
        b.rim = b:CreateTexture(nil, "OVERLAY"); b.rim:SetAllPoints(b.crest); b.rim:SetTexture(M .. "crest_rim")
        b.glyph = b:CreateTexture(nil, "OVERLAY", nil, 2); b.glyph:SetSize(22, 22); b.glyph:SetPoint("CENTER", b.crest, "CENTER", 0, 3)
        b.title = W.Text(b, 16, T.text); b.title:SetPoint("LEFT", b.crest, "RIGHT", 12, 4)
        if ns.Paper() then W.Bold(b.title) end
        b.chev = W.Text(b, 18, T.dim, nil, "RIGHT"); b.chev:SetPoint("TOPRIGHT", -14, -18); b.chev:SetText(">")
        b.stats = {}
        local sw = (rw - 24) / 3
        for k = 1, 3 do
            local v = W.Text(b, 16, T.text, W.NUM); v:SetPoint("BOTTOMLEFT", 12 + (k - 1) * sw, 24); v:SetWidth(sw - 8); v:SetJustifyH("LEFT")
            if ns.Paper() then W.Bold(v) end
            local l = W.Text(b, 10, T.dim); l:SetPoint("TOPLEFT", v, "BOTTOMLEFT", 0, -2); l:SetWidth(sw - 8); l:SetJustifyH("LEFT")
            if k > 1 then local sep = W.Line(b); sep:SetPoint("BOTTOMLEFT", 12 + (k - 1) * sw - 6, 10); sep:SetSize(1, 34); sep:SetAlpha(0.4) end
            b.stats[k] = { v = v, l = l }
        end
        b:SetScript("OnClick", function(self) if self.page then ns.ShowPage(self.page) end end)
        W.Tip(b, function() return b.title:GetText() or "" end, "Click to open the page.")
        p.cards[i] = b
    end

    -- pinned statistics along the bottom
    local strip = W.Panel(p, T.tile, T.edge)
    strip:SetPoint("TOPLEFT", 0, -(bodyH + GAP)); strip:SetSize(CW, pinH)
    local pl = W.Text(strip, 14, T.text); pl:SetPoint("LEFT", 16, 0); pl:SetText("Pinned stats")
    if ns.Paper() then W.Bold(pl) end
    local gear = W.FlatButton(strip, "Pins", 54, 26, "Manage pins", "Choose which statistics are pinned here.")
    gear:SetPoint("RIGHT", -10, 0); gear:SetScript("OnClick", function() if ctx.OpenPins then ctx.OpenPins() end end)
    p.pins = {}
    local px0, pw = 150, (CW - 150 - 80) / 4
    for i = 1, 4 do
        local b = CreateFrame("Button", nil, strip)
        b:SetPoint("LEFT", px0 + (i - 1) * pw, 0); b:SetSize(pw - 10, pinH - 8)
        b.icon = W.Icon(b, "star", 24, T.amber); b.icon:SetPoint("LEFT", 6, 0)
        b.value = W.Text(b, 15, T.text, W.NUM); b.value:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, 4); b.value:SetWidth(pw - 60); b.value:SetJustifyH("LEFT")
        if ns.Paper() then W.Bold(b.value) end
        b.label = W.Text(b, 10, T.dim); b.label:SetPoint("TOPLEFT", b.value, "BOTTOMLEFT", 0, -2); b.label:SetWidth(pw - 60); b.label:SetJustifyH("LEFT")
        if i > 1 then local sep = W.Line(strip); sep:SetPoint("LEFT", px0 + (i - 1) * pw - 8, 0); sep:SetSize(1, pinH - 18); sep:SetAlpha(0.4) end
        b:SetScript("OnClick", function(self) if self.stat then ns.ShowStatDetail(self.stat) end end)
        p.pins[i] = b
    end

    function p:Update(view, base, sess)
        local ch = ns.char
        local score = ns.Score(ch)
        self.score:SetText(Int(score))
        self.scoreSub:SetText("Lifetime")
        self.motto:SetText('"' .. ns.ScoreMotto(score) .. '"')
        local list = ns.OverviewActivity(ch, #self.activity.rows)
        self.activity:Set(list, "Quests, items and levels appear here as you play.")
        for i, card in ipairs(ns.ExplorerCards(view)) do
            local b = self.cards[i]
            b.page = card.page
            b.title:SetText(card.title)
            b.crest:SetVertexColor(card.color[1], card.color[2], card.color[3], 1)
            b.glyph:SetTexture(W.MEDIA .. "icons\\" .. card.icon)
            b.glyph:SetVertexColor(1, 0.92, 0.7)
            for k, s in ipairs(card.stats) do b.stats[k].v:SetText(s[1]); b.stats[k].l:SetText(s[2]) end
        end
        -- your Dashboard pins; until you pin some, four headline statistics
        local _, byID = ns.DashboardPinCatalog()
        local list = {}
        for _, id in ipairs(ns.DashboardPins()) do
            local pin = byID[id]
            if pin and pin.stat then list[#list + 1] = { stat = pin.stat, icon = pin.icon } end
        end
        if #list == 0 then
            for _, d in ipairs({ { "Damage done", "sword" }, { "Enemies killed", "skull" }, { "Quests completed", "scroll" }, { "Gold earned", "coin" } }) do
                local st = ns.FindStat(d[1])
                if st then list[#list + 1] = { stat = st, icon = d[2] } end
            end
        end
        for i, b in ipairs(self.pins) do
            local pin = list[i]
            b:SetShown(pin ~= nil)
            if pin then
                local st = pin.stat
                b.stat = st
                local v = ns.StatValue(st, view)
                b.value:SetText(ns.FormatStat(st, v))
                b.label:SetText(st.label)
                if pin.icon then b.icon:SetTexture(W.MEDIA .. "icons\\" .. pin.icon) end
            end
        end
    end
    return p
end

function ns.BuildFramedOverview(ctx)
    if ns.Explorer() then return BuildExplorer(ctx) end
    return BuildLedger(ctx)
end

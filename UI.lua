-- LifeTimeStats - main window, pages, minimap button, backup dialog (Odometer theme)
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local ADDON, ns = ...

local T, W = ns.THEME, ns.W
local C = W.C
local Int, Time, Money = ns.FormatInt, ns.FormatTime, ns.FormatMoney

local WIN_W, WIN_H = 1140, 740
local HEADER_H, SIDEBAR_W, FOOTER_H, PAD = 44, 176, 24, 10
local CW = WIN_W - SIDEBAR_W - PAD * 2           -- content width  (944)
local CH = WIN_H - HEADER_H - FOOTER_H - PAD * 2 -- content height (652)
local KPI_H, GAP = 72, 10
local NAV_STEP = 31
local KPI_W = (CW - GAP * 3) / 4
local BODY_Y = KPI_H + GAP                        -- y where panels start (82)
local BODY_H = CH - BODY_Y                        -- 570

local win
local pages = {}
local current

-- ------------------------------------------------------------ helpers
local function c(v, k) return (v and v.c and v.c[k]) or 0 end
local function PlusAlways(n, fmt) return "+" .. (fmt or Int)(n or 0) end
local function Plus(n, fmt)
    if not n or n == 0 then return "" end
    return "+" .. (fmt or Int)(n)
end
local function DayLabel(d)
    local y, m, dd = d:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if not y then return d end
    return date("%b %d", time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 }))
end
local function DateLabel(t) return t and date("%b %d %H:%M", t) or "" end
local function Settings() return ns.settings end
local function RangeName()
    local r = Settings().range
    return ({ today = "TODAY", session = "SESSION", week = "LAST 7 DAYS", month = "LAST 30 DAYS" })[r] or "LIFETIME"
end

local function Views()
    local s = Settings()
    local base = ns.GetView(s.scope, "lifetime")
    local view = ns.GetView(s.scope, s.range)
    return view, base, ns.session
end

local function Series(base, key, n)
    local out, labels = {}, {}
    for i, e in ipairs(ns.DaySeries(base, key, n)) do
        out[i] = { e.v }
        labels[i] = DayLabel(e.d)
    end
    return out, labels
end

local function KpiRow(page, defs)
    page.kpis = {}
    for i, d in ipairs(defs) do
        page.kpis[i] = W.Odometer(page, (i - 1) * (KPI_W + GAP), 0, KPI_W, KPI_H, d.label, d.icon, d.tip)
    end
    page.kpiDefs = defs
end

local function UpdateKpis(page, view, base, sess)
    for i, d in ipairs(page.kpiDefs) do
        local v = d.value(view)
        page.kpis[i]:SetValue(v, d.sub and d.sub(view, base, sess) or "", d.exact and d.exact(view) or nil)
    end
end

-- Account scope: each character's part of a counter (Accountwide Stats style).
local function PerChar(key)
    local list = {}
    for _, rec in pairs(ns.db.chars or {}) do
        local v = type(rec) == "table" and rec.c and rec.c[key]
        if v and v > 0 and rec.meta then list[#list + 1] = { rec.meta.name or "?", v, rec.meta.class } end
    end
    if #list < 2 then return nil end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(#list, 8) do
        local e = list[i]
        local cc = e[3] and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e[3]]
        local nm = cc and cc.colorStr and ("|c" .. cc.colorStr .. e[1] .. "|r") or e[1]
        out[#out + 1] = nm .. ": " .. Int(e[2])
    end
    return table.concat(out, "\n")
end

local function StatRows(cat, view, sess)
    local rows = {}
    local perChar = Settings().scope == "account" and Settings().range == "lifetime"
    local range = Settings().range
    local other = range == "session" and ns.GetView(Settings().scope, "today") or sess
    for _, st in ipairs(ns.STATS[cat] or {}) do
        local v, what = ns.StatValue(st, view)
        local ov = ns.StatValue(st, other)
        local empty = view.today and st.rec
        local na, naTip = ns.IsNA(st, v)
        rows[#rows + 1] = {
            (st.label2 and what) and (st.label .. ": " .. what) or st.label,
            na and "n/a" or (empty and "—" or ns.FormatStat(st, v)),
            (Settings().showSession and type(ov) == "number" and ov > 0 and not st.get) and ("+" .. ns.FormatStat(st, ov)) or "",
            tip = na and naTip or st.tip, what = what,
        }
        if perChar and st.key and not na then
            local pc = PerChar(st.key)
            if pc then rows[#rows].tip = ((st.tip and (st.tip .. "\n\n")) or "") .. pc end
        end
    end
    return rows
end

-- ------------------------------------------------------------ page factory
local function NewPage(id)
    local p = CreateFrame("Frame", nil, win.content)
    p:SetAllPoints()
    p:Hide()
    p.id = id
    pages[id] = p
    return p
end

local function Panel(page, title, icon, x, y, w, h, tip)
    return W.Card(page, title, icon, x, y, w, h, tip)
end

-- ============================================================ DASHBOARD
local function BuildDashboard()
    local p = NewPage("dashboard")
    KpiRow(p, {
        { label = "Steps taken", icon = "steps", value = ns.Steps, tip = "Distance on foot divided by a 0.75 m stride.",
          sub = function(v, b, s) return ns.GOLD .. PlusAlways(ns.Steps(s)) .. "|r this session" end },
        { label = "Times jumped", icon = "jump", value = function(v) return c(v, "jumps") end, tip = "Jumps that actually left the ground.",
          sub = function(v, b, s) return ns.GOLD .. PlusAlways(c(s, "jumps")) .. "|r this session" end },
        { label = "Enemies killed", icon = "sword", value = ns.Kills, tip = "Creatures and hostile players that died after you damaged them.",
          sub = function(v, b, s) return ns.GOLD .. PlusAlways(ns.Kills(s)) .. "|r this session · " .. Int(c(v, "kills_pvp")) .. " players" end },
        { label = "Deaths", icon = "skull", value = function(v) return c(v, "deaths") end, tip = "Times you died.",
          sub = function(v) return "K/D " .. ns.GOLD .. string.format("%.1f", ns.Div(ns.Kills(v), c(v, "deaths"))) .. "|r · first: " .. (v.first and v.first.death or "—") end },
    })
    local hw = (CW - GAP) / 2
    local zc = Panel(p, "Kills vs deaths by zone", "combat", 0, BODY_Y, hw, 180, "Your five deadliest zones: kills on the left, deaths on the right.")
    p.mirror = W.Mirror(zc.body, zc.bw, zc.bh - 16, 5, C.amber, C.rust)
    local lg = W.Legend(zc.body, { { "Kills", C.amber }, { "Deaths", C.rust } }); lg:SetPoint("BOTTOMLEFT", 0, 0)

    local gc = Panel(p, "Gold, last 30 days", "coin", hw + GAP, BODY_Y, hw, 180, "Net gold per day: earned minus spent. Red days spent more than they earned.")
    p.goldBig = W.Text(gc.body, 28, T.amber, W.NUM); p.goldBig:SetPoint("TOPLEFT", 0, -8)
    p.goldInfo = W.Text(gc.body, 11, T.dim); p.goldInfo:SetPoint("TOPLEFT", 0, -48); p.goldInfo:SetWordWrap(true); p.goldInfo:SetWidth(132); p.goldInfo:SetJustifyH("LEFT")
    local gb = CreateFrame("Frame", nil, gc.body); gb:SetPoint("TOPLEFT", 142, 0); gb:SetSize(gc.bw - 142, gc.bh)
    p.goldCols = W.Columns(gb, gc.bw - 142, gc.bh, 30, "signed")

    local qw = KPI_W
    local y2 = BODY_Y + 190
    local dc = Panel(p, "Deaths by cause", "skull", 0, y2, qw, 200)
    p.deathRing = W.RingWithLegend(dc.body, dc.bw, dc.bh)
    local bc = Panel(p, "By level band", "adventure", qw + GAP, y2, qw, 200, "Quests, kills (÷10) and deaths for each 10-level band.")
    p.bands = W.Columns(bc.body, bc.bw, bc.bh - 16, 6, "group", 3)
    local bl = W.Legend(bc.body, { { "Quests", C.cream2 }, { "Kills ÷10", C.amber }, { "Deaths", C.rust } }); bl:SetPoint("BOTTOMLEFT", 0, 0)
    local sc = Panel(p, "Gold sources", "coin", (qw + GAP) * 2, y2, qw, 200, "Where all the gold you ever earned came from.")
    p.srcRing = W.RingWithLegend(sc.body, sc.bw, sc.bh)
    local jc = Panel(p, "Jumps by hour", "jump", (qw + GAP) * 3, y2, qw, 200, "When you jump the most, in 2-hour blocks of your local time.")
    p.jumpDots = W.Dots(jc.body, jc.bw, jc.bh, 12, 9)

    local y3 = y2 + 210
    local h3 = CH - y3
    local w1, w2 = 360, 300
    local w3 = CW - w1 - w2 - GAP * 2
    local stc = Panel(p, "Steps per day", "steps", 0, y3, w1, h3)
    p.stepCols = W.Columns(stc.body, stc.bw, stc.bh, 30, "single")
    local rc = Panel(p, "Rates", "timeline", w1 + GAP, y3, w2, h3)
    p.gauges = {}
    local gs = math.min(rc.bh - 30, 92)
    for i = 1, 3 do
        local g = W.TickRing(rc.body, gs, 48, 7, 3)
        g:SetPoint("TOP", rc.body, "TOPLEFT", rc.bw / 6 * (2 * i - 1), 0)
        local lab = W.Text(rc.body, 11, T.text); lab:SetPoint("TOP", g, "BOTTOM", 0, -3)
        local sub = W.Text(rc.body, 10, T.dim); sub:SetPoint("TOP", lab, "BOTTOM", 0, -1)
        p.gauges[i] = { ring = g, lab = lab, sub = sub }
    end
    local fc = Panel(p, "Your legend", "crown", w1 + w2 + GAP * 2, y3, w3, h3, "What defines this character: favourite spell, nemesis, most hunted creature, best fight and homeland.")
    p.legend = {}
    local LH = math.max(16, math.floor(fc.bh / 5))
    for i = 1, 5 do
        local l = W.Text(fc.body, 10, T.dim); l:SetPoint("TOPLEFT", 0, -(i - 1) * LH)
        local v = W.Text(fc.body, 12, T.amber, nil, "RIGHT"); v:SetPoint("TOPRIGHT", 0, -(i - 1) * LH)
        v:SetPoint("LEFT", fc.body, "LEFT", 92, 0)
        p.legend[i] = { l = l, v = v }
    end

    function p:Update(view, base, sess)
        UpdateKpis(self, view, base, sess)
        -- zones
        local zk = ns.TopList(base, "zonekills", 5)
        local zd = base.t.zonedeaths or {}
        local list = {}
        for i, e in ipairs(zk) do list[i] = { e[1], e[2], zd[e[1]] or 0 } end
        self.mirror:Set(list)
        -- gold
        local vals, labels = {}, {}
        local net, inn, out, best = 0, 0, 0, 0
        for i, e in ipairs(ns.DaySeries(base, function(d) return (d.money_in or 0) - (d.money_out or 0) end, 30)) do
            vals[i] = { e.v }; labels[i] = DayLabel(e.d)
            net = net + e.v; best = math.max(best, e.v)
        end
        for _, e in ipairs(ns.DaySeries(base, "money_in", 30)) do inn = inn + e.v end
        for _, e in ipairs(ns.DaySeries(base, "money_out", 30)) do out = out + e.v end
        self.goldBig:SetText(Money(net))
        self.goldInfo:SetText("Net, last 30 days\nEarned " .. Money(inn) .. "\nSpent " .. Money(out) .. "\nBest day " .. Money(best))
        self.goldCols:Set(vals, { C.amber }, labels, { labels[1], labels[15], "Today" }, Money, { "Net gold" })
        -- deaths
        local o = c(base, "deaths_fatigue") + c(base, "deaths_slime")
        self.deathRing:Set({
            { "Creatures", c(base, "deaths_npc"), C.amber }, { "Players", c(base, "deaths_pvp"), C.rust },
            { "Falling", c(base, "deaths_fall"), C.cream2 }, { "Drowning", c(base, "deaths_drown"), C.teal },
            { "Fire / lava", c(base, "deaths_lava"), C.amber2 or C.rust }, { "Other", o, C.dim },
        }, Int(c(base, "deaths")), "deaths")
        -- bands
        local bv, bLabels = {}, {}
        local bq, bk, bd = base.t.bandquests or {}, base.t.bandkills or {}, base.t.banddeaths or {}
        for i = 1, 6 do
            local lo = (i - 1) * 10
            local key = (lo == 0 and 1 or lo) .. "-" .. (lo + 9)
            bv[i] = { bq[key] or 0, (bk[key] or 0) / 10, bd[key] or 0 }
            bLabels[i] = "Levels " .. key
        end
        self.bands:Set(bv, { C.cream2, C.amber, C.rust }, bLabels, { "1-9", "20-29", "50-59" }, ns.FMT.num1, { "Quests", "Kills ÷10", "Deaths" })
        -- gold sources
        local loot, quest, vend, ah, mail = c(base, "money_loot"), c(base, "money_quest"), c(base, "money_vendor_in"), c(base, "money_ah_in"), c(base, "money_mail_in")
        local other = math.max(0, c(base, "money_in") - loot - quest - vend - ah - mail)
        self.srcRing:Set({
            { "Looted", loot, C.amber }, { "Quests", quest, C.cream2 }, { "Vendors", vend, C.amber2 },
            { "Auctions", ah, C.teal }, { "Mail", mail, C.rust }, { "Other", other, C.dim },
        }, Money(c(base, "money_in")), "earned", Money)
        -- jumps by hour
        local jh = base.t.jumphour or {}
        local dots = {}
        for b = 1, 12 do dots[b] = (jh[tostring((b - 1) * 2)] or 0) + (jh[tostring((b - 1) * 2 + 1)] or 0) end
        self.jumpDots:Set(dots, { "00", "12", "23" })
        -- steps per day
        local sv, sl = Series(base, function(d) return (d.dist_foot or 0) * ns.YARDS_TO_STEPS end, 30)
        self.stepCols:Set(sv, { C.cream2 }, sl, { sl[1], sl[15], "Today" }, Int, { "Steps" }, true)
        -- rates
        local r1 = ns.Div(c(base, "crits") * 100, c(base, "hits"))
        local r2 = ns.Div(c(base, "quests_done") * 100, c(base, "quests_accepted"))
        local r3 = ns.Div(c(base, "runs_party_boss") * 100, c(base, "runs_party"))
        local R = {
            { r1, C.amber, "Crit rate", Int(c(base, "crits")) .. " crits" },
            { r2, C.cream2, "Quests finished", Int(c(base, "quests_done")) .. " / " .. Int(c(base, "quests_accepted")) },
            { r3, C.rust, "Runs with boss", Int(c(base, "runs_party_boss")) .. " / " .. Int(c(base, "runs_party")) },
        }
        for i, g in ipairs(self.gauges) do
            g.ring:SetPercent(R[i][1], R[i][2], string.format("%d%%", R[i][1] + 0.5))
            g.lab:SetText(R[i][3]); g.sub:SetText(R[i][4])
        end
        -- legend
        local function Top(id) local t = ns.TopList(base, id, 1)[1] return t and tostring(t[1]) or "—", t and t[2] or 0 end
        local spell, sv = Top("spelldamage")
        local nem = Top("hurtby")
        local hunted, hk = Top("creatures")
        local home = Top("zonetime")
        local dps = base.r and base.r.max_fight_dps
        local rows = {
            { "Signature spell", spell ~= "—" and (spell .. "  " .. ns.GREY .. Int(sv) .. "|r") or "—" },
            { "Nemesis", nem },
            { "Most hunted", hunted ~= "—" and (hunted .. "  " .. ns.GREY .. Int(hk) .. "|r") or "—" },
            { "Best fight", dps and (ns.FMT.num1(dps) .. " dps") or "—" },
            { "Homeland", home },
        }
        for i, e in ipairs(self.legend) do e.l:SetText(rows[i][1]:upper()); e.v:SetText(rows[i][2]) end
    end
end

-- ============================================================ CATEGORY PAGES
local function CategoryPage(id, kpis, panels, cols)
    local p = NewPage(id)
    KpiRow(p, kpis)
    local tw = 470
    local tc = Panel(p, (cols and cols.title) or "All statistics", "lists", 0, BODY_Y, tw, BODY_H, "Hover a row to see how it is measured.")
    p.table = W.Table(tc.body, tc.bw, tc.bh, cols and cols.cols or {
        { "STATISTIC", 230, kind = "text" }, { "LIFETIME", 120, kind = "num" }, { "SESSION", 0, kind = "dim" },
    })
    local rx, rw = tw + GAP, CW - tw - GAP
    local y = BODY_Y
    p.panels = {}
    for i, def in ipairs(panels) do
        local h = def.h or (BODY_H - (y - BODY_Y))
        local card = Panel(p, def.title, def.icon, rx, y, rw, h, def.tip)
        p.panels[i] = { def = def, obj = def.build(card.body, card.bw, card.bh) }
        y = y + h + GAP
    end
    function p:Update(view, base, sess)
        UpdateKpis(self, view, base, sess)
        if cols and cols.rows then
            self.table:SetData(cols.rows(view, base, sess), true)
        else
            self.table:SetHeader(2, RangeName())
            self.table:SetHeader(3, Settings().range == "session" and "TODAY" or "SESSION")
            self.table:SetData(StatRows(id, view, sess), true)
        end
        for _, pn in ipairs(self.panels) do pn.def.update(pn.obj, view, base, sess) end
    end
    return p
end

local function RingPanel(title, icon, h, partsFn, center, tip)
    return { title = title, icon = icon, h = h, tip = tip,
        build = function(b, bw, bh) return W.RingWithLegend(b, bw, bh) end,
        update = function(o, v, base, s) local parts, big, small, fmt = partsFn(base, v, s); o:Set(parts, big, small, fmt) end }
end
local function ListPanel(title, icon, h, tally, fmt, n, tip)
    return { title = title, icon = icon, h = h, tip = tip,
        build = function(b, bw, bh) return W.BarList(b, bw, bh, n or 6) end,
        update = function(o, v, base) o:Set(ns.TopList(base, tally, n or 6), fmt) end }
end
local function DayPanel(title, icon, h, mode, series, fn, colors, names, fmt, tip)
    return { title = title, icon = icon, h = h, tip = tip,
        build = function(b, bw, bh)
            local o = { cols = W.Columns(b, bw, bh - (series > 1 and 16 or 0), 30, mode, series) }
            if series > 1 then
                local items = {}
                for i, n in ipairs(names) do items[i] = { n, colors[i] } end
                local lg = W.Legend(b, items); lg:SetPoint("BOTTOMLEFT", 0, 0)
            end
            return o
        end,
        update = function(o, v, base)
            local vals, labels = {}, {}
            for i, e in ipairs(ns.DaySeries(base, function(d) return d end, 30)) do
                vals[i] = fn(e.v or {}); labels[i] = DayLabel(e.d)
            end
            o.cols:Set(vals, colors, labels, { labels[1], labels[15], "Today" }, fmt, names, series == 1)
        end }
end

local function BuildCategories()
    CategoryPage("travel", {
        { label = "Total distance (yd)", icon = "travel", value = function(v) return c(v, "dist_total") end,
          sub = function(v, b, s) return string.format("%.0f mi · %s mi session", c(v, "dist_total") / 1760, ns.GOLD .. string.format("+%.1f", c(s, "dist_total") / 1760) .. "|r") end },
        { label = "On foot (yd)", icon = "steps", value = function(v) return c(v, "dist_foot") end, sub = function(v) return Int(ns.Steps(v)) .. " steps" end },
        { label = "Mounted (yd)", icon = "horseshoe", value = function(v) return c(v, "dist_mount") end, sub = function(v) return Int(c(v, "mount_ups")) .. " mount-ups" end },
        { label = "Flight paths (yd)", icon = "wing", value = function(v) return c(v, "dist_taxi") end, sub = function(v) return Int(c(v, "flights")) .. " flights · " .. Money(c(v, "money_taxi")) end },
    }, {
        RingPanel("How you travel", "travel", 180, function(b)
            return { { "On foot", c(b, "dist_foot"), C.cream2 }, { "Mounted", c(b, "dist_mount"), C.amber }, { "Flight", c(b, "dist_taxi"), C.amber2 },
                     { "Ghost", c(b, "dist_ghost"), C.dim }, { "Swim", c(b, "dist_swim"), C.teal } },
                c(b, "dist_total") >= 1760 and string.format("%.1f", c(b, "dist_total") / 1760) or Int(c(b, "dist_total")),
                c(b, "dist_total") >= 1760 and "miles" or "yards", function(n) return string.format("%.0f%%", ns.Div(n * 100, c(b, "dist_total"))) end
        end),
        ListPanel("Zones by distance", "travel", 170, "zonedist", function(n) return n >= 10000 and string.format("%.0fk yd", n / 1000) or (Int(n) .. " yd") end, 6),
        DayPanel("Distance per day", "timeline", nil, "stack", 2, function(d) return { d.dist_foot or 0, d.dist_mount or 0 } end,
            { C.cream2, C.amber }, { "On foot", "Mounted" }, function(n) return Int(n) .. " yd" end),
    })

    CategoryPage("combat", {
        { label = "Hits landed", icon = "sword", value = function(v) return c(v, "hits") end, sub = function(v)
              if c(v, "dmg_done") > 0 then return Int(c(v, "dmg_done")) .. " damage · " .. string.format("%.1f DPS", ns.Div(c(v, "dmg_done"), c(v, "time_combat"))) end
              return Int(c(v, "fights_won")) .. " fights won"
          end },
        { label = "Critical hits", icon = "star", value = function(v) return c(v, "crits") end, sub = function(v) return string.format("%.1f%% crit rate", ns.Div(c(v, "crits") * 100, c(v, "hits"))) end },
        { label = "Dodges + parries", icon = "shield", value = function(v) return c(v, "in_dodge") + c(v, "in_parry") end, sub = function(v) return Int(c(v, "in_dodge")) .. " dodged · " .. Int(c(v, "in_parry")) .. " parried" end },
        { label = "Enemy players killed", icon = "crown", value = function(v) return c(v, "kills_pvp") end, sub = function(v) return Int(c(v, "hk_server")) .. " honorable kills" end },
    }, {
        RingPanel("Your attacks", "sword", 180, function(b)
            return { { "Hits", math.max(0, c(b, "hits") - c(b, "crits")), C.cream2 }, { "Crits", c(b, "crits"), C.amber },
                     { "Missed", c(b, "out_miss"), C.dim }, { "Dodged", c(b, "out_dodge"), C.rust }, { "Parried", c(b, "out_parry"), C.amber2 },
                     { "Blocked", c(b, "out_block"), C.teal }, { "Resisted", c(b, "out_resist"), C.edge or C.dim } },
                Int(c(b, "hits") + c(b, "misses_out")), "attacks"
        end),
        RingPanel("Attacks on you", "shield", 180, function(b)
            return { { "Hits", math.max(0, c(b, "hits_taken") - c(b, "crits_taken")), C.cream2 }, { "Crits", c(b, "crits_taken"), C.rust },
                     { "Dodged", c(b, "in_dodge"), C.amber }, { "Parried", c(b, "in_parry"), C.amber2 }, { "Blocked", c(b, "in_block"), C.teal },
                     { "Missed", c(b, "in_miss"), C.dim }, { "Resisted", c(b, "in_resist"), T.tileHi } },
                Int(c(b, "hits_taken") + c(b, "avoided_in")), "incoming"
        end),
        DayPanel("Kills per day", "sword", nil, "single", 1, function(d) return { (d.kills_npc or 0) + (d.kills_pvp or 0) } end, { C.amber }, { "Kills" }, Int),
    })

    CategoryPage("deaths", {
        { label = "Deaths", icon = "skull", value = function(v) return c(v, "deaths") end, sub = function(v) return string.format("%.1f kills per death", ns.Div(ns.Kills(v), c(v, "deaths"))) end },
        { label = "Corpse runs", icon = "travel", value = function(v) return c(v, "corpse_runs") end, sub = function(v) return "longest " .. Time(v.r.max_corpse_time or 0) end },
        { label = "Falls survived", icon = "fall", value = function(v) return c(v, "falls_survived") end, sub = function(v) return "biggest " .. Int(v.r.max_fall_survived or 0) .. " dmg" end },
        { label = "Seconds dead", icon = "clock", value = function(v) return c(v, "time_dead") end, sub = function(v) return Time(c(v, "time_dead")) .. " total" end },
    }, {
        RingPanel("Deaths by cause", "skull", 180, function(b)
            return { { "Creatures", c(b, "deaths_npc"), C.amber }, { "Players", c(b, "deaths_pvp"), C.rust }, { "Falling", c(b, "deaths_fall"), C.cream2 },
                     { "Drowning", c(b, "deaths_drown"), C.teal }, { "Fatigue", c(b, "deaths_fatigue"), C.dim }, { "Lava / fire", c(b, "deaths_lava"), C.amber2 } },
                Int(c(b, "deaths")), "deaths"
        end),
        ListPanel("Killed most often by", "skull", 170, "killers", Int, 6),
        ListPanel("Zones by deaths", "travel", nil, "zonedeaths", Int, 7),
    })

    CategoryPage("adventure", {
        { label = "Quests completed", icon = "scroll", value = function(v) return c(v, "quests_done") end, sub = function(v) return string.format("%.0f%% of accepted", ns.Div(c(v, "quests_done") * 100, c(v, "quests_accepted"))) end },
        { label = "Dungeon runs", icon = "tower", value = function(v) return c(v, "runs_party") end, sub = function(v) return Int(c(v, "runs_party_boss")) .. " with a boss kill" end },
        { label = "Dungeon bosses", icon = "tower", value = function(v) return c(v, "boss_kills_party") end, sub = function(v) return Int((v.un and v.un.bosses_party) or 0) .. " different" end },
        { label = "Raid bosses", icon = "crown", value = function(v) return c(v, "boss_kills_raid") end, sub = function(v) return Int(c(v, "raid_clears")) .. " full clears" end },
    }, {
        { title = "By level band", icon = "adventure", h = 180, tip = "Quests, kills (÷10) and deaths for each 10-level band.",
          build = function(b, bw, bh)
              local o = W.Columns(b, bw, bh - 16, 6, "group", 3)
              local lg = W.Legend(b, { { "Quests", C.cream2 }, { "Kills ÷10", C.amber }, { "Deaths", C.rust } }); lg:SetPoint("BOTTOMLEFT", 0, 0)
              return o
          end,
          update = function(o, v, base)
              local bv, bl = {}, {}
              local bq, bk, bd = base.t.bandquests or {}, base.t.bandkills or {}, base.t.banddeaths or {}
              for i = 1, 6 do
                  local lo = (i - 1) * 10
                  local key = (lo == 0 and 1 or lo) .. "-" .. (lo + 9)
                  bv[i] = { bq[key] or 0, (bk[key] or 0) / 10, bd[key] or 0 }; bl[i] = "Levels " .. key
              end
              o:Set(bv, { C.cream2, C.amber, C.rust }, bl, { "1-9", "20-29", "50-59" }, ns.FMT.num1, { "Quests", "Kills ÷10", "Deaths" })
          end },
        ListPanel("Instance runs", "tower", 170, "instances", Int, 6),
        DayPanel("XP per day", "adventure", nil, "single", 1, function(d) return { d.xp or 0 } end, { C.amber }, { "XP" }, Int),
    })

    CategoryPage("wealth", {
        { label = "Gold earned", icon = "coin", value = function(v) return math.floor(c(v, "money_in") / 10000) end, exact = function(v) return Money(c(v, "money_in")) end, sub = function(v) return Money(c(v, "money_in")) end },
        { label = "Gold spent", icon = "coin", value = function(v) return math.floor(c(v, "money_out") / 10000) end, exact = function(v) return Money(c(v, "money_out")) end, sub = function(v) return Money(c(v, "money_out")) end },
        { label = "Items looted", icon = "chest", value = function(v) return c(v, "items_looted") end, sub = function(v) return Int(c(v, "loot_q4")) .. " epics · " .. Int(c(v, "loot_q3")) .. " blues" end },
        { label = "Repairs", icon = "shield", value = function(v) return c(v, "repairs") end, sub = function(v) return Money(c(v, "money_repair")) .. " spent" end },
    }, {
        RingPanel("Gold sources", "coin", 180, function(b)
            local loot, quest, vend, ah, mail = c(b, "money_loot"), c(b, "money_quest"), c(b, "money_vendor_in"), c(b, "money_ah_in"), c(b, "money_mail_in")
            return { { "Looted", loot, C.amber }, { "Quests", quest, C.cream2 }, { "Vendors", vend, C.amber2 }, { "Auctions", ah, C.teal },
                     { "Mail", mail, C.rust }, { "Other", math.max(0, c(b, "money_in") - loot - quest - vend - ah - mail), C.dim } },
                Money(c(b, "money_in")), "earned", Money
        end),
        RingPanel("Loot by quality", "chest", 180, function(b)
            return { { "Poor", c(b, "loot_q0"), C.dim }, { "Common", c(b, "loot_q1"), C.cream }, { "Uncommon", c(b, "loot_q2"), C.teal },
                     { "Rare", c(b, "loot_q3"), C.cream2 }, { "Epic", c(b, "loot_q4"), C.amber }, { "Legendary", c(b, "loot_q5"), C.rust } },
                Int(c(b, "items_looted")), "items"
        end),
        DayPanel("Net gold per day", "coin", nil, "signed", 1, function(d) return { (d.money_in or 0) - (d.money_out or 0) } end, { C.amber }, { "Net gold" }, Money),
    })

    CategoryPage("social", {
        { label = "Chat messages", icon = "social", value = function(v) return c(v, "chat_sent") end, sub = function(v) return Int(c(v, "whispers_sent")) .. " whispers sent" end },
        { label = "Emotes", icon = "social", value = function(v) return c(v, "emotes") end, sub = function(v) return Int(c(v, "emote_DANCE")) .. " dances · " .. Int(c(v, "emote_CHICKEN")) .. " chickens" end },
        { label = "Critters loved", icon = "heart", value = function(v) return c(v, "critters_loved") end, sub = function(v) return Int(c(v, "critters_love_kill")) .. " then killed · " .. Int(c(v, "ui_errors")) .. " red errors" end },
        { label = "Stats checked", icon = "dashboard", value = function(v) return c(v, "lts_opens") end, sub = function() return "Yes, this counts too." end },
    }, {
        ListPanel("Favourite emotes", "social", 180, "emotes", Int, 6),
        ListPanel("Red error messages", "skull", 180, "uierrors", Int, 6),
        DayPanel("Chat messages per day", "social", nil, "single", 1, function(d) return { d.chat_sent or 0 } end, { C.cream2 }, { "Messages" }, Int),
    })

    CategoryPage("life", {
        { label = "Times drunk", icon = "social", value = function(v) return c(v, "times_drunk") end, sub = function(v) return Int(c(v, "drunk_smashed")) .. " completely smashed" end },
        { label = "Campfires lit", icon = "star", value = function(v) return c(v, "campfires") end, sub = function(v) return Int(c(v, "nights_camped")) .. " nights camped out" end },
        { label = "Hearth locations", icon = "star", value = function(v) return (v.un and v.un.bindspots) or 0 end, sub = function(v) return Int((v.un and v.un.hearthstones) or 0) .. " unique hearthstones · " .. Int(c(v, "hearths")) .. " used" end },
        { label = "Books read", icon = "scroll", value = function(v) return c(v, "books_read") end, sub = function(v) return Int(c(v, "potions")) .. " potions drunk" end },
    }, {
        RingPanel("Where you rest at night", "clock", 180, function(b)
            return { { "Camped out", c(b, "nights_camped"), C.amber }, { "Inn or city", c(b, "nights_inn"), C.cream2 } },
                Int(c(b, "nights_camped") + c(b, "nights_inn")), "logouts"
        end),
        ListPanel("Where you camped", "travel", 170, "campzones", Int, 6),
        DayPanel("Time in the wild per day", "timeline", nil, "single", 1, function(d) return { d.time_wild or 0 } end, { C.amber }, { "Wild" }, Time),
    })

    CategoryPage("records", {
        { label = "Biggest hit", icon = "sword", value = function(v) return v.r.max_hit or 0 end, sub = function(v) return v.r.max_hit_what or "" end },
        { label = "Biggest crit", icon = "star", value = function(v) return v.r.max_crit or 0 end, sub = function(v) return v.r.max_crit_what or "" end },
        { label = "Longest kill streak", icon = "skull", value = function(v) return v.r.max_streak or 0 end, sub = function() return "kills without dying" end },
        { label = "Biggest heal", icon = "heart", value = function(v) return v.r.max_heal or 0 end, sub = function(v) return v.r.max_heal_what or "" end },
    }, {
        ListPanel("Time per level", "clock", 280, "leveltime", Time, 11, "Online time spent on each level (only levels started with the addon running)."),
        ListPanel("Most cast spells", "star", nil, "spells", Int, 10),
    }, {
        title = "Records",
        cols = { { "RECORD", 250, kind = "text" }, { "BEST", 100, kind = "num" }, { "SOURCE", 0, kind = "dim" } },
        rows = function(view)
            local rows = {}
            for _, st in ipairs(ns.STATS.records) do
                local v, what = ns.StatValue(st, view)
                local na, naTip = ns.IsNA(st, v)
                rows[#rows + 1] = { st.label, na and "n/a" or ((view.today) and "—" or ns.FormatStat(st, v)), what or "", tip = na and naTip or st.tip, what = what }
            end
            return rows
        end,
    })
end

-- ============================================================ FASTEST & UNIQUES
local function BuildFastest()
    local p = NewPage("fastest")
    KpiRow(p, {
        { label = "Unique NPCs met", icon = "person", value = function(v) return (v.un and v.un.npcs) or 0 end, sub = function() return "talked, traded, trained" end },
        { label = "Unique creatures killed", icon = "sword", value = function(v) return (v.un and v.un.creatures) or 0 end, sub = function(v) return "of " .. Int(c(v, "kills_npc")) .. " kills" end },
        { label = "Dungeon bosses", icon = "tower", value = function(v) return c(v, "boss_kills_party") end, sub = function(v) return Int((v.un and v.un.bosses_party) or 0) .. " unique · " .. Int(c(v, "runs_party")) .. " runs" end },
        { label = "Raid bosses", icon = "crown", value = function(v) return c(v, "boss_kills_raid") end, sub = function(v) return Int((v.un and v.un.bosses_raid) or 0) .. " unique · " .. Int(c(v, "raid_clears")) .. " full clears" end },
    })
    local w1, w2 = 380, 260
    local w3 = CW - w1 - w2 - GAP * 2
    local fc = Panel(p, "Fastest times", "fastest", 0, BODY_Y, w1, BODY_H, "Lower is better. Instance clears count from entering to the last boss; a run only qualifies if it killed as many bosses as your best run there.")
    p.fastT = W.Table(fc.body, fc.bw, fc.bh, { { "FASTEST", 170, kind = "text" }, { "BEST", 72, kind = "num" }, { "WHERE / WHEN", 0, kind = "dim" } })
    local uc = Panel(p, "Uniques", "star", w1 + GAP, BODY_Y, w2, BODY_H, "How many different things you have met, killed, visited or used.")
    p.uniqT = W.Table(uc.body, uc.bw, uc.bh, { { "DIFFERENT", 150, kind = "text" }, { "TOTAL", 46, kind = "num" }, { "NEW", 0, kind = "dim" } })
    local ff = Panel(p, "Firsts", "clock", w1 + w2 + GAP * 2, BODY_Y, w3, BODY_H, "The first time something happened after LifeTimeStats was installed.")
    p.firstT = W.Table(ff.body, ff.bw, ff.bh, { { "FIRST", 86, kind = "text" }, { "WHAT", 104, kind = "num" }, { "WHEN", 0, kind = "dim" } })

    function p:Update(view, base, sess)
        UpdateKpis(self, base, base, sess)
        local rows = {}
        local f, fw, fd = base.f or {}, base.fw or {}, base.fd or {}
        for _, e in ipairs(ns.FASTEST) do
            rows[#rows + 1] = { e.label, f[e.key] and Time(f[e.key]) or "—", f[e.key] and ((fw[e.key] or "") .. "  " .. (fd[e.key] and date("%b %d", fd[e.key]) or "")) or "not yet" }
        end
        local dyn = {}
        for k, v in pairs(f) do
            local kind, name = k:match("^(%a+):(.+)$")
            if kind then
                dyn[#dyn + 1] = { (kind == "run" and "" or "Full clear: ") .. name, Time(v), (fw[k] or "") .. "  " .. (fd[k] and date("%b %d", fd[k]) or ""),
                    tip = kind == "run" and "Fastest run, entering to last boss." or "Fastest full raid clear." }
            end
        end
        table.sort(dyn, function(a, b) return a[1] < b[1] end)
        for _, r in ipairs(dyn) do rows[#rows + 1] = r end
        self.fastT:SetData(rows, true)

        local ur = {}
        local un, sun = base.un or {}, sess.un or {}
        for _, e in ipairs(ns.UNIQUES) do
            ur[#ur + 1] = { e.label, Int(un[e.set] or 0), Plus(sun[e.set]) }
        end
        self.uniqT:SetData(ur, true)

        local fr = {}
        local first, firstd = base.first or {}, base.firstd or {}
        for _, e in ipairs(ns.FIRSTS) do
            local short = e.label:gsub("^First ", "")
            short = short:sub(1, 1):upper() .. short:sub(2)
            fr[#fr + 1] = { short, first[e.key] or "not yet", firstd[e.key] and DateLabel(firstd[e.key]) or "", tipTitle = e.label, tip = first[e.key] }
        end
        self.firstT:SetData(fr, true)
    end
end

-- ============================================================ TOP LISTS
local function BuildLists()
    local p = NewPage("lists")
    local lw = 250
    local lc = Panel(p, "Lists", "lists", 0, 0, lw, CH)
    p.selected = ns.LISTS[1].id
    p.nameT = W.Table(lc.body, lc.bw, lc.bh, { { "LIST", 180, kind = "text" }, { "#", 0, kind = "dim" } }, function(d)
        p.selected = d.id
        ns.RefreshWindow()
    end)
    local rc = Panel(p, "Top 100", "star", lw + GAP, 0, CW - lw - GAP, CH)
    p.title = rc.title
    p.rankT = W.Table(rc.body, rc.bw, rc.bh, {
        { "#", 36, kind = "dim" }, { "NAME", 240, kind = "text" }, { "", 170, kind = "bar" }, { "TOTAL", 120, kind = "num" }, { "SESSION", 0, kind = "dim" },
    })
    function p:Update(view, base, sess)
        local names = {}
        for _, l in ipairs(ns.LISTS) do
            local n = 0
            if l.count then n = l.count(base) else for _ in pairs(base.t[l.id] or {}) do n = n + 1 end end
            names[#names + 1] = { l.name, n, id = l.id, color = (l.id == self.selected) and T.amber or nil }
        end
        self.nameT:SetData(names, true)
        local def
        for _, l in ipairs(ns.LISTS) do if l.id == self.selected then def = l end end
        self.title:SetText(def.name:upper())
        if def.rows then
            self.rankT:SetData(def.rows(base, sess), self.lastSel == self.selected)
            self.lastSel = self.selected
            return
        end
        local top = ns.TopList(base, def.id, 100)
        local maxv = top[1] and top[1][2] or 0
        local st = sess.t[def.id] or {}
        local f = ns.FMT[def.fmt] or Int
        local rows = {}
        for i, e in ipairs(top) do
            rows[i] = { tostring(i), tostring(e[1]), maxv > 0 and e[2] / maxv or 0, f(e[2]), st[e[1]] and ("+" .. f(st[e[1]])) or "" }
        end
        self.rankT:SetData(rows, self.lastSel == self.selected)
        self.lastSel = self.selected
    end
end

-- ============================================================ TIMELINE
local METRICS = {
    { id = "steps", label = "Steps", fn = function(d) return (d.dist_foot or 0) * ns.YARDS_TO_STEPS end, fmt = Int },
    { id = "kills", label = "Kills", fn = function(d) return (d.kills_npc or 0) + (d.kills_pvp or 0) end, fmt = Int },
    { id = "deaths", label = "Deaths", fn = function(d) return d.deaths or 0 end, fmt = Int },
    { id = "xp", label = "XP", fn = function(d) return d.xp or 0 end, fmt = Int },
    { id = "gold", label = "Gold", fn = function(d) return (d.money_in or 0) - (d.money_out or 0) end, fmt = Money, signed = true },
    { id = "time", label = "Online", fn = function(d) return d.time_online or 0 end, fmt = Time },
    { id = "dmg", label = "Damage", fn = function(d) return d.dmg_done or 0 end, fmt = Int },
    { id = "dpslvl", label = "DPS by level", levels = true, fmt = ns.FMT.num1 },
}

local function BuildTimeline()
    local p = NewPage("timeline")
    KpiRow(p, {
        { label = "Steps today", icon = "steps", value = function(v, base) local d = ns.char.days[ns.Today()] or {} return (d.dist_foot or 0) * ns.YARDS_TO_STEPS end, sub = function() return date("%A, %b %d") end },
        { label = "Kills today", icon = "sword", value = function() local d = ns.char.days[ns.Today()] or {} return (d.kills_npc or 0) + (d.kills_pvp or 0) end, sub = function() local d = ns.char.days[ns.Today()] or {} return Int(d.deaths or 0) .. " deaths" end },
        { label = "Quests today", icon = "scroll", value = function() local d = ns.char.days[ns.Today()] or {} return d.quests_done or 0 end, sub = function() local d = ns.char.days[ns.Today()] or {} return Int(d.xp or 0) .. " XP" end },
        { label = "Minutes online today", icon = "clock", value = function() local d = ns.char.days[ns.Today()] or {} return (d.time_online or 0) / 60 end, sub = function() local d = ns.char.days[ns.Today()] or {} return Money((d.money_in or 0) - (d.money_out or 0)) .. " net" end },
    })
    local cc = Panel(p, "Last 30 days", "timeline", 0, BODY_Y, CW, 220)
    p.metric = "steps"
    local opts = {}
    for i, m in ipairs(METRICS) do opts[i] = { id = m.id, label = m.label, tip = m.levels and "Average damage per second of fight time at each level (game damage meter), last 30 levels." or ("Chart " .. m.label:lower() .. " per day.") } end
    p.seg = W.Segmented(cc, opts, function(id) p.metric = id; ns.RefreshWindow() end)
    p.seg:SetPoint("TOPRIGHT", -8, -2)
    p.chartSingle = W.Columns(cc.body, cc.bw, cc.bh, 30, "single")
    p.chartHolder = CreateFrame("Frame", nil, cc.body); p.chartHolder:SetAllPoints()
    p.chartSigned = W.Columns(p.chartHolder, cc.bw, cc.bh, 30, "signed")
    local tc = Panel(p, "Day by day", "lists", 0, BODY_Y + 230, CW, BODY_H - 230)
    p.dayT = W.Table(tc.body, tc.bw, tc.bh, {
        { "DATE", 120, kind = "text" }, { "STEPS", 100, kind = "num" }, { "JUMPS", 80, kind = "num" }, { "KILLS", 80, kind = "num" },
        { "DEATHS", 70, kind = "num" }, { "QUESTS", 70, kind = "num" }, { "XP", 90, kind = "num" }, { "GOLD (NET)", 150, kind = "num" }, { "ONLINE", 0, kind = "dim" },
    })
    function p:Update(view, base, sess)
        UpdateKpis(self, view, base, sess)
        self.seg:Select(self.metric)
        local m
        for _, x in ipairs(METRICS) do if x.id == self.metric then m = x end end
        local vals, labels = {}, {}
        local series = ns.DaySeries(base, function(d) return d end, 30)
        local axis
        if m.levels then
            local dl, tl = base.t.dmglevel or {}, base.t.timelevel or {}
            local top = math.max(30, UnitLevel("player") or 1)
            for i = 1, 30 do
                local lv = top - 30 + i
                local k = string.format("%02d", lv)
                vals[i] = { ns.Div(dl[k] or 0, tl[k] or 0) }
                labels[i] = "Level " .. lv
            end
            axis = { "Lv " .. (top - 29), "Lv " .. (top - 15), "Lv " .. top }
        else
            for i, e in ipairs(series) do vals[i] = { m.fn(e.v or {}) }; labels[i] = DayLabel(e.d) end
            axis = { labels[1], labels[15], "Today" }
        end
        local chart = m.signed and self.chartSigned or self.chartSingle
        self.chartHolder:SetShown(m.signed and true or false)
        chart:Set(vals, { m.signed and C.amber or C.cream2 }, labels, axis, m.fmt, { m.label }, not m.signed)
        if m.signed then self.chartSingle:Set({}, { C.amber }, {}, { "", "", "" }) end
        local rows = {}
        for i = #series, 1, -1 do
            local e = series[i]
            local d = e.v
            if d and next(d) then
                rows[#rows + 1] = { DayLabel(e.d) .. (i == #series and " (today)" or ""), Int((d.dist_foot or 0) * ns.YARDS_TO_STEPS), Int(d.jumps or 0),
                    Int((d.kills_npc or 0) + (d.kills_pvp or 0)), Int(d.deaths or 0), Int(d.quests_done or 0), Int(d.xp or 0),
                    Money((d.money_in or 0) - (d.money_out or 0)), Time(d.time_online or 0) }
            end
        end
        self.dayT:SetData(rows, true)
    end
end

-- ============================================================ SEARCH
local function BuildSearch()
    local p = NewPage("search")
    local sc = Panel(p, "Search results", "lists", 0, 0, CW, CH)
    p.title = sc.title
    p.table = W.Table(sc.body, sc.bw, sc.bh, {
        { "STATISTIC", 360, kind = "text" }, { "PAGE", 170, kind = "dim" }, { "VALUE", 200, kind = "num" }, { "SESSION", 0, kind = "dim" },
    }, function(d)
        if d.cat then
            win.search:SetText("")
            if d.list and pages.lists then pages.lists.selected = d.list end
            ns.ShowPage(d.cat)
        end
    end)
    function p:Update(view, base, sess)
        local q = (win.search:GetText() or ""):lower()
        local rows = {}
        local catName = {}
        for _, cdef in ipairs(ns.CATEGORIES) do catName[cdef.id] = cdef.name end
        for cat, list in pairs(ns.STATS) do
            for _, st in ipairs(list) do
                if st.label:lower():find(q, 1, true) then
                    local v, what = ns.StatValue(st, view)
                    local sv = ns.StatValue(st, sess)
                    rows[#rows + 1] = { st.label, catName[cat] or cat, ns.FormatStat(st, v), (sv and sv > 0) and ("+" .. ns.FormatStat(st, sv)) or "",
                        tip = (st.tip or "") .. "\nClick to open " .. (catName[cat] or cat) .. ".", what = what, cat = cat }
                end
            end
        end
        for _, u in ipairs(ns.UNIQUES) do
            if u.label:lower():find(q, 1, true) then
                rows[#rows + 1] = { "Unique: " .. u.label, catName.fastest, Int((base.un or {})[u.set] or 0), "", cat = "fastest" }
            end
        end
        for _, f in ipairs(ns.FASTEST) do
            if f.label:lower():find(q, 1, true) then
                local fv = (base.f or {})[f.key]
                rows[#rows + 1] = { "Fastest: " .. f.label, catName.fastest, fv and Time(fv) or "—", "", cat = "fastest" }
            end
        end
        -- entries inside the top lists (spells, creatures, zones, people...)
        if #q >= 2 then
            local found = 0
            for _, l in ipairs(ns.LISTS) do
                local t = base.t and base.t[l.id]
                if t then
                    local f = ns.FMT[l.fmt] or Int
                    for name, v in pairs(t) do
                        if found < 80 and tostring(name):lower():find(q, 1, true) then
                            found = found + 1
                            local sv = sess.t and sess.t[l.id] and sess.t[l.id][name]
                            rows[#rows + 1] = { tostring(name) .. "  " .. ns.GREY .. "(" .. l.name .. ")|r", catName.lists or "Top Lists", f(v), sv and ("+" .. f(sv)) or "",
                                tip = l.name .. "\nClick to open Top Lists.", cat = "lists", list = l.id }
                        end
                    end
                end
            end
        end
        table.sort(rows, function(a, b) return a[1] < b[1] end)
        self.title:SetText(("Search results for \"" .. q .. "\" (" .. #rows .. ")"):upper())
        self.table:SetData(rows, self.lastQ == q)
        self.lastQ = q
    end
end

-- ============================================================ ACHIEVEMENTS
local ACH_CATS = { "All", "Travel", "Combat", "Deaths", "Adventure", "Wealth", "Silly", "Fastest" }

local function AchTile(parent, w, h)
    local t = W.Panel(parent, T.tile)
    t:SetSize(w, h)
    t.icon = W.Icon(t, "star", 30); t.icon:SetPoint("TOPLEFT", 10, -10)
    t.name = W.Text(t, 13, T.text, nil, "LEFT"); t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 10, 1); t.name:SetWidth(w - 60 - 80)
    t.desc = W.Text(t, 11, T.dim, nil, "LEFT"); t.desc:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -3); t.desc:SetWidth(w - 60)
    t.pips = {}
    for i = 1, 6 do
        local pip = W.Fill(t, T.edge, "ARTWORK"); pip:SetSize(9, 9)
        pip:SetPoint("TOPRIGHT", -10 - (6 - i) * 12, -12)
        t.pips[i] = pip
    end
    t.track = W.Fill(t, T.bg, "BORDER"); t.track:SetPoint("BOTTOMLEFT", 10, 12); t.track:SetSize(w - 110, 6)
    t.bar = W.Fill(t, T.amber, "ARTWORK"); t.bar:SetPoint("LEFT", t.track, "LEFT"); t.bar:SetHeight(6)
    t.val = W.Text(t, 11, T.amber, W.NUM, "RIGHT"); t.val:SetPoint("BOTTOMRIGHT", -10, 8); t.val:SetWidth(90)
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
        local def, st, ach = self.def, self.st, self.ach
        if not def then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(def.name, T.amber[1], T.amber[2], T.amber[3])
        GameTooltip:AddLine(def.cat, T.dim[1], T.dim[2], T.dim[3])
        for i, target in ipairs(def.tiers) do
            local when = ach[ns.AchKey(def, i)]
            local line = string.format("%s  " .. def.desc, ns.TIER_NAMES[i], ns.FMT[def.fmt](target))
            local right = when and (self.retro[ns.AchKey(def, i)] and "before v1.3" or date("%b %d, %Y", when)) or (ns.TIER_POINTS[i] .. " pts")
            local col = when and T.amber or T.text
            GameTooltip:AddDoubleLine(line, right, col[1], col[2], col[3], T.dim[1], T.dim[2], T.dim[3])
        end
        if st.value then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Current: " .. ns.FMT[def.fmt](st.value), T.text[1], T.text[2], T.text[3])
        end
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function t:Set(def, st, ach, retro)
        self.def, self.st, self.ach, self.retro = def, st, ach, retro or {}
        self:Show()
        local done = st.tier >= st.max
        local lit = st.tier > 0
        self.icon:SetTexture(W.MEDIA .. "icons\\" .. def.icon)
        local ic = lit and T.amber or T.dim
        self.icon:SetVertexColor(ic[1], ic[2], ic[3], lit and 1 or 0.6)
        self.name:SetText(def.name .. (lit and (" " .. ns.TIER_NAMES[st.tier]) or ""))
        local nc = done and T.amber or T.text
        self.name:SetTextColor(nc[1], nc[2], nc[3])
        if not ns.AchAvailable(def) and st.tier == 0 then
            self.desc:SetText("Not measurable on Forever (the game hides this from addons)")
            self.name:SetTextColor(T.dim[1], T.dim[2], T.dim[3])
            for _, pip in ipairs(self.pips) do pip:Hide() end
            self.bar:Hide(); self.val:SetText("n/a")
            return
        end
        if done then
            self.desc:SetText("All tiers earned · " .. string.format(def.desc, ns.FMT[def.fmt](def.tiers[st.max])))
        else
            self.desc:SetText("Next: " .. string.format(def.desc, ns.FMT[def.fmt](st.nextTarget)))
        end
        for i, pip in ipairs(self.pips) do
            pip:SetShown(i <= st.max)
            W.Color(pip, i <= st.tier and T.amber or T.edge)
        end
        self.bar:SetWidth(math.max(1, (self.track:GetWidth() or 1) * st.progress))
        self.bar:SetShown(st.progress > 0)
        if def.below then
            self.val:SetText(st.value and ns.FMT[def.fmt](st.value) or "not yet")
        else
            self.val:SetText(done and "done" or string.format("%d%%", st.progress * 100))
        end
    end
    return t
end

local function BuildAchievements()
    local p = NewPage("achievements")
    KpiRow(p, {
        { label = "Achievements earned", icon = "trophy", value = function(v) return (ns.AchTotals(v)) end,
          sub = function(v) local e, t = ns.AchTotals(v) return string.format("of %d · %d new", t, ns.AchNewCount()) end },
        { label = "Achievement points", icon = "star", value = function(v) local _, _, pts = ns.AchTotals(v) return pts end,
          sub = function(v) local _, _, _, mx = ns.AchTotals(v) return "of " .. Int(mx) .. " possible" end },
        { label = "Completion (%)", icon = "timeline", value = function(v) local e, t = ns.AchTotals(v) return ns.Div(e * 100, t) end,
          sub = function() return #ns.ACHIEVEMENTS .. " achievements, up to 6 tiers" end },
        { label = "Fully completed", icon = "crown", value = function(v)
              local n = 0
              for _, def in ipairs(ns.ACHIEVEMENTS) do if (v.ach or {})[ns.AchKey(def, #def.tiers)] then n = n + 1 end end
              return n
          end, sub = function() return "every tier earned" end },
    })
    local lw = 640
    local card = Panel(p, "Achievements", "trophy", 0, BODY_Y, lw, BODY_H, "Hover a badge to see every tier and when you earned it.")
    p.cat = "All"
    local opts = {}
    for i, cname in ipairs(ACH_CATS) do opts[i] = { id = cname, label = cname, tip = "Show " .. (cname == "All" and "every achievement" or (cname:lower() .. " achievements")) .. "." } end
    p.seg = W.Segmented(card, opts, function(id) p.cat = id; p.offset = 0; ns.RefreshWindow() end)
    for _, b in ipairs(p.seg.buttons) do b:SetWidth(math.max(40, b.text:GetStringWidth() + 12)) end
    local x = 1
    for _, b in ipairs(p.seg.buttons) do b:ClearAllPoints(); b:SetPoint("LEFT", x, 0); x = x + b:GetWidth() end
    p.seg:SetWidth(x + 1)
    p.seg:SetPoint("TOPRIGHT", -6, -2)
    p.sort = "default"
    local sortB = W.FlatButton(card, "Sort: list", 92, 20, "Sort", "Switch between the normal order and closest to the next tier first.")
    sortB:SetPoint("TOPLEFT", 140, -4)
    sortB:SetScript("OnClick", function(self)
        p.sort = (p.sort == "default") and "closest" or "default"
        self.text:SetText(p.sort == "closest" and "Sort: closest" or "Sort: list")
        p.offset = 0
        ns.RefreshWindow()
    end)
    local cols, tileH, gap = 2, 74, 8
    local tileW = (card.bw - gap) / cols
    local rowsVis = math.floor((card.bh + gap) / (tileH + gap))
    p.tiles = {}
    for i = 1, cols * rowsVis do
        local tile = AchTile(card.body, tileW, tileH)
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        tile:SetPoint("TOPLEFT", col * (tileW + gap), -row * (tileH + gap))
        p.tiles[i] = tile
    end
    p.offset = 0
    card.body:EnableMouseWheel(true)
    card.body:SetScript("OnMouseWheel", function(_, delta)
        p.offset = math.max(0, p.offset - delta)
        ns.RefreshWindow()
    end)
    local rx, rw = lw + GAP, CW - lw - GAP
    local rc = Panel(p, "Recently earned", "clock", rx, BODY_Y, rw, 290)
    p.recent = W.Table(rc.body, rc.bw, rc.bh, { { "ACHIEVEMENT", 170, kind = "text" }, { "WHEN", 0, kind = "dim" } })
    local nc = Panel(p, "Closest to the next tier", "timeline", rx, BODY_Y + 300, rw, BODY_H - 300)
    p.close = W.BarList(nc.body, nc.bw, nc.bh, 9, math.floor(nc.bw * 0.55), 44)

    function p:Update(view, base, sess)
        local v = Settings().scope == "account" and base or ns.char
        UpdateKpis(self, v, base, sess)
        self.seg:Select(self.cat)
        local ach, retro = v.ach or {}, v.achr or {}
        local list, near, recent = {}, {}, {}
        for _, def in ipairs(ns.ACHIEVEMENTS) do
            local ok, st = pcall(ns.AchState, def, v)
            if ok then
                if self.cat == "All" or def.cat == self.cat then list[#list + 1] = { def, st } end
                if st.tier < st.max and st.progress > 0 then near[#near + 1] = { def.name .. " " .. ns.TIER_NAMES[st.tier + 1], st.progress * 100 } end
                for t = 1, #def.tiers do
                    local when = ach[ns.AchKey(def, t)]
                    if when then recent[#recent + 1] = { def.name .. " " .. ns.TIER_NAMES[t], retro[ns.AchKey(def, t)] and "before v1.3" or DateLabel(when), when = when,
                        tipTitle = def.name .. " " .. ns.TIER_NAMES[t], tip = string.format(def.desc, ns.FMT[def.fmt](def.tiers[t])) } end
                end
            end
        end
        if self.sort == "closest" then
            table.sort(list, function(a, b)
                local da, db = a[2].tier >= a[2].max, b[2].tier >= b[2].max
                if da ~= db then return db end
                if a[2].progress ~= b[2].progress then return a[2].progress > b[2].progress end
                return a[1].name < b[1].name
            end)
        end
        local maxOff = math.max(0, math.ceil(#list / cols) - rowsVis)
        self.offset = math.min(self.offset, maxOff)
        for i, tile in ipairs(self.tiles) do
            local e = list[self.offset * cols + i]
            if e then tile:Set(e[1], e[2], ach, retro) else tile:Hide() end
        end
        table.sort(recent, function(a, b) return a.when > b.when end)
        self.recent:SetData(recent, true)
        table.sort(near, function(a, b) return a[2] > b[2] end)
        for i = #near, 10, -1 do near[i] = nil end
        self.close:Set(near, function(n) return string.format("%d%%", n) end)
        ns.AchMarkSeen()
        ns.UpdateNavBadge()
    end
end

-- ============================================================ COMPARE
local function ClassColor(class)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return cc and { cc.r, cc.g, cc.b, 1 } or T.text
end

local function CompareSource(key)
    if key == "__account" then return ns.GetView("account", "lifetime"), "All characters", nil end
    local rec = ns.db.chars[key]
    if not ns.ValidRecord(rec) then return nil end
    ns.EnsureRecord(rec)
    return rec, rec.meta.name or key, rec.meta.class
end

StaticPopupDialogs["LIFETIMESTATS_FORGET_CHAR"] = {
    text = "Forget every LifeTimeStats value for %s?\n\nUse this for characters you deleted. It cannot be undone.",
    button1 = "Forget", button2 = CANCEL or "Cancel",
    OnAccept = function(_, data)
        if data and data ~= ns.charKey then
            ns.db.chars[data] = nil
            ns.InvalidateAccount()
            if pages.compare then pages.compare.b = false end
            ns.Print("Forgot " .. data .. ".")
            ns.RefreshWindow()
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local CMP_ORDER = { "travel", "combat", "deaths", "adventure", "wealth", "social", "records" }

local function BuildCompare()
    local p = NewPage("compare")
    p.leadA, p.leadB, p.ptsA, p.ptsB, p.nameA, p.nameB, p.b, p.lastPair = 0, 0, 0, 0, "", "", false, ""
    KpiRow(p, {
        { label = "Stats A leads", icon = "person", value = function() return p.leadA or 0 end, sub = function() return p.nameA or "" end },
        { label = "Stats B leads", icon = "person", value = function() return p.leadB or 0 end, sub = function() return p.nameB or "pick a character" end },
        { label = "A achievement points", icon = "trophy", value = function() return p.ptsA or 0 end, sub = function() return p.nameA or "" end },
        { label = "B achievement points", icon = "trophy", value = function() return p.ptsB or 0 end, sub = function() return p.nameB or "" end },
    })
    p.a = ns.charKey
    local lw = 300
    local lc = Panel(p, "Characters", "person", 0, BODY_Y, lw, BODY_H, "Click: compare with this character (right side). Ctrl+click: put it on the left side.")
    p.charT = W.Table(lc.body, lc.bw, lc.bh - 32, { { "CHARACTER", 150, kind = "text" }, { "LV", 34, kind = "num" }, { "PLAYED", 0, kind = "dim" } }, function(d)
        if IsControlKeyDown() then p.a = d.key else p.b = d.key end
        ns.RefreshWindow()
    end)
    local forget = W.FlatButton(lc.body, "Forget character", 130, 22, nil, "Remove the right-side character's LifeTimeStats data (for characters you deleted). Asks first. You cannot forget the character you are playing.")
    forget:SetPoint("BOTTOMLEFT", 0, 0)
    forget:SetScript("OnClick", function()
        if p.b and p.b ~= ns.charKey and p.b ~= "__account" then
            StaticPopup_Show("LIFETIMESTATS_FORGET_CHAR", p.b, nil, p.b)
        else
            ns.Print("Pick another character first (not the one you are playing).")
        end
    end)
    local swap = W.FlatButton(lc.body, "Swap sides", 90, 22, nil, "Swap the left and right characters.")
    swap:SetPoint("BOTTOMRIGHT", 0, 0)
    swap:SetScript("OnClick", function() if p.b and p.b ~= "__account" then p.a, p.b = p.b, p.a; ns.RefreshWindow() end end)

    local rc = Panel(p, "Side by side", "lists", lw + GAP, BODY_Y, CW - lw - GAP, BODY_H, "The bar shows each side's share of the total: longer = left side leads.")
    p.cmpT = W.Table(rc.body, rc.bw, rc.bh, { { "STATISTIC", 230, kind = "text" }, { "A", 120, kind = "num" }, { "", 110, kind = "bar" }, { "B", 0, kind = "num" } })

    function p:Update()
        -- character list
        local list = {}
        for key, rec in pairs(ns.db.chars) do
            if ns.ValidRecord(rec) then
                local m = rec.meta
                list[#list + 1] = { (m.name or key) .. (key == ns.charKey and " (you)" or "") .. "  " .. (m.realm or ""), tostring(m.level or "?"),
                    ns.FormatTime((rec.c and rec.c.played_server) or 0), key = key, color = ClassColor(m.class),
                    tipTitle = m.name or key, tip = "Click: compare on the right. Ctrl+click: put on the left." }
            end
        end
        table.sort(list, function(x, y) return x[1] < y[1] end)
        list[#list + 1] = { "All characters", "", "", key = "__account", color = T.amber, tipTitle = "All characters", tip = "Every character added together." }
        if not self.b then
            for _, e in ipairs(list) do if e.key ~= self.a then self.b = e.key break end end
        end
        for _, e in ipairs(list) do
            if e.key == self.a then e[1] = "A: " .. e[1] elseif e.key == self.b then e[1] = "B: " .. e[1] end
        end
        self.charT:SetData(list, true)

        local va, nameA, classA = CompareSource(self.a)
        if not va then self.a = ns.charKey; va, nameA, classA = CompareSource(self.a) end
        local vb, nameB, classB
        if self.b then vb, nameB, classB = CompareSource(self.b) end
        self.nameA, self.nameB = nameA, nameB
        self.cmpT:SetHeader(2, (nameA or "A"):upper())
        self.cmpT:SetHeader(4, (nameB or "B"):upper())
        local rows, leadA, leadB = {}, 0, 0
        if vb then
            local catName = {}
            for _, cdef in ipairs(ns.CATEGORIES) do catName[cdef.id] = cdef.name end
            local function Row(label, a, b, fmtf, tip, lowerBetter)
                local fa, fb = fmtf(a or 0), fmtf(b or 0)
                local share
                if (a or 0) + (b or 0) > 0 then
                    share = (a or 0) / ((a or 0) + (b or 0))
                    if lowerBetter and (a or 0) > 0 and (b or 0) > 0 then share = 1 - share end
                end
                if a and b and a ~= b then
                    local aWins = (a > b) ~= (lowerBetter and true or false)
                    if lowerBetter and (a == 0 or b == 0) then aWins = a ~= 0 end
                    if aWins then leadA = leadA + 1; fa = "+ " .. fa else leadB = leadB + 1; fb = fb .. " +" end
                end
                rows[#rows + 1] = { label, fa, share, fb, tip = tip }
            end
            local function Head(text) rows[#rows + 1] = { text:upper(), "", nil, "", color = T.amber } end
            Head("Overview")
            local _, _, pa = ns.AchTotals(va)
            local _, _, pb = ns.AchTotals(vb)
            self.ptsA, self.ptsB = pa, pb
            Row("Achievement points", pa, pb, Int)
            Row("Time played (server)", (va.c or {}).played_server, (vb.c or {}).played_server, Time)
            Row("Highest level", (va.r or {}).max_level, (vb.r or {}).max_level, ns.FMT.level)
            Head("Uniques")
            for _, u in ipairs(ns.UNIQUES) do Row(u.label, (va.un or {})[u.set], (vb.un or {})[u.set], Int) end
            Head("Fastest (lower is better)")
            for _, f in ipairs(ns.FASTEST) do
                local a, b = (va.f or {})[f.key], (vb.f or {})[f.key]
                if a or b then Row(f.label, a, b, function(n) return n > 0 and Time(n) or "-" end, nil, true) end
            end
            for _, cat in ipairs(CMP_ORDER) do
                Head(catName[cat] or cat)
                for _, st in ipairs(ns.STATS[cat]) do
                    local a = ns.StatValue(st, va)
                    local b = ns.StatValue(st, vb)
                    Row(st.label, a, b, function(n) return ns.FormatStat(st, n) end, st.tip)
                end
            end
        end
        self.leadA, self.leadB = leadA, leadB
        self.cmpT:SetData(rows, self.lastPair == (tostring(self.a) .. tostring(self.b)))
        self.lastPair = tostring(self.a) .. tostring(self.b)
        local ca, cb = ClassColor(classA), (self.b == "__account") and T.amber or ClassColor(classB)
        self.kpis[1].sub:SetTextColor(ca[1], ca[2], ca[3]); self.kpis[3].sub:SetTextColor(ca[1], ca[2], ca[3])
        self.kpis[2].sub:SetTextColor(cb[1], cb[2], cb[3]); self.kpis[4].sub:SetTextColor(cb[1], cb[2], cb[3])
        UpdateKpis(self, ns.char, ns.char, ns.session)
    end
end

-- ============================================================ JOURNAL
local function BuildJournal()
    local p = NewPage("journal")
    KpiRow(p, {
        { label = "Journal entries", icon = "scroll", value = function(v) return #(ns.char.journal or {}) end, sub = function() return "written for you as you play" end },
        { label = "Zones in travel log", icon = "travel", value = function() local n = 0 for _ in pairs(ns.char.zonelog or {}) do n = n + 1 end return n end, sub = function() return "first visit and level" end },
        { label = "Days adventured", icon = "clock", value = function() return (ns.char.un and ns.char.un.days_played) or 0 end, sub = function() return "days you logged in" end },
        { label = "Titles earned", icon = "crown", value = function() return #ns.EarnedTitles() end, sub = function() return ns.TitledName() end },
    })
    local lw = 560
    local jc = Panel(p, "Your story", "scroll", 0, BODY_Y, lw, BODY_H, "Firsts, level-ups, new zones, inns, deaths and achievements, newest first.")
    p.jT = W.Table(jc.body, jc.bw, jc.bh, { { "WHEN", 92, kind = "dim" }, { "LV", 32, kind = "num" }, { "ENTRY", 0, kind = "text" } })
    local rc = Panel(p, "Life per level", "adventure", lw + GAP, BODY_Y, CW - lw - GAP, 290, "What happened while you were at each level (from the level-ups seen since install).")
    p.lvT = W.Table(rc.body, rc.bw, rc.bh, { { "LV", 34, kind = "num" }, { "TIME", 70, kind = "dim" }, { "KILLS", 52, kind = "num" }, { "DEATHS", 52, kind = "num" }, { "STEPS", 0, kind = "num" } })
    local zc = Panel(p, "Travel log", "travel", lw + GAP, BODY_Y + 300, CW - lw - GAP, BODY_H - 300, "Every zone, when you first arrived and at what level.")
    p.zT = W.Table(zc.body, zc.bw, zc.bh, { { "ZONE", 170, kind = "text" }, { "LV", 34, kind = "num" }, { "ARRIVED", 0, kind = "dim" } })
    function p:Update(view, base, sess)
        UpdateKpis(self, view, base, sess)
        local j, rows = ns.char.journal or {}, {}
        for i = #j, 1, -1 do rows[#rows + 1] = { date("%b %d %H:%M", j[i][1]), tostring(j[i][3] or ""), j[i][2], tipTitle = j[i][2] } end
        self.jT:SetData(rows, true)
        local snaps, levels = ns.char.lvlsnap or {}, {}
        for k in pairs(snaps) do levels[#levels + 1] = tonumber(k) end
        table.sort(levels)
        local lr = {}
        for i = #levels, 1, -1 do
            local lv = levels[i]
            local cur, prev = snaps[tostring(lv)], snaps[tostring(lv - 1)]
            if prev then
                local function d(k) return (cur[k] or 0) - (prev[k] or 0) end
                lr[#lr + 1] = { tostring(lv - 1), Time(d("time_online")), Int(d("kills_npc") + d("kills_pvp")), Int(d("deaths")), Int(d("dist_foot") * ns.YARDS_TO_STEPS) }
            end
        end
        self.lvT:SetData(lr, true)
        local zr = {}
        for z, e in pairs(ns.char.zonelog or {}) do zr[#zr + 1] = { z, tostring(e[2] or ""), date("%b %d %H:%M", e[1]), when = e[1] } end
        table.sort(zr, function(a, b) return a.when > b.when end)
        self.zT:SetData(zr, true)
    end
end

-- ============================================================ HOW IT WORKS
ns.HELP = {
    { "Counting", "LifeTimeStats starts counting when it is installed. The game does not remember most of these numbers, so nothing before that can be recovered. /played and lifetime honorable kills are read from the server." },
    { "Lifetime, Session, Today", "Lifetime is everything since install. Session is since you logged in (a /reload keeps it; Reset session in settings or /lts session clears it). Today resets at local midnight; 40 days of daily history are kept." },
    { "This character / All characters", "All characters adds up every character on this account that has logged in with LifeTimeStats. Records take the best, fastest times take the quickest, uniques are merged." },
    { "Steps and distance", "Distance comes from your movement speed, sampled four times a second. Steps are distance on foot divided by a 0.75 m stride. Mounted, swimming, flight path and ghost distance are separate and never count as steps. Travel and Cat form count as on foot." },
    { "Jumps and falls", "A jump only counts when you actually leave the ground (not while swimming or on a flight path). Airtime runs from leaving the ground to landing. Fall damage is the health you lost right as you landed; a fall is survived if you are still alive a second later." },
    { "Forever and the combat log", "Forever does not give addons the combat log (it is reserved for Blizzard's own UI), so LifeTimeStats reads combat from what is still available: experience and honor messages, the units you fight, the combat text feed and your own health. A few statistics need the combat log itself (healing you do, interrupts, dispels, buffs, killing blows); they show n/a and fill in automatically if Forever ever allows it. /lts debug shows which sources are working." },
    { "Kills", "A kill counts when you get experience or honor for it, or when a hostile unit you were fighting (your target, mouseover, nameplates, boss frames) dies and was not tagged by someone else. The two are matched so one kill is never counted twice. Grey creatures that give no experience count only when you can see them die. Inside instances names are hidden from addons, so those kills are listed as Unknown (instance)." },
    { "Your damage and avoidance", "Hits, crits and attacks that were dodged, parried, blocked or resisted come from the combat text feed on your target, and only while you fight alone, because in a group the feed cannot tell whose hit it was. Attacks on you (hits, crits, crushing blows, dodges, parries, blocks, misses, resists) are always counted. Forever hides how big each hit is, so damage done, DPS and biggest hit show n/a; damage taken and healing received are worked out from your own health instead (healing only while in combat, so regeneration does not count)." },
    { "Deaths and corpse runs", "The cause is worked out at the moment you die: a fall that just hurt you, running out of breath while swimming, fatigue, or the hostile unit you were targeting. A corpse run lasts from releasing your spirit until you are alive again; its distance is how far your ghost moved." },
    { "Dungeons and raids", "Each separate instance is one run. A /reload, disconnect or leaving for under 30 minutes stays the same run; an instance reset starts a new one. Classic has no 'dungeon complete' event, so the addon counts runs with a boss kill. Fastest clear = entering to the last boss, and only runs that killed as many bosses as your best run there count. Raids also count a full clear when your lockout shows every boss dead." },
    { "Fastest times", "Lower is better. Level times use online time from one level-up to the next, so the level you were on when you installed is skipped. Quest times run from accepting to turning in (even across days)." },
    { "Uniques and firsts", "Uniques count different things you met, killed, visited or used; each list stops growing at 20,000 entries. Firsts are the first time something happened after install." },
    { "Gold", "Every change in the gold you carry is counted. The source (loot, vendor, auction house, mail, flight master, trainer) comes from which window was open at the time." },
    { "Where you are", "Capital cities are the six Classic capitals. Continent and zone come from the game map. Time per place is sampled four times a second." },
    { "Your data", "Stored twice: in the account file and the character file. If one fails to load, the other restores your totals. Backup gives a text copy; Restore never lowers a value. Nothing is ever sent anywhere." },
    { "Achievements", "99 achievements with up to 6 tiers each (354 badges, 7,110 points), earned from your lifetime values. Fastest-time achievements are earned by being quicker than the target. Values you already had when 1.3 was installed are marked 'before v1.3'. Alerts are off by default; the sidebar shows how many are new. Settings can switch alerts to a chat line, an on-screen toast, or both." },
    { "Compare", "The Compare page lists every character on this account that has logged in with LifeTimeStats. Click one to put it on the right, Ctrl+click to put it on the left, or pick All characters. A + marks the side that leads; for fastest times lower is better. Forget character removes a deleted alt's data after asking." },
    { "Sharing", "Share (footer button or /lts share) shows a one-line summary of the page you are on. You can edit it, pick Say, Party, Raid, Guild or Instance, and press Send. Nothing is ever posted without that click, and /lts share g deaths posts straight to guild only because you typed it." },
    { "Adventurer's Life", "Drunk levels come from the 'You feel tipsy / drunk / completely smashed' messages. A night camped out is a logout away from an inn or city. Hearth locations are read from your hearthstone's bind point at login and whenever you set it. Inns are rest areas outside the capital cities. Food, drink and Well Fed are read from your buffs out of combat." },
    { "Journal and titles", "The Journal writes itself: firsts, level-ups, new zones, new inns, deaths and achievements, with the date and your level. Life per level compares the totals saved at each level-up. Titles are unlocked by achievements; pick one with /lts title or in settings and it shows next to your name. /lts sheet gives a copyable character sheet." },
    { "Keyboard", "1-9, 0, F, J, L, A, C and H switch pages and Ctrl+F searches while the mouse is over this window and you are out of combat, so your action bars are never blocked. Esc closes. Ctrl + mouse wheel on the header changes the size." },
}

local function BuildHelp()
    local p = NewPage("help")
    local card = Panel(p, "How it works", "scroll", 0, 0, CW, CH)
    local sf = CreateFrame("ScrollFrame", nil, card.body)
    sf:SetPoint("TOPLEFT"); sf:SetSize(card.bw, card.bh)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(card.bw - 12, 10)
    sf:SetScrollChild(child)
    local y = 0
    for _, h in ipairs(ns.HELP) do
        local head = W.Text(child, 13, T.amber); head:SetPoint("TOPLEFT", 0, -y); head:SetText(h[1])
        local body = W.Text(child, 12, T.text, nil, "LEFT")
        body:SetWordWrap(true); body:SetWidth(card.bw - 20)
        body:SetPoint("TOPLEFT", 0, -y - 20); body:SetText(h[2])
        local bh = body:GetStringHeight()
        if not bh or bh < 14 then bh = 16 * math.ceil(#h[2] / 140) end
        y = y + 20 + bh + 14
        local rule = W.Line(child); rule:SetPoint("TOPLEFT", 0, -y + 7); rule:SetSize(card.bw - 20, 1)
    end
    child:SetHeight(y)
    local footer = W.Text(child, 10, T.dim); footer:SetPoint("TOPLEFT", 0, -y)
    footer:SetText(string.format("LifeTimeStats v%s by Malikor · %d statistics · GPL-3.0-or-later", ns.VERSION, ns.CountStats()))
    child:SetHeight(y + 20)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local maxS = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxS, self:GetVerticalScroll() - delta * 40)))
    end)
    function p:Update() end
end

-- ============================================================ shell
function ns.ShowPage(id)
    if not pages[id] then id = "dashboard" end
    if id ~= "search" then Settings().lastCategory = id end
    if current and current ~= pages[id] then current:Hide() end
    current = pages[id]
    current:Show()
    for _, b in ipairs(win.navButtons) do
        local sel = b.id == id
        b.bar:SetShown(sel)
        W.Color(b.bg, sel and T.tileHi or T.bg)
        local col = sel and T.amber or T.text
        b.text:SetTextColor(col[1], col[2], col[3])
        b.icon:SetVertexColor(sel and T.amber[1] or T.dim[1], sel and T.amber[2] or T.dim[2], sel and T.amber[3] or T.dim[3])
    end
    ns.RefreshWindow()
end

function ns.UpdateNavBadge()
    if not win then return end
    local n = ns.AchNewCount and ns.AchNewCount() or 0
    for _, b in ipairs(win.navButtons) do
        if b.id == "achievements" then
            b.badge:SetText(n > 0 and (n > 99 and "99" or tostring(n)) or "")
            b.badgeBg:SetShown(n > 0)
            b.badgeBg:SetWidth(n > 9 and 18 or 12)
        end
    end
end

function ns.RefreshWindow()
    if not win or not win:IsShown() or not current then return end
    local s = Settings()
    win.scopeSeg:Select(s.scope)
    win.rangeSeg:Select(s.range)
    local view, base, sess = Views()
    local ok, err = pcall(current.Update, current, view, base, sess)
    if not ok then ns.LogError("ui:" .. tostring(current.id), err) end
    local since = ns.char.meta.created and date("%b %d, %Y", ns.char.meta.created) or "?"
    win.footer:SetText(string.format("Counting since %s   ·   %d statistics tracked   ·   %d character%s",
        since, ns.CountStats(), ns.CharCount(), ns.CharCount() == 1 and "" or "s"))
    ns.UpdateNavBadge()
    if win.nameText and ns.TitledName then win.nameText:SetText(ns.TitledName()) end
    if win.today then
        local d = ns.char.days[ns.Today()] or {}
        local vals = { Int((d.dist_foot or 0) * ns.YARDS_TO_STEPS), Int((d.kills_npc or 0) + (d.kills_pvp or 0)), Int(d.dmg_done or 0), Int(d.heal_done or 0),
            Int(d.deaths or 0), Int(d.quests_done or 0), Time(d.time_online or 0) }
        for i, fs in ipairs(win.today) do fs:SetText(vals[i]) end
    end
    win.level:SetText(string.format("%s · Level %d%s", UnitClass("player") or "", UnitLevel("player") or 0,
        ns.Score and ("  ·  " .. ns.FormatInt((ns.Score(ns.char))) .. " pts") or ""))
end

local function DefaultScale()
    local h = UIParent:GetHeight() or 768
    local sc = math.min(1, (h * 0.92) / WIN_H)
    return math.floor(sc * 20) / 20
end

local function CreateWindow()
    if ns.ApplyTheme then pcall(ns.ApplyTheme) end
    W.Init()
    C = W.C
    win = W.Panel(UIParent, T.bg)
    win:SetSize(WIN_W, WIN_H)
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetToplevel(true)
    win:Hide()
    local s = Settings().window
    if not s.scale then s.scale = DefaultScale() end
    win:SetScale(s.scale)
    win:SetPoint(s.point or "CENTER", UIParent, s.point or "CENTER", s.x or 0, s.y or 0)
    tinsert(UISpecialFrames, "LifeTimeStatsWindow")
    _G.LifeTimeStatsWindow = win

    -- header ----------------------------------------------------------
    local head = CreateFrame("Frame", nil, win)
    head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(HEADER_H)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() if not Settings().lockWindow then win:StartMoving() end end)
    head:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local p, _, _, x, y = win:GetPoint()
        s.point, s.x, s.y = p, x, y
    end)
    head:EnableMouseWheel(true)
    head:SetScript("OnMouseWheel", function(_, delta)
        if not IsControlKeyDown() then return end
        s.scale = math.max(0.5, math.min(1.5, (s.scale or 1) + delta * 0.05))
        win:SetScale(s.scale)
    end)
    local hbg = W.Fill(head, T.tile); hbg:SetAllPoints()
    local rule = W.Fill(head, T.amber, "ARTWORK"); rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(2)
    local logo = head:CreateTexture(nil, "ARTWORK"); logo:SetSize(28, 28); logo:SetPoint("LEFT", 10, 0); logo:SetTexture(W.MEDIA .. "icon")
    local t1 = W.Text(head, 18, T.amber); t1:SetPoint("LEFT", logo, "RIGHT", 8, 0); t1:SetText("LifeTime")
    local t2 = W.Text(head, 18, T.text); t2:SetPoint("LEFT", t1, "RIGHT", 0, 0); t2:SetText("Stats")

    local sb = W.Panel(head, T.bg)
    sb:SetSize(180, 26); sb:SetPoint("LEFT", 186, 0)
    local search = CreateFrame("EditBox", nil, sb)
    search:SetPoint("TOPLEFT", 10, 0); search:SetPoint("BOTTOMRIGHT", -10, 0)
    search:SetFont(W.FONT, 12, "")
    search:SetTextColor(T.text[1], T.text[2], T.text[3])
    search:SetAutoFocus(false)
    local ph = W.Text(sb, 12, T.dim); ph:SetPoint("LEFT", 10, 0); ph:SetText("Search stats...  (Ctrl+F)")
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        ph:SetShown(t == "" and not self:HasFocus())
        if t ~= "" then ns.ShowPage("search") elseif current == pages.search then ns.ShowPage(Settings().lastCategory) end
    end)
    search:SetScript("OnEditFocusGained", function() ph:Hide() end)
    search:SetScript("OnEditFocusLost", function(self) ph:SetShown((self:GetText() or "") == "") end)
    sb:EnableMouse(true)
    W.Tip(sb, "Search", "Type part of a statistic's name to find it on any page. Esc clears.")
    win.search = search

    local close = CreateFrame("Button", nil, head)
    close:SetSize(26, 26); close:SetPoint("RIGHT", -8, 0)
    close.t = W.Text(close, 18, T.text); close.t:SetPoint("CENTER"); close.t:SetText("x")
    close:SetScript("OnClick", function() win:Hide() end)
    close:SetScript("OnEnter", function() close.t:SetTextColor(T.amber[1], T.amber[2], T.amber[3]) end)
    close:SetScript("OnLeave", function() close.t:SetTextColor(T.text[1], T.text[2], T.text[3]) end)
    W.Tip(close, "Close", "Closes the window (Esc also works).")

    local portrait = head:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(32, 32); portrait:SetPoint("RIGHT", close, "LEFT", -10, 0)
    if portrait.SetMask then pcall(portrait.SetMask, portrait, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    win.portrait = portrait
    local ring = head:CreateTexture(nil, "OVERLAY")
    ring:SetSize(36, 36); ring:SetPoint("CENTER", portrait); ring:SetTexture(W.MEDIA .. "dot"); ring:SetVertexColor(T.amber[1], T.amber[2], T.amber[3]); ring:SetDrawLayer("BACKGROUND")
    local name = W.Text(head, 13, T.text, nil, "RIGHT"); name:SetPoint("BOTTOMRIGHT", portrait, "LEFT", -8, 1); name:SetText(UnitName("player") or "")
    win.nameText = name
    win.level = W.Text(head, 10, T.dim, nil, "RIGHT"); win.level:SetPoint("TOPRIGHT", portrait, "LEFT", -8, -1)

    local gear = W.FlatButton(head, "Settings", 66, 24, nil, "Open LifeTimeStats settings.")
    gear:SetPoint("RIGHT", portrait, "LEFT", -150, 0)
    gear:SetScript("OnClick", function() ns.OpenOptions() end)

    win.rangeSeg = W.Segmented(head, {
        { id = "lifetime", label = "Lifetime", tip = "Everything since LifeTimeStats was installed." },
        { id = "session", label = "Session", tip = "Since you logged in (or reset the session)." },
        { id = "today", label = "Today", tip = "Since midnight, local time." },
        { id = "week", label = "Week", tip = "The last 7 days, today included. Records and lists show lifetime values." },
        { id = "month", label = "Month", tip = "The last 30 days, today included. Records and lists show lifetime values." },
    }, function(id) Settings().range = id; ns.RefreshWindow() end)
    win.rangeSeg:SetPoint("RIGHT", gear, "LEFT", -10, 0)
    win.scopeSeg = W.Segmented(head, {
        { id = "char", label = "Character", tip = "Only this character." },
        { id = "account", label = "Account", tip = "Every character on this account that has logged in with LifeTimeStats. Hover a value to see each character's part." },
    }, function(id) Settings().scope = id; ns.InvalidateAccount(); ns.RefreshWindow() end)
    win.scopeSeg:SetPoint("RIGHT", win.rangeSeg, "LEFT", -8, 0)

    -- sidebar ---------------------------------------------------------
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 1, -HEADER_H - 1); side:SetPoint("BOTTOMLEFT", 1, FOOTER_H)
    side:SetWidth(SIDEBAR_W - 1)
    local sr = W.Line(side); sr:SetPoint("TOPRIGHT"); sr:SetPoint("BOTTOMRIGHT"); sr:SetWidth(1)
    win.navButtons = {}
    for i, cat in ipairs(ns.CATEGORIES) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(SIDEBAR_W - 2, NAV_STEP - 1)
        b:SetPoint("TOPLEFT", 0, -6 - (i - 1) * NAV_STEP)
        b.bg = W.Fill(b, T.bg); b.bg:SetAllPoints()
        local line = W.Line(b); line:SetPoint("BOTTOMLEFT", 8, 0); line:SetPoint("BOTTOMRIGHT", -8, 0); line:SetHeight(1); line:SetAlpha(0.5)
        b.bar = W.Fill(b, T.amber, "ARTWORK"); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
        b.icon = W.Icon(b, cat.icon, 16, T.dim); b.icon:SetPoint("LEFT", 14, 0)
        b.text = W.Text(b, 12, T.text); b.text:SetPoint("LEFT", b.icon, "RIGHT", 9, 0); b.text:SetText(cat.short or cat.name)
        b.text:SetWidth(SIDEBAR_W - 14 - 16 - 9 - 34); b.text:SetJustifyH("LEFT")
        if (b.text:GetStringWidth() or 0) > SIDEBAR_W - 73 then b.text:SetFont(W.FONT, 11, "") end
        local kb = W.Panel(b, T.bg)
        kb:SetSize(16, 16); kb:SetPoint("RIGHT", -10, 0)
        local kt = W.Text(kb, 9, T.dim); kt:SetPoint("CENTER"); kt:SetText(cat.key)
        b.badgeBg = W.Fill(b, T.amber, "OVERLAY"); b.badgeBg:SetSize(14, 12); b.badgeBg:SetPoint("CENTER", b.icon, "TOPRIGHT", 2, -1); b.badgeBg:Hide()
        b.badge = W.Text(b, 9, T.bg, W.NUM); b.badge:SetPoint("CENTER", b.badgeBg, "CENTER", 0, 0); b.badge:SetDrawLayer("OVERLAY", 7)
        b.id = cat.id
        b:SetScript("OnClick", function() win.search:SetText(""); ns.ShowPage(cat.id) end)
        b:SetScript("OnEnter", function(self)
            if current ~= pages[self.id] then W.Color(self.bg, T.tile) end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(cat.name, T.amber[1], T.amber[2], T.amber[3])
            GameTooltip:AddLine("Shortcut: " .. cat.key .. " (while the mouse is over this window, out of combat)", T.dim[1], T.dim[2], T.dim[3], true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            if current ~= pages[self.id] then W.Color(self.bg, T.bg) end
            GameTooltip:Hide()
        end)
        win.navButtons[i] = b
    end

    -- today summary fills the space under the page list
    local navBottom = 6 + #ns.CATEGORIES * NAV_STEP
    local todayH = CH + PAD * 2 - navBottom - 12
    if todayH >= 70 then
        local tb = CreateFrame("Frame", nil, side)
        tb:SetPoint("TOPLEFT", 10, -navBottom - 8); tb:SetSize(SIDEBAR_W - 22, todayH)
        local tl = W.Line(tb); tl:SetPoint("TOPLEFT"); tl:SetPoint("TOPRIGHT"); tl:SetHeight(1)
        local th = W.Text(tb, 10, T.dim); th:SetPoint("TOPLEFT", 4, -8); th:SetText("TODAY")
        win.today = {}
        local labels = { "Steps", "Kills", "Damage", "Healing", "Deaths", "Quests", "Online" }
        local RH = 15
        local rowsFit = math.min(#labels, math.floor((todayH - 24) / RH))
        for i = 1, rowsFit do
            local l = W.Text(tb, 11, T.text); l:SetPoint("TOPLEFT", 4, -12 - i * RH); l:SetText(labels[i])
            local v = W.Text(tb, 11, T.amber, W.NUM, "RIGHT"); v:SetPoint("TOPRIGHT", -4, -12 - i * RH)
            win.today[i] = v
        end
        tb:EnableMouse(true)
        W.Tip(tb, "Today", "Since local midnight, this character. The Timeline page has the last 30 days.")
    end

    -- content ---------------------------------------------------------
    local content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT", SIDEBAR_W + PAD, -HEADER_H - PAD)
    content:SetSize(CW, CH)
    win.content = content

    -- footer ----------------------------------------------------------
    local foot = CreateFrame("Frame", nil, win)
    foot:SetPoint("BOTTOMLEFT", 1, 1); foot:SetPoint("BOTTOMRIGHT", -1, 1); foot:SetHeight(FOOTER_H)
    local fbg = W.Fill(foot, T.tile); fbg:SetAllPoints()
    local ftop = W.Line(foot); ftop:SetPoint("TOPLEFT"); ftop:SetPoint("TOPRIGHT"); ftop:SetHeight(1)
    win.footer = W.Text(foot, 10, T.dim); win.footer:SetPoint("LEFT", 10, 0)
    local restore = W.FlatButton(foot, "Restore", 64, 18, nil, "Paste a backup string. Values only ever go up: the larger number wins.")
    restore:SetPoint("RIGHT", -6, 0); restore:SetScript("OnClick", function() ns.ShowImport() end)
    local backup = W.FlatButton(foot, "Backup", 64, 18, nil, "Copy a text backup of this character's stats.")
    backup:SetPoint("RIGHT", restore, "LEFT", -6, 0); backup:SetScript("OnClick", function() ns.ShowExport() end)
    local share = W.FlatButton(foot, "Share", 64, 18, nil, "Preview a one-line summary of this page and post it to a chat channel you pick. Nothing is posted until you press Send.")
    share:SetPoint("RIGHT", backup, "LEFT", -6, 0)
    share:SetScript("OnClick", function() ns.ShowShare(current and current.id or "dashboard") end)
    local sheet = W.FlatButton(foot, "Sheet", 64, 18, nil, "Show a character sheet you can copy and paste anywhere.")
    sheet:SetPoint("RIGHT", share, "LEFT", -6, 0)
    sheet:SetScript("OnClick", function() ns.ShowSheet() end)
    local ver = W.Text(foot, 10, T.dim); ver:SetPoint("RIGHT", sheet, "LEFT", -12, 0); ver:SetText("v" .. ns.VERSION)

    -- pages -----------------------------------------------------------
    BuildDashboard()
    BuildCategories()
    BuildFastest()
    BuildLists()
    BuildTimeline()
    BuildSearch()
    BuildHelp()
    BuildAchievements()
    BuildCompare()
    BuildJournal()

    -- keyboard: only while the mouse is over the window and out of combat
    local keyMap = {}
    for _, cat in ipairs(ns.CATEGORIES) do keyMap[cat.key] = cat.id end
    win:EnableKeyboard(true)
    if win.SetPropagateKeyboardInput then win:SetPropagateKeyboardInput(true) end
    win:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() or not self.SetPropagateKeyboardInput then return end
        local handled = false
        if self:IsMouseOver() and not win.search:HasFocus() then
            if key == "F" and IsControlKeyDown() then
                win.search:SetFocus(); handled = true
            elseif keyMap[key] and not IsModifierKeyDown() then
                win.search:SetText(""); ns.ShowPage(keyMap[key]); handled = true
            end
        end
        pcall(self.SetPropagateKeyboardInput, self, not handled)
        if handled then
            C_Timer.After(0, function() if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, true) end end)
        end
    end)

    win:SetScript("OnShow", function()
        ns.Add("lts_opens")
        if SetPortraitTexture then SetPortraitTexture(win.portrait, "player") end
        ns.ShowPage(Settings().lastCategory)
    end)
    local acc = 0
    win:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc >= 1 then acc = 0; ns.RefreshWindow() end
    end)
end

function ns.OpenPage(id)
    if not win then CreateWindow() end
    if not win:IsShown() then Settings().lastCategory = id; win:Show() else ns.ShowPage(id) end
end

function ns.ToggleWindow()
    if not win then CreateWindow() end
    win:SetShown(not win:IsShown())
end

function ns.ResetWindow()
    local s = Settings().window
    s.point, s.x, s.y, s.scale = "CENTER", 0, 0, nil
    if win then
        s.scale = DefaultScale()
        win:SetScale(s.scale)
        win:ClearAllPoints()
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function ns.ApplyWindowSettings()
    if win then win:SetScale(Settings().window.scale or DefaultScale()) end
end

-- ------------------------------------------------------------ minimap button
local mmb
local function PositionMinimapButton()
    local a = math.rad(Settings().minimap.angle or 215)
    local r = (Minimap:GetWidth() / 2) + 5
    mmb:ClearAllPoints()
    mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function CreateMinimapButton()
    mmb = CreateFrame("Button", "LifeTimeStatsMinimapButton", Minimap)
    mmb:SetSize(31, 31)
    mmb:SetFrameStrata("MEDIUM")
    mmb:SetFrameLevel(8)
    mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mmb:RegisterForDrag("LeftButton")
    local bg = mmb:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22); bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = mmb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture(W.MEDIA .. "icon")
    local border = mmb:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    mmb:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then ns.OpenOptions() else ns.ToggleWindow() end
    end)
    mmb:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local sc = Minimap:GetEffectiveScale()
            Settings().minimap.angle = math.deg(math.atan2(cy / sc - my, cx / sc - mx))
            PositionMinimapButton()
        end)
    end)
    mmb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mmb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("LifeTimeStats", T.amber[1], T.amber[2], T.amber[3])
        local v = ns.char
        local function L(a, b) GameTooltip:AddDoubleLine(a, b, T.text[1], T.text[2], T.text[3], T.amber[1], T.amber[2], T.amber[3]) end
        L("Steps", Int(ns.Steps(v)))
        L("Jumps", Int(c(v, "jumps")))
        L("Kills", Int(ns.Kills(v)))
        L("Deaths", Int(c(v, "deaths")))
        local d = v.days and v.days[ns.Today()]
        if d then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Today", T.dim[1], T.dim[2], T.dim[3])
            L("Steps", Int((d.dist_foot or 0) * ns.YARDS_TO_STEPS))
            L("Kills", Int((d.kills_npc or 0) + (d.kills_pvp or 0)))
            L("Online", Time(d.time_online or 0))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: open window   Right-click: settings", T.dim[1], T.dim[2], T.dim[3])
        GameTooltip:AddLine("Drag: move button", T.dim[1], T.dim[2], T.dim[3])
        GameTooltip:Show()
    end)
    mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PositionMinimapButton()
end

function ns.UpdateMinimapButton()
    if not mmb then CreateMinimapButton() end
    mmb:SetShown(not Settings().minimap.hide)
end

-- ------------------------------------------------------------ backup dialog
local dlg
local function CreateDialog()
    dlg = W.Panel(UIParent, T.bg)
    dlg:SetSize(480, 320)
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("DIALOG")
    dlg:EnableMouse(true)
    dlg:SetMovable(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving)
    dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    dlg:Hide()
    tinsert(UISpecialFrames, "LifeTimeStatsBackupDialog")
    _G.LifeTimeStatsBackupDialog = dlg
    local bar = W.Fill(dlg, T.amber, "ARTWORK"); bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1); bar:SetHeight(2)
    dlg.title = W.Text(dlg, 13, T.amber); dlg.title:SetPoint("TOPLEFT", 12, -12)
    dlg.hint = W.Text(dlg, 11, T.dim); dlg.hint:SetPoint("TOPLEFT", 12, -32); dlg.hint:SetPoint("RIGHT", -12, 0); dlg.hint:SetJustifyH("LEFT"); dlg.hint:SetWordWrap(true)
    local box = W.Panel(dlg, T.tile)
    box:SetPoint("TOPLEFT", 12, -64); box:SetPoint("BOTTOMRIGHT", -12, 44)
    local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6); sf:SetPoint("BOTTOMRIGHT", -26, 6)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFont(W.NUM, 12, "")
    eb:SetTextColor(T.text[1], T.text[2], T.text[3])
    eb:SetWidth(410)
    eb:SetScript("OnEscapePressed", function() dlg:Hide() end)
    sf:SetScrollChild(eb)
    dlg.eb = eb
    local closeB = W.FlatButton(dlg, "Close", 80, 22, nil, "Close this dialog.")
    closeB:SetPoint("BOTTOMRIGHT", -12, 12)
    closeB:SetScript("OnClick", function() dlg:Hide() end)
    dlg.action = W.FlatButton(dlg, "Restore", 80, 22, nil, "Merge the pasted backup into this character. Nothing is ever lowered.")
    dlg.action:SetPoint("RIGHT", closeB, "LEFT", -8, 0)
    dlg.action:SetScript("OnClick", function()
        local data, n = ns.Deserialize(eb:GetText())
        if not data then
            dlg.hint:SetText("|cffd9604aCould not read backup:|r " .. tostring(n))
            return
        end
        local changed = ns.MergeMax(ns.char, data)
        ns.Save()
        ns.Print(string.format("Restore complete: %d of %d values raised.", changed, n))
        dlg:Hide()
        ns.RefreshWindow()
    end)
end

local function DlgDefault() dlg:SetSize(480, 320); dlg.eb:SetWidth(410) end
function ns.ShowExport()
    if not dlg then CreateDialog() end
    DlgDefault()
    dlg.title:SetText("Backup - " .. ns.charKey)
    dlg.hint:SetText("Press Ctrl+A then Ctrl+C and keep the text somewhere safe. Restore it with /lts import.")
    dlg.action:Hide()
    dlg.eb:SetText(ns.Serialize(ns.char))
    dlg:Show()
    dlg.eb:SetFocus()
    dlg.eb:HighlightText()
end

-- Plain text window for /lts debug, /lts dm and /lts errors.
function ns.ShowText(title, hint, text)
    if not dlg then CreateDialog() end
    dlg:SetSize(620, 460)
    dlg.eb:SetWidth(550)
    dlg.title:SetText(title)
    dlg.hint:SetText(hint or "Ctrl+A then Ctrl+C to copy.")
    dlg.action:Hide()
    dlg.eb:SetText(text or "")
    dlg:Show()
    dlg.eb:SetFocus()
    dlg.eb:HighlightText()
    dlg.eb:SetCursorPosition(0)
end

function ns.ShowSheet()
    if not dlg then CreateDialog() end
    DlgDefault()
    dlg.title:SetText("Character sheet - " .. ns.TitledName())
    dlg.hint:SetText("Ctrl+A then Ctrl+C to copy. Paste it into Discord, a forum post or your notes.")
    dlg.action:Hide()
    dlg.eb:SetText(ns.CharacterSheet())
    dlg:Show()
    dlg.eb:SetFocus()
    dlg.eb:HighlightText()
end

function ns.ShowImport()
    if not dlg then CreateDialog() end
    DlgDefault()
    dlg.title:SetText("Restore - " .. ns.charKey)
    dlg.hint:SetText("Paste a backup made by LifeTimeStats (Ctrl+V). Nothing is lowered: counters keep the larger number, fastest times keep the faster one.")
    dlg.action:Show()
    dlg.eb:SetText("")
    dlg:Show()
    dlg.eb:SetFocus()
end

-- ------------------------------------------------------------ share dialog
local sd
local function CreateShare()
    sd = W.Panel(UIParent, T.bg)
    sd:SetSize(520, 190)
    sd:SetPoint("CENTER", 0, 120)
    sd:SetFrameStrata("DIALOG")
    sd:EnableMouse(true); sd:SetMovable(true); sd:RegisterForDrag("LeftButton")
    sd:SetScript("OnDragStart", sd.StartMoving); sd:SetScript("OnDragStop", sd.StopMovingOrSizing)
    sd:Hide()
    tinsert(UISpecialFrames, "LifeTimeStatsShareDialog")
    _G.LifeTimeStatsShareDialog = sd
    local bar = W.Fill(sd, T.amber, "ARTWORK"); bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1); bar:SetHeight(2)
    local title = W.Text(sd, 13, T.amber); title:SetPoint("TOPLEFT", 12, -12); title:SetText("Share")
    sd.hint = W.Text(sd, 11, T.dim); sd.hint:SetPoint("TOPLEFT", 12, -32)
    local box = W.Panel(sd, T.tile); box:SetPoint("TOPLEFT", 12, -52); box:SetPoint("TOPRIGHT", -12, -52); box:SetHeight(64)
    local eb = CreateFrame("EditBox", nil, box)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetMaxLetters(255)
    eb:SetFont(W.FONT, 12, ""); eb:SetTextColor(T.text[1], T.text[2], T.text[3])
    eb:SetPoint("TOPLEFT", 8, -6); eb:SetPoint("BOTTOMRIGHT", -8, 6)
    eb:SetScript("OnEscapePressed", function() sd:Hide() end)
    eb:SetScript("OnTextChanged", function(self) sd.count:SetText(#(self:GetText() or "") .. " / 255") end)
    sd.eb = eb
    sd.count = W.Text(sd, 10, T.dim, nil, "RIGHT"); sd.count:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
    sd.chanLabel = W.Text(sd, 11, T.text); sd.chanLabel:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10); sd.chanLabel:SetText("Post to:")
    sd.chanButtons = {}
    local closeB = W.FlatButton(sd, "Close", 70, 22, nil, "Close without posting.")
    closeB:SetPoint("BOTTOMRIGHT", -12, 12); closeB:SetScript("OnClick", function() sd:Hide() end)
    local sendB = W.FlatButton(sd, "Send", 70, 22, nil, "Post the text above to the selected channel.")
    sendB:SetPoint("RIGHT", closeB, "LEFT", -8, 0)
    sendB:SetScript("OnClick", function()
        if ns.ShareSend(eb:GetText(), sd.channel or "SAY") then sd:Hide() end
    end)
end

function ns.ShowShare(topic)
    if not sd then CreateShare() end
    local view = (Settings().scope == "account") and ns.GetView("account", "lifetime") or ns.char
    if topic == "compare" then topic = "dashboard" end
    sd.eb:SetText(ns.ShareText(topic, view))
    sd.hint:SetText("Edit if you like, pick a channel, then Send. Nothing is posted until you press Send.")
    for _, b in ipairs(sd.chanButtons) do b:Hide() end
    local chans = ns.ShareChannels()
    sd.channel = sd.channel or "SAY"
    local found = false
    for _, ch in ipairs(chans) do if ch[1] == sd.channel then found = true end end
    if not found then sd.channel = chans[1][1] end
    local x = 60
    for i, ch in ipairs(chans) do
        local b = sd.chanButtons[i]
        if not b then
            b = W.FlatButton(sd, "", 70, 22)
            sd.chanButtons[i] = b
        end
        b.text:SetText(ch[2])
        b.channel = ch[1]
        b:ClearAllPoints(); b:SetPoint("LEFT", sd.chanLabel, "LEFT", x, 0); x = x + 76
        b:SetScript("OnClick", function(self) sd.channel = self.channel; ns.ShowShareSelect() end)
        if not b.hooked then b:HookScript("OnLeave", function() ns.ShowShareSelect() end); b.hooked = true end
        b:Show()
    end
    ns.ShowShareSelect()
    sd:Show()
end

function ns.ShowShareSelect()
    for _, b in ipairs(sd.chanButtons) do
        if b:IsShown() then
            local on = b.channel == sd.channel
            W.Color(b.bg, on and T.tileHi or T.tile)
            local c2 = on and T.amber or T.text
            b.text:SetTextColor(c2[1], c2[2], c2[3])
            b.edge:SetAlpha(on and 1 or 0.5)
        end
    end
end

function ns.CreateUI()
    ns.UpdateMinimapButton()
end

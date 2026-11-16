-- LifeTimeStats - main window, pages, minimap button and backup dialog
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local ADDON, ns = ...

local T, W = ns.THEME, ns.W
local C = W.C
local Int, Time, Money = ns.FormatInt, ns.FormatTime, ns.FormatMoney

-- The window is 1140 x 740 ("Normal"), or as large as the screen allows ("Fill screen").
-- The sizes below are recomputed by ComputeLayout() just before the window is built, so every
-- page is laid out for the size in use.
local BASE_W, BASE_H = 1140, 740
local WIN_W, WIN_H = BASE_W, BASE_H
local HEADER_H, SIDEBAR_W, FOOTER_H, PAD = 44, 176, 24, 10
local KPI_H, GAP = 72, 10
local NAV_STEP = 29 -- 18 pages still leave room for the 7-row Today box
local BODY_Y = KPI_H + GAP                        -- y where panels start (82)
local CW, CH, KPI_W, BODY_H
local function Derive()
    CW = WIN_W - SIDEBAR_W - PAD * 2           -- content width  (944 at Normal)
    CH = WIN_H - HEADER_H - FOOTER_H - PAD * 2 -- content height (652 at Normal)
    KPI_W = (CW - GAP * 3) / 4
    BODY_H = CH - BODY_Y                       -- 570 at Normal
end
Derive()

-- Room the window needs beyond its own edges: the notebook's parchment overhangs 46 px on each
-- side and 30 px top and bottom, and the section tabs stick out on the right.
local TAB_ROOM = 118 + 34 + 12
function ns.WindowSizeFor(mode, uiW, uiH, scale, book)
    if mode ~= "fill" or type(uiW) ~= "number" or type(uiH) ~= "number" then return BASE_W, BASE_H end
    scale = (type(scale) == "number" and scale > 0) and scale or 1
    local w = uiW / scale - (book and 46 or 0) - TAB_ROOM - 16
    local h = uiH / scale - (book and 60 or 0) - 24
    w = math.max(BASE_W, math.min(2600, math.floor(w)))
    h = math.max(BASE_H, math.min(1600, math.floor(h)))
    return w, h
end
local function ComputeLayout()
    local s = ns.settings and ns.settings.window or {}
    -- the framed skins put their title on a plaque over the top rail, so the header row sits lower
    HEADER_H = (ns.Framed and ns.Framed()) and 62 or 44
    local book = (ns.Notebook and ns.Notebook()) or (ns.Framed and ns.Framed())
    WIN_W, WIN_H = ns.WindowSizeFor(s.size, UIParent:GetWidth(), UIParent:GetHeight(), s.scale or 1, book)
    Derive()
end
function ns.WindowSize() return WIN_W, WIN_H end

local win
local pages = {}
local current
local pinLayer
local noteLayer

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
    return ({ today = "TODAY", session = "SESSION", week = "LAST 7 DAYS", month = "Last 30 days" })[r] or "LIFETIME"
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

local function KpiRow(page, defs, allowFormatted)
    page.kpis = {}
    for i, d in ipairs(defs) do
        local tile = W.Odometer(page, (i - 1) * (KPI_W + GAP), 0, KPI_W, KPI_H, d.label, d.icon, d.tip, allowFormatted)
        page.kpis[i] = tile
        -- a tile backed by a statistic opens its card when clicked
        tile.stat = ns.FindStat and (ns.FindStat(d.id) or ns.FindStat(d.label))
        if tile.HookScript then
            tile:EnableMouse(true)
            tile:HookScript("OnMouseUp", function(self, button)
                local st = rawget(self, "stat")
                if st and button ~= "RightButton" then ns.ShowStatDetail(st) end
            end)
        end
    end
    page.kpiDefs = defs
end

local function UpdateKpi(tile, def, view, base, sess)
    tile:SetValue(def.value(view), def.sub and def.sub(view, base, sess) or "", def.exact and def.exact(view) or nil)
end

local function UpdateKpis(page, view, base, sess)
    for i, d in ipairs(page.kpiDefs) do
        UpdateKpi(page.kpis[i], d, view, base, sess)
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

-- Rows for a stat page, grouped into its sections: a heading row starts each section.
-- Returns the rows and { { name, index } } for the section tabs. `focus` (a stat label) is
-- inked in the accent colour, for search results that open the page.
local function StatRows(cat, view, sess, focus)
    local rows, sections = {}, {}
    local perChar = Settings().scope == "account" and Settings().range == "lifetime"
    local range = Settings().range
    local other = range == "session" and ns.GetView(Settings().scope, "today") or sess
    local groups = ns.SectionedStats and ns.SectionedStats(cat) or { { stats = ns.STATS[cat] or {} } }
    for _, group in ipairs(groups) do
    if group.name and #groups > 1 then
        rows[#rows + 1] = { group.name, "", "", header = true }
        sections[#sections + 1] = { name = group.name, index = #rows }
    end
    for _, st in ipairs(group.stats) do
        local v, what = ns.StatValue(st, view)
        local ov = ns.StatValue(st, other)
        local empty = view.today and st.rec
        local na, naTip = ns.IsNA(st, v)
        rows[#rows + 1] = {
            (st.label2 and what) and (st.label .. ": " .. what) or st.label,
            na and "n/a" or (empty and "—" or ns.FormatStat(st, v)),
            (Settings().showSession and type(ov) == "number" and ov > 0 and not st.get) and ("+" .. ns.FormatStat(st, ov)) or "",
            tip = na and naTip or st.tip, what = what, stat = st.label, def = st,
            color = (focus and st.label == focus) and T.amber or nil,
        }
        if perChar and st.key and not na then
            local pc = PerChar(st.key)
            if pc then rows[#rows].tip = ((st.tip and (st.tip .. "\n\n")) or "") .. pc end
        end
    end
    end
    return rows, sections
end

-- Section tabs for a page whose table has heading rows: one tab per section, the active one
-- being the section at the top of the visible rows. Clicking scrolls the table there.
local function TableSectionTabs(tbl, sections)
    local out = {}
    local top = (tbl.offset or 0) + 1
    local active = 1
    for i, s in ipairs(sections or {}) do if s.index <= top + 1 then active = i end end
    for i, s in ipairs(sections or {}) do
        out[i] = { name = s.name, active = i == active, click = function() tbl:ScrollTo(s.index) end }
    end
    return out
end
ns.TableSectionTabs = TableSectionTabs

-- Find the row for a stat on a page and bring it into view (used by search results).
local function FocusRow(p, tbl, label)
    p.focus = label
    for i, d in ipairs(tbl.data or {}) do
        if d.stat == label or d[1] == label then tbl:Reveal(i); return true end
    end
end

-- A built page by id (used by the offline tests and other modules).
function ns.Page(id) return pages[id] end

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
local function UpdateDashboardKpis(page, view, base, sess)
    local _, byID = ns.DashboardPinCatalog()
    local used, nextSlot = {}, 1
    local showCharacterParts = Settings().scope == "account" and Settings().range == "lifetime"
    for _, id in ipairs(ns.DashboardPins()) do
        local pin = byID[id]
        local stat = pin.stat
        local value = ns.StatValue(stat, view)
        local unavailable, why = ns.IsNA(stat, value)
        local tip = unavailable and why or stat.tip
        if showCharacterParts and stat.key and not unavailable then
            local parts = PerChar(stat.key)
            if parts then tip = tip and (tip .. "\n\n" .. parts) or parts end
        end
        local tile = page.kpis[nextSlot]
        tile:Configure(stat.label, pin.icon, tip)
        tile.stat = stat
        local sub = "Pinned · " .. pin.category
        local goal = ns.GoalFor and ns.GoalFor(id)
        if goal and type(value) == "number" then
            sub = goal.done and ("Goal reached · " .. ns.FormatStat(stat, goal.target)) or string.format("Goal %.0f%% of %s", math.min(99.9, value * 100 / goal.target), ns.FormatStat(stat, goal.target))
        end
        tile:SetFormatted(unavailable and "n/a" or ns.FormatStat(stat, value), sub)
        -- notebook: a pinned statistic whose goal is reached gets a wax seal
        if ns.Notebook() and ns.MakeSeal then
            local seal = rawget(tile, "goalSeal")
            if not seal then
                seal = ns.MakeSeal(tile, 30)
                seal.text:SetText("")
                seal:SetPoint("CENTER", tile, "TOPRIGHT", -8, -6)
                rawset(tile, "goalSeal", seal)
            end
            seal:SetShown(goal and goal.done and true or false)
        end
        used[id], nextSlot = true, nextSlot + 1
    end
    for _, def in ipairs(page.kpiDefs) do
        if nextSlot > #page.kpis then break end
        if not used[def.id] then
            local tile = page.kpis[nextSlot]
            local seal = rawget(tile, "goalSeal")
            if seal then seal:Hide() end
            tile:Configure(def.label, def.icon, def.tip)
            tile.stat = ns.FindStat(def.id) or ns.FindStat(def.label)
            UpdateKpi(tile, def, view, base, sess)
            nextSlot = nextSlot + 1
        end
    end
end

local function CreateDashboardPinPicker()
    local layer = CreateFrame("Frame", nil, win)
    layer:SetAllPoints()
    layer:SetFrameLevel((win:GetFrameLevel() or 0) + 10)
    layer:EnableMouse(true)
    layer:Hide()
    local dim = W.Fill(layer, { 0.06, 0.04, 0.02, 0.66 })
    dim:SetPoint("TOPLEFT", 1, -HEADER_H); dim:SetPoint("BOTTOMRIGHT", -1, FOOTER_H)

    local width, height = 630, 390
    local dlg = W.Window(layer)
    dlg:SetSize(width, height)
    dlg:SetPoint("CENTER")
    dlg:EnableMouse(true)
    local ink = ns.JournalSkin() and W.JOURNAL or nil
    local banner = W.Fill(dlg, T.tile)
    banner:SetPoint("TOPLEFT", 1, -1); banner:SetPoint("TOPRIGHT", -1, -1); banner:SetHeight(37)
    if ink then W.Shade(banner, ink.base, ink.top) end
    local rule = W.Line(dlg, ink and ink.trim or nil)
    rule:SetPoint("TOPLEFT", 1, -38); rule:SetPoint("TOPRIGHT", -1, -38); rule:SetHeight(1)
    local title = W.Text(dlg, 16, ink and ink.gold or T.amber)
    title:SetPoint("TOPLEFT", 13, -11)
    title:SetText("Manage Dashboard pins")

    local close
    if ink then
        local ok, native = pcall(CreateFrame, "Button", nil, dlg, "UIPanelCloseButtonNoScripts")
        if ok then close = native end
    end
    if not close then close = W.FlatButton(dlg, "×", 24, 24) end
    close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -9, -7)
    close:SetScript("OnClick", function() layer:Hide() end)
    W.Tip(close, "Close", "Close the pin picker.")

    local label = W.Text(dlg, 12, T.text)
    label:SetPoint("TOPLEFT", 13, -56); label:SetText("Find a statistic")
    local box = W.Panel(dlg, T.bg)
    box:SetPoint("LEFT", label, "RIGHT", 9, 0); box:SetSize(236, 24)
    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 7, 0); edit:SetPoint("BOTTOMRIGHT", -7, 0)
    edit:SetFont(W.FONT, 12, "")
    edit:SetTextColor(T.text[1], T.text[2], T.text[3])
    edit:SetAutoFocus(false)
    local placeholder = W.Text(box, 11, T.dim, nil, "LEFT")
    placeholder:SetPoint("LEFT", 7, 0); placeholder:SetText("Search by name or category")
    local count = W.Text(dlg, 12, ink and ink.gold or T.amber, nil, "RIGHT")
    count:SetPoint("TOPRIGHT", -13, -56)

    local done = W.FlatButton(dlg, "Done", 76, 20)
    done:SetPoint("BOTTOMRIGHT", -13, 10)
    done:SetScript("OnClick", function() layer:Hide() end)
    local status = W.Text(dlg, 11, T.dim, nil, "LEFT")
    status:SetPoint("BOTTOMLEFT", 13, 14); status:SetPoint("RIGHT", done, "LEFT", -8, 0)
    local listParent = CreateFrame("Frame", nil, dlg)
    listParent:SetPoint("TOPLEFT", 12, -82); listParent:SetSize(width - 24, height - 124)

    local list
    local function Refresh(keepOffset, message)
        local catalog, byID = ns.DashboardPinCatalog()
        local pins = ns.DashboardPins()
        local limit = ns.DASHBOARD_PIN_LIMIT
        local full = #pins >= limit
        local query = (edit:GetText() or ""):match("^%s*(.-)%s*$"):lower()
        local rows, pinned = {}, {}
        local function Add(pin, selected)
            if query ~= "" and not (pin.stat.label:lower():find(query, 1, true)
                or pin.category:lower():find(query, 1, true)) then return end
            rows[#rows + 1] = { pin.stat.label, pin.category, selected and "Unpin" or (full and "Slots full" or "Pin"),
                id = pin.id, tip = pin.stat.tip }
        end
        for _, id in ipairs(pins) do
            pinned[id] = true
            Add(byID[id], true)
        end
        for _, pin in ipairs(catalog) do
            if not pinned[pin.id] then Add(pin, false) end
        end
        list:SetData(rows, keepOffset)
        count:SetText(string.format("%d of %d pins", #pins, limit))
        status:SetText(message or (full and "Unpin a statistic to free a slot." or "Click a row to pin or unpin it. Scroll for more."))
    end

    list = W.Table(listParent, width - 24, height - 124, {
        { "STATISTIC", 306, kind = "text" }, { "CATEGORY", 195, kind = "text" }, { "PINS", 0, kind = "text" },
    }, function(row)
        local ok, why = ns.ToggleDashboardPin(row.id)
        GameTooltip:Hide()
        Refresh(true, not ok and why or nil)
        if ok then ns.RefreshWindow() end
    end, "No statistics match this search.")

    edit:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "" and not self:HasFocus())
        Refresh(false)
    end)
    edit:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    edit:SetScript("OnEditFocusLost", function(self) placeholder:SetShown((self:GetText() or "") == "") end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function() layer:Hide() end)
    layer:SetScript("OnShow", function()
        Refresh(false)
        edit:SetFocus()
    end)
    layer:SetScript("OnHide", function()
        edit:ClearFocus()
        GameTooltip:Hide()
    end)
    return layer
end


-- ------------------------------------------------------------ one statistic, in detail
-- Clicking a row of a stat page opens this card over the window: the statistic's last 30
-- days, its totals and best day, and the same statistic on every character (or, for a record,
-- every time it was beaten).
local detailLayer
local function DetailDay(d)
    if type(d) ~= "string" or #d ~= 8 then return tostring(d or "") end
    local t = time({ year = tonumber(d:sub(1, 4)), month = tonumber(d:sub(5, 6)), day = tonumber(d:sub(7, 8)), hour = 12 })
    return date("%b %d, %Y", t)
end
local function CreateStatDetail()
    local layer = CreateFrame("Frame", nil, win)
    layer:SetAllPoints()
    layer:SetFrameLevel((win:GetFrameLevel() or 0) + 12)
    layer:EnableMouse(true)
    layer:Hide()
    local dim = W.Fill(layer, { 0.06, 0.04, 0.02, 0.66 })
    dim:SetPoint("TOPLEFT", 1, -HEADER_H); dim:SetPoint("BOTTOMRIGHT", -1, FOOTER_H)
    -- a click outside the card closes it
    layer:SetScript("OnMouseDown", function() layer:Hide() end)

    local width = math.min(760, CW)
    local height = math.min(CH, 560)
    local dlg = W.Window(layer)
    dlg:SetSize(width, height)
    dlg:SetPoint("CENTER", win.content or layer, "CENTER")
    dlg:EnableMouse(true)
    dlg:SetScript("OnMouseDown", function() end)
    local ink = ns.JournalSkin() and W.JOURNAL or nil
    local banner = W.Fill(dlg, T.tile)
    banner:SetPoint("TOPLEFT", 1, -1); banner:SetPoint("TOPRIGHT", -1, -1); banner:SetHeight(52)
    if ink then W.Shade(banner, ink.base, ink.top) end
    if ns.Paper() then banner:SetAlpha(0.35) end
    local rule = W.Line(dlg, ink and ink.trim or nil)
    rule:SetPoint("TOPLEFT", 1, -53); rule:SetPoint("TOPRIGHT", -1, -53); rule:SetHeight(1)
    layer.title = W.Text(dlg, 16, ink and ink.gold or T.amber)
    layer.title:SetPoint("TOPLEFT", 14, -10); layer.title:SetPoint("RIGHT", -44, 0); layer.title:SetJustifyH("LEFT")
    if ns.Paper() then W.Bold(layer.title, T.amber) end
    layer.home = W.Text(dlg, 11, T.dim)
    layer.home:SetPoint("TOPLEFT", 14, -32); layer.home:SetPoint("RIGHT", -44, 0); layer.home:SetJustifyH("LEFT")

    local close
    if ink then
        local ok, native = pcall(CreateFrame, "Button", nil, dlg, "UIPanelCloseButtonNoScripts")
        if ok then close = native end
    end
    if not close then close = W.FlatButton(dlg, "×", 24, 24) end
    close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -9, -12)
    close:SetScript("OnClick", function() layer:Hide() end)
    W.Tip(close, "Close", "Close this statistic.")

    layer.tip = W.Text(dlg, 12, T.text)
    layer.tip:SetPoint("TOPLEFT", 14, -64); layer.tip:SetPoint("RIGHT", -14, 0)
    layer.tip:SetJustifyH("LEFT"); layer.tip:SetWordWrap(true)

    -- eight facts in two rows
    layer.facts = {}
    local fw = (width - 28) / 4
    for i = 1, 8 do
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local lab = W.Text(dlg, 10, T.dim)
        lab:SetPoint("TOPLEFT", 14 + col * fw, -112 - row * 44); lab:SetWidth(fw - 10); lab:SetJustifyH("LEFT")
        local val = W.Text(dlg, 15, T.amber, W.NUM)
        val:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 0, -3); val:SetWidth(fw - 10); val:SetJustifyH("LEFT"); val:SetWordWrap(false)
        if ns.Paper() then W.Bold(val, T.amber) end
        layer.facts[i] = { lab = lab, val = val }
    end

    local chartY, chartH = 206, 112
    layer.chartTitle = W.Text(dlg, 10, T.dim)
    layer.chartTitle:SetPoint("TOPLEFT", 14, -chartY)
    -- the pace line: when the next round number comes at the last 30 days' rate
    layer.pace = W.Text(dlg, 11, T.amber, nil, "RIGHT")
    layer.pace:SetPoint("TOPRIGHT", -14, -chartY + 1); layer.pace:SetWidth(width - 160); layer.pace:SetWordWrap(false)
    local chartHost = CreateFrame("Frame", nil, dlg)
    chartHost:SetPoint("TOPLEFT", 14, -chartY - 16); chartHost:SetSize(width - 28, chartH)
    layer.chart = W.Columns(chartHost, width - 28, chartH, 30, "single")
    layer.chartHost = chartHost

    local tableY = chartY + 16 + chartH + 12
    layer.tableHost = CreateFrame("Frame", nil, dlg)
    layer.tableHost:SetPoint("TOPLEFT", 14, -tableY); layer.tableHost:SetSize(width - 28, height - tableY - 12)
    layer.charTable = W.Table(layer.tableHost, width - 28, height - tableY - 12,
        { { "CHARACTER", 260, kind = "text" }, { "VALUE", 180, kind = "num" }, { "", 0, kind = "dim" } }, nil, "No characters yet")
    layer.recTable = W.Table(layer.tableHost, width - 28, height - tableY - 12,
        { { "WHEN", 190, kind = "dim" }, { "NEW BEST", 170, kind = "num" }, { "WHERE", 0, kind = "text" } }, nil, "Not beaten yet")
    return layer
end

function ns.ShowStatDetail(st)
    if not win or not st then return end
    if not detailLayer then detailLayer = CreateStatDetail() end
    local L = detailLayer
    local h = ns.StatHistory(st, ns.char)
    L.stat = st
    L.data = h
    local F = function(v) return ns.FormatStat(st, v) end
    L.title:SetText(st.label)
    L.home:SetText(h.home or "")
    L.tip:SetText(st.tip or (st.rec and "A personal record: the best value ever reached." or ""))

    local facts
    if h.kind == "record" then
        local first, last = h.history[#h.history], h.history[1]
        facts = {
            { "Best", F(h.value) }, { "Set at", h.what or "—" }, { "Times beaten", Int(#h.history) },
            { "Characters with it", Int((function() local n = 0 for _, c in ipairs(h.chars) do if c.v > 0 then n = n + 1 end end return n end)()) },
            { "First set", first and date("%b %d, %Y", first.at) or "—" }, { "Last beaten", last and date("%b %d, %Y", last.at) or "—" },
            { "Best on the account", h.chars[1] and h.chars[1].v > 0 and (F(h.chars[1].v) .. " · " .. tostring(h.chars[1].name)) or "—" }, { "", "" },
        }
    else
        facts = {
            { "Lifetime", F(h.value) }, { "This session", F(h.session or 0) },
            { "Today", h.series and F(h.today) or "—" }, { "Last 7 days", h.series and F(h.last7) or "—" },
            { "Last 30 days", h.series and F(h.last30) or "—" },
            { "Best day", h.bestEver and (F(h.bestEver.v) .. " · " .. DetailDay(h.bestEver.d)) or "—" },
            { "Days with any", h.series and (Int(h.daysOnFile or 0) .. " of the last 40") or "—" },
            { "All characters", (function() local t = 0 for _, c in ipairs(h.chars) do t = t + c.v end return F(t) end)() },
        }
    end
    for i, f in ipairs(L.facts) do
        local d = facts[i] or { "", "" }
        f.lab:SetText(ns.Paper() and W.SmallCaps(d[1]) or d[1]:upper())
        f.val:SetText(d[2])
    end

    -- the 30-day chart (counters only)
    if h.series then
        L.chartTitle:SetText(ns.Paper() and W.SmallCaps("Last 30 days") or "LAST 30 DAYS")
        local vals, labels = {}, {}
        for i, e in ipairs(h.series) do vals[i] = { e.v or 0 }; labels[i] = DayLabel(e.d) end
        L.chart:Set(vals, { C.amber }, labels, { labels[1], labels[15], "Today" }, F, { st.label }, true)
        L.chartHost:Show(); L.chartTitle:Show()
        local pace = ns.StatPace(st, h)
        local text = ""
        if pace and pace.rate == 0 then
            text = "Not done in the last 30 days."
        elseif pace and pace.target then
            local rate = pace.rate >= 10 and Int(pace.rate) or string.format("%.1f", pace.rate)
            if st.fmt and st.fmt ~= "int" then rate = F(pace.rate) end
            text = string.format("At %s a day: %s %s", rate, F(pace.target),
                pace.days <= 1 and "by tomorrow" or ("around " .. date("%b %d, %Y", pace.at) .. " (in " .. Int(pace.days) .. " days)"))
        end
        L.pace:SetText(text); L.pace:Show()
    else
        L.chartHost:Hide(); L.chartTitle:Hide(); L.pace:Hide()
    end

    if h.kind == "record" then
        local rows = {}
        for _, e in ipairs(h.history) do
            rows[#rows + 1] = { date("%b %d, %Y  %H:%M", e.at), F(e.v), e.w or "", tip = e.character }
        end
        L.recTable:SetData(rows); L.recTable:Show(); L.charTable:Hide()
    else
        local rows = {}
        for _, c in ipairs(h.chars) do
            local col = c.class and ns.ClassRGB and ns.ClassRGB(c.class) or nil
            rows[#rows + 1] = { tostring(c.name) .. (c.me and "  (this character)" or ""), F(c.v), "", color = col }
        end
        L.charTable:SetData(rows); L.charTable:Show(); L.recTable:Hide()
    end
    L:Show()
end
function ns.HideStatDetail() if detailLayer then detailLayer:Hide() end end

local function OpenDashboardPinPicker()
    if not pinLayer then pinLayer = CreateDashboardPinPicker() end
    pinLayer:Show()
end

local function BuildDashboard()
    -- the framed skins draw their own overview (Overview.lua)
    if ns.Framed() and ns.BuildFramedOverview then
        return ns.BuildFramedOverview({
            NewPage = NewPage, Panel = Panel, CW = CW, CH = CH, GAP = GAP, DayLabel = DayLabel,
            OpenPins = OpenDashboardPinPicker,
            RangeName = function()
                return ({ today = "Today", session = "This session", week = "Last 7 days", month = "Last 30 days" })[Settings().range] or "Lifetime"
            end,
        })
    end
    local p = NewPage("dashboard")
    KpiRow(p, {
        { id = "computed:steps", label = "Steps taken", icon = "steps", value = ns.Steps, tip = "Distance on foot divided by a 0.75 m stride.",
          sub = function(v, b, s) return ns.GOLD .. PlusAlways(ns.Steps(s)) .. "|r this session" end },
        { id = "counter:jumps", label = "Times jumped", icon = "jump", value = function(v) return c(v, "jumps") end, tip = "Jumps that actually left the ground.",
          sub = function(v, b, s) return ns.GOLD .. PlusAlways(c(s, "jumps")) .. "|r this session" end },
        { id = "computed:kills", label = "Enemies killed", icon = "sword", value = ns.Kills, tip = "Creatures and hostile players that died after you damaged them.",
          sub = function(v, b, s) return ns.GOLD .. PlusAlways(ns.Kills(s)) .. "|r this session · " .. Int(c(v, "kills_pvp")) .. " players" end },
        { id = "counter:deaths", label = "Deaths", icon = "skull", value = function(v) return c(v, "deaths") end, tip = "Times you died.",
          sub = function(v) return "K/D " .. ns.GOLD .. string.format("%.1f", ns.Div(ns.Kills(v), c(v, "deaths"))) .. "|r · first: " .. (v.first and v.first.death or "—") end },
    }, true)
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
    local w1, w2 = math.floor(CW * 0.38), math.floor(CW * 0.32)
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
        UpdateDashboardKpis(self, view, base, sess)
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
    local tw = math.max(470, math.floor(CW * 0.5))
    if cols and cols.cols and not cols.scaled then cols.cols[1][2] = cols.cols[1][2] + (tw - 470); cols.scaled = true end
    local tc = Panel(p, (cols and cols.title) or "All statistics", "lists", 0, BODY_Y, tw, BODY_H, "Hover a row to see how it is measured. Click it for its last 30 days, best day and every character.")
    p.table = W.Table(tc.body, tc.bw, tc.bh, cols and cols.cols or {
        { "STATISTIC", 230 + (tw - 470), kind = "text" }, { "LIFETIME", 120, kind = "num" }, { "SESSION", 0, kind = "dim" },
    }, function(d) if d.def then ns.ShowStatDetail(d.def) end end)
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
        local rows, sections
        if cols and cols.rows then
            rows, sections = cols.rows(view, base, sess, self.focus)
        else
            self.table:SetHeader(2, RangeName())
            self.table:SetHeader(3, Settings().range == "session" and "TODAY" or "SESSION")
            rows, sections = StatRows(id, view, sess, self.focus)
        end
        self.sections = sections
        self.table:SetData(rows, true)
        for _, pn in ipairs(self.panels) do pn.def.update(pn.obj, view, base, sess) end
    end
    function p:SectionTabs() return TableSectionTabs(self.table, self.sections) end
    function p:FocusStat(label)
        self.focus = label
        ns.RefreshWindow()
        FocusRow(self, self.table, label)
    end
    p.table.onScroll = function() if ns.UpdateSectionTabs then ns.UpdateSectionTabs() end end
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
        { title = "Time per level", icon = "clock", h = 280, tip = "Online time spent on each level. The level you are on now is shown as it grows; the level you installed on is marked (since install).",
          build = function(b, bw, bh) return W.BarList(b, bw, bh, 11) end,
          update = function(o, v, base)
              local list = ns.TopList(base, "leveltime", 10)
              local m = ns.char and ns.char.meta
              if base == ns.char and m and m.levelMark and m.levelMarkLevel == UnitLevel("player") then
                  table.insert(list, 1, { "Level " .. m.levelMarkLevel .. (m.levelMarkPartial and " (since install)" or " (now)"), (ns.char.c.time_online or 0) - m.levelMark })
              end
              o:Set(list, Time)
          end },
        ListPanel("Most cast spells", "star", nil, "spells", Int, 10),
    }, {
        title = "Records",
        cols = { { "RECORD", 250, kind = "text" }, { "BEST", 100, kind = "num" }, { "SOURCE", 0, kind = "dim" } },
        rows = function(view, base, sess, focus)
            local rows, sections = {}, {}
            for _, group in ipairs(ns.SectionedStats("records")) do
                rows[#rows + 1] = { group.name, "", "", header = true }
                sections[#sections + 1] = { name = group.name, index = #rows }
                for _, st in ipairs(group.stats) do
                    local v, what = ns.StatValue(st, view)
                    local na, naTip = ns.IsNA(st, v)
                    rows[#rows + 1] = { st.label, na and "n/a" or ((view.today) and "—" or ns.FormatStat(st, v)), what or "", tip = na and naTip or st.tip, what = what,
                        stat = st.label, def = st, color = (focus and st.label == focus) and T.amber or nil }
                end
            end
            return rows, sections
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
    local lw = math.max(250, math.floor(CW * 0.27))
    local lc = Panel(p, "Lists", "lists", 0, 0, lw, CH)
    p.selected = ns.LISTS[1].id
    p.nameT = W.Table(lc.body, lc.bw, lc.bh, { { "LIST", 180, kind = "text" }, { "#", 0, kind = "dim" } }, function(d)
        p.selected = d.id
        ns.RefreshWindow()
    end)
    function p:SectionTabs() return TableSectionTabs(self.nameT, self.sections) end
    p.nameT.onScroll = function() if ns.UpdateSectionTabs then ns.UpdateSectionTabs() end end
    local rc = Panel(p, "Top 100", "star", lw + GAP, 0, CW - lw - GAP, CH)
    p.title = rc.title
    p.rankT = W.Table(rc.body, rc.bw, rc.bh, {
        { "#", 36, kind = "dim" }, { "NAME", 240, kind = "text" }, { "", 170, kind = "bar" }, { "TOTAL", 120, kind = "num" }, { "SESSION", 0, kind = "dim" },
    })
    function p:Update(view, base, sess)
        local names, sections = {}, {}
        for _, group in ipairs(ns.SectionedLists()) do
            names[#names + 1] = { group.name, "", header = true }
            sections[#sections + 1] = { name = group.name, index = #names }
            for _, l in ipairs(group.lists) do
                local n = 0
                if l.count then n = l.count(base) else for _ in pairs(base.t[l.id] or {}) do n = n + 1 end end
                names[#names + 1] = { l.name, n, id = l.id, color = (l.id == self.selected) and T.amber or nil }
            end
        end
        self.sections = sections
        self.nameT:SetData(names, true)
        if self.revealSelected then
            self.revealSelected = nil
            for i, d in ipairs(names) do if d.id == self.selected then self.nameT:Reveal(i) end end
        end
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
    -- 12-month view: days older than 40 are kept as monthly totals, so this reaches back a year.
    p.monthHolder = CreateFrame("Frame", nil, cc.body); p.monthHolder:SetAllPoints()
    p.monthSingle = W.Columns(p.monthHolder, cc.bw, cc.bh, 12, "single")
    p.monthSignedHolder = CreateFrame("Frame", nil, p.monthHolder); p.monthSignedHolder:SetAllPoints()
    p.monthSigned = W.Columns(p.monthSignedHolder, cc.bw, cc.bh, 12, "signed")
    p.chartTitle = cc.title
    local tc = Panel(p, "Day by day", "lists", 0, BODY_Y + 230, CW, BODY_H - 230)
    p.tableTitle = tc.title
    p.period = "days"
    p.periodSeg = W.Segmented(tc, {
        { id = "days", label = "Days", tip = "The last 30 days, one row and one column each." },
        { id = "months", label = "Months", tip = "The last 12 months. Older days are kept as monthly totals." },
    }, function(id) p.period = id; ns.RefreshWindow() end)
    p.periodSeg:SetPoint("TOPRIGHT", -8, -2)
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
        local months = self.period == "months" and not m.levels
        self.periodSeg:Select(self.period)
        if self.chartTitle then self.chartTitle:SetText(ns.CardTitle(months and "Last 12 months" or (m.levels and "Last 30 levels" or "Last 30 days"))) end
        if self.tableTitle then self.tableTitle:SetText(ns.CardTitle(self.period == "months" and "Month by month" or "Day by day")) end
        self.monthHolder:SetShown(months)
        local mseries = (self.period == "months") and ns.MonthRecords(base, 12) or nil
        if months then
            local mv, ml = {}, {}
            for i, e in ipairs(mseries) do
                mv[i] = { m.fn(e.v) }
                ml[i] = date("%b %Y", time({ year = tonumber(e.m:sub(1, 4)), month = tonumber(e.m:sub(5, 6)), day = 1, hour = 12 }))
            end
            local mchart = m.signed and self.monthSigned or self.monthSingle
            self.monthSignedHolder:SetShown(m.signed and true or false)
            mchart:Set(mv, { m.signed and C.amber or C.cream2 }, ml, { ml[1], ml[6], "This month" }, m.fmt, { m.label }, not m.signed)
            if m.signed then self.monthSingle:Set({}, { C.amber }, {}, { "", "", "" }) end
            self.chartSingle:Set({}, { C.amber }, {}, { "", "", "" })
            self.chartSigned:Set({}, { C.amber }, {}, { "", "", "" })
            self.chartHolder:SetShown(false)
        else
            local chart = m.signed and self.chartSigned or self.chartSingle
            self.chartHolder:SetShown(m.signed and true or false)
            chart:Set(vals, { m.signed and C.amber or C.cream2 }, labels, axis, m.fmt, { m.label }, not m.signed)
            if m.signed then self.chartSingle:Set({}, { C.amber }, {}, { "", "", "" }) end
        end
        local rows = {}
        if mseries then
            for i = #mseries, 1, -1 do
                local e, d = mseries[i], mseries[i].v
                if next(d) then
                    rows[#rows + 1] = { date("%B %Y", time({ year = tonumber(e.m:sub(1, 4)), month = tonumber(e.m:sub(5, 6)), day = 1, hour = 12 })) .. (i == #mseries and " (so far)" or ""),
                        Int((d.dist_foot or 0) * ns.YARDS_TO_STEPS), Int(d.jumps or 0), Int((d.kills_npc or 0) + (d.kills_pvp or 0)), Int(d.deaths or 0),
                        Int(d.quests_done or 0), Int(d.xp or 0), Money((d.money_in or 0) - (d.money_out or 0)), Time(d.time_online or 0) }
                end
            end
            self.dayT:SetData(rows, true)
            return
        end
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
            if d.list and pages.lists then pages.lists.selected = d.list; pages.lists.revealSelected = true end
            ns.ShowPage(d.cat)
            local pg = pages[d.cat]
            if pg and pg.FocusStat and d.stat then pg:FocusStat(d.stat) end
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
                    local where = catName[cat] or cat
                    local sec = ns.StatSection and ns.StatSection(cat, st)
                    if sec then where = where .. " › " .. sec end
                    rows[#rows + 1] = { st.label, where, ns.FormatStat(st, v), (sv and sv > 0) and ("+" .. ns.FormatStat(st, sv)) or "",
                        tip = (st.tip or "") .. "\nClick to open " .. (catName[cat] or cat) .. ".", what = what, cat = cat, stat = st.label }
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
    -- notebook: an earned achievement is stamped with a wax seal showing its tier
    if ns.Notebook() and ns.MakeSeal then
        t.seal = ns.MakeSeal(t, 34)
        t.seal:SetPoint("CENTER", t, "TOPRIGHT", -6, -4)
    end
    t:EnableMouse(true)
    t:SetScript("OnEnter", function(self)
        local def, st, ach = self.def, self.st, self.ach
        if not def then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(def.name, ns.TipColor("amber"))
        GameTooltip:AddLine(def.cat, ns.TipColor("dim"))
        for i, target in ipairs(def.tiers) do
            local when = ach[ns.AchKey(def, i)]
            local line = string.format("%s  " .. def.desc, ns.TIER_NAMES[i], ns.FMT[def.fmt](target))
            local right = when and (self.retro[ns.AchKey(def, i)] and "before v1.3" or date("%b %d, %Y", when)) or (ns.TIER_POINTS[i] .. " pts")
            local col = when and T.amber or T.text
            GameTooltip:AddDoubleLine(line, right, col[1], col[2], col[3], ns.TipColor("dim"))
        end
        if st.value then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Current: " .. ns.FMT[def.fmt](st.value), ns.TipColor("text"))
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
        local seal = rawget(self, "seal")
        if seal then
            seal.text:SetText(lit and ns.TIER_NAMES[st.tier] or "")
            seal:SetShown(lit)
            seal:SetAlpha(done and 1 or 0.8)
        end
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
    local lw = math.max(640, math.floor(CW * 0.68))
    local card = Panel(p, "Achievements", "trophy", 0, BODY_Y, lw, BODY_H, "Hover a badge to see every tier and when you earned it.")
    p.cat = "All"
    local opts = {}
    for i, cname in ipairs(ACH_CATS) do opts[i] = { id = cname, label = cname, tip = "Show " .. (cname == "All" and "every achievement" or (cname:lower() .. " achievements")) .. "." } end
    p.seg = W.Segmented(card, opts, function(id) p.cat = id; p.offset = 0; ns.RefreshWindow() end)
    function p:SectionTabs()
        local out = {}
        for i, cname in ipairs(ACH_CATS) do
            out[i] = { name = cname, active = self.cat == cname, click = function()
                self.cat = cname; self.offset = 0
                if self.seg.Select then self.seg:Select(cname) end
                ns.RefreshWindow()
            end }
        end
        return out
    end
    for _, b in ipairs(p.seg.buttons) do b:SetWidth(math.max(40, b.text:GetStringWidth() + 12)) end
    local x = 1
    for _, b in ipairs(p.seg.buttons) do b:ClearAllPoints(); b:SetPoint("LEFT", x, 0); x = x + b:GetWidth() end
    p.seg:SetWidth(x + 1)
    p.seg:SetPoint("TOPRIGHT", -6, -2)
    p.seg:Hide() -- the categories are the tabs down the right edge of the window
    p.sort = "default"
    local sortB = W.FlatButton(card, "Sort: list", 92, 20, "Sort", "Switch between the normal order and closest to the next tier first.")
    sortB:SetPoint("TOPLEFT", 140, -4)
    sortB:SetScript("OnClick", function(self)
        p.sort = (p.sort == "default") and "closest" or "default"
        self.text:SetText(p.sort == "closest" and "Sort: closest" or "Sort: list")
        p.offset = 0
        ns.RefreshWindow()
    end)
    local cols, tileH, gap = (card.bw >= 940 and 3 or 2), 74, 8
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
local JOURNAL_PAGE_SIZE = 10

local function JournalZoneLower(text)
    local lower = C_Intl and C_Intl.ToLower
    if type(lower) == "function" then
        local ok, value = pcall(lower, text)
        if ok and not ns.IsSecret(value) and type(value) == "string" then return value end
    end
    return text:lower()
end

local function JournalEntryTitle(entry)
    local _, zone = ns.JournalEntryInfo(entry)
    return DateLabel(entry[1]) .. "  ·  Level " .. (entry[3] or "?") .. (zone and ("  ·  " .. zone) or "")
end

local function CreateJournalNoteEditor()
    local layer = CreateFrame("Frame", nil, win)
    layer:SetAllPoints()
    layer:SetFrameLevel((win:GetFrameLevel() or 0) + 10)
    layer:EnableMouse(true)
    layer:Hide()
    local dim = W.Fill(layer, { 0.06, 0.04, 0.02, 0.66 })
    dim:SetPoint("TOPLEFT", 1, -HEADER_H); dim:SetPoint("BOTTOMRIGHT", -1, FOOTER_H)

    local width = 580
    local dlg = W.Window(layer)
    dlg:SetSize(width, 372)
    dlg:SetPoint("CENTER")
    dlg:EnableMouse(true)
    local ink = ns.JournalSkin() and W.JOURNAL or nil
    local banner = W.Fill(dlg, T.tile)
    banner:SetPoint("TOPLEFT", 1, -1); banner:SetPoint("TOPRIGHT", -1, -1); banner:SetHeight(38)
    if ink then W.Shade(banner, ink.base, ink.top) end
    local headerRule = W.Line(dlg, ink and ink.trim or nil)
    headerRule:SetPoint("TOPLEFT", 1, -39); headerRule:SetPoint("TOPRIGHT", -1, -39); headerRule:SetHeight(1)
    local title = W.Text(dlg, 16, ink and ink.gold or T.amber)
    title:SetPoint("TOPLEFT", 13, -11)
    local close
    if ink then
        local ok, native = pcall(CreateFrame, "Button", nil, dlg, "UIPanelCloseButtonNoScripts")
        if ok then close = native end
    end
    if not close then close = W.FlatButton(dlg, "×", 24, 24) end
    close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -9, -7)
    close:SetScript("OnClick", function() layer:Hide() end)
    W.Tip(close, "Close", "Discard the draft and return to the Journal.")

    local eventBox = W.Panel(dlg, T.tile)
    eventBox:SetPoint("TOPLEFT", 13, -51); eventBox:SetSize(width - 26, 77)
    local eventScroll = CreateFrame("ScrollFrame", nil, eventBox, "UIPanelScrollFrameTemplate")
    eventScroll:SetPoint("TOPLEFT", 10, -7); eventScroll:SetPoint("BOTTOMRIGHT", -25, 7)
    eventScroll.scrollBarHideIfUnscrollable = true
    local eventBody = CreateFrame("Frame", nil, eventScroll)
    local textWidth = width - 62
    eventBody:SetSize(textWidth, 63)
    eventBody:SetPoint("TOPLEFT", eventScroll, "TOPLEFT")
    eventScroll:SetScrollChild(eventBody)
    local meta = W.Text(eventBody, 11, T.dim, nil, "LEFT")
    meta:SetPoint("TOPLEFT", 0, -1); meta:SetWidth(textWidth); meta:SetWordWrap(true)
    local eventText = W.Text(eventBody, 14, T.text, nil, "LEFT")
    eventText:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -6); eventText:SetWidth(textWidth); eventText:SetWordWrap(true)

    local label = W.Text(dlg, 13, ink and ink.gold or T.amber)
    label:SetPoint("TOPLEFT", 13, -140); label:SetText("Personal note")
    local limit = W.Text(dlg, 11, T.dim)
    limit:SetPoint("TOPRIGHT", -13, -141)
    limit:SetText(string.format("Up to %d characters", ns.JOURNAL_NOTE_LIMIT))
    local box = W.Panel(dlg, T.bg)
    box:SetPoint("TOPLEFT", 13, -160); box:SetSize(width - 26, 141)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -7); scroll:SetPoint("BOTTOMRIGHT", -25, 7)
    scroll.scrollBarHideIfUnscrollable = true
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(W.FONT, 13, "")
    edit:SetTextColor(T.text[1], T.text[2], T.text[3])
    edit:SetSize(textWidth, 1)
    edit:SetPoint("TOPLEFT", scroll, "TOPLEFT")
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    local cursorY, cursorHeight
    local function KeepCursorVisible()
        if not layer:IsVisible() or not cursorY or not cursorHeight then return end
        local offset, height = scroll:GetVerticalScroll(), scroll:GetHeight()
        local top = -cursorY
        if top + cursorHeight > offset + height then top = top + cursorHeight - height
        elseif top >= offset then return end
        scroll:SetVerticalScroll(math.max(0, math.min(top, scroll:GetVerticalScrollRange())))
    end
    edit:SetScript("OnCursorChanged", function(_, _, y, _, lineHeight)
        cursorY, cursorHeight = y, lineHeight
        KeepCursorVisible()
    end)
    scroll:HookScript("OnScrollRangeChanged", function()
        if edit:HasFocus() then KeepCursorVisible() end
    end)
    edit:SetScript("OnEscapePressed", function() layer:Hide() end)

    local privacy = "Saved in this character’s local journal."
    local status = W.Text(dlg, 11, T.dim, nil, "LEFT")
    status:SetPoint("TOPLEFT", 13, -313); status:SetWidth(width - 26)
    local footerRule = W.Line(dlg)
    footerRule:SetPoint("BOTTOMLEFT", 1, 39); footerRule:SetPoint("BOTTOMRIGHT", -1, 39); footerRule:SetHeight(1)
    local save = W.FlatButton(dlg, "Save note", 83, 21)
    save:SetPoint("BOTTOMRIGHT", -13, 9)
    local cancel = W.FlatButton(dlg, "Cancel", 77, 21)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
    cancel:SetScript("OnClick", function() layer:Hide() end)
    local remove = W.FlatButton(dlg, "Remove note", 96, 21)
    remove:SetPoint("BOTTOMLEFT", 13, 9)
    remove.text:SetTextColor(C.rust[1], C.rust[2], C.rust[3])

    local entry
    local function Apply(text)
        local ok, why = ns.SetJournalNote(entry, text)
        if not ok then
            status:SetTextColor(C.rust[1], C.rust[2], C.rust[3])
            status:SetText(why or "The note could not be saved.")
            return
        end
        layer:Hide()
    end
    save:SetScript("OnClick", function() Apply(edit:GetText() or "") end)
    remove:SetScript("OnClick", function() Apply(nil) end)
    layer:SetScript("OnHide", function()
        entry, cursorY, cursorHeight = nil, nil, nil
        edit:ClearFocus()
        edit:SetText("")
        GameTooltip:Hide()
    end)

    function layer:Open(selected)
        entry = selected
        local saved = ns.JournalNote(selected)
        title:SetText(saved and "Edit journal note" or "Add journal note")
        meta:SetText(JournalEntryTitle(selected))
        eventText:SetText(selected[2])
        remove:SetShown(saved ~= nil)
        status:SetTextColor(T.dim[1], T.dim[2], T.dim[3]); status:SetText(privacy)
        edit:SetText(saved or "")
        GameTooltip:Hide()
        self:Show()
        eventBody:SetHeight(math.max(63, (meta:GetStringHeight() or 0) + (eventText:GetStringHeight() or 0) + 10))
        eventScroll:SetVerticalScroll(0)
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
        edit:SetFocus()
    end

    return layer
end

local function OpenJournalNote(entry)
    if not noteLayer then noteLayer = CreateJournalNoteEditor() end
    noteLayer:Open(entry)
end

local function JournalFilters(parent, width)
    local categories = W.Segmented(parent, {
        { id = "all", label = "All", tip = "Show every entry type." },
        { id = "first", label = "Firsts", tip = "Show firsts and first visits." },
        { id = "boss", label = "Boss kills", tip = "Show recorded boss kills." },
        { id = "death", label = "Deaths", tip = "Show recorded deaths." },
        { id = "personalBest", label = "Personal bests", tip = "Show personal records." },
    }, function(id) parent:SetFilter(id, parent.zoneText) end)
    categories:SetPoint("TOPLEFT", 9, -5)
    categories:Select("all")

    local label = W.Text(parent, 11, T.text)
    label:SetText("Zone")
    local box = W.Panel(parent, T.bg)
    local room = width - categories:GetWidth() - label:GetStringWidth() - 36
    local stacked = room < 76
    local height = stacked and 60 or 34
    box:SetSize(stacked and 122 or math.min(122, room), 23)
    box:SetPoint("TOPRIGHT", -9, stacked and -33 or -5)
    label:SetPoint("RIGHT", box, "LEFT", -6, 0)
    local zone = CreateFrame("EditBox", nil, box)
    zone:SetPoint("TOPLEFT", 7, 0); zone:SetPoint("BOTTOMRIGHT", -7, 0)
    zone:SetFont(W.FONT, 11, "")
    zone:SetTextColor(T.text[1], T.text[2], T.text[3])
    zone:SetAutoFocus(false)
    local hint = W.Text(box, 11, T.dim)
    hint:SetPoint("LEFT", 7, 0); hint:SetText("All zones")
    zone:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "" and not self:HasFocus())
        parent:SetFilter(parent.kindFilter, text)
    end)
    zone:SetScript("OnEditFocusGained", function() hint:Hide() end)
    zone:SetScript("OnEditFocusLost", function(self) hint:SetShown((self:GetText() or "") == "") end)
    zone:SetScript("OnEscapePressed", zone.ClearFocus)
    zone:SetScript("OnEnterPressed", zone.ClearFocus)
    zone:SetScript("OnHide", zone.ClearFocus)
    local rule = W.Line(parent)
    rule:SetPoint("TOPLEFT", 1, -height); rule:SetPoint("TOPRIGHT", -1, -height); rule:SetHeight(1)
    return categories, zone, height
end

local function JournalFeed(parent, width, height)
    local ink = ns.JournalSkin() and W.JOURNAL or nil
    local f = W.Panel(parent, ink and ink.page or T.bg)
    f:SetAllPoints()
    f.offset, f.entries, f.rows = 0, {}, {}
    f.source, f.kindFilter, f.zoneText = f.entries, "all", ""
    local gold = ink and ink.gold or T.amber
    local categories, zoneEdit, toolbarHeight = JournalFilters(f, width)
    f.zoneEdit = zoneEdit
    for i = 1, JOURNAL_PAGE_SIZE do
        local row = CreateFrame("Button", nil, f)
        row:SetWidth(width - 26)
        row.day = W.Text(row, 13, gold, nil, "LEFT")
        row.day:SetPoint("TOPLEFT", 0, -1)
        row.rule = W.Line(row, gold)
        row.rule:SetPoint("TOPLEFT", 0, -16); row.rule:SetPoint("TOPRIGHT", 0, -16)
        row.rule:SetHeight(1); row.rule:SetAlpha(0.45)
        row.meta = W.Text(row, 11, T.dim, nil, "LEFT")
        row.prose = W.Text(row, 13, T.text, nil, "LEFT")
        row.prose:SetWidth(width - 120)
        row.prose:SetJustifyV("TOP")
        row.prose:SetWordWrap(true)
        row.prose:SetMaxLines(2)
        local line = W.Line(row)
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1); line:SetAlpha(0.5)
        W.Tip(row, function() return JournalEntryTitle(row.entry) end,
            function() return row.entry[2] end, "Click to view the entry or write a personal note.")
        row:SetScript("OnClick", function(self)
            local e = self.entry
            if e then OpenJournalNote(e) end
        end)
        f.rows[i] = row
    end
    local empty = W.Text(f, 14, T.dim)
    empty:SetPoint("TOP", 0, -toolbarHeight - 27)
    local footerRule = W.Line(f)
    footerRule:SetPoint("BOTTOMLEFT", 1, 30); footerRule:SetPoint("BOTTOMRIGHT", -1, 30); footerRule:SetHeight(1)
    local newer = W.FlatButton(f, "Newer", 65, 20)
    newer:SetPoint("BOTTOMLEFT", 9, 5)
    local older = W.FlatButton(f, "Older", 65, 20)
    older:SetPoint("BOTTOMRIGHT", -9, 5)
    local position = W.Text(f, 11, T.dim)
    position:SetPoint("BOTTOM", 0, 9)

    function f:Render()
        local total = #self.entries
        local n = math.min(JOURNAL_PAGE_SIZE, total - self.offset)
        local days, dayCount, lastDay = {}, 0, nil
        for i = 1, n do
            local e = self.entries[total - self.offset - i + 1]
            local day = date("%Y-%m-%d", e[1])
            if day ~= lastDay then
                days[i] = date("%A, %B %d, %Y", e[1])
                dayCount = dayCount + 1
                lastDay = day
            end
        end
        -- Keep a usable two-line entry even when every row starts a different day.
        local dayHeight = 18
        local rowHeight = math.min(38, math.floor((height - toolbarHeight - 42 - dayCount * dayHeight) / math.max(1, n)))
        local y = -toolbarHeight - 7
        for i, row in ipairs(self.rows) do
            local e = i <= n and self.entries[total - self.offset - i + 1]
            if e then
                local daySpace = days[i] and dayHeight or 0
                local h = rowHeight + daySpace
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", f, "TOPLEFT", 13, y)
                row:SetHeight(h)
                row.day:SetText(days[i] or "")
                row.day:SetShown(daySpace > 0); row.rule:SetShown(daySpace > 0)
                row.meta:ClearAllPoints()
                row.meta:SetPoint("TOPLEFT", 0, -daySpace - 4)
                row.meta:SetText(date("%H:%M", e[1]) .. "  ·  Lv " .. (e[3] or "?"))
                row.prose:ClearAllPoints()
                row.prose:SetPoint("TOPLEFT", 94, -daySpace - 3)
                row.prose:SetFont(W.FONT, rowHeight < 29 and 12 or 13, "")
                row.prose:SetHeight(rowHeight - 2)
                row.prose:SetText(e[2])
                row.entry = e
                row:Show()
                y = y - h
            else
                row.entry = nil
                row:Hide()
            end
        end
        self.anchor = self.offset > 0 and self.entries[total - self.offset] or nil
        if n == 0 then
            empty:SetText(self.total == 0 and "Your story will appear here as you play." or "No journal entries match these filters.")
        end
        empty:SetShown(n == 0)
        position:SetText(n > 0 and string.format("Entries %d–%d of %d", self.offset + 1, self.offset + n, total) or "")
        newer:SetEnabled(self.offset > 0)
        newer:SetAlpha(self.offset > 0 and 1 or 0.55)
        older:SetEnabled(self.offset + n < total)
        older:SetAlpha(self.offset + n < total and 1 or 0.55)
    end

    function f:SetEntries(entries)
        local total = #entries
        local latest = entries[total]
        local sourceChanged = entries ~= self.source
        local filterChanged = self.kindFilter ~= self.cachedKind or self.zoneText ~= self.cachedZone
        if not sourceChanged and not filterChanged and total == self.total and latest == self.latest then return end
        self.source, self.total, self.latest = entries, total, latest
        self.cachedKind, self.cachedZone = self.kindFilter, self.zoneText

        local query = JournalZoneLower(self.zoneText:match("^%s*(.-)%s*$"))
        local matches = entries
        if self.kindFilter ~= "all" or query ~= "" then
            matches = {}
            for _, entry in ipairs(entries) do
                local kind, zone, alsoKind = ns.JournalEntryInfo(entry)
                local matchesKind = self.kindFilter == "all" or kind == self.kindFilter or alsoKind == self.kindFilter
                if matchesKind and (query == "" or (zone and JournalZoneLower(zone):find(query, 1, true))) then
                    matches[#matches + 1] = entry
                end
            end
        end
        self.entries = matches
        if sourceChanged or filterChanged then
            self.offset = 0
        elseif self.offset > 0 and self.anchor then
            -- New entries and retention trim must not move the reader's first entry.
            for i = #matches, 1, -1 do
                if matches[i] == self.anchor then self.offset = #matches - i; break end
            end
        end
        self.offset = math.min(self.offset, math.max(0, #matches - 1))
        self:Render()
    end

    function f:SetFilter(kind, zone)
        if self.kindFilter == kind and self.zoneText == zone then return end
        self.kindFilter, self.zoneText = kind, zone
        categories:Select(kind)
        self:SetEntries(self.source)
    end

    local function Turn(direction)
        local nextOffset = f.offset + direction * JOURNAL_PAGE_SIZE
        if nextOffset >= #f.entries then return end
        nextOffset = math.max(0, nextOffset)
        if f.offset == nextOffset then return end
        f.offset = nextOffset
        f:Render()
    end
    newer:SetScript("OnClick", function() Turn(-1) end)
    older:SetScript("OnClick", function() Turn(1) end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) if delta ~= 0 then Turn(delta > 0 and -1 or 1) end end)
    return f
end

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
    p.story = JournalFeed(jc.body, jc.bw, jc.bh)
    local rc = Panel(p, "Life per level", "adventure", lw + GAP, BODY_Y, CW - lw - GAP, 290, "What happened while you were at each level (from the level-ups seen since install).")
    p.lvT = W.Table(rc.body, rc.bw, rc.bh, { { "LV", 34, kind = "num" }, { "TIME", 70, kind = "dim" }, { "KILLS", 52, kind = "num" }, { "DEATHS", 52, kind = "num" }, { "STEPS", 0, kind = "num" } })
    local zc = Panel(p, "Travel log", "travel", lw + GAP, BODY_Y + 300, CW - lw - GAP, BODY_H - 300, "Every zone, when you first arrived and at what level.")
    p.zT = W.Table(zc.body, zc.bw, zc.bh, { { "ZONE", 170, kind = "text" }, { "LV", 34, kind = "num" }, { "ARRIVED", 0, kind = "dim" } })
    function p:Update(view, base, sess)
        UpdateKpis(self, view, base, sess)
        self.story:SetEntries(ns.char.journal or self.emptyStory)
        local snaps, levels = ns.char.lvlsnap or {}, {}
        for k in pairs(snaps) do levels[#levels + 1] = tonumber(k) end
        table.sort(levels)
        local lr = {}
        -- current level so far (from the last snapshot)
        local curLv = UnitLevel("player") or 0
        local now = snaps[tostring(curLv)]
        if now then
            local function d(k) return (ns.char.c[k] or 0) - (now[k] or 0) end
            lr[#lr + 1] = { curLv .. (now.partial and " (since install)" or " (now)"), Time(d("time_online")), Int(d("kills_npc") + d("kills_pvp")), Int(d("deaths")), Int(d("dist_foot") * ns.YARDS_TO_STEPS) }
        end
        for i = #levels, 1, -1 do
            local lv = levels[i]
            local cur, prev = snaps[tostring(lv)], snaps[tostring(lv - 1)]
            if prev then
                local function d(k) return (cur[k] or 0) - (prev[k] or 0) end
                lr[#lr + 1] = { tostring(lv - 1) .. (prev.partial and " (partial)" or ""), Time(d("time_online")), Int(d("kills_npc") + d("kills_pvp")), Int(d("deaths")), Int(d("dist_foot") * ns.YARDS_TO_STEPS) }
            end
        end
        self.lvT:SetData(lr, true)
        local zr = {}
        for z, e in pairs(ns.char.zonelog or {}) do zr[#zr + 1] = { z, tostring(e[2] or ""), date("%b %d %H:%M", e[1]), when = e[1] } end
        table.sort(zr, function(a, b) return a.when > b.when end)
        self.zT:SetData(zr, true)
    end
    p.emptyStory = {}
end

-- ============================================================ HOW IT WORKS
ns.HELP = {
    { "Finding your way", "Tabs down the left edge open the chapters of the book (Hero, Deeds, Quests, Legends, Chronicle, Lore); the tags in the margin are the pages of that chapter. Tabs down the right edge jump to the sections of the page you are reading, and the highlighted one is the section in view. Ctrl+F searches every statistic: each result names its page and section, and clicking it opens the page at that row. Click any statistic for its last 30 days, best day and every character. For more room, set Window size to Fill screen in the settings (or type /lts size fill)." },
    { "Counting", "LifeTimeStats starts counting when it is installed. The game does not remember most of these numbers, so nothing before that can be recovered. /played and lifetime honorable kills are read from the server." },
    { "Lifetime, Session, Today", "Lifetime is everything since install. Session is since you logged in (a /reload keeps it; Reset session in settings or /lts session clears it). Today resets at local midnight; 40 days of daily history are kept." },
    { "This character / All characters", "All characters adds up every character on this account that has logged in with LifeTimeStats. Records take the best, fastest times take the quickest, uniques are merged." },
    { "Steps and distance", "Distance comes from your movement speed, sampled four times a second. Steps are distance on foot divided by a 0.75 m stride. Mounted, swimming, flight path and ghost distance are separate and never count as steps. Travel and Cat form count as on foot." },
    { "Jumps and falls", "A jump only counts when you actually leave the ground (not while swimming or on a flight path). Airtime runs from leaving the ground to landing. Fall damage is the health you lost right as you landed; a fall is survived if you are still alive a second later." },
    { "Forever and the combat log", "Forever does not give addons the combat log (it is reserved for Blizzard's own UI), so LifeTimeStats reads combat from what is still available: experience and honor messages, the units you fight, the combat text feed and your own health. After every fight it also reads Forever's built-in damage meter, which gives damage and healing you do (total and per spell), damage taken and who dealt it, avoidable damage, interrupts and dispels. A few statistics still need the combat log itself (overhealing, buffs, debuffs, killing blows you deal); they show n/a. /lts debug shows which sources are working." },
    { "Kills", "A kill counts when you get experience or honor for it, or when a hostile unit you were fighting (your target, mouseover, nameplates, boss frames) dies and was not tagged by someone else. The two are matched so one kill is never counted twice. Grey creatures that give no experience count only when you can see them die. Inside instances names are hidden from addons, so those kills are listed as Unknown (instance)." },
    { "Your damage and avoidance", "Hits, crits and attacks that were dodged, parried, blocked or resisted come from the combat text feed on your target, and only while you fight alone, because in a group the feed cannot tell whose hit it was. Attacks on you (hits, crits, crushing blows, dodges, parries, blocks, misses, resists) are always counted. Forever hides how big each single hit is, so biggest hit comes only from death recaps; damage done, DPS and damage per spell come from the game's damage meter after each fight." },
    { "Crowd control, cinematics and respecs", "Crowd control comes from the game's loss-of-control alert (the big icon in the middle of the screen): each stun, fear, root, silence, polymorph or similar effect counts once when it lands, with its full duration. Cinematics and movies count from start to end; pressing Escape or Cancel marks one as skipped. A respec counts when you confirm unlearning your talents at a trainer, with the price the trainer showed." },
    { "Your bags", "An item counts as used when you right-click it in your bags or /use it, unless a vendor, bank, mailbox, trade or auction window is open (then it is sold, stored or attached) or it is gear you equip. Different items carried counts every item ID that has been in your bags while LifeTimeStats was running; bag space and slots filled are checked a few seconds after your bags change." },
    { "Deaths and corpse runs", "The cause comes from the game's death recap (fire, lava, falling, drowning, fatigue, slime, or the attacker and spell); if there is none, from the damage meter's killing blow during a fight, else from a fall, running out of breath, or the hostile unit you were targeting. A corpse run lasts from releasing your spirit until you are alive again; its distance is how far your ghost moved." },
    { "Dungeons and raids", "Each separate instance is one run. A /reload, disconnect or leaving for under 30 minutes stays the same run; an instance reset starts a new one. Classic has no 'dungeon complete' event, so the addon counts runs with a boss kill. Fastest clear = entering to the last boss, and only runs that killed as many bosses as your best run there count. Raids also count a full clear when your lockout shows every boss dead." },
    { "Fastest times", "Lower is better. Level times use online time from one level-up to the next, so the level you were on when you installed is skipped. Quest times run from accepting to turning in (even across days)." },
    { "Uniques and firsts", "Uniques count different things you met, killed, visited or used; each list stops growing at 20,000 entries. Firsts are the first time something happened after install." },
    { "Gold", "Every change in the gold you carry is counted. The source (loot, vendor, auction house, mail, flight master, trainer) comes from which window was open at the time." },
    { "Where you are", "Capital cities are the six Classic capitals. Continent and zone come from the game map. Time per place is sampled four times a second." },
    { "Your data", "LifeTimeStats stores data locally in the account and character files. Stats only merges statistics and personal-best history on restore. Full character includes Journal entries, private notes and play-session history. A full restore replaces saved character data after confirmation. Share posts a summary without private notes to your selected WoW chat channel." },
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
    p.topics = {}
    for _, h in ipairs(ns.HELP) do
        p.topics[#p.topics + 1] = { name = h[1], y = y }
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
        ns.UpdateSectionTabs()
    end)
    -- one tab per topic; the active one is the topic at the top of the view
    function p:SectionTabs()
        local out, at, active = {}, sf:GetVerticalScroll() or 0, 1
        for i, t in ipairs(self.topics) do if t.y <= at + 10 then active = i end end
        for i, t in ipairs(self.topics) do
            out[i] = { name = t.name, active = i == active, click = function()
                local maxS = math.max(0, child:GetHeight() - sf:GetHeight())
                sf:SetVerticalScroll(math.min(maxS, t.y))
            end }
        end
        return out
    end
    function p:Update() end
end

-- ============================================================ shell
function ns.ShowPage(id)
    if not pages[id] then id = "dashboard" end
    ns.activePage = id
    if id ~= "search" then Settings().lastCategory = id end
    if id ~= "dashboard" and pinLayer then pinLayer:Hide() end
    if id ~= "journal" and noteLayer then noteLayer:Hide() end
    win:SetDashboardPinButtonShown(id == "dashboard")
    if current and current ~= pages[id] then current:Hide() end
    if pages[id] ~= current then pages[id].focus = nil end
    if detailLayer then detailLayer:Hide() end
    current = pages[id]
    current:Show()
    local nb = rawget(win, "notebook")
    if nb then pcall(nb.Select, nb, id) end
    local ink = ns.JournalSkin() and W.JOURNAL or nil
    for _, b in ipairs(win.navButtons) do
        local sel = b.id == id
        b.bar:SetShown(sel)
        W.Color(b.bg, sel and (ink and ink.tab or T.tileHi) or T.bg, ink and not sel and 0.20 or nil)
        if ink then b.tabEdge:SetShown(sel) end
        local col = sel and (ink and ink.gold or T.amber) or T.text
        b.text:SetTextColor(col[1], col[2], col[3])
        b.icon:SetVertexColor(sel and T.amber[1] or T.dim[1], sel and T.amber[2] or T.dim[2], sel and T.amber[3] or T.dim[3])
        if ns.Framed() and ns.StyleFramedNav then ns.StyleFramedNav(b, sel) end
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
    ns.UpdateSectionTabs()
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
    win.level:SetText(string.format("Level %d%s", UnitLevel("player") or 0,
        ns.Score and ("  ·  " .. ns.FormatInt((ns.Score(ns.char))) .. " pts") or ""))
end

local function DefaultScale()
    local w, h = UIParent:GetWidth() or WIN_W, UIParent:GetHeight() or WIN_H
    local sc = math.min(1, w * 0.96 / WIN_W, h * 0.92 / WIN_H)
    return math.max(0.05, math.floor(sc * 20) / 20)
end

-- Section tabs: bookmarks down the right edge of the window, one per section of the page
-- shown (stat pages, Records, Top Lists, Achievements). Pages without sections hide them.
local SECTION_TABS, SECTION_TAB_W, SECTION_TAB_H, SECTION_GAP = 26, 118, 22, 3
local function BuildSectionBar()
    local book = ns.Notebook()
    local bar = CreateFrame("Frame", nil, win)
    bar:SetSize(SECTION_TAB_W, SECTION_TABS * (SECTION_TAB_H + SECTION_GAP))
    local outside = book and 34 or (ns.Framed() and 30 or 2) -- past the parchment or the wooden frame
    bar:SetPoint("TOPLEFT", win, "TOPRIGHT", outside, -(HEADER_H + PAD))
    bar:SetFrameLevel((win:GetFrameLevel() or 1) + 1)
    bar.tabs = {}
    for i = 1, SECTION_TABS do
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(SECTION_TAB_W, SECTION_TAB_H)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * (SECTION_TAB_H + SECTION_GAP))
        if book then
            b.bg = b:CreateTexture(nil, "BACKGROUND")
            b.bg:SetAllPoints()
            b.bg:SetTexture(W.MEDIA .. "notebook\\tag")
            b.bg:SetTexCoord(1, 0, 0, 1) -- the tag points away from the page
        else
            b.bg = W.Fill(b, T.tile, "BACKGROUND")
            b.bg:SetAllPoints()
            b.edge = W.Fill(b, T.amber, "BORDER"); b.edge:SetPoint("TOPLEFT"); b.edge:SetPoint("BOTTOMLEFT"); b.edge:SetWidth(2)
        end
        b.text = W.Text(b, 10, T.dim, nil, "LEFT")
        b.text:SetPoint("LEFT", book and 10 or 8, 0); b.text:SetWidth(SECTION_TAB_W - 16)
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self) if self.def and self.def.click then self.def.click(); ns.UpdateSectionTabs() end end)
        b:SetScript("OnEnter", function(self)
            if not self.def then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.def.name, ns.TipColor("amber"))
            GameTooltip:AddLine("Jump to this section of the page.", ns.TipColor("text", true))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        bar.tabs[i] = b
    end
    bar.book = book
    -- keep the tabs on screen when the window is dragged against the right edge
    if win.SetClampRectInsets then pcall(win.SetClampRectInsets, win, 0, -(outside + SECTION_TAB_W), 0, 0) end
    bar:Hide()
    win.sectionBar = bar
end

function ns.UpdateSectionTabs()
    local bar = win and rawget(win, "sectionBar")
    if not bar then return end
    local defs = current and current.SectionTabs and current:SectionTabs() or nil
    if not defs or #defs < 2 then bar:Hide(); return end
    local book = bar.book
    local J = W.JOURNAL
    for i, b in ipairs(bar.tabs) do
        local d = defs[i]
        b.def = d
        if d then
            local text = book and W.SmallCaps(d.name) or d.name
            b.text:SetText(text)
            local col = d.active and T.amber or ((book or ns.Paper()) and T.text or T.dim)
            b.text:SetTextColor(col[1], col[2], col[3])
            if book then
                if d.active then W.Bold(b.text, T.amber) elseif b.text.SetShadowOffset then b.text:SetShadowOffset(0, 0) end
                local c = d.active and J.page or J.tab
                b.bg:SetVertexColor(c[1], c[2], c[3], 1)
                b:SetPoint("TOPLEFT", d.active and 6 or 0, -(i - 1) * (SECTION_TAB_H + SECTION_GAP))
            else
                -- opaque, so the tabs read cleanly over the game world
                W.Color(b.bg, d.active and T.tileHi or T.tile, ns.Framed() and 0.97 or nil)
                b.edge:SetShown(d.active)
            end
            b:Show()
        else
            b:Hide()
        end
    end
    bar:Show()
end

local function CreateWindow()
    if ns.ApplyTheme then pcall(ns.ApplyTheme) end
    W.Init()
    C = W.C
    local ink = ns.JournalSkin() and W.JOURNAL or nil
    local trim = ink and ink.trim or T.amber
    ComputeLayout()
    win = W.Window(UIParent)
    win:SetSize(WIN_W, WIN_H)
    win:SetFrameStrata("HIGH")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetToplevel(true)
    win:Hide()
    local s = Settings().window
    if not s.scale then s.scale = s.size == "fill" and 1 or DefaultScale() end
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
    if ink then W.Shade(hbg, ink.base, ink.top) end
    if ns.Paper() then hbg:SetAlpha(0) end -- the parchment shows through
    local rule = W.Fill(head, trim, "ARTWORK"); rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(2)
    local logo = head:CreateTexture(nil, "ARTWORK"); logo:SetSize(28, 28); logo:SetPoint("LEFT", 10, 0); logo:SetTexture(W.MEDIA .. "icon")
    local t1 = W.Text(head, 18, ink and ink.gold or T.amber); t1:SetPoint("LEFT", logo, "RIGHT", 8, 0); t1:SetText("LifeTime")
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

    local close
    if ink then
        local ok, native = pcall(CreateFrame, "Button", nil, head, "UIPanelCloseButtonNoScripts")
        if ok then close = native end
    end
    if not close then
        close = CreateFrame("Button", nil, head)
        close.t = W.Text(close, 18, T.text); close.t:SetPoint("CENTER"); close.t:SetText("x")
        close:SetScript("OnEnter", function() close.t:SetTextColor(T.amber[1], T.amber[2], T.amber[3]) end)
        close:SetScript("OnLeave", function() close.t:SetTextColor(T.text[1], T.text[2], T.text[3]) end)
    end
    close:SetSize(26, 26); close:SetPoint("RIGHT", -8, 0)
    close:SetScript("OnClick", function() win:Hide() end)
    W.Tip(close, "Close", "Closes the window (Esc also works).")

    local portrait = head:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(32, 32); portrait:SetPoint("RIGHT", close, "LEFT", -10, 0)
    if portrait.SetMask then pcall(portrait.SetMask, portrait, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    win.portrait = portrait
    local ring = head:CreateTexture(nil, "OVERLAY")
    ring:SetSize(36, 36); ring:SetPoint("CENTER", portrait); ring:SetTexture(W.MEDIA .. "dot"); ring:SetVertexColor(T.amber[1], T.amber[2], T.amber[3]); ring:SetDrawLayer("BACKGROUND")
    local name = W.Text(head, 13, T.text, nil, "RIGHT"); name:SetPoint("BOTTOMRIGHT", portrait, "LEFT", -8, 1); name:SetText(UnitName("player") or "")
    win.nameText = name
    win.level = W.Text(head, 10, T.dim, nil, "RIGHT"); win.level:SetPoint("TOPRIGHT", portrait, "LEFT", -8, -1); win.level:SetWidth(136)

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
    win.headParts = { logo = logo, t1 = t1, t2 = t2, rule = rule, sb = sb, close = close, portrait = portrait, ring = ring, gear = gear }

    -- sidebar ---------------------------------------------------------
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 1, -HEADER_H - 1); side:SetPoint("BOTTOMLEFT", 1, FOOTER_H)
    side:SetWidth(SIDEBAR_W - 1)
    if ink and not ns.Paper() then
        local spine = W.Fill(side, ink.base); spine:SetAllPoints()
        W.Shade(spine, ink.base, ink.top)
    end
    local sr = W.Line(side); sr:SetPoint("TOPRIGHT"); sr:SetPoint("BOTTOMRIGHT"); sr:SetWidth(1)
    win.navButtons = {}
    for i, cat in ipairs(ns.CATEGORIES) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(SIDEBAR_W - 2, NAV_STEP - 1)
        b:SetPoint("TOPLEFT", 0, -6 - (i - 1) * NAV_STEP)
        b.bg = W.Fill(b, T.bg); b.bg:SetAllPoints()
        local line = W.Line(b); line:SetPoint("BOTTOMLEFT", 8, 0); line:SetPoint("BOTTOMRIGHT", -8, 0); line:SetHeight(1); line:SetAlpha(0.5)
        b.bar = W.Fill(b, trim, "ARTWORK"); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(3)
        if ink then
            b.tabEdge = W.Line(b, trim, "ARTWORK")
            b.tabEdge:SetPoint("BOTTOMLEFT", 3, 0); b.tabEdge:SetPoint("BOTTOMRIGHT", 0, 0); b.tabEdge:SetHeight(1)
        end
        b.icon = W.Icon(b, cat.icon, 16, T.dim); b.icon:SetPoint("LEFT", 14, 0)
        b.text = W.Text(b, 12, T.text); b.text:SetPoint("LEFT", b.icon, "RIGHT", 9, 0); b.text:SetText(cat.short or cat.name)
        b.text:SetWidth(SIDEBAR_W - 14 - 16 - 9 - 34); b.text:SetJustifyH("LEFT")
        if (b.text:GetStringWidth() or 0) > SIDEBAR_W - 73 then b.text:SetFont(W.FONT, 11, "") end
        local kb = W.Panel(b, T.bg)
        kb:SetSize(16, 16); kb:SetPoint("RIGHT", -10, 0)
        local kt = W.Text(kb, 9, T.dim); kt:SetPoint("CENTER"); kt:SetText(cat.key)
        b.kb = kb
        b.badgeBg = W.Fill(b, T.amber, "OVERLAY"); b.badgeBg:SetSize(14, 12); b.badgeBg:SetPoint("CENTER", b.icon, "TOPRIGHT", 2, -1); b.badgeBg:Hide()
        b.badge = W.Text(b, 9, T.bg, W.NUM); b.badge:SetPoint("CENTER", b.badgeBg, "CENTER", 0, 0); b.badge:SetDrawLayer("OVERLAY", 7)
        b.id = cat.id
        b:SetScript("OnClick", function() win.search:SetText(""); ns.ShowPage(cat.id) end)
        b:SetScript("OnEnter", function(self)
            if current ~= pages[self.id] then W.Color(self.bg, T.tile) end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(cat.name, ns.TipColor("amber"))
            GameTooltip:AddLine("Shortcut: " .. cat.key .. " (while the mouse is over this window, out of combat)", ns.TipColor("dim", true))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            if current ~= pages[self.id] then W.Color(self.bg, T.bg, ink and 0.20 or nil) end
            GameTooltip:Hide()
        end)
        win.navButtons[i] = b
    end

    -- today summary fills the space under the page list
    local navBottom = 6 + #ns.CATEGORIES * NAV_STEP
    local todayH = CH + PAD * 2 - navBottom - 12
    if todayH >= 70 then
        local tb = CreateFrame("Frame", nil, side)
        win.todayBox = tb
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

    if ns.Notebook() and ns.BuildNotebookFrame then ns.BuildNotebookFrame(win, side, { HEADER_H = HEADER_H, FOOTER_H = FOOTER_H, SIDEBAR_W = SIDEBAR_W, PAD = PAD, CW = CW, CH = CH }) end
    if ns.Framed() and ns.BuildFramedSkin then ns.BuildFramedSkin(win, side, head, { HEADER_H = HEADER_H, FOOTER_H = FOOTER_H, SIDEBAR_W = SIDEBAR_W, PAD = PAD, CW = CW, CH = CH }) end

    -- section tabs down the right side ---------------------------------
    BuildSectionBar()

    -- content ---------------------------------------------------------
    local content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT", SIDEBAR_W + PAD, -HEADER_H - PAD)
    content:SetSize(CW, CH)
    win.content = content

    -- footer ----------------------------------------------------------
    local foot = CreateFrame("Frame", nil, win)
    foot:SetPoint("BOTTOMLEFT", 1, 1); foot:SetPoint("BOTTOMRIGHT", -1, 1); foot:SetHeight(FOOTER_H)
    local fbg = W.Fill(foot, T.tile); fbg:SetAllPoints()
    if ink then W.Shade(fbg, ink.base, ink.top) end
    if ns.Paper() then fbg:SetAlpha(0) end
    local ftop = W.Line(foot); ftop:SetPoint("TOPLEFT"); ftop:SetPoint("TOPRIGHT"); ftop:SetHeight(1)
    win.footer = W.Text(foot, 10, T.dim); win.footer:SetPoint("LEFT", 10, 0)
    local restore = W.FlatButton(foot, "Restore", 64, 18, nil, "Merge a stats backup or preview a full character restore.")
    restore:SetPoint("RIGHT", -6, 0); restore:SetScript("OnClick", function() ns.ShowImport() end)
    local backup = W.FlatButton(foot, "Backup", 64, 18, nil, "Choose a stats-only or full character text backup.")
    backup:SetPoint("RIGHT", restore, "LEFT", -6, 0); backup:SetScript("OnClick", function() ns.ShowExport() end)
    local share = W.FlatButton(foot, "Share", 64, 18, nil, "Preview a one-line summary of this page and post it to a chat channel you pick. Nothing is posted until you press Send.")
    share:SetPoint("RIGHT", backup, "LEFT", -6, 0)
    share:SetScript("OnClick", function() ns.ShowShare(current and current.id or "dashboard") end)
    local sheet = W.FlatButton(foot, "Sheet", 64, 18, nil, "Show a character sheet you can copy and paste anywhere.")
    sheet:SetPoint("RIGHT", share, "LEFT", -6, 0)
    sheet:SetScript("OnClick", function() ns.ShowSheet() end)
    local pins = W.FlatButton(foot, "Manage pins", 91, 18, nil, "Choose which statistics appear first on the Dashboard.")
    pins:SetPoint("RIGHT", sheet, "LEFT", -6, 0)
    pins:SetScript("OnClick", OpenDashboardPinPicker)
    pins:Hide()
    local ver = W.Text(foot, 10, T.dim); ver:SetText("v" .. ns.VERSION)
    function win:SetDashboardPinButtonShown(shown)
        pins:SetShown(shown)
        ver:ClearAllPoints()
        ver:SetPoint("RIGHT", shown and pins or sheet, "LEFT", -12, 0)
    end

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
    if ns.BuildGuidePage then ns.BuildGuidePage({ NewPage = NewPage, Panel = Panel, CW = CW, CH = CH, GAP = GAP }) end
    if ns.BuildRosterPage then ns.BuildRosterPage({ NewPage = NewPage, Panel = Panel, CW = CW, CH = CH, GAP = GAP }) end

    -- keyboard: only while the mouse is over the window and out of combat
    local keyMap = {}
    for _, cat in ipairs(ns.CATEGORIES) do keyMap[cat.key] = cat.id end
    win:EnableKeyboard(true)
    if win.SetPropagateKeyboardInput then win:SetPropagateKeyboardInput(true) end
    win:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() or not self.SetPropagateKeyboardInput then return end
        local handled = false
        local modal = pinLayer
        if noteLayer and noteLayer:IsShown() then modal = noteLayer end
        if modal and modal:IsShown() then
            if key == "ESCAPE" then modal:Hide(); handled = true end
        elseif self:IsMouseOver() and not win.search:HasFocus() and not pages.journal.story.zoneEdit:HasFocus() then
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
    win:SetScript("OnHide", function()
        if pinLayer then pinLayer:Hide() end
        if noteLayer then noteLayer:Hide() end
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

-- Addon compartment (the addon list button by the minimap on clients that have it).
-- These three names are referenced from the TOC, so they must be globals.
function LifeTimeStats_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns.OpenOptions() else ns.ToggleWindow() end
end
function LifeTimeStats_OnAddonCompartmentEnter(_, frame)
    if not GameTooltip or not frame then return end
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine("LifeTimeStats")
    GameTooltip:AddLine("Click to open · Right-click for settings", 1, 1, 1)
    GameTooltip:Show()
end
function LifeTimeStats_OnAddonCompartmentLeave() if GameTooltip then GameTooltip:Hide() end end

function ns.ToggleWindow()
    if not win then CreateWindow() end
    win:SetShown(not win:IsShown())
end

function ns.ResetWindow()
    local s = Settings().window
    local fill = s.size == "fill"
    s.point, s.x, s.y, s.scale = "CENTER", fill and -math.floor(TAB_ROOM / 2) or 0, 0, nil
    if win then
        s.scale = fill and 1 or DefaultScale()
        win:SetScale(s.scale)
        win:ClearAllPoints()
        win:SetPoint("CENTER", UIParent, "CENTER", s.x, 0)
    end
end

-- Normal or Fill screen. The pages are laid out once, so a new size applies after a reload.
StaticPopupDialogs["LIFETIMESTATS_RELOAD_SIZE"] = {
    text = "LifeTimeStats: the new window size applies after reloading the interface. Reload now?",
    button1 = RELOADUI or "Reload", button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function ns.SetWindowSize(mode)
    mode = (mode == "fill") and "fill" or "normal"
    local s = Settings().window
    if (s.size or "normal") == mode then return false end
    s.size = mode
    -- centred, nudged left so the section tabs on the right stay on screen
    s.point, s.x, s.y = "CENTER", (mode == "fill") and -math.floor(TAB_ROOM / 2) or 0, 0
    if mode == "fill" then s.scale = 1 end
    StaticPopup_Show("LIFETIMESTATS_RELOAD_SIZE")
    return true
end

function ns.ApplyWindowSettings()
    if win then win:SetScale(Settings().window.scale or DefaultScale()) end
end

-- ------------------------------------------------------------ minimap button
local mmb
-- Minimap shapes as minimap addons report them through GetMinimapShape(); which quadrants
-- are round. A square minimap keeps the button on its edge instead of over the map.
local SHAPES = {
    ROUND = { true, true, true, true }, SQUARE = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true }, ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false }, ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true }, ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true }, ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true }, ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true }, ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}
function ns.MinimapButtonOffset(angleDeg, w, h, shape)
    local a = math.rad(angleDeg or 215)
    local x, y = math.cos(a), math.sin(a)
    local q = 1
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    local quad = (SHAPES[shape or "ROUND"] or SHAPES.ROUND)[q]
    local hw, hh = w / 2 + 5, h / 2 + 5
    if quad then return x * hw, y * hh end
    -- square edge: push the round position out to the frame's border, then clamp
    local dw, dh = math.sqrt(2 * hw * hw) - 10, math.sqrt(2 * hh * hh) - 10
    return math.max(-hw, math.min(x * dw, hw)), math.max(-hh, math.min(y * dh, hh))
end
local function MinimapShape()
    if type(GetMinimapShape) == "function" then
        local ok, shape = pcall(GetMinimapShape)
        if ok and type(shape) == "string" then return shape end
    end
    return Settings().minimap.square and "SQUARE" or "ROUND"
end
local function PositionMinimapButton()
    local x, y = ns.MinimapButtonOffset(Settings().minimap.angle or 215, Minimap:GetWidth() or 140, Minimap:GetHeight() or 140, MinimapShape())
    mmb:ClearAllPoints()
    mmb:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
ns.PositionMinimapButton = function() if mmb then PositionMinimapButton() end end
function ns.MinimapButton() return mmb end

local function CreateMinimapButton()
    mmb = CreateFrame("Button", "LifeTimeStatsMinimapButton", Minimap)
    mmb:SetSize(31, 31)
    mmb:SetFrameStrata("MEDIUM")
    mmb:SetFrameLevel(8)
    mmb:SetClampedToScreen(true)
    mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mmb:RegisterForDrag("LeftButton")
    local bg = mmb:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(22, 22); bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = mmb:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22); icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture(W.MEDIA .. "icon")
    if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    mmb.icon = icon
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
        GameTooltip:AddLine("LifeTimeStats", ns.TipColor("amber"))
        local v = ns.char
        local function L(a, b)
            local lr, lg, lb = ns.TipColor("text")
            GameTooltip:AddDoubleLine(a, b, lr, lg, lb, ns.TipColor("amber"))
        end
        L("Steps", Int(ns.Steps(v)))
        L("Jumps", Int(c(v, "jumps")))
        L("Kills", Int(ns.Kills(v)))
        L("Deaths", Int(c(v, "deaths")))
        local d = v.days and v.days[ns.Today()]
        if d then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Today", ns.TipColor("dim"))
            L("Steps", Int((d.dist_foot or 0) * ns.YARDS_TO_STEPS))
            L("Kills", Int((d.kills_npc or 0) + (d.kills_pvp or 0)))
            L("Online", Time(d.time_online or 0))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: open window   Right-click: settings", ns.TipColor("dim"))
        GameTooltip:AddLine("Drag: move button", ns.TipColor("dim"))
        GameTooltip:Show()
    end)
    mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    PositionMinimapButton()
end

-- With LibDataBroker and LibDBIcon loaded (Leatrix Plus, ElvUI, minimap button bags...),
-- LifeTimeStats registers a launcher there instead, so those addons can place, hide or
-- collect it like any other minimap button. Neither library is bundled.
local ldbIcon
local function BrokerIcon()
    if ldbIcon ~= nil then return ldbIcon or nil end
    ldbIcon = false
    local stub = LibStub
    if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
    local okL, ldb = pcall(stub, "LibDataBroker-1.1", true)
    local okI, dbi = pcall(stub, "LibDBIcon-1.0", true)
    if not (okL and ldb and okI and dbi and ldb.NewDataObject and dbi.Register) then return nil end
    local obj = ldb:NewDataObject("LifeTimeStats", {
        type = "launcher", text = "LifeTimeStats", icon = W.MEDIA .. "icon",
        OnClick = function(_, btn) if btn == "RightButton" then ns.OpenOptions() else ns.ToggleWindow() end end,
        OnTooltipShow = function(tt)
            if not tt or not tt.AddLine then return end
            tt:AddLine("LifeTimeStats", ns.TipColor("amber"))
            local v = ns.char
            if v then
                tt:AddDoubleLine("Steps", Int(ns.Steps(v)), 1, 1, 1, ns.TipColor("amber"))
                tt:AddDoubleLine("Kills", Int(ns.Kills(v)), 1, 1, 1, ns.TipColor("amber"))
                tt:AddDoubleLine("Deaths", Int(c(v, "deaths")), 1, 1, 1, ns.TipColor("amber"))
            end
            tt:AddLine("Left-click: open window   Right-click: settings", ns.TipColor("dim"))
        end,
    })
    local s = Settings().minimap
    s.ldb = s.ldb or { hide = s.hide, minimapPos = s.angle }
    local ok = obj and pcall(dbi.Register, dbi, "LifeTimeStats", obj, s.ldb)
    if not ok then return nil end
    ldbIcon = dbi
    ns.src.minimapBroker = true
    return dbi
end

function ns.UpdateMinimapButton()
    local s = Settings().minimap
    local dbi = BrokerIcon()
    if dbi then
        if mmb then mmb:Hide() end
        s.ldb.hide = s.hide and true or false
        if s.hide then pcall(dbi.Hide, dbi, "LifeTimeStats") else pcall(dbi.Show, dbi, "LifeTimeStats") end
        return
    end
    if not mmb then CreateMinimapButton() end
    PositionMinimapButton()
    mmb:SetShown(not s.hide)
end

-- /lts minimap reset: back to the bottom-left of the minimap and shown.
function ns.ResetMinimapButton()
    local s = Settings().minimap
    s.hide, s.angle = false, 215
    if s.ldb then s.ldb.hide, s.ldb.minimapPos = false, 215 end
    ns.UpdateMinimapButton()
end

-- ------------------------------------------------------------ backup dialog
local dlg
local RESTORE_HINT = "Paste a LifeTimeStats backup with Ctrl+V. Stats backups merge. Full character backups require confirmation before replacement."

local function LayoutBackupDialog(mode, width, height)
    dlg.mode, dlg.previewInput = mode, nil
    dlg:SetSize(width, height)
    dlg.eb:SetWidth(width - 70)
    local export, restore = mode == "export", mode == "restore"
    dlg.exportModes:SetShown(export)
    dlg.summary:Hide()
    dlg.editPaste:Hide()
    dlg.box:Show()
    local hintTop, boxTop = export and -66 or -32, export and -116 or -64
    dlg.hint:ClearAllPoints()
    dlg.hint:SetPoint("TOPLEFT", 12, hintTop); dlg.hint:SetPoint("RIGHT", -12, 0)
    dlg.box:ClearAllPoints()
    dlg.box:SetPoint("TOPLEFT", 12, boxTop); dlg.box:SetPoint("BOTTOMRIGHT", -12, 44)
    dlg.action:SetShown(restore)
    dlg.action.text:SetText("Restore")
    dlg.action.text:SetTextColor(T.text[1], T.text[2], T.text[3])
    dlg.close.text:SetText(restore and "Cancel" or "Close")
    dlg.close:ClearAllPoints()
    if restore then
        dlg.close:SetPoint("RIGHT", dlg.action, "LEFT", -8, 0)
    else
        dlg.close:SetPoint("BOTTOMRIGHT", -12, 12)
    end
end

local function SetRestoreInput(hint)
    LayoutBackupDialog("restore", 480, 320)
    dlg.title:SetText("Restore - " .. ns.charKey)
    dlg.hint:SetText(hint or RESTORE_HINT)
end

local function ShowBackupExport(mode)
    local full = mode == "full"
    dlg.exportModes:Select(mode)
    dlg.title:SetText("Backup - " .. ns.charKey)
    if full then
        local payload, why = ns.SerializeFullBackup()
        dlg.hint:SetText(payload
            and "Copy manually with Ctrl+A and Ctrl+C. Contains private Journal notes. Restore on this character only. Account settings and the active session are outside this backup."
            or ("|cffd9604aCould not create full backup:|r " .. tostring(why)))
        dlg.eb:SetText(payload or "")
    else
        dlg.hint:SetText("Copy with Ctrl+A then Ctrl+C. Includes statistics and personal-best history. Journal and play-session history stay in the saved files.")
        dlg.eb:SetText(ns.Serialize(ns.char))
    end
    dlg.eb:SetFocus()
    dlg.eb:HighlightText()
end

local function ShowFullBackupPreview(input, snapshot)
    dlg.previewInput = input
    dlg:SetSize(560, 254)
    dlg.title:SetText("Restore full character backup")
    dlg.hint:SetText("This will replace this character’s statistics and saved history.")
    dlg.eb:ClearFocus()
    dlg.box:Hide()
    local journal, sessions = snapshot.record.journal or {}, snapshot.record.sessionlog or {}
    local noteCount = snapshot.noteCount
    if not noteCount then
        noteCount = 0
        for _, entry in ipairs(journal) do
            if ns.JournalNote(entry) then noteCount = noteCount + 1 end
        end
    end
    local validDate, saved = pcall(date, "%b %d, %Y at %H:%M", snapshot.savedAt)
    dlg.summary.source:SetText("Source: " .. snapshot.character:gsub("|", "||") .. "  ·  This character")
    dlg.summary.saved:SetText(validDate and type(saved) == "string" and "Backed up " .. saved or "Backup date unavailable")
    dlg.summary.counts:SetText(string.format("%d Journal entries  ·  %d personal notes  ·  %d saved sessions", #journal, noteCount, #sessions))
    dlg.summary:Show()
    dlg.editPaste:Show()
    dlg.action.text:SetText("Replace history")
    dlg.action.text:SetTextColor(C.rust[1], C.rust[2], C.rust[3])
end

local function ApplyBackup()
    if dlg.mode ~= "restore" then return end
    local text = dlg.eb:GetText() or ""
    if dlg.previewInput and dlg.previewInput ~= text then
        SetRestoreInput("The pasted text changed. Review the backup again.")
        return
    end
    if ns.IsFullBackup(text) then
        local snapshot, why = ns.DeserializeFullBackup(text)
        if not snapshot then
            SetRestoreInput("|cffd9604aCould not read full backup:|r " .. tostring(why))
            return
        end
        if snapshot.character ~= ns.charKey then
            SetRestoreInput("|cffd9604aThis full backup belongs to another character.|r")
            return
        end
        if not dlg.previewInput then
            ShowFullBackupPreview(text, snapshot)
            return
        end
        local ok, reason = ns.RestoreFullBackup(snapshot)
        if not ok then
            SetRestoreInput("|cffd9604aCould not restore full backup:|r " .. tostring(reason))
            return
        end
        ns.Print("Full character backup restored.")
    else
        local data, why = ns.Deserialize(text)
        if not data then
            SetRestoreInput("|cffd9604aCould not read backup:|r " .. tostring(why))
            return
        end
        local changed = ns.MergeMax(ns.char, data)
        ns.InvalidateAccount()
        ns.Save()
        ns.Print(string.format("Restore complete. Entries updated: %d.", changed))
    end
    dlg:Hide()
    ns.RefreshWindow()
end

local function CreateDialog()
    dlg = W.Window(UIParent)
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
    dlg.exportModes = W.Segmented(dlg, {
        { id = "stats", label = "Stats only", tip = "Back up statistics and personal-best history for a merge restore." },
        { id = "full", label = "Full character", tip = "Back up this character’s statistics and saved history including private Journal notes." },
    }, function(id) if dlg.mode == "export" then ShowBackupExport(id) end end)
    dlg.exportModes:SetPoint("TOPLEFT", 12, -34)
    dlg.exportModes:Hide()
    dlg.box = W.Panel(dlg, T.tile)
    local sf = CreateFrame("ScrollFrame", nil, dlg.box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6); sf:SetPoint("BOTTOMRIGHT", -26, 6)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFont(W.NUM, 12, "")
    eb:SetTextColor(T.text[1], T.text[2], T.text[3])
    eb:SetWidth(410)
    eb:SetScript("OnEscapePressed", function() dlg:Hide() end)
    eb:SetScript("OnTextChanged", function(self)
        if dlg.mode == "restore" and dlg.previewInput and self:GetText() ~= dlg.previewInput then
            SetRestoreInput("The pasted text changed. Review the backup again.")
        end
    end)
    sf:SetScrollChild(eb)
    dlg.eb = eb
    dlg.summary = W.Panel(dlg, T.tile)
    dlg.summary:SetPoint("TOPLEFT", 12, -62); dlg.summary:SetPoint("TOPRIGHT", -12, -62); dlg.summary:SetHeight(96)
    dlg.summary.source = W.Text(dlg.summary, 13, T.amber, nil, "LEFT")
    dlg.summary.source:SetPoint("TOPLEFT", 10, -10); dlg.summary.source:SetWidth(514)
    dlg.summary.saved = W.Text(dlg.summary, 11, T.dim, nil, "LEFT")
    dlg.summary.saved:SetPoint("TOPLEFT", 10, -32)
    local rule = W.Line(dlg.summary)
    rule:SetPoint("TOPLEFT", 10, -52); rule:SetPoint("TOPRIGHT", -10, -52); rule:SetHeight(1)
    dlg.summary.counts = W.Text(dlg.summary, 12, T.text, nil, "LEFT")
    dlg.summary.counts:SetPoint("TOPLEFT", 10, -66)
    local ready = W.Text(dlg.summary, 11, T.dim, nil, "LEFT")
    ready:SetPoint("TOPLEFT", dlg.summary, "BOTTOMLEFT", 0, -9)
    ready:SetText("The backup text is ready. Choose Edit paste to change it.")
    dlg.summary:Hide()
    dlg.close = W.FlatButton(dlg, "Close", 80, 22, nil, "Close this dialog.")
    dlg.close:SetScript("OnClick", function() dlg:Hide() end)
    dlg.action = W.FlatButton(dlg, "Restore", 128, 22)
    dlg.action:SetPoint("BOTTOMRIGHT", -12, 12)
    dlg.action:SetScript("OnClick", ApplyBackup)
    dlg.action:Hide()
    dlg.editPaste = W.FlatButton(dlg, "Edit paste", 93, 22)
    dlg.editPaste:SetPoint("BOTTOMLEFT", 12, 12)
    dlg.editPaste:SetScript("OnClick", function()
        SetRestoreInput()
        eb:SetFocus()
    end)
    dlg.editPaste:Hide()
    dlg:SetScript("OnHide", function()
        local clear = dlg.mode == "export" or dlg.mode == "restore"
        dlg.mode, dlg.previewInput = nil, nil
        eb:ClearFocus()
        if clear then eb:SetText("") end
    end)
end

function ns.ShowExport()
    if not dlg then CreateDialog() end
    LayoutBackupDialog("export", 540, 355)
    dlg:Show()
    ShowBackupExport("stats")
end

-- Plain text window for /lts debug, /lts dm and /lts errors.
function ns.ShowText(title, hint, text)
    if not dlg then CreateDialog() end
    LayoutBackupDialog("text", 620, 460)
    dlg.title:SetText(title)
    dlg.hint:SetText(hint or "Ctrl+A then Ctrl+C to copy.")
    dlg.eb:SetText(text or "")
    dlg:Show()
    dlg.eb:SetFocus()
    dlg.eb:HighlightText()
    dlg.eb:SetCursorPosition(0)
end

function ns.ShowSheet()
    if not dlg then CreateDialog() end
    LayoutBackupDialog("text", 480, 320)
    dlg.title:SetText("Character sheet - " .. ns.TitledName())
    dlg.hint:SetText("Ctrl+A then Ctrl+C to copy. Paste it into Discord, a forum post or your notes.")
    dlg.eb:SetText(ns.CharacterSheet())
    dlg:Show()
    dlg.eb:SetFocus()
    dlg.eb:HighlightText()
end

function ns.ShowImport()
    if not dlg then CreateDialog() end
    SetRestoreInput()
    dlg.eb:SetText("")
    dlg:Show()
    dlg.eb:SetFocus()
end

-- ------------------------------------------------------------ share dialog
local sd
local function CreateShare()
    sd = W.Window(UIParent)
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

-- LifeTimeStats - settings panel (Options > AddOns > LifeTimeStats)
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local T = ns.THEME
local panel, category

StaticPopupDialogs["LIFETIMESTATS_RESET_CHAR"] = {
    text = "Erase ALL lifetime stats for %s?\n\nThis cannot be undone. Make a Backup first if you might want them back.",
    button1 = "Erase",
    button2 = CANCEL or "Cancel",
    OnAccept = function()
        local rec = ns.NewCharRecord()
        rec.meta.name, rec.meta.realm = ns.char.meta.name, ns.char.meta.realm
        rec.meta.rev = (ns.char.meta.rev or 0) + 1
        ns.db.chars[ns.charKey] = rec
        LifeTimeStatsCharDB.data = rec
        ns.char = rec
        ns.ResetSession()
        ns.Print("Lifetime stats for this character erased.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["LIFETIMESTATS_RELOAD"] = {
    text = "LifeTimeStats: the new theme applies after reloading the interface. Reload now?",
    button1 = RELOADUI or "Reload",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ------------------------------------------------------------ themed controls
local W
local ROW_H = 34

-- Toggle row: square box, label, one-line description. The whole row is clickable.
local function Toggle(parent, x, y, w, label, desc, get, set)
    local r = CreateFrame("Button", nil, parent)
    r:SetPoint("TOPLEFT", x, -y); r:SetSize(w, ROW_H)
    r.hl = W.Fill(r, T.tileHi); r.hl:SetAllPoints(); r.hl:Hide()
    local box = W.Panel(r, T.bg, T.edge); box:SetSize(14, 14); box:SetPoint("TOPLEFT", 6, -4)
    local fill = W.Fill(box, T.amber, "ARTWORK"); fill:SetPoint("TOPLEFT", 3, -3); fill:SetPoint("BOTTOMRIGHT", -3, 3)
    local l = W.Text(r, 12, T.text); l:SetPoint("TOPLEFT", 28, -4); l:SetText(label)
    local d = W.Text(r, 10, T.dim); d:SetPoint("TOPLEFT", 28, -19); d:SetPoint("RIGHT", -4, 0); d:SetJustifyH("LEFT"); d:SetText(desc)
    function r:Sync() fill:SetShown(get() and true or false) end
    r:SetScript("OnClick", function(self) set(not get()); self:Sync() end)
    r:SetScript("OnEnter", function() r.hl:Show() end)
    r:SetScript("OnLeave", function() r.hl:Hide() end)
    r:Sync()
    return r
end

-- Label on the left, control on the right.
local function RowLabel(parent, x, y, label, desc)
    local l = W.Text(parent, 12, T.text); l:SetPoint("TOPLEFT", x + 6, -y - 4); l:SetText(label)
    if desc then
        local d = W.Text(parent, 10, T.dim); d:SetPoint("TOPLEFT", x + 6, -y - 19); d:SetText(desc)
        return l, d
    end
    return l
end

-- Arrow cycler: ‹ value ›
local function Cycler(parent, w, getText, step, tip)
    local f = W.Panel(parent, T.bg)
    f:SetSize(w, 22)
    local t = W.Text(f, 11, T.text); t:SetPoint("CENTER")
    local function Arrow(sym, dir, point)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(22, 22); b:SetPoint(point)
        local a = W.Text(b, 14, T.amber); a:SetPoint("CENTER"); a:SetText(sym)
        b:SetScript("OnClick", function() step(dir); t:SetText(getText()) end)
        b:SetScript("OnEnter", function() a:SetTextColor(T.text[1], T.text[2], T.text[3]) end)
        b:SetScript("OnLeave", function() a:SetTextColor(T.amber[1], T.amber[2], T.amber[3]) end)
    end
    Arrow("<", -1, "LEFT"); Arrow(">", 1, "RIGHT")
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function() step(1); t:SetText(getText()) end)
    if tip then W.Tip(f, tip[1], tip[2]) end
    function f:Sync() t:SetText(getText()) end
    f:Sync()
    return f
end

-- Flat horizontal slider.
local function FlatSlider(parent, w, minV, maxV, stepV, get, set, fmt)
    local s = CreateFrame("Slider", nil, parent)
    s:SetOrientation("HORIZONTAL"); s:SetSize(w, 16)
    s:SetMinMaxValues(minV, maxV); s:SetValueStep(stepV)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = W.Fill(s, T.edge, "BACKGROUND"); track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(2)
    local on = W.Fill(s, T.amber, "BORDER"); on:SetPoint("LEFT"); on:SetHeight(2)
    s:SetThumbTexture(W.WHITE)
    local th = s:GetThumbTexture()
    if th then th:SetSize(8, 14); th:SetVertexColor(T.amber[1], T.amber[2], T.amber[3]) end
    local val = W.Text(parent, 11, T.amber, W.NUM, "RIGHT"); val:SetPoint("LEFT", s, "RIGHT", 10, 0)
    local function Show(v)
        val:SetText(fmt(v))
        on:SetWidth(math.max(1, (v - minV) / (maxV - minV) * w))
    end
    s:SetValue(get()); Show(get())
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / stepV + 0.5) * stepV
        set(v); Show(v)
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * stepV) end)
    function s:Sync() self:SetValue(get()); Show(get()) end
    return s
end

local function Button(parent, label, w, tip, fn, danger)
    local b = W.FlatButton(parent, label, w, 24, label, tip)
    if danger then b.text:SetTextColor(W.C.rust[1], W.C.rust[2], W.C.rust[3]); W.Color(b.edge, W.C.rust) end
    b:SetScript("OnClick", fn)
    return b
end

-- Small colour chips showing a theme's palette.
local function Swatches(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(5 * 14 + 4 * 3, 12)
    f.chips = {}
    for i = 1, 5 do
        local c = W.Panel(f, T.bg, { 0, 0, 0, 1 }); c:SetSize(14, 12); c:SetPoint("LEFT", (i - 1) * 17, 0)
        f.chips[i] = c
    end
    function f:Show(id)
        local t = ns.THEME_BY_ID[id] or ns.THEME_BY_ID.odometer
        local list = { t.bg, t.tile, t.text, t.amber, t.rust }
        for i, c in ipairs(self.chips) do local col = list[i] c:SetBackdropColor(col[1], col[2], col[3], 1) end
    end
    return f
end

-- ------------------------------------------------------------ panel
function ns.CreateOptions()
    W = ns.W
    local S = ns.settings
    panel = CreateFrame("Frame")
    panel.name = "LifeTimeStats"
    ns.optionsPanel = panel
    local CW = 620

    local sf = CreateFrame("ScrollFrame", nil, panel)
    sf:SetPoint("TOPLEFT", 4, -4); sf:SetPoint("BOTTOMRIGHT", -4, 4)
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(CW, 660)
    sf:SetScrollChild(c)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, d)
        local maxS = math.max(0, c:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maxS, self:GetVerticalScroll() - d * 40)))
    end)

    -- header ----------------------------------------------------------
    local hb = W.Panel(c, T.tile); hb:SetPoint("TOPLEFT", 0, 0); hb:SetSize(CW, 52)
    local rule = W.Fill(hb, T.amber, "ARTWORK"); rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(2)
    local logo = hb:CreateTexture(nil, "ARTWORK"); logo:SetSize(32, 32); logo:SetPoint("LEFT", 10, 0); logo:SetTexture(W.MEDIA .. "icon")
    local t1 = W.Text(hb, 18, T.amber); t1:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 1); t1:SetText("LifeTime")
    local t2 = W.Text(hb, 18, T.text); t2:SetPoint("LEFT", t1, "RIGHT", 0, 0); t2:SetText("Stats")
    local ver = W.Text(hb, 11, T.dim); ver:SetPoint("LEFT", t2, "RIGHT", 8, -1); ver:SetText("v" .. ns.VERSION)
    local sub = W.Text(hb, 11, T.dim); sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 10, 0); sub:SetText("Lifetime statistics for your character  ·  /lts opens the window")
    local open = Button(hb, "Open window", 110, "Open the LifeTimeStats window.", function() ns.ToggleWindow() end)
    open:SetPoint("RIGHT", -10, 0)

    local colW, gap, y0 = (CW - 10) / 2, 10, 62
    local L, R = 0, colW + gap
    local rows = {}
    local function Track(r) rows[#rows + 1] = r return r end

    -- APPEARANCE (left) -----------------------------------------------
    local ap = W.Card(c, "Appearance", "dashboard", L, y0, colW, 262)
    local b = ap.body
    RowLabel(b, 0, 0, "Theme", "Applies after /reload")
    local sw = Swatches(b); sw:SetPoint("TOPLEFT", 6, -36)
    local reload = Button(b, "Reload now", 90, "Reload the interface to apply the new theme.", function() ReloadUI() end)
    reload:SetPoint("TOPRIGHT", -2, -30); reload:Hide()
    local function ThemeId() return S.theme == "auto" and ns.DetectUI() or (S.theme or "auto") end
    local themeCyc = Cycler(b, 160, function() return ns.ThemeName(S.theme or "auto") end, function(dir)
        local i = 1
        for k, id in ipairs(ns.THEME_ORDER) do if id == (S.theme or "auto") then i = k end end
        S.theme = ns.THEME_ORDER[(i - 1 + dir) % #ns.THEME_ORDER + 1]
        sw:Show(ThemeId()); reload:SetShown(ThemeId() ~= ns.themeId or S.theme ~= ns.themeChosen)
    end, { "Theme", function()
        local t = ns.THEME_BY_ID[ThemeId()] or ns.THEME_BY_ID.odometer
        return "Auto matches the UI addon you run (EllesmereUI, ElvUI or Tukui), else Odometer.\n\n" .. t.name .. ": " .. t.desc
    end })
    themeCyc:SetPoint("TOPRIGHT", -2, -2)
    sw:Show(ThemeId())
    ns.themeChosen = S.theme
    Track(Toggle(b, 0, 56, ap.bw, "Class colour accent", "Tint numbers, borders and charts with your class colour. After /reload.",
        function() return S.classColor end, function(v) S.classColor = v; reload:Show() end))
    RowLabel(b, 0, 98, "Window scale")
    local sl = FlatSlider(b, 130, 0.6, 1.6, 0.05, function() return S.window.scale or 1 end,
        function(v) S.window.scale = math.floor(v * 100 + 0.5) / 100; ns.ApplyWindowSettings() end, function(v) return string.format("%d%%", v * 100 + 0.5) end)
    sl:SetPoint("TOPRIGHT", -46, -100)
    Track(sl)
    Track(Toggle(b, 0, 134, ap.bw, "Lock window", "Stop the window from being dragged.",
        function() return S.lockWindow end, function(v) S.lockWindow = v end))
    Track(Toggle(b, 0, 168, ap.bw, "Minimap button", "Left-click opens the window, right-click opens settings.",
        function() return not S.minimap.hide end, function(v) S.minimap.hide = not v; ns.UpdateMinimapButton() end))

    -- SCREENSHOTS (left) ----------------------------------------------
    local ss = W.Card(c, "Screenshots", "star", L, y0 + 272, colW, 150)
    b = ss.body
    Track(Toggle(b, 0, 0, ss.bw, "On level-up", "A moment after each new level.",
        function() return S.shotLevel end, function(v) S.shotLevel = v end))
    Track(Toggle(b, 0, 34, ss.bw, "On first boss kill", "The first time you kill each dungeon or raid boss.",
        function() return S.shotBoss end, function(v) S.shotBoss = v end))
    Track(Toggle(b, 0, 68, ss.bw, "On achievement", "When you earn a LifeTimeStats achievement tier.",
        function() return S.shotAch end, function(v) S.shotAch = v end))

    -- CHAT & DISPLAY (right) ------------------------------------------
    local cd = W.Card(c, "Chat and display", "social", R, y0, colW, 298)
    b = cd.body
    Track(Toggle(b, 0, 0, cd.bw, "Session column", "Show how much each value grew this session.",
        function() return S.showSession end, function(v) S.showSession = v; ns.RefreshWindow() end))
    Track(Toggle(b, 0, 34, cd.bw, "Last-session recap at login", "One chat line with your last session's highlights.",
        function() return S.recap end, function(v) S.recap = v end))
    Track(Toggle(b, 0, 68, cd.bw, "Level-up line", "How long the level took and your time online.",
        function() return S.levelMsg end, function(v) S.levelMsg = v end))
    Track(Toggle(b, 0, 102, cd.bw, "Kill counts on tooltips", "How often you killed, fought and were hurt by a creature.",
        function() return S.tooltipKills end, function(v) S.tooltipKills = v end))
    Track(Toggle(b, 0, 136, cd.bw, "Milestones in chat", "A line when counters pass 100, 1,000, 10,000...",
        function() return S.milestones end, function(v) S.milestones = v end))
    Track(Toggle(b, 0, 170, cd.bw, "Record new highs in the journal", "Add meaningful new records to your local adventure chronicle; no live chat spam.",
        function() return S.recordMoments end, function(v) S.recordMoments = v end))
    RowLabel(b, 0, 205, "Achievement alerts", nil)
    local alerts = W.Segmented(b, {
        { id = "off", label = "Off", tip = "Only a 'new' count on the sidebar." },
        { id = "chat", label = "Chat", tip = "A chat line." },
        { id = "toast", label = "Toast", tip = "A small pop-up you can click to open the page." },
        { id = "both", label = "Both", tip = "Chat line and toast." },
    }, function(id) S.achAnnounce = id; alerts:Select(id) end)
    alerts:SetPoint("TOPLEFT", 6, -225)
    alerts:Select(S.achAnnounce or "off")
    alerts.Sync = function(self) self:Select(S.achAnnounce or "off") end
    Track(alerts)

    -- TRACKING (right) ------------------------------------------------
    local tr = W.Card(c, "Tracking and title", "records", R, y0 + 272, colW, 150)
    b = tr.body
    Track(Toggle(b, 0, 0, tr.bw, "Count pet and guardian damage", "Include your pet's damage, kills and misses.",
        function() return S.countPet end, function(v) S.countPet = v end))
    RowLabel(b, 0, 40, "Title", "Shown by your name")
    local titleCyc = Cycler(b, 160, function() return ns.TitledName() end, function(dir)
        ns.CycleTitle(dir); if ns.RefreshWindow then ns.RefreshWindow() end
    end, { "Title", "Cycle through the titles you have earned (or none)." })
    titleCyc:SetPoint("TOPRIGHT", -2, -42)
    Track(titleCyc)

    -- DATA (full width) -----------------------------------------------
    local da = W.Card(c, "Your data", "chest", 0, y0 + 432, CW, 150)
    b = da.body
    local info = W.Text(b, 12, T.text); info:SetPoint("TOPLEFT", 6, -2)
    local note = W.Text(b, 10, T.dim); note:SetPoint("TOPLEFT", 6, -20); note:SetPoint("RIGHT", -6, 0); note:SetJustifyH("LEFT"); note:SetWordWrap(true)
    note:SetText("Stored twice (account file and character file), so one lost SavedVariables file does not wipe your totals. Backups are plain numbers and can never run code.")
    local bw2, bx = (da.bw - 5 * 8) / 6, 0
    local function Btn(label, tip, fn, danger)
        local x = Button(b, label, bw2, tip, fn, danger)
        x:SetPoint("BOTTOMLEFT", bx, 4); bx = bx + bw2 + 8
    end
    Btn("Backup", "Copyable text backup of this character.", function() ns.ShowExport() end)
    Btn("Restore", "Paste a backup. Values only go up.", function() ns.ShowImport() end)
    Btn("Character sheet", "A text summary to paste anywhere.", function() ns.ShowSheet() end)
    Btn("Reset session", "Zero the session column. Lifetime values stay.", function() ns.ResetSession(); ns.Print("Session counters reset.") end)
    Btn("Reset window", "Centre the window and fit it to your screen.", function() ns.ResetWindow(); sl:Sync() end)
    Btn("Erase character", "Erase every lifetime value for this character. Asks first.", function() StaticPopup_Show("LIFETIMESTATS_RESET_CHAR", ns.charKey) end, true)

    panel:SetScript("OnShow", function()
        local ok, str = pcall(ns.Serialize, ns.char)
        local kb = ok and (#str / 1024) or 0
        local days = 0
        for _ in pairs(ns.char.days) do days = days + 1 end
        info:SetText(string.format("%s%d|r statistics  ·  %s%d|r character%s  ·  %s%.0f KB|r for this character  ·  %s%d|r day%s of history",
            ns.GOLD, ns.CountStats(), ns.GOLD, ns.CharCount(), ns.CharCount() == 1 and "" or "s", ns.GOLD, kb, ns.GOLD, days, days == 1 and "" or "s"))
        for _, r in ipairs(rows) do if r.Sync then r:Sync() end end
        themeCyc:Sync(); sw:Show(ThemeId())
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "LifeTimeStats")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function ns.OpenOptions()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

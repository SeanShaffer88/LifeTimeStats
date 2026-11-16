-- LifeTimeStats - the framed tome skins: "Lifetime Stats" (the default) and "Stats Explorer".
-- A dark wooden frame with gold corners and a title plaque around clean parchment, a menu of
-- pages down the left (parchment in Lifetime Stats, dark wood in Stats Explorer) and the
-- character and time-range choices as a dropdown or a segmented bar. Pages are unchanged; the
-- overview page has its own layout for each skin (Overview.lua).
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local LIGHT = { 0.94, 0.90, 0.80 }       -- light text on wood and on the green selection
local GOLD_TEXT = { 1.00, 0.84, 0.48 }   -- the plaque's title

function ns.FramedTitle() return ns.Explorer and ns.Explorer() and "Stats Explorer" or "Lifetime Stats" end

-- Light text that the paper ink rule must leave alone (on wood, on the plaque, on green).
local function Light(fs, c)
    if not fs then return fs end
    fs.noInk = true
    c = c or LIGHT
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    return fs
end
ns.FramedLight = Light

-- ------------------------------------------------------------ dropdown
-- A button showing the current choice; clicking it opens a list below it.
local function Dropdown(parent, w, items, onPick, opts)
    local W, T = ns.W, ns.THEME
    opts = opts or {}
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 28)
    local bg = W.Panel(b, T.tile, T.edge); bg:SetAllPoints(); bg:SetFrameLevel(b:GetFrameLevel())
    local x = 10
    if opts.portrait then
        b.portrait = b:CreateTexture(nil, "ARTWORK")
        b.portrait:SetSize(22, 22); b.portrait:SetPoint("LEFT", 4, 0)
        x = 32
    end
    if opts.icon then
        b.icon = W.Icon(b, opts.icon, 16, T.dim); b.icon:SetPoint("LEFT", 8, 0)
        x = 30
    end
    b.text = W.Text(b, 12, T.text); b.text:SetPoint("LEFT", x, 0); b.text:SetPoint("RIGHT", -26, 0); b.text:SetJustifyH("LEFT")
    b.arrow = b:CreateTexture(nil, "ARTWORK")
    b.arrow:SetSize(18, 18); b.arrow:SetPoint("RIGHT", -5, 0)
    b.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    local menu = W.Panel(b, T.bg, T.edge)
    menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
    menu:SetSize(w, #items * 24 + 6)
    menu:SetFrameLevel((b:GetFrameLevel() or 1) + 40)
    menu:Hide()
    b.menu, b.items, b.rows = menu, items, {}
    for i, it in ipairs(items) do
        local r = CreateFrame("Button", nil, menu)
        r:SetSize(w - 6, 24); r:SetPoint("TOPLEFT", 3, -3 - (i - 1) * 24)
        r.hl = W.Fill(r, T.tileHi); r.hl:SetAllPoints(); r.hl:Hide()
        r.text = W.Text(r, 12, T.text); r.text:SetPoint("LEFT", 8, 0); r.text:SetText(it.label)
        r.id = it.id
        r:SetScript("OnEnter", function(self)
            self.hl:Show()
            if it.tip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(it.label, ns.TipColor("amber"))
                GameTooltip:AddLine(it.tip, ns.TipColor("text", true))
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        r:SetScript("OnClick", function() menu:Hide(); onPick(it.id) end)
        b.rows[i] = r
    end
    b:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    if opts.tip then W.Tip(b, opts.tip[1], opts.tip[2]) end
    function b:Select(id)
        self.selected = id
        for _, it in ipairs(self.items) do
            if it.id == id then self.text:SetText(it.short or it.label) end
        end
        for _, r in ipairs(self.rows) do
            local c = r.id == id and T.amber or T.text
            r.text:SetTextColor(c[1], c[2], c[3])
        end
        if self.portrait and SetPortraitTexture then pcall(SetPortraitTexture, self.portrait, "player") end
    end
    return b
end
ns.FramedDropdown = Dropdown

-- ------------------------------------------------------------ the frame
function ns.BuildFramedSkin(win, side, head, dim)
    local W, T = ns.W, ns.THEME
    local M = W.MEDIA .. "framed\\"
    local explorer = ns.Explorer()
    local fr = {}
    win.framed = fr
    if win.SetBackdropColor then pcall(win.SetBackdropColor, win, 0, 0, 0, 0) end
    if win.SetBackdropBorderColor then pcall(win.SetBackdropBorderColor, win, 0, 0, 0, 0) end

    -- clean parchment inside the frame
    fr.paper = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    fr.paper:SetAllPoints()
    fr.paper:SetTexture(M .. "parchment")

    -- the wooden frame: four rails just outside the window, gold corners over their joins
    local art = CreateFrame("Frame", nil, win)
    art:SetAllPoints()
    art:SetFrameLevel((win:GetFrameLevel() or 1) + 30)
    fr.art = art
    local R = 26
    local function Rail(tex, coords)
        local t = art:CreateTexture(nil, "BORDER")
        t:SetTexture(M .. tex)
        if coords then t:SetTexCoord(unpack(coords)) end
        return t
    end
    fr.top = Rail("edge_h"); fr.top:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 0, -4); fr.top:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", 0, -4); fr.top:SetHeight(R + 4)
    fr.bottom = Rail("edge_h", { 0, 1, 1, 0 }); fr.bottom:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, 4); fr.bottom:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, 4); fr.bottom:SetHeight(R + 4)
    fr.left = Rail("edge_v"); fr.left:SetPoint("TOPRIGHT", win, "TOPLEFT", 4, 0); fr.left:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", 4, 0); fr.left:SetWidth(R + 4)
    fr.right = Rail("edge_v", { 1, 0, 0, 1 }); fr.right:SetPoint("TOPLEFT", win, "TOPRIGHT", -4, 0); fr.right:SetPoint("BOTTOMLEFT", win, "BOTTOMRIGHT", -4, 0); fr.right:SetWidth(R + 4)
    fr.corners = {}
    for i, c in ipairs({
        { "TOPLEFT", -R + 4, R - 4, { 0, 1, 0, 1 } }, { "TOPRIGHT", R - 4, R - 4, { 1, 0, 0, 1 } },
        { "BOTTOMLEFT", -R + 4, -R + 4, { 0, 1, 1, 0 } }, { "BOTTOMRIGHT", R - 4, -R + 4, { 1, 0, 1, 0 } },
    }) do
        local t = art:CreateTexture(nil, "ARTWORK")
        t:SetTexture(M .. "corner"); t:SetSize(52, 52); t:SetTexCoord(unpack(c[4]))
        t:SetPoint(c[1], win, c[1], c[2], c[3])
        fr.corners[i] = t
    end

    -- the title plaque over the top rail
    local plaque = CreateFrame("Frame", nil, art)
    plaque:SetSize(440, 96)
    plaque:SetPoint("CENTER", win, "TOP", 0, 18) -- its body ends just above the header row
    plaque:SetFrameLevel((art:GetFrameLevel() or 1) + 2)
    local pt = plaque:CreateTexture(nil, "ARTWORK"); pt:SetAllPoints(); pt:SetTexture(M .. "plaque")
    local title = Light(W.Text(plaque, 22, GOLD_TEXT, W.FONT, "CENTER"), GOLD_TEXT)
    title:SetPoint("CENTER", 14, 0)
    title:SetText(ns.FramedTitle())
    if title.SetShadowOffset then title:SetShadowOffset(1, -1); title:SetShadowColor(0, 0, 0, 0.9) end
    local emblem = plaque:CreateTexture(nil, "OVERLAY")
    emblem:SetSize(34, 34); emblem:SetPoint("RIGHT", title, "LEFT", -10, 0); emblem:SetTexture(M .. "emblem")
    fr.plaque, fr.title, fr.emblem = plaque, title, emblem

    -- header: the old title moves into the plaque; character and range become the skin's controls
    local hp = win.headParts or {}
    for _, k in ipairs({ "logo", "t1", "t2", "rule", "portrait", "ring" }) do if hp[k] then hp[k]:Hide() end end
    if win.nameText then win.nameText:Hide() end
    if win.level then win.level:Hide() end
    local S = ns.settings
    local oldScope, oldRange = win.scopeSeg, win.rangeSeg
    oldScope:Hide(); oldRange:Hide()
    local charDD = Dropdown(head, explorer and 220 or 200, {
        { id = "char", label = UnitName("player") or "This character", tip = "Only this character." },
        { id = "account", label = "All characters", tip = "Every character on this account that has logged in with LifeTimeStats." },
    }, function(id) S.scope = id; if ns.InvalidateAccount then ns.InvalidateAccount() end; ns.RefreshWindow() end,
        { portrait = true, tip = { "Character", "Whose statistics to show: this character or every character on the account." } })
    win.scopeSeg = charDD
    local sb = hp.sb
    local close, gear = hp.close, hp.gear
    if explorer then
        charDD:SetPoint("LEFT", head, "LEFT", 12, 0)
        local seg = W.Segmented(head, {
            { id = "session", label = "Session", tip = "Since you logged in (or reset the session)." },
            { id = "today", label = "Daily", tip = "Since midnight, local time." },
            { id = "week", label = "Weekly", tip = "The last 7 days, today included." },
            { id = "month", label = "Monthly", tip = "The last 30 days, today included." },
            { id = "lifetime", label = "Lifetime", tip = "Everything since LifeTimeStats was installed." },
        }, function(id) S.range = id; ns.RefreshWindow() end)
        for _, b in ipairs(seg.buttons) do b:SetHeight(26); b:SetWidth(math.max(84, b:GetWidth())) end
        local x = 1
        for _, b in ipairs(seg.buttons) do b:ClearAllPoints(); b:SetPoint("LEFT", x, 0); x = x + b:GetWidth() end
        seg:SetSize(x + 1, 28)
        seg:SetPoint("LEFT", charDD, "RIGHT", 16, 0)
        -- the chosen range is a green tab with light text
        local plain = seg.Select
        function seg:Select(id)
            plain(self, id)
            for _, b in ipairs(self.buttons) do
                local on = b.id == id
                b.bg:SetShown(on)
                if on then W.Color(b.bg, T.amber) end
                b.bar:Hide()
                b.text.noInk = on or nil
                local c = on and LIGHT or T.text
                b.text:SetTextColor(c[1], c[2], c[3])
            end
        end
        win.rangeSeg = seg
        if sb then sb:ClearAllPoints(); sb:SetPoint("RIGHT", close, "LEFT", -14, 0); sb:SetSize(250, 28) end
        if gear then gear:ClearAllPoints(); gear:SetPoint("RIGHT", sb or close, "LEFT", -10, 0) end
    else
        local rangeDD = Dropdown(head, 150, {
            { id = "lifetime", label = "All time", tip = "Everything since LifeTimeStats was installed." },
            { id = "session", label = "This session", tip = "Since you logged in (or reset the session)." },
            { id = "today", label = "Today", tip = "Since midnight, local time." },
            { id = "week", label = "Last 7 days", tip = "The last 7 days, today included." },
            { id = "month", label = "Last 30 days", tip = "The last 30 days, today included." },
        }, function(id) S.range = id; ns.RefreshWindow() end, { icon = "clock", tip = { "Time range", "Which stretch of time the pages show." } })
        rangeDD:SetPoint("RIGHT", close, "LEFT", -12, 0)
        charDD:SetPoint("RIGHT", rangeDD, "LEFT", -10, 0)
        win.rangeSeg = rangeDD
        if sb then sb:ClearAllPoints(); sb:SetPoint("LEFT", head, "LEFT", 12, 0); sb:SetSize(dim.SIDEBAR_W + 60, 28) end
        if gear then gear:ClearAllPoints(); gear:SetPoint("RIGHT", charDD, "LEFT", -10, 0) end
    end

    -- the menu of pages
    local panel = side:CreateTexture(nil, "BACKGROUND", nil, -6)
    panel:SetPoint("TOPLEFT", 6, -2); panel:SetPoint("BOTTOMRIGHT", -4, 2)
    if explorer then
        panel:SetTexture(M .. "wood")
        local rim = W.Panel(side, { 0, 0, 0, 0 }, { 0.79, 0.63, 0.33, 0.9 })
        rim:SetPoint("TOPLEFT", 6, -2); rim:SetPoint("BOTTOMRIGHT", -4, 2)
        rim:SetFrameLevel(side:GetFrameLevel())
    else
        panel:SetColorTexture(T.tile[1], T.tile[2], T.tile[3], 0.6)
    end
    fr.menuPanel = panel
    for _, b in ipairs(win.navButtons or {}) do
        if b.kb then b.kb:Hide() end
        b.bar:Hide()
        b.bg:SetAlpha(explorer and 0.14 or 0.5)
        b.sel = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        b.sel:SetPoint("TOPLEFT", 4, 0); b.sel:SetPoint("BOTTOMRIGHT", 6, 0)
        b.sel:SetTexture(M .. "navsel")
        b.sel:SetVertexColor(T.amber[1], T.amber[2], T.amber[3], 1)
        b.sel:Hide()
        b.text.noInk = true
        b.text:SetFont(W.FONT, 13, "")
        if explorer then b.text:SetTextColor(LIGHT[1], LIGHT[2], LIGHT[3]) end
    end
    if explorer and win.todayBox then win.todayBox:Hide() end -- its pinned statistics sit along the bottom instead
    fr.divider = side:CreateTexture(nil, "ARTWORK")
    fr.divider:SetSize(140, 9); fr.divider:SetTexture(M .. "divider")
    local navBottom = 6 + #(win.navButtons or {}) * 29
    fr.divider:SetPoint("TOP", side, "TOPLEFT", (dim.SIDEBAR_W) / 2, -navBottom - 2)
    local dc = explorer and { 0.79, 0.63, 0.33 } or T.edge
    fr.divider:SetVertexColor(dc[1], dc[2], dc[3], 0.9)
    return fr
end

-- Selected and unselected menu entries (called from ShowPage after the generic styling).
function ns.StyleFramedNav(b, sel)
    local T = ns.THEME
    if not b.sel then return end
    b.sel:SetShown(sel)
    local explorer = ns.Explorer()
    local c = sel and LIGHT or (explorer and LIGHT or T.text)
    b.text:SetTextColor(c[1], c[2], c[3])
    local ic = sel and LIGHT or (explorer and { 0.80, 0.72, 0.56 } or T.dim)
    b.icon:SetVertexColor(ic[1], ic[2], ic[3])
end

-- LifeTimeStats - two more skins with a frame of their own (LifeTimeStats' own artwork):
--   Stone & Gold (in the style of Altoholic): dark stone inside steel rails with a gold bevel,
--     a round portrait on the corner, a gold title line, a menu of chapters with gold headers
--     and the pages under them, and the chapters again as tabs along the bottom.
--   Adventure Journal (in the style of Dungeon Journal): dark brown leather in a darker frame
--     with a thin gold line, a gold title in the middle of the top bar and gold-edged buttons.
-- Pages are unchanged; the overview is the standard Dashboard.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local HEAD_FILL = { 0.26, 0.20, 0.07, 0.95 }   -- Stone & Gold chapter header
local BTN_FILL = { 0.16, 0.11, 0.07, 0.95 }    -- Adventure Journal button
local BTN_ON = { 0.36, 0.25, 0.12, 1 }
local GOLD_EDGE = { 0.62, 0.48, 0.22, 1 }

local function Tiled(f, path, size)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    t:SetAllPoints()
    t:SetTexture(path, "REPEAT", "REPEAT")
    if t.SetHorizTile then t:SetHorizTile(true); t:SetVertTile(true) end
    return t
end

-- ------------------------------------------------------------ the frame
function ns.BuildStyledSkin(win, side, head, dim)
    local W, T = ns.W, ns.THEME
    local M = W.MEDIA .. "styled\\"
    local stone = ns.Stone()
    local st = {}
    win.styled = st
    if win.SetBackdropColor then pcall(win.SetBackdropColor, win, 0, 0, 0, 0) end
    if win.SetBackdropBorderColor then pcall(win.SetBackdropBorderColor, win, 0, 0, 0, 0) end
    st.back = Tiled(win, M .. (stone and "rock" or "leather"), 256)

    -- rails and corners
    local art = CreateFrame("Frame", nil, win)
    art:SetAllPoints()
    art:SetFrameLevel((win:GetFrameLevel() or 1) + 30)
    st.art = art
    local R = 20
    local h, v = stone and "sedge_h" or "jedge_h", stone and "sedge_v" or "jedge_v"
    local function Rail(tex, coords)
        local t = art:CreateTexture(nil, "BORDER")
        t:SetTexture(M .. tex)
        if coords then t:SetTexCoord(unpack(coords)) end
        return t
    end
    st.top = Rail(h); st.top:SetPoint("BOTTOMLEFT", win, "TOPLEFT", 0, -3); st.top:SetPoint("BOTTOMRIGHT", win, "TOPRIGHT", 0, -3); st.top:SetHeight(R + 3)
    st.bottom = Rail(h, { 0, 1, 1, 0 }); st.bottom:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 0, 3); st.bottom:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", 0, 3); st.bottom:SetHeight(R + 3)
    st.left = Rail(v); st.left:SetPoint("TOPRIGHT", win, "TOPLEFT", 3, 0); st.left:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", 3, 0); st.left:SetWidth(R + 3)
    st.right = Rail(v, { 1, 0, 0, 1 }); st.right:SetPoint("TOPLEFT", win, "TOPRIGHT", -3, 0); st.right:SetPoint("BOTTOMLEFT", win, "BOTTOMRIGHT", -3, 0); st.right:SetWidth(R + 3)
    st.corners = {}
    for i, c in ipairs({
        { "TOPLEFT", -R + 2, R - 2, { 0, 1, 0, 1 } }, { "TOPRIGHT", R - 2, R - 2, { 1, 0, 0, 1 } },
        { "BOTTOMLEFT", -R + 2, -R + 2, { 0, 1, 1, 0 } }, { "BOTTOMRIGHT", R - 2, -R + 2, { 1, 0, 1, 0 } },
    }) do
        local t = art:CreateTexture(nil, "ARTWORK")
        t:SetTexture(M .. "rivet"); t:SetSize(40, 40); t:SetTexCoord(unpack(c[4]))
        t:SetPoint(c[1], win, c[1], c[2], c[3])
        st.corners[i] = t
    end

    -- header: a gold title line in the middle; the controls on either side
    local hp = win.headParts or {}
    for _, k in ipairs({ "logo", "t1", "t2", "rule", "portrait", "ring" }) do if hp[k] then hp[k]:Hide() end end
    if win.nameText then win.nameText:Hide() end
    if win.level then win.level:Hide() end
    local bar = head:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetPoint("TOPLEFT", 4, -4); bar:SetPoint("BOTTOMRIGHT", -4, 4)
    bar:SetColorTexture(0, 0, 0, stone and 0.45 or 0.35)
    st.title = W.Text(head, stone and 14 or 17, T.amber, W.FONT, "CENTER")
    st.title:SetPoint("CENTER", 0, 0)
    st.title:SetText(stone and ("LifeTimeStats  |cffffffffv" .. tostring(ns.VERSION) .. "|r  by |cff4fc4eeMalikor|r") or "LifeTimeStats Journal")
    if st.title.SetShadowOffset then st.title:SetShadowOffset(1, -1); st.title:SetShadowColor(0, 0, 0, 1) end

    local S = ns.settings
    win.scopeSeg:Hide(); win.rangeSeg:Hide()
    local charDD = ns.FramedDropdown(head, 170, {
        { id = "char", label = UnitName("player") or "This character", tip = "Only this character." },
        { id = "account", label = "All characters", tip = "Every character on this account that has logged in with LifeTimeStats." },
    }, function(id) S.scope = id; if ns.InvalidateAccount then ns.InvalidateAccount() end; ns.RefreshWindow() end,
        { portrait = true, tip = { "Character", "Whose statistics to show." } })
    local rangeDD = ns.FramedDropdown(head, 136, {
        { id = "lifetime", label = "All time" }, { id = "session", label = "This session" }, { id = "today", label = "Today" },
        { id = "week", label = "Last 7 days" }, { id = "month", label = "Last 30 days" },
    }, function(id) S.range = id; ns.RefreshWindow() end, { icon = "clock", tip = { "Time range", "Which stretch of time the pages show." } })
    rangeDD:SetPoint("RIGHT", hp.close, "LEFT", -10, 0)
    charDD:SetPoint("RIGHT", rangeDD, "LEFT", -8, 0)
    win.scopeSeg, win.rangeSeg = charDD, rangeDD
    if hp.gear then hp.gear:ClearAllPoints(); hp.gear:SetPoint("RIGHT", charDD, "LEFT", -8, 0) end
    local sb = hp.sb
    if sb then
        sb:ClearAllPoints()
        sb:SetPoint("LEFT", head, "LEFT", stone and 64 or 12, 0)
        sb:SetSize(200, 26)
    end

    -- Stone & Gold: the portrait in a gold ring on the top-left corner
    if stone then
        local pf = CreateFrame("Frame", nil, art)
        pf:SetSize(76, 76); pf:SetPoint("CENTER", win, "TOPLEFT", 14, -10)
        pf:SetFrameLevel((art:GetFrameLevel() or 1) + 4)
        st.portrait = pf:CreateTexture(nil, "ARTWORK")
        st.portrait:SetSize(60, 60); st.portrait:SetPoint("CENTER")
        if st.portrait.SetMask then pcall(st.portrait.SetMask, st.portrait, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
        if SetPortraitTexture then pcall(SetPortraitTexture, st.portrait, "player") end
        local ring = pf:CreateTexture(nil, "OVERLAY"); ring:SetAllPoints(); ring:SetTexture(M .. "ring")
        st.ring = ring
    end

    -- the menu
    local navs = win.navButtons or {}
    local byId = {}
    for _, b in ipairs(navs) do
        byId[b.id] = b
        if b.kb then b.kb:Hide() end
        b.bar:Hide()
        b.bg:SetAlpha(0)
        b.text:SetFont(W.FONT, 12, "")
    end
    if stone then
        -- chapters with gold headers and their pages indented under them
        local inset = side:CreateTexture(nil, "BACKGROUND", nil, -6)
        inset:SetPoint("TOPLEFT", 6, -4); inset:SetPoint("BOTTOMRIGHT", -4, 4)
        inset:SetColorTexture(0, 0, 0, 0.40)
        st.headers = {}
        local RH, y = 25, -8
        for _, tab in ipairs(ns.NOTEBOOK_TABS or {}) do
            local hdr = CreateFrame("Button", nil, side)
            hdr:SetSize(dim.SIDEBAR_W - 20, RH - 2); hdr:SetPoint("TOPLEFT", 10, y)
            W.Box(hdr, HEAD_FILL, GOLD_EDGE)
            hdr.text = W.Text(hdr, 12, T.amber); hdr.text:SetPoint("LEFT", 8, 0); hdr.text:SetText(tab.name)
            hdr.tab = tab
            hdr:SetScript("OnClick", function(self) ns.ShowPage(self.tab.pages[1]) end)
            st.headers[#st.headers + 1] = hdr
            y = y - RH
            for _, pid in ipairs(tab.pages) do
                local b = byId[pid]
                if b then
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 10, y); b:SetSize(dim.SIDEBAR_W - 20, RH - 2)
                    b.icon:Hide()
                    b.text:ClearAllPoints(); b.text:SetPoint("LEFT", 20, 0); b.text:SetWidth(dim.SIDEBAR_W - 48)
                    b.hbar = b:CreateTexture(nil, "BACKGROUND", nil, 2)
                    b.hbar:SetAllPoints(); b.hbar:SetTexture(M .. "hbar"); b.hbar:SetVertexColor(0.85, 0.65, 0.10, 0.85); b.hbar:Hide()
                    y = y - RH
                end
            end
        end
        if win.todayBox then win.todayBox:Hide() end -- the chapter list fills the column
    else
        for _, b in ipairs(navs) do
            local fill = W.Box(b, BTN_FILL, GOLD_EDGE)
            b.jfill = fill
            b.text:SetWidth(dim.SIDEBAR_W - 56) -- the shortcut badge is hidden, so names get its room
            b.text:SetText(b.text:GetText())
            b.text:SetTextColor(T.amber[1], T.amber[2], T.amber[3])
        end
    end

    -- Stone & Gold: chapter tabs along the bottom
    if stone then
        st.tabs = {}
        local x = 18
        for _, tab in ipairs(ns.NOTEBOOK_TABS or {}) do
            local t = CreateFrame("Button", nil, art)
            t:SetSize(108, 28)
            t:SetPoint("TOPLEFT", win, "BOTTOMLEFT", x, -(R - 2))
            t.fill = W.Box(t, { 0.10, 0.09, 0.07, 0.96 }, GOLD_EDGE)
            t.text = W.Text(t, 12, T.amber, nil, "CENTER"); t.text:SetPoint("CENTER", 0, 1); t.text:SetText(tab.name)
            t.tab = tab
            t:SetScript("OnClick", function(self)
                local last = ns.settings and ns.settings.notebookPage and ns.settings.notebookPage[self.tab.id]
                ns.ShowPage(last or self.tab.pages[1])
            end)
            st.tabs[#st.tabs + 1] = t
            x = x + 112
        end
        if win.SetClampRectInsets then pcall(win.SetClampRectInsets, win, -40, -(24 + 118), 40, -50) end
    end
    return st
end

-- Selected and unselected menu entries, and the chapter tabs (called from ShowPage).
function ns.StyleStyledNav(b, sel, pageId)
    local T = ns.THEME
    if ns.Stone() then
        if b.hbar then b.hbar:SetShown(sel) end
        local c = sel and { 1, 1, 1 } or { 0.86, 0.86, 0.86 }
        b.text:SetTextColor(c[1], c[2], c[3])
    elseif b.jfill then
        ns.W.Color(b.jfill, sel and BTN_ON or BTN_FILL)
        local c = sel and { 1, 0.90, 0.55 } or T.amber
        b.text:SetTextColor(c[1], c[2], c[3])
        b.icon:SetVertexColor(c[1], c[2], c[3])
    end
end

function ns.UpdateStyledTabs(pageId)
    local win = _G.LifeTimeStatsWindow
    local st = win and rawget(win, "styled")
    if not st or not st.tabs then return end
    local tab = ns.NotebookTabFor and ns.NotebookTabFor(pageId)
    for _, t in ipairs(st.tabs) do
        local on = tab and t.tab.id == tab.id
        ns.W.Color(t.fill, on and { 0.32, 0.25, 0.08, 1 } or { 0.10, 0.09, 0.07, 0.96 })
        local c = on and { 1, 1, 1 } or { 1, 0.82, 0 }
        t.text:SetTextColor(c[1], c[2], c[3])
    end
    if tab and ns.settings then
        ns.settings.notebookPage = ns.settings.notebookPage or {}
        ns.settings.notebookPage[tab.id] = pageId
    end
end

-- LifeTimeStats - the Adventurer's Notebook window frame: wood around parchment pages, a spiral
-- binding, tabs down the left edge (one per chapter of the tome) and a page index of tag-shaped
-- buttons in the margin. Pages themselves are unchanged; only the frame and navigation differ.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

-- The tome's chapters: each side tab opens one of these, the margin lists its pages.
ns.NOTEBOOK_TABS = {
    { id = "hero",      name = "Hero",      chapter = "I",   pages = { "dashboard", "roster", "compare" } },
    { id = "deeds",     name = "Deeds",     chapter = "II",  pages = { "travel", "combat", "deaths", "wealth", "social" } },
    { id = "quests",    name = "Quests",    chapter = "III", pages = { "adventure", "guide", "life" } },
    { id = "legends",   name = "Legends",   chapter = "IV",  pages = { "records", "fastest", "achievements", "lists" } },
    { id = "chronicle", name = "Chronicle", chapter = "V",   pages = { "journal", "timeline" } },
    { id = "lore",      name = "Lore",      chapter = "VI",  pages = { "help" } },
}
-- Page names in the tome's voice (the sidebar names stay for the other skins).
ns.NOTEBOOK_PAGE_NAMES = {
    dashboard = "Overview", roster = "Characters", compare = "Compare",
    travel = "Travels", combat = "Battles", deaths = "Deaths", wealth = "Purse & Pack", social = "Company",
    adventure = "Adventures", guide = "Dungeon Tome", life = "Life on the Road",
    records = "Records", fastest = "Feats & Firsts", achievements = "Honours", lists = "Rolls of Note",
    journal = "Journal", timeline = "Days", help = "How it works",
}

-- The ink sketch drawn in the margin of each page (Media/notebook/sketches/<name>.tga).
ns.NOTEBOOK_SKETCHES = {
    dashboard = "compass", roster = "hero", compare = "scales",
    travel = "boot", combat = "swords", deaths = "skull", wealth = "backpack", social = "mugs",
    adventure = "mapscroll", guide = "tower", life = "campfire",
    records = "crown", fastest = "hourglass", achievements = "medal", lists = "scroll",
    journal = "quill", timeline = "sunmoon", help = "book", search = "magnifier",
}

-- Wax seal colour and the tint helper used by the Achievements page and the Dashboard.
ns.WAX = { 0.58, 0.13, 0.11 }
function ns.MakeSeal(parent, size, numeral)
    local W = ns.W
    local seal = CreateFrame("Frame", nil, parent)
    seal:SetSize(size, size)
    seal.tex = seal:CreateTexture(nil, "OVERLAY")
    seal.tex:SetAllPoints()
    seal.tex:SetTexture(W.MEDIA .. "notebook\\seal")
    seal.tex:SetVertexColor(ns.WAX[1], ns.WAX[2], ns.WAX[3], 1)
    seal.text = W.Text(seal, math.max(8, math.floor(size * 0.32)), { 0.98, 0.90, 0.80 }, nil, "CENTER")
    seal.text:SetPoint("CENTER", 0, 0)
    seal.text:SetText(numeral or "")
    seal:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    seal:Hide()
    return seal
end

function ns.NotebookTabFor(pageId)
    for _, tab in ipairs(ns.NOTEBOOK_TABS) do
        for _, p in ipairs(tab.pages) do if p == pageId then return tab end end
    end
end

-- "Hero" -> "H\nE\nR\nO": the game cannot be relied on to rotate text, so tabs stack letters.
local function Stack(text)
    local out = {}
    for ch in text:upper():gmatch(".") do out[#out + 1] = ch end
    return table.concat(out, "\n")
end
ns.NotebookStack = Stack

function ns.BuildNotebookFrame(win, side, dim)
    local W, T = ns.W, ns.THEME
    local J = W.JOURNAL
    local MEDIA = W.MEDIA .. "notebook\\"
    local nb = { tabs = {}, tags = {} }
    win.notebook = nb

    -- the window's own backdrop would draw over the wood and paper on the same layer
    if win.SetBackdropColor then pcall(win.SetBackdropColor, win, 0, 0, 0, 0) end

    -- one hand-made parchment sheet for the whole window: torn edges, scorched rim, inked frame.
    -- It is a little larger than the window, so the torn edges sit just outside and every
    -- control stays on solid paper.
    if win.SetBackdropBorderColor then pcall(win.SetBackdropBorderColor, win, 0, 0, 0, 0) end
    local sheet = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    sheet:SetPoint("TOPLEFT", win, "TOPLEFT", -46, 30)
    sheet:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 46, -30)
    sheet:SetTexture(MEDIA .. "sheet")
    nb.sheet = sheet
    -- a soft drop shadow so the sheet lifts off the world behind it
    local shadow = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetPoint("TOPLEFT", sheet, "TOPLEFT", 6, -8)
    shadow:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", 6, -8)
    shadow:SetTexture(MEDIA .. "sheet")
    shadow:SetVertexColor(0, 0, 0, 0.45)
    shadow:SetDrawLayer("BACKGROUND", -8)
    sheet:SetDrawLayer("BACKGROUND", -7)
    nb.shadow = shadow
    -- the fold down the middle of the page, under the content
    local crease = win:CreateTexture(nil, "BACKGROUND", nil, -5)
    local mid = dim.SIDEBAR_W + dim.PAD + dim.CW / 2
    crease:SetPoint("TOPLEFT", win, "TOPLEFT", mid - 24, -dim.HEADER_H)
    crease:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", mid + 24, dim.FOOTER_H)
    crease:SetTexture(MEDIA .. "crease")
    nb.crease = crease
    -- an inked line between the margin and the page
    local margin = side:CreateTexture(nil, "BORDER")
    margin:SetPoint("TOPLEFT", side, "TOPLEFT", 174, -4); margin:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 174, 4); margin:SetWidth(1)
    margin:SetColorTexture(T.text[1], T.text[2], T.text[3], 0.35)

    -- bookmark tabs down the left edge of the sheet
    local TAB_H, TAB_GAP = 100, 6
    for i, tab in ipairs(ns.NOTEBOOK_TABS) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(44, TAB_H)
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 4, -8 - (i - 1) * (TAB_H + TAB_GAP))
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(MEDIA .. "tab")
        b.text = W.Text(b, 11, T.dim, nil, "CENTER")
        b.text:SetWordWrap(true)
        b.text:SetWidth(20)
        b.text:SetPoint("CENTER", 2, 0)
        b.text:SetText(Stack(tab.name))
        b.tab = tab
        b:SetScript("OnClick", function(self)
            local sb = rawget(win, "search"); if sb then sb:SetText("") end
            local last = ns.settings and ns.settings.notebookPage and ns.settings.notebookPage[self.tab.id]
            ns.ShowPage(last or self.tab.pages[1])
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Chapter " .. self.tab.chapter .. ": " .. self.tab.name, T.amber[1], T.amber[2], T.amber[3])
            local names = {}
            for _, p in ipairs(self.tab.pages) do names[#names + 1] = ns.NOTEBOOK_PAGE_NAMES[p] or p end
            GameTooltip:AddLine(table.concat(names, " · "), T.text[1], T.text[2], T.text[3], true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        nb.tabs[i] = b
    end

    -- page index in the margin: chapter heading, then one tag per page of the chapter
    nb.chapter = W.Text(side, 10, T.dim, nil, "CENTER"); nb.chapter:SetPoint("TOP", side, "TOPLEFT", 130, -12); nb.chapter:SetWidth(92)
    nb.title = W.Text(side, 15, T.amber, nil, "CENTER"); nb.title:SetPoint("TOP", nb.chapter, "BOTTOM", 0, -3); nb.title:SetWidth(96)
    W.Bold(nb.title, T.amber)
    local TAG_H, TAG_GAP = 26, 7
    for i = 1, 6 do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(96, TAG_H)
        b:SetPoint("TOP", side, "TOPLEFT", 130, -56 - (i - 1) * (TAG_H + TAG_GAP))
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetTexture(MEDIA .. "tag")
        b.line = b:CreateTexture(nil, "BORDER"); b.line:SetAllPoints(); b.line:SetTexture(MEDIA .. "tagline")
        b.text = W.Text(b, 10, T.text, nil, "CENTER"); b.text:SetPoint("CENTER"); b.text:SetWidth(84)
        b:SetScript("OnClick", function(self) if self.page then
            local sb = rawget(win, "search"); if sb then sb:SetText("") end
            ns.ShowPage(self.page)
        end end)
        nb.tags[i] = b
    end

    nb.rings = {} -- the spiral binding was replaced by the parchment sheet in 1.23

    -- an ink sketch for the page, between the page index and Today
    nb.sketch = side:CreateTexture(nil, "ARTWORK")
    nb.sketch:SetSize(84, 84)
    nb.sketch:SetPoint("TOP", side, "TOPLEFT", 130, -262)
    nb.sketch:SetVertexColor(T.text[1], T.text[2], T.text[3], 0.85)

    -- the Today box moves to the bottom of the margin
    local tb = rawget(win, "todayBox")
    if tb then
        tb:ClearAllPoints()
        -- ends at x 170, left of the inked margin rule at 174, so values are not clipped
        tb:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 72, 8)
        tb:SetSize(98, 128)
        -- smaller values so "Online 23m 33s" fits the margin
        for _, v in ipairs(rawget(win, "today") or {}) do
            if v.SetFont then pcall(v.SetFont, v, W.NUM, 10, "") end
        end
    end
    for _, b in ipairs(win.navButtons or {}) do b:Hide() end

    local GREEN = { 0.80, 0.85, 0.66 }
    function nb:Select(pageId)
        local tab = ns.NotebookTabFor(pageId)
        if tab and ns.settings then
            ns.settings.notebookPage = ns.settings.notebookPage or {}
            ns.settings.notebookPage[tab.id] = pageId
        end
        for _, b in ipairs(self.tabs) do
            local on = tab and b.tab.id == tab.id
            local c = on and J.page or J.tab
            b.bg:SetVertexColor(c[1], c[2], c[3], 1)
            b:SetWidth(on and 52 or 44)
            b.active = on and true or false
            local tc = on and T.amber or T.dim
            b.text:SetTextColor(tc[1], tc[2], tc[3])
            if on then W.Bold(b.text, T.amber) elseif b.text.SetShadowOffset then b.text:SetShadowOffset(0, 0) end
        end
        local sk = ns.NOTEBOOK_SKETCHES[pageId]
        if sk then self.sketch:SetTexture(MEDIA .. "sketches\\" .. sk) end
        self.sketch:SetShown(sk ~= nil)
        self.sketchName = sk
        self.chapter:SetText(tab and ("CHAPTER " .. tab.chapter) or "")
        self.title:SetText(tab and tab.name or "Search")
        for i, b in ipairs(self.tags) do
            local page = tab and tab.pages[i]
            b.page = page
            b:SetShown(page ~= nil)
            if page then
                local on = page == pageId
                b.text:SetText(W.SmallCaps(ns.NOTEBOOK_PAGE_NAMES[page] or page))
                -- long names ("Life on the Road") shrink to fit the tag
                local size = 10 -- small caps: capitals, a point smaller
                b.text:SetFont(W.FONT, size, "")
                while size > 8 and (b.text:GetStringWidth() or 0) > 80 do size = size - 1; b.text:SetFont(W.FONT, size, "") end
                local c = on and GREEN or J.base
                b.bg:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.75)
                local lc = on and { 0.37, 0.50, 0.23 } or T.dim
                b.line:SetVertexColor(lc[1], lc[2], lc[3], 1)
                local tc = on and T.text or T.dim
                b.text:SetTextColor(tc[1], tc[2], tc[3])
                if on then W.Bold(b.text) elseif b.text.SetShadowOffset then b.text:SetShadowOffset(0, 0) end
            end
        end
        self.current = pageId
    end
    return nb
end

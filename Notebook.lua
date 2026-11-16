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

    -- wood all around, parchment from the spiral to the right edge
    local wood = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    wood:SetAllPoints()
    wood:SetTexture(MEDIA .. "wood", "REPEAT", "REPEAT")
    if wood.SetHorizTile then wood:SetHorizTile(true); wood:SetVertTile(true) end
    local paper = win:CreateTexture(nil, "BACKGROUND", nil, -7)
    paper:SetPoint("TOPLEFT", win, "TOPLEFT", 78, -3)
    paper:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -3, 3)
    paper:SetTexture(MEDIA .. "paper", "REPEAT", "REPEAT")
    if paper.SetHorizTile then paper:SetHorizTile(true); paper:SetVertTile(true) end
    nb.paper, nb.wood = paper, wood
    -- the fold between the two pages, under the content
    local crease = win:CreateTexture(nil, "BACKGROUND", nil, -6)
    local mid = dim.SIDEBAR_W + dim.PAD + dim.CW / 2
    crease:SetPoint("TOPLEFT", win, "TOPLEFT", mid - 24, -dim.HEADER_H)
    crease:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", mid + 24, dim.FOOTER_H)
    crease:SetTexture(MEDIA .. "crease")
    nb.crease = crease

    -- spiral binding down the left edge of the paper
    local strip = side:CreateTexture(nil, "BORDER")
    strip:SetPoint("TOPLEFT", side, "TOPLEFT", 70, 0); strip:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 70, 0); strip:SetWidth(10)
    strip:SetColorTexture(J.base[1] * 0.85, J.base[2] * 0.85, J.base[3] * 0.85, 0.9)
    nb.rings = {}
    local h = side:GetHeight()
    if not h or h < 100 then h = dim.CH + dim.PAD * 2 end
    local n = math.floor((h - 10) / 28)
    for i = 1, n do
        local r = side:CreateTexture(nil, "ARTWORK")
        r:SetTexture(MEDIA .. "ring")
        r:SetSize(44, 22)
        r:SetPoint("LEFT", side, "TOPLEFT", 44, -14 - (i - 1) * 28)
        nb.rings[i] = r
    end

    -- side tabs (on the wood, left of the spiral)
    local TAB_H, TAB_GAP = 100, 6
    for i, tab in ipairs(ns.NOTEBOOK_TABS) do
        local b = CreateFrame("Button", nil, side)
        b:SetSize(44, TAB_H)
        b:SetPoint("TOPLEFT", side, "TOPLEFT", 4, -8 - (i - 1) * (TAB_H + TAB_GAP))
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(MEDIA .. "tab")
        b.text = W.Text(b, 10, T.dim, nil, "CENTER")
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

    -- the Today box moves to the bottom of the margin
    local tb = rawget(win, "todayBox")
    if tb then
        tb:ClearAllPoints()
        tb:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 82, 8)
        tb:SetSize(96, 128)
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
        end
        self.chapter:SetText(tab and ("CHAPTER " .. tab.chapter) or "")
        self.title:SetText(tab and tab.name or "Search")
        for i, b in ipairs(self.tags) do
            local page = tab and tab.pages[i]
            b.page = page
            b:SetShown(page ~= nil)
            if page then
                local on = page == pageId
                b.text:SetText(ns.NOTEBOOK_PAGE_NAMES[page] or page)
                local c = on and GREEN or J.base
                b.bg:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.75)
                local lc = on and { 0.37, 0.50, 0.23 } or T.dim
                b.line:SetVertexColor(lc[1], lc[2], lc[3], 1)
                local tc = on and T.text or T.dim
                b.text:SetTextColor(tc[1], tc[2], tc[3])
            end
        end
        self.current = pageId
    end
    return nb
end

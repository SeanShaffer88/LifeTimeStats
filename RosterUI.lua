-- LifeTimeStats - Characters page: every character at a glance, one page per character,
-- the players you grouped with, and farming rates per session.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local function Int(n) return ns.FormatInt(n or 0) end
local function Time(n) return ns.FormatTime(n or 0) end
local function Money(n) return ns.FormatMoney(math.floor(n or 0)) end
local function Day(t) return type(t) == "number" and t > 0 and date("%b %d, %Y", t) or "—" end
local DIM = "|cff8a8a8a"
local STANDING = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

local function Ago(t)
    if type(t) ~= "number" or t <= 0 then return "never" end
    local d = time() - t
    if d < 120 then return "just now" end
    if d < 7200 then return math.floor(d / 60) .. " min ago" end
    if d < 172800 then return math.floor(d / 3600) .. " h ago" end
    return math.floor(d / 86400) .. " days ago"
end
ns.RosterAgo = Ago

local function ClassName(file, fallback)
    if type(fallback) == "string" and fallback ~= "" and fallback ~= file then return fallback end
    if type(file) ~= "string" or file == "" then return fallback or "" end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or (file:sub(1, 1) .. file:sub(2):lower())
end
ns.RosterClassName = ClassName

local function ClassColor(cls)
    local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c and c.r then return { c.r, c.g, c.b, 1 } end
end

local SECTIONS = {
    { id = "all",     name = "All characters",   tip = "Every character on this account: level, gold, /played, item level and when you last played them." },
    { id = "people",  name = "People",           tip = "Players who were in your group, kept only on this computer: time grouped, times grouped, first and last time, class and level." },
    { id = "farming", name = "Farming sessions", tip = "Your play sessions ranked by gold per active hour, with XP, kills and the vendor value of your loot per hour." },
}
ns.ROSTER_SECTIONS = SECTIONS

local R = {}

function R.all()
    local rows, list = {}, ns.RosterCharacters()
    local most = 0
    for _, c in ipairs(list) do most = math.max(most, c.snap.played or c.rec.c.played_server or 0) end
    for i, c in ipairs(list) do
        local s = c.snap
        local played = s.played or c.rec.c.played_server or 0
        local seen = s.t ~= nil
        rows[#rows + 1] = { tostring(i), c.name .. "  " .. DIM .. (s.level or c.rec.meta.level or "?") .. " " .. ClassName(s.class or c.rec.meta.class, s.className) .. "|r",
            most > 0 and played / most or 0, seen and Money(s.gold or 0) or "—",
            Time(played) .. (s.ilvl and (" · ilvl " .. s.ilvl) or "") .. " · " .. (seen and Ago(s.t) or "log in to update"),
            key = c.key, tip = (c.realm or "") .. (s.zone and ("\nLast seen in " .. s.zone) or "") .. (s.guild and ("\n<" .. s.guild .. ">") or "") }
    end
    local t = ns.RosterTotals()
    rows[#rows + 1] = { "", "|cffffb238ACCOUNT|r", nil, Money(t.gold),
        Time(t.played) .. " · " .. Int(t.chars) .. " characters · " .. Int(t.levels) .. " levels", head = true,
        tip = t.unseen > 0 and (Int(t.unseen) .. " character" .. (t.unseen == 1 and " has" or "s have") .. " not logged in since 1.17, so their gold is not in this total yet.") or nil }
    return rows
end

function R.char(key)
    local rec = ns.db and ns.db.chars and ns.db.chars[key]
    if not ns.ValidRecord or not ns.ValidRecord(rec) then return {} end
    local s, meta = rec.snap or {}, rec.meta
    local rows = { { "", "‹ Back to all characters", nil, "", "", back = "all" } }
    local function Rw(name, value, detail) rows[#rows + 1] = { "", name, nil, value or "", detail or "" } end
    local function Head(text) rows[#rows + 1] = { "", "|cffffb238" .. text:upper() .. "|r", nil, "", "", head = true } end
    rows[#rows + 1] = { "", (meta.name or key) .. (meta.realm and ("  " .. DIM .. meta.realm .. "|r") or ""), nil, "", Ago(s.t), head = true }
    Rw("Level", tostring(s.level or meta.level or "?"), (s.xp and s.xpMax and s.xpMax > 0) and string.format("%.0f%% to next", s.xp * 100 / s.xpMax) or "")
    if not s.t then Rw("Snapshot", "", "Log in with this character to fill in this page") end
    Rw("Race and class", "", ((s.race or "") .. " " .. ClassName(s.class or meta.class, s.className)):gsub("^%s+", ""))
    Rw("Title", "", s.title or s.titleLTS or "—")
    Rw("Guild", "", s.guild and (s.guild .. (s.guildRank and (" · " .. s.guildRank) or "")) or "—")
    Rw("Gold", Money(s.gold or 0))
    Rw("Played", Time(s.played or rec.c.played_server or 0), "since LifeTimeStats: " .. Time(rec.c.time_online or 0))
    Rw("Rested XP", s.rested and Int(s.rested) or "—", (s.rested and s.xpMax and s.xpMax > 0) and string.format("%.0f%% of a level", s.rested * 100 / s.xpMax) or "")
    Rw("Last seen in", "", (s.zone or "—") .. (s.subzone and s.subzone ~= s.zone and (" · " .. s.subzone) or ""))
    Rw("Hearthstone", "", s.hearth or "—")
    Rw("Average item level", s.ilvl and tostring(s.ilvl) or "—", rec.r.max_ilvl and ("best " .. rec.r.max_ilvl) or "")
    Rw("Bag space", s.bagTotal and (Int(s.bagFree or 0) .. " / " .. Int(s.bagTotal) .. " free") or "—")
    Rw("Best reputation", s.rep and (STANDING[s.rep.r] or tostring(s.rep.r)) or "—", s.rep and s.rep.n or "")
    Rw("Adventurer score", ns.Score and Int((ns.Score(rec))) or "—")
    Rw("Counting since", Day(meta.created))
    if type(s.profs) == "table" and #s.profs > 0 then
        Head("Professions")
        for i, p in ipairs(s.profs) do
            rows[#rows + 1] = { tostring(i), p.n, (p.m or 0) > 0 and (p.r or 0) / p.m or 0, Int(p.r) .. " / " .. Int(p.m), "" }
        end
    end
    if type(s.locks) == "table" and #s.locks > 0 then
        Head("Saved instances")
        for i, l in ipairs(s.locks) do
            local left = (l.e or 0) - time()
            rows[#rows + 1] = { tostring(i), l.n .. (l.d and (DIM .. "  " .. l.d .. "|r") or ""), (l.t and l.t > 0) and (l.p or 0) / l.t or nil,
                (l.t and l.t > 0) and (Int(l.p or 0) .. " / " .. Int(l.t)) or "",
                left > 0 and ("resets in " .. Time(left)) or "expired" }
        end
    end
    return rows
end

function R.people()
    local rows, list = {}, ns.RosterPeople()
    local most = list[1] and list[1].t or 0
    local multi = ns.GuideRecords and #ns.GuideRecords() > 1
    for i, p in ipairs(list) do
        local cls = p.cls and ((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.cls]) or p.cls:sub(1, 1) .. p.cls:sub(2):lower()) or nil
        rows[#rows + 1] = { tostring(i), p.name .. ((p.lvl or cls) and ("  " .. DIM .. (p.lvl and ("level " .. p.lvl .. " ") or "") .. (cls or "") .. "|r") or ""),
            most > 0 and p.t / most or 0, Time(p.t),
            Int(p.n) .. " time" .. (p.n == 1 and "" or "s") .. " · first " .. Day(p.f) .. " · last " .. Ago(p.l),
            tip = (p.z and ("First grouped in " .. p.z) or "") .. (multi and ("\nWith: " .. table.concat(p.with, ", ")) or "") }
    end
    return rows
end

function R.farming()
    local rows, list = {}, {}
    for _, r in ipairs(ns.GuideRecords and ns.GuideRecords() or { { rec = ns.char, name = "" } }) do
        for _, e in ipairs((r.rec and r.rec.sessionlog) or {}) do
            if type(e) == "table" then
                local rate = ns.SessionRates(e)
                if (rate.active or 0) >= 300 then list[#list + 1] = { e = e, r = rate, who = r.name } end
            end
        end
    end
    table.sort(list, function(a, b) return (a.r.gold or 0) > (b.r.gold or 0) end)
    local best = list[1] and math.max(list[1].r.gold or 0, 1) or 1
    local multi = ns.GuideRecords and #ns.GuideRecords() > 1
    for i, x in ipairs(list) do
        if i > 200 then break end
        local e, r = x.e, x.r
        rows[#rows + 1] = { tostring(i), date("%b %d %H:%M", e.s or 0) .. "  " .. DIM .. (e.z or "") .. (multi and (" · " .. x.who) or "") .. "|r",
            math.max(0, (r.gold or 0) / best), Money(r.gold or 0) .. "/h",
            Int(r.xp) .. " XP/h · " .. Int(r.kills) .. " kills/h · " .. Money(r.value or 0) .. " loot/h",
            tip = "Active " .. Time(r.active) .. " · net " .. Money(e.g or 0) .. " · " .. Int(e.it or 0) .. " items looted worth " .. Money(e.lv or 0) }
    end
    return rows
end
ns.RosterBuilders = R

function ns.RosterRows(state)
    if state.section == "char" then return R.char(state.key) end
    return (R[state.section] or R.all)()
end

function ns.RosterTitle(state)
    if state.section == "char" then
        local rec = ns.db and ns.db.chars and ns.db.chars[state.key]
        return rec and rec.meta and rec.meta.name or "Character"
    end
    for _, s in ipairs(SECTIONS) do if s.id == state.section then return s.name end end
    return "Characters"
end

function ns.RosterNavRows(state)
    local amber = ns.THEME.amber
    local counts = { all = #ns.RosterCharacters(), people = #ns.RosterPeople(), farming = 0 }
    for _, r in ipairs(ns.GuideRecords and ns.GuideRecords() or {}) do counts.farming = counts.farming + #((r.rec and r.rec.sessionlog) or {}) end
    local rows = {}
    for _, s in ipairs(SECTIONS) do
        rows[#rows + 1] = { s.name, Int(counts[s.id] or 0), section = s.id, tip = s.tip, color = state.section == s.id and amber or nil }
    end
    for _, c in ipairs(ns.RosterCharacters()) do
        local sel = state.section == "char" and state.key == c.key
        rows[#rows + 1] = { "  " .. c.name, tostring(c.snap.level or c.rec.meta.level or ""), section = "char", key = c.key,
            color = sel and amber or ClassColor(c.snap.class or c.rec.meta.class), tip = c.realm }
    end
    return rows
end

-- ------------------------------------------------------------ page: character-select layout
-- Right: one card per character (class icon, name in class colour, level and class, last zone),
-- like the character select screen. Left: the chosen character, with your own 3D model (alts,
-- whose appearance the client does not give addons, show their class crest), the key facts and
-- a table of professions, saved instances and lifetime highlights. People and Farming replace
-- the left side.
local CARD_H, CARD_GAP = 58, 4

local function ClassIcon(tex, cls)
    local atlas = cls and GetClassAtlas and GetClassAtlas(cls)
    if atlas and C_Texture and C_Texture.GetAtlasExists and C_Texture.GetAtlasExists(atlas) and tex.SetAtlas then
        tex:SetAtlas(atlas)
        tex:SetTexCoord(0, 1, 0, 1)
        return
    end
    local coords = cls and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    if coords then tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) else tex:SetTexCoord(0, 1, 0, 1) end
end

-- Facts shown beside the model: { label, value } for one character record.
function ns.RosterFacts(rec)
    local s, meta = rec.snap or {}, rec.meta or {}
    local function pct(a, b) return (a and b and b > 0) and string.format("%.0f%%", a * 100 / b) or nil end
    local rested = s.rested and (Int(s.rested) .. (pct(s.rested, s.xpMax) and (" (" .. pct(s.rested, s.xpMax) .. ")") or "")) or "—"
    return {
        { "Gold", s.t and Money(s.gold or 0) or "—" },
        { "Played", Time(s.played or (rec.c and rec.c.played_server) or 0) },
        { "Rested XP", rested },
        { "Next level", pct(s.xp, s.xpMax) or "—" },
        { "Item level", s.ilvl and tostring(s.ilvl) or "—" },
        { "Bag space", s.bagTotal and (Int(s.bagFree or 0) .. " / " .. Int(s.bagTotal) .. " free") or "—" },
        { "Hearthstone", s.hearth or "—" },
        { "Reputation", s.rep and ((STANDING[s.rep.r] or "?") .. " · " .. s.rep.n) or "—" },
        { "Score", ns.Score and Int((ns.Score(rec))) or "—" },
        { "Counting since", Day(meta.created) },
    }
end

-- The lower table on a character page: professions, saved instances and lifetime highlights.
function R.details(key)
    local rec = ns.db and ns.db.chars and ns.db.chars[key]
    if not ns.ValidRecord or not ns.ValidRecord(rec) then return {} end
    local s, rows = rec.snap or {}, {}
    local function Head(text) rows[#rows + 1] = { "", "|cffffb238" .. text:upper() .. "|r", nil, "", "", head = true } end
    if type(s.profs) == "table" and #s.profs > 0 then
        Head("Professions")
        for i, pr in ipairs(s.profs) do
            rows[#rows + 1] = { tostring(i), pr.n, (pr.m or 0) > 0 and (pr.r or 0) / pr.m or 0, Int(pr.r) .. " / " .. Int(pr.m), "" }
        end
    end
    if type(s.locks) == "table" and #s.locks > 0 then
        Head("Saved instances")
        for i, l in ipairs(s.locks) do
            local left = (l.e or 0) - time()
            rows[#rows + 1] = { tostring(i), l.n, (l.t and l.t > 0) and (l.p or 0) / l.t or nil,
                (l.t and l.t > 0) and (Int(l.p or 0) .. " / " .. Int(l.t)) or "",
                left > 0 and ("resets in " .. Time(left)) or "expired" }
        end
    end
    local c = rec.c or {}
    Head("Lifetime")
    local life = {
        { "Steps taken", Int((c.dist_foot or 0) * (ns.YARDS_TO_STEPS or 1)) },
        { "Enemies killed", Int((c.kills_npc or 0) + (c.kills_pvp or 0)) },
        { "Deaths", Int(c.deaths or 0) },
        { "Quests completed", Int(c.quests_done or 0) },
        { "Gold earned", Money(c.money_in or 0) },
        { "Items looted", Int(c.items_looted or 0) },
        { "Boss kills", Int(c.boss_kills or 0) },
        { "Time online with LifeTimeStats", Time(c.time_online or 0) },
    }
    for _, x in ipairs(life) do rows[#rows + 1] = { "", x[1], nil, x[2], "" } end
    if not s.t then
        rows[#rows + 1] = { "", DIM .. "Log in with this character once to fill in its gold, professions and more.|r", nil, "", "" }
    end
    return rows
end

function ns.BuildRosterPage(env)
    local W, T = ns.W, ns.THEME
    local p = env.NewPage("roster")
    local RW = 300
    local LW = env.CW - RW - env.GAP
    local state = { section = "char", key = ns.charKey }
    p.state = state
    ns.rosterPage = p

    -- ---------------------------------------------------- left: the chosen character
    local hero = env.Panel(p, "Character", "person", 0, 0, LW, env.CH)
    p.title = hero.title
    local hv = CreateFrame("Frame", nil, hero.body); hv:SetAllPoints()
    p.heroView = hv
    local stage = W.Fill(hv, T.bg, "BACKGROUND"); stage:SetPoint("TOPLEFT"); stage:SetSize(210, 270)
    local model = CreateFrame("PlayerModel", nil, hv)
    model:SetPoint("TOPLEFT", 4, -4); model:SetSize(202, 262)
    p.model = model
    local crest = hv:CreateTexture(nil, "ARTWORK"); crest:SetSize(112, 112); crest:SetPoint("CENTER", stage, "CENTER", 0, 10)
    p.crest = crest
    local crestNote = W.Text(hv, 10, T.dim, nil, "CENTER"); crestNote:SetPoint("TOP", crest, "BOTTOM", 0, -10); crestNote:SetWidth(190)
    crestNote:SetText("Log in with this character to see more here")
    p.crestNote = crestNote
    local x0 = 228
    p.nameText = W.Text(hv, 22, T.text, nil, "LEFT"); p.nameText:SetPoint("TOPLEFT", x0, -2)
    p.line1 = W.Text(hv, 13, T.text, nil, "LEFT"); p.line1:SetPoint("TOPLEFT", x0, -32)
    p.line2 = W.Text(hv, 11, T.dim, nil, "LEFT"); p.line2:SetPoint("TOPLEFT", x0, -52)
    p.line3 = W.Text(hv, 11, T.dim, nil, "LEFT"); p.line3:SetPoint("TOPLEFT", x0, -68); p.line3:SetWidth(LW - x0 - 30)
    p.facts = {}
    local colW = (LW - 20 - x0) / 2
    for i = 1, 10 do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local lbl = W.Text(hv, 10, T.dim, nil, "LEFT"); lbl:SetPoint("TOPLEFT", x0 + col * colW, -98 - row * 34)
        local val = W.Text(hv, 13, T.amber, W.NUM, "LEFT"); val:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2); val:SetWidth(colW - 10)
        p.facts[i] = { lbl, val }
    end
    local detailY = 282
    local dh = CreateFrame("Frame", nil, hv)
    dh:SetPoint("TOPLEFT", hv, "TOPLEFT", 0, -detailY); dh:SetSize(hero.bw, hero.bh - detailY)
    p.details = W.Table(dh, hero.bw, hero.bh - detailY, {
        { "#", 30, kind = "dim" }, { "ENTRY", 250, kind = "text" }, { "", 110, kind = "bar" }, { "VALUE", 110, kind = "num" }, { "DETAIL", 0, kind = "dim" },
    }, nil, "Nothing recorded yet.")

    -- People / Farming fill the left side instead
    local lv = CreateFrame("Frame", nil, hero.body); lv:SetAllPoints(); lv:Hide()
    p.listView = lv
    p.list = W.Table(lv, hero.bw, hero.bh, {
        { "#", 32, kind = "dim" }, { "ENTRY", 230, kind = "text" }, { "", 80, kind = "bar" }, { "VALUE", 110, kind = "num" }, { "DETAIL", 0, kind = "dim" },
    }, nil, "Nothing recorded yet.")

    -- ---------------------------------------------------- right: character cards
    local side = env.Panel(p, "Characters", "person", LW + env.GAP, 0, RW, env.CH, "Every character on this account, kept on this computer only.")
    local listH = side.bh - 108
    p.visibleCards = math.max(1, math.floor((listH + CARD_GAP) / (CARD_H + CARD_GAP)))
    p.cards, p.offset = {}, 0
    for i = 1, p.visibleCards do
        local b = CreateFrame("Button", nil, side.body)
        b:SetSize(side.bw, CARD_H); b:SetPoint("TOPLEFT", 0, -(i - 1) * (CARD_H + CARD_GAP))
        b.bg = W.Fill(b, T.tileHi, "BACKGROUND"); b.bg:SetAllPoints()
        b.sel = W.Fill(b, T.amber, "BORDER"); b.sel:SetPoint("TOPLEFT"); b.sel:SetPoint("BOTTOMLEFT"); b.sel:SetWidth(3)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(40, 40); b.icon:SetPoint("LEFT", 10, 0)
        b.name = W.Text(b, 14, T.text, nil, "LEFT"); b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, 0)
        b.info = W.Text(b, 11, T.text, nil, "LEFT"); b.info:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
        b.zone = W.Text(b, 10, T.dim, nil, "LEFT"); b.zone:SetPoint("TOPLEFT", b.info, "BOTTOMLEFT", 0, -2); b.zone:SetWidth(side.bw - 70)
        b:SetScript("OnClick", function(self)
            if not self.key then return end
            state.section, state.key = "char", self.key
            p.force = true
            ns.RefreshWindow()
        end)
        b:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetAlpha(1) end end)
        b:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetAlpha(0.45) end end)
        p.cards[i] = b
    end
    side.body:EnableMouseWheel(true)
    side.body:SetScript("OnMouseWheel", function(_, delta)
        p.offset = math.max(0, p.offset - delta)
        p.force = true
        ns.RefreshWindow()
    end)
    p.summary = W.Text(side.body, 11, T.text); p.summary:SetPoint("TOPLEFT", 2, -(listH + 6)); p.summary:SetWidth(side.bw - 4)
    p.summary2 = W.Text(side.body, 10, T.dim); p.summary2:SetPoint("TOPLEFT", p.summary, "BOTTOMLEFT", 0, -4); p.summary2:SetWidth(side.bw - 4)
    local half = (side.bw - 6) / 2
    p.peopleBtn = W.FlatButton(side.body, "People", half, 26, "People", SECTIONS[2].tip)
    p.peopleBtn:SetPoint("BOTTOMLEFT", 0, 0)
    p.peopleBtn:SetScript("OnClick", function() state.section = "people"; p.force = true; ns.RefreshWindow() end)
    p.farmBtn = W.FlatButton(side.body, "Farming", half, 26, "Farming sessions", SECTIONS[3].tip)
    p.farmBtn:SetPoint("BOTTOMRIGHT", 0, 0)
    p.farmBtn:SetScript("OnClick", function() state.section = "farming"; p.force = true; ns.RefreshWindow() end)

    local function ShowCards(chars)
        local n = #chars
        p.offset = math.max(0, math.min(p.offset, n - p.visibleCards))
        for i, b in ipairs(p.cards) do
            local c = chars[i + p.offset]
            b.key = c and c.key
            b:SetShown(c ~= nil)
            if c then
                local cls = c.snap.class or c.rec.meta.class
                ClassIcon(b.icon, cls)
                b.name:SetText(c.name)
                local col = ClassColor(cls) or T.text
                b.name:SetTextColor(col[1], col[2], col[3])
                b.info:SetText("Level " .. (c.snap.level or c.rec.meta.level or "?") .. " " .. ClassName(cls, c.snap.className))
                b.zone:SetText(c.snap.t and ((c.snap.zone or "?") .. " · " .. Ago(c.snap.t)) or "log in to update")
                b.selected = state.section == "char" and state.key == c.key
                b.sel:SetShown(b.selected)
                b.bg:SetAlpha(b.selected and 1 or 0.45)
            end
        end
    end

    local function ShowCharacter(key)
        local rec = ns.db.chars[key]
        if not ns.ValidRecord(rec) then return end
        local s, meta = rec.snap or {}, rec.meta
        local cls = s.class or meta.class
        local isMe = key == ns.charKey
        p.model:SetShown(isMe)
        if isMe and p.model.SetUnit then pcall(p.model.SetUnit, p.model, "player") end
        p.crest:SetShown(not isMe)
        p.crestNote:SetShown(not isMe and not s.t)
        if not isMe then ClassIcon(p.crest, cls) end
        p.nameText:SetText(meta.name or key)
        local col = ClassColor(cls) or T.text
        p.nameText:SetTextColor(col[1], col[2], col[3])
        p.line1:SetText("Level " .. (s.level or meta.level or "?") .. " " .. ((s.race and (s.race .. " ")) or "") .. ClassName(cls, s.className))
        local title = s.title or s.titleLTS
        local guild = s.guild and ("<" .. s.guild .. ">" .. (s.guildRank and (" " .. s.guildRank) or "")) or (meta.realm or "")
        p.line2:SetText((title and (title .. "   ") or "") .. guild)
        p.line3:SetText(s.t and ("Last seen in " .. (s.zone or "?") .. (s.subzone and s.subzone ~= s.zone and (", " .. s.subzone) or "") .. " · " .. Ago(s.t))
            or "Not seen since LifeTimeStats 1.17")
        for i, f in ipairs(ns.RosterFacts(rec)) do
            p.facts[i][1]:SetText(f[1]:upper())
            p.facts[i][2]:SetText(f[2])
        end
        p.details:SetData(R.details(key))
    end

    local lastAt = -100
    function p:Update()
        if not self.force and GetTime() - lastAt < 5 then return end
        self.force, lastAt = nil, GetTime()
        local chars = ns.RosterCharacters()
        if state.section == "char" and not (state.key and ns.db.chars[state.key]) then state.key = ns.charKey end
        ShowCards(chars)
        local t = ns.RosterTotals()
        self.summary:SetText(Int(t.chars) .. " characters · " .. Money(t.gold))
        self.summary2:SetText(Time(t.played) .. " played · " .. Int(t.levels) .. " levels"
            .. (t.unseen > 0 and (" · " .. t.unseen .. " not updated yet") or ""))
        local onChar = state.section == "char"
        self.heroView:SetShown(onChar)
        self.listView:SetShown(not onChar)
        self.title:SetText(ns.CardTitle(ns.RosterTitle(state)))
        if onChar then ShowCharacter(state.key) else self.list:SetData(ns.RosterRows(state)) end
    end
    return p
end

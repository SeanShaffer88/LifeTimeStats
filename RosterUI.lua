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
        rows[#rows + 1] = { tostring(i), c.name .. "  " .. DIM .. "level " .. (s.level or c.rec.meta.level or "?") .. " " .. (s.className or c.rec.meta.class or "") .. "|r",
            most > 0 and played / most or 0, Money(s.gold or 0),
            Time(played) .. " played · " .. (s.ilvl and ("ilvl " .. s.ilvl .. " · ") or "") .. Ago(s.t),
            key = c.key, tip = (c.realm or "") .. (s.zone and ("\nLast seen in " .. s.zone) or "") .. (s.guild and ("\n<" .. s.guild .. ">") or "") }
    end
    local t = ns.RosterTotals()
    rows[#rows + 1] = { "", "|cffffb238ACCOUNT|r", nil, Money(t.gold),
        Time(t.played) .. " played · " .. Int(t.chars) .. " characters · " .. Int(t.levels) .. " levels", head = true }
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
    Rw("Race and class", "", ((s.race or "") .. " " .. (s.className or meta.class or "")):gsub("^%s+", ""))
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

function ns.BuildRosterPage(env)
    local W = ns.W
    local p = env.NewPage("roster")
    local lw = 250
    local state = { section = "all" }
    p.state = state
    ns.rosterPage = p
    local lc = env.Panel(p, "Characters", "person", 0, 0, lw, env.CH, "Every character on this account, kept on this computer only.")
    p.nav = W.Table(lc.body, lc.bw, lc.bh, { { "CHARACTER", 190, kind = "text" }, { "", 0, kind = "dim" } }, function(d)
        state.section, state.key = d.section, d.key
        ns.RefreshWindow()
    end)
    local rc = env.Panel(p, "All characters", "person", lw + env.GAP, 0, env.CW - lw - env.GAP, env.CH)
    p.title = rc.title
    p.list = W.Table(rc.body, rc.bw, rc.bh, {
        { "#", 36, kind = "dim" }, { "ENTRY", 290, kind = "text" }, { "", 110, kind = "bar" }, { "VALUE", 130, kind = "num" }, { "DETAIL", 0, kind = "dim" },
    }, function(d)
        if d.back then state.section, state.key = d.back, nil
        elseif d.key then state.section, state.key = "char", d.key
        else return end
        ns.RefreshWindow()
    end, "Nothing recorded yet.")
    local lastKey, lastAt = nil, -100
    function p:Update()
        local key = tostring(state.section) .. "|" .. tostring(state.key) .. "|" .. tostring(ns.settings and ns.settings.scope)
        if key == lastKey and GetTime() - lastAt < 5 then return end
        lastAt = GetTime()
        self.nav:SetData(ns.RosterNavRows(state), true)
        self.title:SetText(ns.CardTitle(ns.RosterTitle(state)))
        self.list:SetData(ns.RosterRows(state), key == lastKey)
        lastKey = key
    end
    return p
end

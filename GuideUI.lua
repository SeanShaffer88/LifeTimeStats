-- LifeTimeStats - Adventure Guide page: a Dungeon Journal-style compendium of what your
-- characters have seen. Left: chapters (sections and every dungeon). Right: the entries.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local function Int(n) return ns.FormatInt(n or 0) end
local function Time(n) return ns.FormatTime(n or 0) end
local function Day(t) return type(t) == "number" and t > 0 and date("%b %d, %Y", t) or "—" end
local DIM = "|cff8a8a8a"

local SECTIONS = {
    { id = "suggest",  name = "Suggestions",        tip = "Next goals for this character: dungeons in your level range you have not entered, bosses never killed, missing full clears and bosses that beat you." },
    { id = "book",     name = "Progress book",      tip = "Every dungeon and raid as a chapter: bosses seen (pulled), bosses killed and runs." },
    { id = "bosses",   name = "Boss pages",         tip = "Every boss you have pulled or killed. Click one for its page." },
    { id = "runs",     name = "Run history",        tip = "Each dungeon and raid run: length, bosses, deaths, wipes and who was with you." },
    { id = "deaths",   name = "Death codex",        tip = "Where and to what you died: by boss fight, by zone and by level." },
    { id = "bestiary", name = "Bestiary",           tip = "Every creature you have killed since 1.15, with type, classification, zone and first kill." },
    { id = "atlas",    name = "Zone atlas",         tip = "Every zone you have a record of: time, distance, quests, kills, deaths, loot and first visit." },
    { id = "chapters", name = "Chronicle chapters", tip = "Your Journal grouped into chapters of ten levels. Click one to copy it as text." },
    { id = "group",    name = "Group memories",     tip = "Who you have run instances and killed bosses with." },
    { id = "loot",     name = "Boss loot",          tip = "What you looted within 3 minutes of each boss kill, from your own loot messages. Not a full loot table." },
}
ns.GUIDE_SECTIONS = SECTIONS

local function Top(map, n)
    local list = {}
    for k, v in pairs(map or {}) do if type(v) == "number" then list[#list + 1] = { k, v } end end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return tostring(a[1]) < tostring(b[1]) end)
    if n then for i = #list, n + 1, -1 do list[i] = nil end end
    return list
end
ns.GuideTop = Top

local function Count(map) local n = 0 for _ in pairs(map or {}) do n = n + 1 end return n end
local function Plural(n, word) return Int(n) .. " " .. word .. (n == 1 and "" or "s") end
local function Head(text) return { "", "|cffffb238" .. text:upper() .. "|r", nil, "", "", head = true } end

local function Dungeon(key) return ns.DUNGEON_BY_KEY and ns.DUNGEON_BY_KEY[key] end

local function BossList(d, view)
    local list, seen = {}, {}
    for _, b in ipairs(d.bosses) do list[#list + 1] = { name = b.name, optional = b.optional }; seen[b.name] = true end
    for name in pairs(((view.u or {})["djlearn_" .. d.key]) or {}) do
        if not seen[name] then list[#list + 1] = { name = name, learned = true }; seen[name] = true end
    end
    return list
end

-- ------------------------------------------------------------ section builders
local B = {}

function B.suggest(view)
    local rows = {}
    for i, s in ipairs(ns.GuideSuggestions(view)) do
        rows[#rows + 1] = { tostring(i), s.text, s.score / 3, "", s.detail, dkey = s.dkey, boss = s.boss, tip = s.detail }
    end
    return rows
end

function B.book(view)
    local rows = {}
    local u, un, t = view.u or {}, view.un or {}, view.t or {}
    for i, d in ipairs(ns.DUNGEONS or {}) do
        local found, total = ns.DungeonProgress(d, view)
        local seen = un["djseen_" .. d.key] or Count(u["djseen_" .. d.key])
        local runs = (t.dungeonruns or {})[d.name] or 0
        local clears = (t.dungeonclears or {})[d.name] or 0
        local tag = (d.raid and "raid " or "") .. d.min .. (d.max ~= d.min and ("-" .. d.max) or "")
        rows[#rows + 1] = { tostring(i), d.name .. "  " .. DIM .. tag .. "|r", total > 0 and found / total or 0,
            d.learn and (found .. " known") or (found .. " / " .. total),
            Plural(seen, "boss") .. " seen · " .. Plural(runs, "run") .. (clears > 0 and (" · " .. Plural(clears, "clear")) or ""),
            dkey = d.key, tip = d.zone .. (d.learn and "\nRoster still being discovered: bosses are added as you meet them." or "") }
    end
    return rows
end

function B.bosses(view)
    local rows, list = {}, {}
    for _, label in ipairs(ns.GuideKnownBosses(view)) do list[#list + 1] = { label, ns.GuideBoss(view, label) } end
    table.sort(list, function(a, b) if a[2].kills ~= b[2].kills then return a[2].kills > b[2].kills end return a[1] < b[1] end)
    local most = list[1] and list[1][2].kills or 0
    for i, e in ipairs(list) do
        local b = e[2]
        rows[#rows + 1] = { tostring(i), e[1], most > 0 and b.kills / most or 0, Int(b.kills),
            Plural(b.wipes, "wipe") .. " · " .. Plural(b.deaths, "death") .. (b.fastest and (" · best " .. Time(b.fastest)) or ""), boss = e[1] }
    end
    return rows
end

function B.dungeon(view, key)
    local d = Dungeon(key)
    if not d then return {} end
    local rows = { { "", "‹ Back to the progress book", nil, "", "", back = "book" } }
    local found, total = ns.DungeonProgress(d, view)
    local fast = (view.f or {})["clear:" .. d.key]
    rows[#rows + 1] = { "", d.name .. "  " .. DIM .. d.zone .. "|r", total > 0 and found / total or 0, found .. " / " .. total,
        "Level " .. d.min .. "-" .. d.max .. (fast and (" · fastest clear " .. Time(type(fast) == "table" and fast.v or fast)) or ""), head = true }
    local killedSet = (view.u or {})["djboss_" .. d.key] or {}
    for i, b in ipairs(BossList(d, view)) do
        local g = ns.GuideBoss(view, b.name)
        local killed = killedSet[b.name] or g.kills > 0
        rows[#rows + 1] = { tostring(i), b.name .. (b.optional and (DIM .. "  optional|r") or (b.learned and (DIM .. "  learned|r") or "")),
            killed and 1 or 0, killed and Int(math.max(g.kills, 1)) or "—",
            killed and ("first " .. Day(g.firstKill) .. (g.fastest and (" · best " .. Time(g.fastest)) or "")) or (g.pulls > 0 and (Plural(g.pulls, "pull") .. ", not killed yet") or "not met yet"),
            boss = b.name }
    end
    return rows
end

function B.boss(view, label, from)
    local g = ns.GuideBoss(view, label)
    local rows = { { "", "‹ Back", nil, "", "", back = from or "bosses" } }
    local function R(name, value, detail) rows[#rows + 1] = { "", name, nil, value or "", detail or "" } end
    rows[#rows + 1] = { "", label, nil, "", "", head = true }
    R("Kills", Int(g.kills))
    R("Pulls", Int(g.pulls), "boss fights started")
    R("Wipes", Int(g.wipes))
    R("Kill rate", g.pulls > 0 and string.format("%.0f%%", math.min(100, g.kills * 100 / g.pulls)) or "—")
    R("Deaths during the fight", Int(g.deaths))
    R("Time spent fighting", Time(g.time))
    R("Fastest kill", g.fastest and Time(g.fastest) or "—", g.fastestWhat or "")
    R("First pulled", Day(g.firstPull))
    R("First killed", Day(g.firstKill), g.firstHow or "")
    R("First kill group", "", g.firstGroup or "—")
    R("Items looted after kills", Int(g.loot))
    local killers = Top(g.killers, 10)
    if #killers > 0 then
        rows[#rows + 1] = Head("What killed you here")
        for i, e in ipairs(killers) do rows[#rows + 1] = { tostring(i), e[1], e[2] / killers[1][2], Int(e[2]), "" } end
    end
    local items = Top(g.items, 30)
    if #items > 0 then
        rows[#rows + 1] = Head("Loot you got")
        for i, e in ipairs(items) do rows[#rows + 1] = { tostring(i), e[1], e[2] / items[1][2], Int(e[2]), "" } end
    end
    return rows
end

function B.runs()
    local rows, runs = {}, ns.GuideRuns()
    local longest = 1
    for _, r in ipairs(runs) do longest = math.max(longest, (r.e.e or r.e.s) - r.e.s) end
    for i, r in ipairs(runs) do
        local e = r.e
        local secs = math.max(0, (e.e or e.s) - e.s)
        rows[#rows + 1] = { tostring(i), date("%b %d %H:%M", e.s) .. "  " .. (e.n or "?") .. (r.who and (DIM .. "  " .. r.who .. "|r") or ""),
            secs / longest, Time(secs),
            Plural(e.b or 0, "boss") .. " · " .. Plural(e.de or 0, "death") .. ((e.w or 0) > 0 and (" · " .. Plural(e.w, "wipe")) or "")
                .. " · " .. ns.GroupSizeLabel(e.g or 1) .. (e.c and " · full clear" or ""),
            tip = "Level " .. (e.l or "?") .. " · " .. Plural(e.loot or 0, "item") .. " looted" .. (e.m and ("\nWith: " .. e.m) or "\nNo other players seen"),
            dkey = e.k }
    end
    return rows
end

function B.deaths(view)
    local rows, t = {}, view.t or {}
    local byBoss = Top(t.guide_bossdeath, 25)
    if #byBoss > 0 then
        rows[#rows + 1] = Head("By boss fight")
        for i, e in ipairs(byBoss) do
            local k = Top(t["gdeath:" .. e[1]], 1)[1]
            rows[#rows + 1] = { tostring(i), e[1], e[2] / byBoss[1][2], Int(e[2]), k and ("mostly " .. k[1]) or "", boss = e[1] }
        end
    end
    local byDungeon = Top(t.guide_rundeath, 15)
    if #byDungeon > 0 then
        rows[#rows + 1] = Head("By dungeon")
        for i, e in ipairs(byDungeon) do rows[#rows + 1] = { tostring(i), e[1], e[2] / byDungeon[1][2], Int(e[2]), "" } end
    end
    local byZone = Top(t.zonedeaths, 25)
    if #byZone > 0 then
        rows[#rows + 1] = Head("You died here most")
        for i, e in ipairs(byZone) do
            local k = Top(t["gzk:" .. e[1]], 1)[1]
            rows[#rows + 1] = { tostring(i), e[1], e[2] / byZone[1][2], Int(e[2]), k and ("mostly " .. k[1]) or "" }
        end
    end
    local killers = Top(t.killedwith, 15)
    if #killers > 0 then
        rows[#rows + 1] = Head("Killing abilities")
        for i, e in ipairs(killers) do rows[#rows + 1] = { tostring(i), e[1], e[2] / killers[1][2], Int(e[2]), "" } end
    end
    local byLevel = Top(t.guide_deathlevel)
    table.sort(byLevel, function(a, b) return (tonumber(a[1]:match("%d+")) or 0) < (tonumber(b[1]:match("%d+")) or 0) end)
    if #byLevel > 0 then
        local most = 0 for _, e in ipairs(byLevel) do most = math.max(most, e[2]) end
        rows[#rows + 1] = Head("By level")
        for i, e in ipairs(byLevel) do rows[#rows + 1] = { tostring(i), e[1], e[2] / most, Int(e[2]), "" } end
    end
    return rows
end

local SPECIAL = { rare = "rare", rareelite = "rare elite", elite = "elite", worldboss = "boss" }
function B.bestiary(view)
    local rows, list = {}, {}
    local beasts = view.bestiary or (ns.char and ns.char.bestiary) or {}
    for name, e in pairs(beasts) do if type(e) == "table" then list[#list + 1] = { name, e } end end
    table.sort(list, function(a, b) if a[2].k ~= b[2].k then return a[2].k > b[2].k end return a[1] < b[1] end)
    local most = list[1] and list[1][2].k or 0
    for i, x in ipairs(list) do
        local e = x[2]
        local special = SPECIAL[e.cl or ""]
        local lv = e.lo and (e.lo == e.hi and ("level " .. e.lo) or ("level " .. e.lo .. "-" .. (e.hi or e.lo))) or nil
        local parts = {}
        if e.ty then parts[#parts + 1] = e.ty end
        if special then parts[#parts + 1] = special end
        if e.z then parts[#parts + 1] = e.z end
        rows[#rows + 1] = { tostring(i), x[1], most > 0 and e.k / most or 0, Int(e.k), table.concat(parts, " · "),
            color = special and ns.THEME.amber or nil,
            tip = "First killed " .. Day(e.f) .. (e.who and (" by " .. e.who) or "") .. "\nLast killed " .. Day(e.l) .. (lv and ("\nSeen at " .. lv) or "") }
    end
    return rows
end

function B.atlas(view)
    local rows, zones = {}, ns.GuideZones(view)
    local most = zones[1] and zones[1].time or 0
    for i, z in ipairs(zones) do
        local k = Top(z.killers, 1)[1]
        rows[#rows + 1] = { tostring(i), z.zone, most > 0 and z.time / most or 0, Time(z.time),
            (z.first and ("since " .. Day(z.first) .. " ") or "") .. Plural(z.quests, "quest") .. " · " .. Plural(z.kills, "kill") .. " · " .. Plural(z.deaths, "death"),
            tip = string.format("Distance %s yd · %s visits · %s items looted · %s new creatures · %s level-ups%s%s%s",
                Int(z.dist), Int(z.visits), Int(z.loot), Int(z.creatures), Int(z.levelups),
                z.firstLevel and ("\nFirst visit at level " .. z.firstLevel) or "",
                z.last and ("\nLast visit " .. Day(z.last)) or "",
                k and ("\nKilled here most by " .. k[1]) or "") }
    end
    return rows
end

function B.chapters()
    local rows, chapters = {}, ns.GuideChapters()
    local most = 0 for _, c in ipairs(chapters) do most = math.max(most, #c.entries) end
    local index = {}
    for i, c in ipairs(chapters) do
        index[c.who] = (index[c.who] or 0) + 1
        local n = index[c.who]
        rows[#rows + 1] = { tostring(i), string.format("Chapter %d: Levels %d-%d", n, c.from, c.to) .. ((#ns.GuideRecords() > 1) and (DIM .. "  " .. c.who .. "|r") or ""),
            most > 0 and #c.entries / most or 0, Plural(#c.entries, "entry"):gsub("entrys", "entries"),
            Plural(c.kinds.first or 0, "first") .. " · " .. Plural(c.kinds.boss or 0, "boss kill") .. " · " .. Plural(c.kinds.death or 0, "death"),
            chapter = c, chapterIndex = n, tip = Day(c.start) .. " to " .. Day(c.finish) .. "\nClick to copy the chapter as text." }
    end
    return rows
end

function B.group(view)
    local t = view.t or {}
    local names = {}
    for _, tn in ipairs({ "guide_grouprun", "guide_groupboss", "guide_firstkillmates" }) do
        for name in pairs(t[tn] or {}) do names[name] = true end
    end
    local list = {}
    for name in pairs(names) do
        list[#list + 1] = { name, (t.guide_grouprun or {})[name] or 0, (t.guide_groupboss or {})[name] or 0, (t.guide_firstkillmates or {})[name] or 0 }
    end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end if a[3] ~= b[3] then return a[3] > b[3] end return a[1] < b[1] end)
    local rows, most = {}, list[1] and list[1][2] or 0
    for i, e in ipairs(list) do
        rows[#rows + 1] = { tostring(i), e[1], most > 0 and e[2] / most or 0, Plural(e[2], "run"),
            Plural(e[3], "boss kill") .. (e[4] > 0 and (" · there for " .. Plural(e[4], "first kill")) or "") }
    end
    return rows
end

function B.loot(view)
    local rows, list = {}, Top((view.t or {}).guide_lootboss)
    for i, e in ipairs(list) do
        local top = Top((view.t or {})["gloot:" .. e[1]], 1)[1]
        rows[#rows + 1] = { tostring(i), e[1], e[2] / list[1][2], Int(e[2]), top and ("most: " .. top[1]) or "", boss = e[1] }
    end
    return rows
end
ns.GuideBuilders = B

-- Rows for a page state; also used by the offline tests.
function ns.GuideRows(view, state)
    if state.boss then return B.boss(view, state.boss, state.dkey and "dungeon" or state.section) end
    if state.section == "dungeon" then return B.dungeon(view, state.dkey) end
    local fn = B[state.section] or B.suggest
    return fn(view)
end

function ns.GuideTitle(state)
    if state.boss then return state.boss end
    if state.section == "dungeon" then local d = Dungeon(state.dkey) return d and d.name or "Dungeon" end
    for _, s in ipairs(SECTIONS) do if s.id == state.section then return s.name end end
    return "Adventure Guide"
end

-- Left column: the sections, then every dungeon.
function ns.GuideChapterRows(view, state)
    local rows = {}
    local counts = {
        suggest = #ns.GuideSuggestions(view), book = Count((view.u or {}).dungeons_seen), bosses = #ns.GuideKnownBosses(view),
        runs = #ns.GuideRuns(), deaths = (view.c or {}).deaths or 0, bestiary = Count(view.bestiary or (ns.char and ns.char.bestiary)),
        atlas = #ns.GuideZones(view), chapters = #ns.GuideChapters(), group = Count((view.t or {}).guide_grouprun),
        loot = Count((view.t or {}).guide_lootboss),
    }
    local amber = ns.THEME.amber
    for _, s in ipairs(SECTIONS) do
        rows[#rows + 1] = { s.name, Int(counts[s.id] or 0), section = s.id, tip = s.tip,
            color = (state.section == s.id and not state.boss) and amber or nil }
    end
    for _, d in ipairs(ns.DUNGEONS or {}) do
        local found, total = ns.DungeonProgress(d, view)
        rows[#rows + 1] = { "  " .. d.name, found .. "/" .. total, section = "dungeon", dkey = d.key,
            color = (state.section == "dungeon" and state.dkey == d.key and not state.boss) and amber or nil }
    end
    return rows
end

-- ------------------------------------------------------------ page
function ns.BuildGuidePage(env)
    local W = ns.W
    local p = env.NewPage("guide")
    local lw = 250
    local CW, CH, GAP = env.CW, env.CH, env.GAP
    local state = { section = "suggest" }
    p.state = state
    ns.guidePage = p
    local lc = env.Panel(p, "Adventure Guide", "tower", 0, 0, lw, CH,
        "A compendium of everything your characters have seen. Account scope shows every character.")
    p.nav = W.Table(lc.body, lc.bw, lc.bh, { { "CHAPTER", 190, kind = "text" }, { "", 0, kind = "dim" } }, function(d)
        state.section, state.dkey, state.boss = d.section, d.dkey, nil
        ns.RefreshWindow()
    end)
    local rc = env.Panel(p, "Suggestions", "scroll", lw + GAP, 0, CW - lw - GAP, CH)
    p.title = rc.title
    p.list = W.Table(rc.body, rc.bw, rc.bh, {
        { "#", 36, kind = "dim" }, { "ENTRY", 290, kind = "text" }, { "", 120, kind = "bar" }, { "VALUE", 110, kind = "num" }, { "DETAIL", 0, kind = "dim" },
    }, function(d)
        if d.back then
            if d.back == "dungeon" then state.boss = nil else state.section, state.boss = d.back, nil end
            if d.back ~= "dungeon" then state.dkey = nil end
        elseif d.chapter then
            if ns.ShowText then ns.ShowText(ns.GuideTitle(state), "Copy with Ctrl+C.", ns.GuideChapterText(d.chapter, d.chapterIndex)) end
            return
        elseif d.boss then
            state.boss = d.boss
            if state.section ~= "dungeon" then state.dkey = nil end
        elseif d.dkey then
            state.section, state.dkey, state.boss = "dungeon", d.dkey, nil
        else
            return
        end
        p.keepScroll = false
        ns.RefreshWindow()
    end, "Nothing recorded yet. Go and have an adventure.")
    local lastKey, lastScope, lastAt = nil, nil, -100
    function p:Update(view, base)
        local v = base or view
        local key = tostring(state.section) .. "|" .. tostring(state.dkey) .. "|" .. tostring(state.boss)
        local scope = ns.settings and ns.settings.scope
        -- The window refreshes every second; the guide only rebuilds every 5 s unless you navigate.
        if key == lastKey and scope == lastScope and GetTime() - lastAt < 5 then return end
        lastScope, lastAt = scope, GetTime()
        self.nav:SetData(ns.GuideChapterRows(v, state), true)
        self.title:SetText(ns.GuideTitle(state):upper())
        self.list:SetData(ns.GuideRows(v, state), key == lastKey)
        lastKey = key
    end
    return p
end

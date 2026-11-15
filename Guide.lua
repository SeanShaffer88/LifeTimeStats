-- LifeTimeStats - Adventure Guide data: boss pages, dungeon run history, death codex,
-- boss loot, bestiary, zone atlas, group memories and Chronicle chapters.
-- Everything is built from what this character actually saw; nothing is bundled.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Tally, Unique, On = ns.Add, ns.Tally, ns.Unique, ns.On
local S = ns.IsSecret

local RUNLOG_CAP, BESTIARY_CAP, MEMBERS_CAP = 200, 3000, 8
local LOOT_WINDOW = 180 -- seconds after a boss kill in which your loot counts as that boss's
ns.RUNLOG_CAP, ns.BESTIARY_CAP = RUNLOG_CAP, BESTIARY_CAP

local function Str(v)
    if type(v) ~= "string" or S(v) or v == "" then return nil end
    return v
end
local function Level()
    local l = UnitLevel("player")
    if S(l) or type(l) ~= "number" then return 0 end
    return l
end
local function Zone()
    return Str(ns.GetJournalZone and ns.GetJournalZone()) or Str(GetRealZoneText and GetRealZoneText()) or "Unknown"
end

-- ------------------------------------------------------------ group
-- Names of the other players in your group right now (realm kept when the client gives it).
function ns.GroupMembers()
    local out = {}
    local raid = IsInRaid and IsInRaid()
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if S(n) or type(n) ~= "number" then n = 0 end
    local me = UnitName("player")
    for i = 1, raid and n or math.max(0, n - 1) do
        local unit = (raid and "raid" or "party") .. i
        local name, realm = UnitName(unit)
        name, realm = Str(name), Str(realm)
        if name and name ~= me and name ~= UNKNOWNOBJECT then
            out[#out + 1] = realm and (name .. "-" .. realm) or name
        end
    end
    return out
end

local function GroupSize()
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if S(n) or type(n) ~= "number" or n < 1 then n = 1 end
    return n
end
local function SizeLabel(n)
    if n <= 1 then return "solo" elseif n == 2 then return "duo" elseif n == 3 then return "trio"
    elseif n <= 5 then return "party" .. n else return "raid" end
end
ns.GroupSizeLabel = SizeLabel

-- ------------------------------------------------------------ run log
-- One row per dungeon or raid run: s start, e last activity, n dungeon, k dungeon key,
-- l level at entry, b bosses, de deaths, w wipes, g largest group, m group members ("A, B"),
-- c full clear, loot items looted.
local function CurrentRun()
    local run = ns.char and ns.char.run
    if not run or run.left or (run.type ~= "party" and run.type ~= "raid") then return nil end
    return run
end

local function RunEntry(run)
    if not run or not ns.char then return nil end
    local log = ns.char.runlog
    for i = #log, math.max(1, #log - 20), -1 do
        if log[i].s == run.start then return log[i] end
    end
end
ns.GuideRunEntry = RunEntry

local function JoinMembers(entry, names)
    local have, list = {}, {}
    for name in (entry.m or ""):gmatch("[^,]+") do
        name = name:gsub("^%s+", "")
        if name ~= "" and not have[name] then have[name] = true; list[#list + 1] = name end
    end
    local added = {}
    for _, name in ipairs(names) do
        if not have[name] and #list < MEMBERS_CAP then
            have[name] = true; list[#list + 1] = name; added[#added + 1] = name
        end
    end
    entry.m = #list > 0 and table.concat(list, ", ") or nil
    return added
end

local function TouchRun(run)
    local entry = RunEntry(run)
    if not entry then return nil end
    entry.e = time()
    local size = GroupSize()
    if size > (entry.g or 1) then entry.g = size end
    for _, name in ipairs(JoinMembers(entry, ns.GroupMembers())) do
        Tally("guide_grouprun", name)
        Unique("guide_groupmates", name)
    end
    if run.cleared then entry.c = true end
    return entry
end
ns.GuideTouchRun = TouchRun

function ns.GuideRunStart(run)
    if not run or (run.type ~= "party" and run.type ~= "raid") or not ns.char then return end
    local log = ns.char.runlog
    log[#log + 1] = { s = run.start, e = run.start, n = Str(run.name) or "?", l = Level(), b = 0, de = 0, w = 0, g = 1 }
    while #log > RUNLOG_CAP do table.remove(log, 1) end
    Add("guide_runs_logged")
    local size = GroupSize()
    Add("guide_runs_" .. SizeLabel(size))
    TouchRun(run)
end

-- ------------------------------------------------------------ encounters
local engage -- { label, raw, t, wall, dkey }

local function Label(run, name)
    local d, label
    if run and ns.DungeonBossLabel then d, label = ns.DungeonBossLabel(run, name) end
    return label or Str(name) or "?", d
end

-- The encounter ID gives the boss its listed name even if the client words it differently.
function ns.EncounterName(id, name)
    if type(id) == "number" and not S(id) and ns.FOREVER_ENCOUNTERS and ns.FOREVER_ENCOUNTERS[id] then
        return ns.FOREVER_ENCOUNTERS[id]
    end
    return name
end

On("ENCOUNTER_START", function(_, id, name)
    if not ns.char then return end
    name = ns.EncounterName(id, name)
    local run = CurrentRun()
    local label, d = Label(run, name)
    engage = { label = label, t = GetTime(), wall = time(), dkey = d and d.key }
    Add("guide_pulls")
    Tally("guide_bosspull", label)
    if d then Unique("djseen_" .. d.key, label) end
    if not ns.char.first["gpull:" .. label] then
        ns.char.first["gpull:" .. label] = "level " .. Level()
        ns.char.firstd["gpull:" .. label] = time()
    end
end)

On("ENCOUNTER_END", function(_, id, name, _, _, success)
    if not ns.char then return end
    name = ns.EncounterName(id, name)
    local e = engage
    engage = nil
    local run = CurrentRun()
    local label = (e and e.label) or Label(run, name)
    local secs = e and (GetTime() - e.t) or nil
    if secs then
        Tally("guide_bosstime", label, secs)
        Add("guide_boss_fight_time", secs)
    end
    if success == 1 or success == true then
        if secs and secs > 0 then
            ns.Min("bossfast:" .. label, secs, "level " .. Level())
            ns.Max("max_boss_fight", secs, label)
        end
    else
        Add("guide_wipes")
        Tally("guide_bosswipe", label)
        local entry = run and RunEntry(run)
        if entry then entry.w = (entry.w or 0) + 1; entry.e = time() end
        if secs then ns.Max("max_wipe_fight", secs, label) end
    end
end)

function ns.GuideEngaged() return engage end

-- Every boss kill, from the encounter event or the unit fallback (Trackers calls this).
local lastBoss
function ns.OnBossKill(name, kind)
    if not ns.char then return end
    if kind ~= "party" and kind ~= "raid" then
        Tally("guide_worldbosses", Str(name) or "?")
        return
    end
    local run = CurrentRun()
    local label, d = Label(run, name)
    Tally("guide_bosskill", label)
    local size = GroupSize()
    Add("guide_boss_kills_" .. SizeLabel(size))
    local members = ns.GroupMembers()
    for _, m in ipairs(members) do Tally("guide_groupboss", m) end
    local ch = ns.char
    local key = "gboss:" .. label
    if not ch.first[key] then
        local il = ns.AvgItemLevel and ns.AvgItemLevel()
        ch.first[key] = "level " .. Level() .. (il and (" · item level " .. il) or "")
        ch.firstd[key] = time()
        ch.first["gbossgrp:" .. label] = #members > 0 and table.concat(members, ", ") or "solo"
        ch.firstd["gbossgrp:" .. label] = time()
        Add("guide_first_boss_kills")
        if #members > 0 then
            for _, m in ipairs(members) do Tally("guide_firstkillmates", m) end
        end
    end
    lastBoss = { label = label, t = GetTime(), start = run and run.start, dkey = d and d.key }
    local entry = run and RunEntry(run)
    if entry then
        entry.b = (entry.b or 0) + 1
        entry.k = entry.k or (d and d.key)
        if d and entry.n ~= d.name then entry.n = d.name end
        TouchRun(run)
        -- Dungeons.lua decides full clears right after this hook.
        if C_Timer then C_Timer.After(0, function() if run.cleared then entry.c = true end end) end
    end
end

-- ------------------------------------------------------------ deaths
function ns.OnPlayerDeath(cause, eventZone)
    if not ns.char then return end
    cause = Str(cause) or "Unknown"
    local zone = Str(eventZone) or Zone()
    Tally("gzk:" .. zone, cause)
    Tally("guide_deathlevel", "Level " .. Level())
    local hour = tonumber(date("%H"))
    if hour then Tally("deathhour", string.format("%02d:00", hour)) end
    if engage then
        Add("guide_boss_deaths")
        Tally("guide_bossdeath", engage.label)
        Tally("gdeath:" .. engage.label, cause)
    end
    local run = CurrentRun()
    if run then
        Add("guide_run_deaths")
        local entry = RunEntry(run)
        if entry then entry.de = (entry.de or 0) + 1; entry.e = time() end
        local d = ns.ResolveDungeon and ns.ResolveDungeon(run)
        Tally("guide_rundeath", (d and d.name) or Str(run.name) or "?")
    end
end

-- ------------------------------------------------------------ loot
function ns.OnLootItem(link, qty, quality)
    if not ns.char or type(link) ~= "string" or S(link) then return end
    qty = tonumber(qty) or 1
    local item = link:match("%[(.-)%]") or link
    Tally("zoneloot", Zone(), qty)
    local run = CurrentRun()
    if run then
        local entry = RunEntry(run)
        if entry then entry.loot = (entry.loot or 0) + qty end
    end
    local b = lastBoss
    if b and GetTime() - b.t <= LOOT_WINDOW and run and run.start == b.start then
        Tally("gloot:" .. b.label, item, qty)
        Tally("guide_lootboss", b.label, qty)
        Add("guide_boss_loot", qty)
        if type(quality) == "number" and quality >= 2 then Add("guide_boss_loot_q" .. quality, qty) end
        Unique("guide_bossitems", item)
    end
end

-- ------------------------------------------------------------ bestiary
function ns.OnCreatureKill(name, npcID)
    if not ns.char then return end
    name = Str(name)
    if not name or name == "?" then return end
    local info = ns.RecentUnitInfo and ns.RecentUnitInfo(name)
    local b = ns.char.bestiary
    local e = b[name]
    if not e then
        local n = 0
        for _ in pairs(b) do n = n + 1; if n >= BESTIARY_CAP then break end end
        if n >= BESTIARY_CAP then Add("bestiary_overflow") return end
        e = { k = 0, f = time(), z = Zone() }
        b[name] = e
        Add("bestiary_entries")
    end
    e.k = e.k + 1
    e.l = time()
    if info then
        e.ty = e.ty or Str(info.ctype)
        e.cl = e.cl or Str(info.class)
        if type(info.level) == "number" and not S(info.level) then
            if not e.lo or info.level < e.lo then e.lo = info.level end
            if not e.hi or info.level > e.hi then e.hi = info.level end
        end
    end
    if e.ty then Tally("creaturetypes", e.ty); Unique("bestiary_types", e.ty) end
    if e.cl then Tally("creatureclass", e.cl) end
    Tally("zonecreatures", e.z or Zone())
end

-- ------------------------------------------------------------ zone atlas
On("ZONE_CHANGED_NEW_AREA", function()
    if not ns.char then return end
    local z = Zone()
    if z == "Unknown" then return end
    Tally("zonevisits", z)
    local row = ns.char.zonelog[z]
    if type(row) == "table" then row[3] = time() end
end)
On("QUEST_TURNED_IN", function()
    if ns.char then Tally("zonequests", Zone()) end
end)
On("PLAYER_LEVEL_UP", function(_, level)
    if ns.char and not S(level) and type(level) == "number" then Tally("levelzones", Zone()) end
end)

-- ------------------------------------------------------------ queries used by the guide page
local function Settings() return ns.settings or {} end

-- Records the guide reads: this character, or every character in account scope.
function ns.GuideRecords()
    local out = {}
    if Settings().scope == "account" and ns.db and ns.db.chars then
        for key, rec in pairs(ns.db.chars) do
            if ns.ValidRecord(rec) then
                out[#out + 1] = { rec = rec, name = (type(rec.meta.name) == "string" and rec.meta.name) or key }
            end
        end
        table.sort(out, function(a, b) return a.name < b.name end)
    elseif ns.char then
        out[1] = { rec = ns.char, name = ns.char.meta and ns.char.meta.name or "" }
    end
    return out
end

-- All runs (newest first), tagged with the character when more than one is shown.
function ns.GuideRuns()
    local runs, recs = {}, ns.GuideRecords()
    for _, r in ipairs(recs) do
        for _, e in ipairs(r.rec.runlog or {}) do
            if type(e) == "table" and type(e.s) == "number" then
                runs[#runs + 1] = { e = e, who = #recs > 1 and r.name or nil }
            end
        end
    end
    table.sort(runs, function(a, b) return a.e.s > b.e.s end)
    return runs
end

-- Boss page facts for one boss label in a view.
function ns.GuideBoss(view, label)
    local t, f, first, firstd = view.t or {}, view.f or {}, view.first or {}, view.firstd or {}
    local function T(name) return (t[name] or {})[label] or 0 end
    local fast = f["bossfast:" .. label]
    return {
        kills = T("guide_bosskill") > 0 and T("guide_bosskill") or (t.bosses or {})[label] or 0,
        pulls = T("guide_bosspull"), wipes = T("guide_bosswipe"), deaths = T("guide_bossdeath"),
        time = T("guide_bosstime"), loot = T("guide_lootboss"),
        fastest = type(fast) == "table" and fast.v or fast, fastestWhat = (view.fw or {})["bossfast:" .. label],
        firstKill = firstd["gboss:" .. label], firstHow = first["gboss:" .. label],
        firstGroup = first["gbossgrp:" .. label], firstPull = firstd["gpull:" .. label],
        killers = t["gdeath:" .. label] or {}, items = t["gloot:" .. label] or {},
    }
end

-- Bosses you have killed, pulled or wiped on anywhere (dungeon list first, then others).
function ns.GuideKnownBosses(view)
    local seen, out = {}, {}
    local t = view.t or {}
    for _, tn in ipairs({ "guide_bosskill", "guide_bosspull", "guide_bosswipe", "bosses_party", "bosses_raid" }) do
        for label in pairs(t[tn] or {}) do
            if not seen[label] then seen[label] = true; out[#out + 1] = label end
        end
    end
    table.sort(out)
    return out
end

-- Next goals for the current character: dungeons in range, missing bosses, unseen places.
function ns.GuideSuggestions(view)
    local out = {}
    local lvl = Level()
    for _, d in ipairs(ns.DUNGEONS or {}) do
        local found, total = ns.DungeonProgress(d, view)
        local inRange = lvl >= d.min - 2 and lvl <= d.max
        if inRange and not d.raid then
            local runs = ((view.t or {}).dungeonruns or {})[d.name] or 0
            if runs == 0 then
                out[#out + 1] = { score = 3, text = d.name .. ": never entered", detail = "Level " .. d.min .. "-" .. d.max .. " · " .. d.zone, dkey = d.key }
            elseif not d.learn and found < total then
                out[#out + 1] = { score = 2, text = d.name .. ": " .. (total - found) .. " boss" .. (total - found == 1 and "" or "es") .. " never killed",
                    detail = found .. " / " .. total .. " found · " .. d.zone, dkey = d.key }
            elseif not ((view.u or {}).dungeons_cleared or {})[d.key] and not d.learn then
                out[#out + 1] = { score = 1, text = d.name .. ": no full clear yet", detail = "Every required boss in one run", dkey = d.key }
            end
        end
    end
    for _, label in ipairs(ns.GuideKnownBosses(view)) do
        local b = ns.GuideBoss(view, label)
        if b.wipes > 0 and b.kills == 0 then
            out[#out + 1] = { score = 2, text = label .. ": " .. b.wipes .. " wipe" .. (b.wipes == 1 and "" or "s") .. ", still standing", detail = "Unfinished business", boss = label }
        end
    end
    table.sort(out, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.text < b.text end)
    return out
end

-- Chronicle chapters: Journal entries grouped by ten-level bands, oldest first.
function ns.GuideChapters()
    local chapters, byBand = {}, {}
    for _, r in ipairs(ns.GuideRecords()) do
        for _, entry in ipairs(r.rec.journal or {}) do
            if type(entry) == "table" and type(entry[1]) == "number" and type(entry[2]) == "string" then
                local lvl = tonumber(entry[3]) or 0
                local band = math.floor(math.max(lvl - 1, 0) / 10)
                local key = r.name .. "#" .. band
                local c = byBand[key]
                if not c then
                    c = { who = r.name, band = band, from = band * 10 + 1, to = band * 10 + 10, entries = {}, kinds = {}, start = entry[1] }
                    byBand[key] = c
                    chapters[#chapters + 1] = c
                end
                c.entries[#c.entries + 1] = entry
                local kind = ns.JournalEntryInfo and ns.JournalEntryInfo(entry) or "other"
                c.kinds[kind or "other"] = (c.kinds[kind or "other"] or 0) + 1
                if entry[1] < c.start then c.start = entry[1] end
                if not c.finish or entry[1] > c.finish then c.finish = entry[1] end
            end
        end
    end
    table.sort(chapters, function(a, b) if a.who ~= b.who then return a.who < b.who end return a.band < b.band end)
    return chapters
end

function ns.GuideChapterText(c, index)
    local lines = {}
    lines[#lines + 1] = string.format("Chapter %d: Levels %d-%d%s", index, c.from, c.to, (c.who and c.who ~= "") and (" · " .. c.who) or "")
    lines[#lines + 1] = string.format("%s to %s · %d entries · %d firsts · %d boss kills · %d deaths · %d personal bests",
        date("%b %d, %Y", c.start), date("%b %d, %Y", c.finish or c.start), #c.entries,
        c.kinds.first or 0, c.kinds.boss or 0, c.kinds.death or 0, c.kinds.personalBest or 0)
    lines[#lines + 1] = ""
    for _, e in ipairs(c.entries) do
        lines[#lines + 1] = date("%Y-%m-%d %H:%M", e[1]) .. "  " .. e[2] .. (e.note and ("  (" .. e.note .. ")") or "")
    end
    return table.concat(lines, "\n")
end

-- Zone atlas rows: one per zone you have a record of.
function ns.GuideZones(view)
    local t = view.t or {}
    local zones, out = {}, {}
    for _, tn in ipairs({ "zonetime", "zonedist", "zonedeaths", "zonekills", "zonequests", "zonevisits", "zoneloot", "zonecreatures" }) do
        for z in pairs(t[tn] or {}) do zones[z] = true end
    end
    local logs = {}
    for _, r in ipairs(ns.GuideRecords()) do
        for z, row in pairs(r.rec.zonelog or {}) do
            zones[z] = true
            local l = logs[z]
            if type(row) == "table" then
                if not l or (row[1] or math.huge) < (l[1] or math.huge) then l = { row[1], row[2], l and l[3] } end
                if (row[3] or 0) > (l[3] or 0) then l[3] = row[3] end
                logs[z] = l
            end
        end
    end
    for z in pairs(zones) do
        if type(z) == "string" and z ~= "" and z ~= "Unknown" then
            local function V(tn) return (t[tn] or {})[z] or 0 end
            local log = logs[z] or {}
            out[#out + 1] = { zone = z, time = V("zonetime"), dist = V("zonedist"), deaths = V("zonedeaths"), kills = V("zonekills"),
                quests = V("zonequests"), visits = V("zonevisits"), loot = V("zoneloot"), creatures = V("zonecreatures"),
                levelups = V("levelzones"), first = log[1], firstLevel = log[2], last = log[3], killers = t["gzk:" .. z] or {} }
        end
    end
    table.sort(out, function(a, b) return a.time > b.time end)
    return out
end

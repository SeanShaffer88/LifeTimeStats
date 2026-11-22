-- LifeTimeStats - your character's story: journal, level snapshots, titles, inns, food,
-- mounts, pets, clothes, nature and game-time.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local B = ns.Bool
local Add, Max, Tally, Unique, First, On = ns.Add, ns.Max, ns.Tally, ns.Unique, ns.First, ns.On
local S = ns.IsSecret
local GetTime = GetTime

local function Zone() local z = ns.GetZone and ns.GetZone() return (z and z ~= "") and z or "?" end
local function SafeStr(v) if S(v) or type(v) ~= "string" or v == "" then return nil end return v end

-- ------------------------------------------------------------ journal
local JOURNAL_CAP = 600
ns.JOURNAL_NOTE_LIMIT = 500
ns.JOURNAL_CHAPTER_LIMIT, ns.JOURNAL_CHAPTER_NAME_LIMIT = 40, 80
local MAX_LOCAL_ID = 9007199254740990
local JOURNAL_KINDS = { first = true, boss = true, death = true, personalBest = true }
local firstLabels = {}
for key, label in pairs(ns.FIRST_LABEL) do firstLabels[label] = key end

local function ReadableZone(value)
    local name = SafeStr(value)
    if name and name ~= "?" and name:find("%S") then return name end
end

local function LocalID(value)
    return not S(value) and not ns.BadNumber(value) and value > 0 and value <= MAX_LOCAL_ID and value % 1 == 0
end

local function ChapterSerial(id)
    if not SafeStr(id) then return end
    local serial = id:match("^chapter:([1-9]%d*)$")
    serial = serial and tonumber(serial)
    if LocalID(serial) then return serial end
end

local function ChapterName(text)
    if not SafeStr(text) or #text > ns.JOURNAL_CHAPTER_NAME_LIMIT * 4 then
        return nil, "Enter a chapter name of up to 80 characters."
    end
    text = text:match("^%s*(.-)%s*$")
    if text == "" or text:find("[%z\1-\31\127|]") then return nil, "Enter a chapter name on one line without pipe characters." end
    local index, characters = 1, 0
    while index <= #text do
        local byte, width = text:byte(index), 1
        if byte >= 194 and byte <= 223 then width = 2
        elseif byte >= 224 and byte <= 239 then width = 3
        elseif byte >= 240 and byte <= 244 then width = 4
        elseif byte >= 128 then return nil, "The chapter name contains invalid text." end
        local second = text:byte(index + 1) or 0
        if (byte == 224 and second < 160) or (byte == 237 and second > 159)
            or (byte == 240 and second < 144) or (byte == 244 and second > 143) then
            return nil, "The chapter name contains invalid text."
        end
        for offset = 1, width - 1 do
            local continuation = text:byte(index + offset) or 0
            if continuation < 128 or continuation > 191 then return nil, "The chapter name contains invalid text." end
        end
        characters = characters + 1
        if characters > ns.JOURNAL_CHAPTER_NAME_LIMIT then return nil, "Keep the chapter name to 80 characters or fewer." end
        index = index + width
    end
    return text
end
ns.ValidateJournalChapterName = ChapterName
ns.JournalChapterSerial = ChapterSerial

function ns.JournalChapters()
    local result, seen = {}, {}
    local chapters = ns.char and ns.char.chapters
    if type(chapters) ~= "table" then return result end
    for _, chapter in ipairs(chapters) do
        if type(chapter) == "table" and not S(chapter) and ChapterSerial(chapter.id)
            and ChapterName(chapter.name) and not seen[chapter.id] then
            result[#result + 1], seen[chapter.id] = chapter, true
            if #result == ns.JOURNAL_CHAPTER_LIMIT then break end
        end
    end
    return result
end

local function FindChapter(id)
    if not ChapterSerial(id) then return end
    for _, chapter in ipairs(ns.JournalChapters()) do if chapter.id == id then return chapter end end
end

local function HasJournalEntry(entry)
    if type(entry) ~= "table" or S(entry) then return false end
    for _, row in ipairs((ns.char and ns.char.journal) or {}) do
        if rawequal(row, entry) then return true end
    end
    return false
end

function ns.CreateJournalChapter(name)
    if not ns.char then return nil, "The active character is unavailable." end
    local clean, reason = ChapterName(name)
    if not clean then return nil, reason end
    local chapters = ns.JournalChapters()
    if #chapters >= ns.JOURNAL_CHAPTER_LIMIT then return nil, "You can keep up to 40 chapters." end
    local serial = LocalID(ns.char.meta.chapterSerial) and ns.char.meta.chapterSerial or 0
    for _, chapter in ipairs(chapters) do serial = math.max(serial, ChapterSerial(chapter.id)) end
    if serial >= MAX_LOCAL_ID then return nil, "No more chapter IDs are available." end
    serial = serial + 1
    local id = "chapter:" .. string.format("%.0f", serial)
    chapters[#chapters + 1] = { id = id, name = clean, created = time() }
    ns.char.chapters, ns.char.meta.chapterSerial = chapters, serial
    ns.journalChapterRevision = (ns.journalChapterRevision or 0) + 1
    return id
end

function ns.RenameJournalChapter(id, name)
    local chapter = FindChapter(id)
    if not chapter then return false, "This chapter is no longer available." end
    local clean, reason = ChapterName(name)
    if not clean then return false, reason end
    chapter.name = clean
    ns.journalChapterRevision = (ns.journalChapterRevision or 0) + 1
    return true
end

function ns.DeleteJournalChapter(id)
    if not FindChapter(id) then return false, "This chapter is no longer available." end
    local chapters = ns.JournalChapters()
    for index, chapter in ipairs(chapters) do
        if chapter.id == id then table.remove(chapters, index); break end
    end
    for _, entry in ipairs(ns.char.journal or {}) do
        if entry.chapter == id then entry.chapter = nil end
    end
    ns.char.chapters = chapters
    ns.journalChapterRevision = (ns.journalChapterRevision or 0) + 1
    return true
end

function ns.JournalChapter(entry)
    if type(entry) == "table" and not S(entry) and FindChapter(entry.chapter) then return entry.chapter end
end

function ns.SetJournalChapter(entry, id)
    if not HasJournalEntry(entry) then return false, "This Journal entry is no longer available." end
    if id ~= nil and not FindChapter(id) then return false, "This chapter is no longer available." end
    entry.chapter = id
    ns.journalChapterRevision = (ns.journalChapterRevision or 0) + 1
    return true
end

local function ClosingName(value)
    return SafeStr(value) and #value <= 512 and not value:find("[%z\1-\31\127]") and value or nil
end

function ns.CopySessionClosing(value)
    local result = { zones = {}, bosses = {}, notes = 0, complete = false }
    if type(value) ~= "table" or S(value) then return result end
    result.complete = not S(value.complete) and value.complete == true
    for _, spec in ipairs({ { "zones", 40, "zoneOverflow" }, { "bosses", 20, "bossOverflow" } }) do
        local seen = {}
        local list = type(value[spec[1]]) == "table" and not S(value[spec[1]]) and value[spec[1]] or {}
        for index = 1, math.min(#list, spec[2]) do
            local name = list[index]
            if ClosingName(name) and not seen[name] then
                result[spec[1]][#result[spec[1]] + 1] = name
                seen[name] = true
            end
        end
        if #list > spec[2] or (not S(value[spec[3]]) and value[spec[3]] == true) then result[spec[3]] = true end
    end
    if not S(value.notes) and not ns.BadNumber(value.notes) and value.notes >= 0 and value.notes <= MAX_LOCAL_ID then
        result.notes = math.floor(value.notes)
    end
    return result
end

local function Closing()
    if not ns.session or not LocalID(ns.session.id) then return end
    if type(ns.session.closing) ~= "table" then ns.session.closing = ns.CopySessionClosing() end
    return ns.session.closing
end

local function ObserveClosingName(field, name, limit, overflow)
    local closing = Closing()
    name = ClosingName(name)
    if not closing then return end
    if not name or name == "?" then closing.complete = false; return end
    for _, observed in ipairs(closing[field]) do if observed == name then return end end
    if #closing[field] < limit then closing[field][#closing[field] + 1] = name
    else closing[overflow] = true end
end

local function NoteEdited(entry)
    local closing = Closing()
    if not closing or entry.noteSession == ns.session.id then return end
    entry.noteSession = ns.session.id
    closing.notes = closing.notes + 1
end

-- The tracker cache is a fallback only when the zone API is unavailable.
-- An unreadable API result can indicate a transition out of the cached zone.
function ns.GetJournalZone()
    if GetRealZoneText then
        local ok, value = pcall(GetRealZoneText)
        if ok then return ReadableZone(value) end
        return
    end
    if ns.GetZone then return ReadableZone(ns.GetZone()) end
end

-- Existing rows have only timestamp, text and level. Interpret the wording of
-- the old writers at read time, so opening the Journal never changes the save.
function ns.JournalEntryInfo(entry)
    if type(entry) ~= "table" or S(entry) then return end
    local kind = SafeStr(entry.kind)
    if entry.kind ~= nil or entry.zone ~= nil then
        if not JOURNAL_KINDS[kind] then kind = nil end
        return kind, ReadableZone(entry.zone)
    end
    local text = SafeStr(entry[2])
    if not text then return end
    local firstKey = firstLabels[text:match("^([^:]+): .+$") or text]
    if firstKey then return "first", nil, firstKey == "boss" and "boss" or nil end

    local zone = text:match("^Arrived in (.+) %(level %d+%)$")
    if zone then return "first", ReadableZone(zone) end
    if text:match("^Rested at .+ for the first time$") or text:match("^First ride on .+$") then return "first" end
    if text:match("^New personal record: .+$") then return "personalBest" end
    zone = text:match("^Reached level %d+ in (.+)$")
    if zone then return nil, ReadableZone(zone) end
    zone = text:match("^Died in (.+)$")
    if zone then return "death", ReadableZone(zone) end
    -- With multiple separators, a legacy killer name and a zone name cannot
    -- reliably be distinguished. Preserve the category and leave the zone blank.
    zone = text:match("^Died to .- in (.+)$")
    if zone then
        if not zone:find(" in ", 1, true) then return "death", ReadableZone(zone) end
        return "death"
    end
end

-- An explicit false location means the original event location was unreadable.
function ns.Journal(text, kind, eventZone)
    local ch = ns.char
    if not ch or not SafeStr(text) then return end
    local zone = eventZone
    if zone == nil then zone = ns.GetJournalZone() end
    local level = UnitLevel("player")
    if S(level) or type(level) ~= "number" then level = 0 end
    ch.journal = ch.journal or {}
    local j = ch.journal
    local entry = { time(), text, level, kind = kind, zone = ReadableZone(zone) }
    if ns.session and LocalID(ns.session.id) then entry.session = ns.session.id end
    j[#j + 1] = entry
    ObserveClosingName("zones", entry.zone, 40, "zoneOverflow")
    if kind == "boss" then ObserveClosingName("bosses", text:match("^Boss killed: (.+)$"), 20, "bossOverflow") end
    if #j > JOURNAL_CAP then if ns.Retention then ns.Retention.Mark(ns.char, "h", "journal") end; table.remove(j, 1) end
    -- Visible history refreshes on the window tick, coalescing event bursts.
end

function ns.JournalNote(entry)
    if type(entry) == "table" and not S(entry) then return SafeStr(entry.note) end
end

function ns.SetJournalNote(entry, text)
    -- Entries can be evicted while the editor is open. Timestamps and text
    -- can match another entry, so require the same row object.
    if not HasJournalEntry(entry) then return false, "This Journal entry is no longer available." end

    if text == nil then
        if entry.note ~= nil then entry.note = nil; NoteEdited(entry) end
        return true
    end
    if S(text) or type(text) ~= "string" then return false, "The note must be readable text." end
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\t", " ")
    if text:find("[%z\1-\8\11-\31\127]") then return false, "The note contains unsupported control characters." end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return false, "Enter a note, or use Remove note." end

    local tooLong = "Keep the note to " .. ns.JOURNAL_NOTE_LIMIT .. " characters or fewer."
    if #text > ns.JOURNAL_NOTE_LIMIT * 4 then return false, tooLong end
    -- WoW edit boxes provide UTF-8. Each code point has one byte outside the
    -- continuation range, regardless of how many bytes it occupies.
    local _, characters = text:gsub("[^\128-\191]", "")
    if characters > ns.JOURNAL_NOTE_LIMIT then return false, tooLong end
    if entry.note ~= text then entry.note = text; NoteEdited(entry) end
    return true
end

-- ------------------------------------------------------------ level snapshots
-- At each level-up: totals so far, so the Journal page can show life per level.
local SNAP_KEYS = { "dist_foot", "jumps", "kills_npc", "kills_pvp", "deaths", "quests_done", "money_in", "time_online", "critter_kills", "times_drunk" }
function ns.LevelSnapshot(level)
    local ch = ns.char
    if not ch then return end
    ch.lvlsnap = ch.lvlsnap or {}
    local s = { t = time() }
    for _, k in ipairs(SNAP_KEYS) do s[k] = ch.c[k] or 0 end
    if ns.LevelSnapshotExtra then pcall(ns.LevelSnapshotExtra, s) end
    ch.lvlsnap[tostring(level)] = s
    local zone = ns.GetJournalZone()
    ns.Journal("Reached level " .. tostring(level) .. " in " .. (zone or "?"), nil, zone or false)
end
-- Starting point for the level you were on when LifeTimeStats was installed (partial level).
function ns.LevelSnapshotQuiet(level, partial)
    local ch = ns.char
    if not ch then return end
    ch.lvlsnap = ch.lvlsnap or {}
    local s = { t = time(), partial = partial or nil }
    for _, k in ipairs(SNAP_KEYS) do s[k] = ch.c[k] or 0 end
    ch.lvlsnap[tostring(level)] = s
end

-- (damage meter reading lives in Meter.lua)

-- ------------------------------------------------------------ fights ended without a kill
local fightKills, inFight = 0, false
On("PLAYER_REGEN_DISABLED", function()
    inFight = true
    fightKills = (ns.char.c.kills_npc or 0) + (ns.char.c.kills_pvp or 0) + (ns.char.c.critter_kills or 0)
end)
On("PLAYER_REGEN_ENABLED", function()
    if not inFight then return end
    inFight = false
    local now = (ns.char.c.kills_npc or 0) + (ns.char.c.kills_pvp or 0) + (ns.char.c.critter_kills or 0)
    if now == fightKills and not B(UnitIsDeadOrGhost("player")) then Add("fights_no_kill") end
end)

-- ------------------------------------------------------------ inns and innkeepers
local function InnName()
    local sub = SafeStr(GetSubZoneText and GetSubZoneText())
    local z = SafeStr(GetRealZoneText and GetRealZoneText())
    if not z then return nil end
    local w = ns.Where and ns.Where()
    if w and w.city then return nil end -- capital cities are not inns
    return sub and (sub .. ", " .. z) or z, z
end
On("PLAYER_UPDATE_RESTING", function()
    if B(IsResting()) then
        local inn, zone = InnName()
        if inn then
            Add("inn_visits")
            if Unique("inns", inn) then
                First("inn", inn, zone)
                ns.Journal("Rested at " .. inn .. " for the first time", "first", zone)
            end
            Tally("innvisits", inn)
        end
    end
end)
On("GOSSIP_SHOW", function()
    if not C_GossipInfo or not C_GossipInfo.GetOptions then return end
    local ok, opts = pcall(C_GossipInfo.GetOptions)
    if not ok or type(opts) ~= "table" then return end
    for _, o in ipairs(opts) do
        local n = SafeStr(o.name)
        if n and (n:find("inn your home") or n:find("Make this inn")) then
            local g = SafeStr(UnitGUID("npc"))
            local id = g and g:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
            local who = SafeStr(UnitName("npc"))
            if id and Unique("innkeepers", id) and who then First("innkeeper", who) end
            return
        end
    end
end)

-- ------------------------------------------------------------ travel log: first visit of each zone
On("ZONE_CHANGED_NEW_AREA", function()
    local z = SafeStr(GetRealZoneText and GetRealZoneText())
    ObserveClosingName("zones", z, 40, "zoneOverflow")
    if not z or not ns.char then return end
    ns.char.zonelog = ns.char.zonelog or {}
    if not ns.char.zonelog[z] then
        ns.char.zonelog[z] = { time(), UnitLevel("player") or 0 }
        ns.travelLogRevision = (ns.travelLogRevision or 0) + 1
        ns.Journal("Arrived in " .. z .. " (level " .. (UnitLevel("player") or 0) .. ")", "first", z)
    end
end)

-- ------------------------------------------------------------ nature: herbs and fish per zone
On("LOOT_OPENED", function()
    if IsFishingLoot and B(IsFishingLoot()) then Tally("fishzones", Zone()) end
end)
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or S(spellID) then return end
    if spellID == 2366 or spellID == 2368 or spellID == 3570 then Tally("herbzones", Zone())
    elseif spellID == 2575 or spellID == 2576 or spellID == 3564 then Tally("orezones", Zone()) end
end)

-- ------------------------------------------------------------ mounts and pets
local lastCast, lastCastT = nil, 0
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or S(spellID) then return end
    local n = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    n = type(n) == "table" and n.name or (GetSpellInfo and GetSpellInfo(spellID))
    if SafeStr(n) then lastCast, lastCastT = n, GetTime() end
end)
local wasMounted = false
On("UNIT_PET", function(_, unit)
    if unit ~= "player" then return end
    local n = SafeStr(UnitName("pet"))
    if n and B(UnitExists("pet")) then
        Add("pets_summoned"); Tally("pets", n)
        if Unique("pets", n) then First("pet", n) end
    end
end)

-- ------------------------------------------------------------ food, drink, well fed, clothes, game time
local function HasAura(name)
    if not name then return false end
    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, found = pcall(AuraUtil.FindAuraByName, name, "player")
        if ok and found and not S(found) then return true end
        return false
    end
    if UnitBuff then
        for i = 1, 40 do
            local ok, n = pcall(UnitBuff, "player", i)
            if not ok or not n then break end
            if not S(n) and n == name then return true end
        end
    end
    return false
end

local fed, naked = false, false
local acc = 0
ns.Sampling.Register("story", 1, ns.Guard("story", function(_, el)
    acc = acc + el
    if acc < 1 then return end
    local dt = acc
    acc = 0
    if not ns.char or dt > 3 then return end
    -- mounts by name: the spell you cast just before you became mounted
    local m = B(IsMounted())
    if m and not wasMounted and lastCast and GetTime() - lastCastT < 4 then
        Tally("mounts", lastCast)
        if Unique("mounts", lastCast) then
            First("mountname", lastCast)
            ns.Journal("First ride on " .. lastCast, "first")
        end
    end
    wasMounted = m
    -- food and drink (out of combat only: auras can be hidden in combat)
    if not B(UnitAffectingCombat("player")) then
        if HasAura("Food") then Add("time_eating", dt) end
        if HasAura("Drink") then Add("time_drinking", dt) end
        local nowFed = HasAura("Well Fed")
        if nowFed and not fed then Add("well_fed"); First("wellfed", Zone()) end
        fed = nowFed
    end
    -- clothes: no chest item = naked
    if GetInventoryItemID then
        local ok, chest = pcall(GetInventoryItemID, "player", 5)
        if ok and not S(chest) then
            local isNaked = chest == nil
            if isNaked then Add("time_naked", dt) end
            if isNaked and not naked then Add("times_naked") end
            naked = isNaked
        end
    end
    -- game time per hour
    if GetGameTime then
        local h = GetGameTime()
        if type(h) == "number" and not S(h) then Tally("gamehour", string.format("%02d:00", h), dt) end
    end
end))

On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    local zone = ns.GetJournalZone()
    if zone then ObserveClosingName("zones", zone, 40, "zoneOverflow")
    else
        local closing = Closing()
        if closing then closing.complete = false end
    end
    if not isLogin or not GetGameTime then return end
    local h = GetGameTime()
    if type(h) ~= "number" or S(h) then return end
    if h >= 5 and h < 8 then Add("logins_dawn") elseif h >= 18 and h < 21 then Add("logins_dusk") end
end)

-- ------------------------------------------------------------ humiliating deaths
function ns.OnStoryDeath(cause, eventZone)
    if B(UnitExists("target")) and B(UnitCanAttack("player", "target")) and not B(UnitIsPlayer("target")) then
        local lvl, my = UnitLevel("target"), UnitLevel("player")
        if type(lvl) == "number" and type(my) == "number" and not S(lvl) and not S(my) and lvl > 0 and lvl <= my - 5 then
            Add("deaths_lowbie")
            Tally("lowbiekillers", SafeStr(UnitName("target")) or "?")
        end
    end
    local zone = ReadableZone(eventZone)
    ns.Journal("Died" .. (cause and cause ~= "Unknown" and (" to " .. cause) or "") .. " in " .. (zone or "?"),
        "death", zone or false)
end

-- ------------------------------------------------------------ titles
-- Earned from achievements; pick one in settings or with /lts title.
ns.TITLES = {
    { id = "barfly",   text = "the Barfly",          ach = "drunk",      tier = 2 },
    { id = "smashed",  text = "the Completely Smashed", ach = "smashed", tier = 1 },
    { id = "wanderer", text = "the Wanderer",        ach = "wild",       tier = 2 },
    { id = "camper",   text = "the Sleeper Rough",   ach = "camp",       tier = 2 },
    { id = "fire",     text = "Firestarter",         ach = "fire",       tier = 2, prefix = true },
    { id = "bookworm", text = "the Learned",         ach = "books",      tier = 2 },
    { id = "critter",  text = "the Critter Whisperer", ach = "critterlove", tier = 2 },
    { id = "monster",  text = "the Monster",         ach = "critterkill", tier = 2 },
    { id = "slayer",   text = "the Slayer",          ach = "kills",      tier = 2 },
    { id = "giant",    text = "Giantslayer",         ach = "giant",      tier = 1, prefix = true },
    { id = "rare",     text = "the Rare Hunter",     ach = "rares",      tier = 2 },
    { id = "mortal",   text = "the Mortal",          ach = "deaths",     tier = 2 },
    { id = "gravity",  text = "the Grounded",        ach = "gravity",    tier = 2 },
    { id = "hopper",   text = "the Bunny",           ach = "jumps",      tier = 2 },
    { id = "walker",   text = "the Long Walker",     ach = "steps",      tier = 3 },
    { id = "hearth",   text = "of Many Hearths",     ach = "bindspots",  tier = 2 },
    { id = "fashion",  text = "the Fashionable",     ach = "fashion",    tier = 2 },
    { id = "night",    text = "the Night Owl",       ach = "nightowl",   tier = 1 },
    { id = "conjurer", text = "the Conjurer",        ach = "conjure",    tier = 2 },
    { id = "gambler",  text = "the Gambler",         ach = "rolls",      tier = 2 },
}
function ns.TitleEarned(t)
    local ach = ns.char and ns.char.ach
    return ach and ach[t.ach .. ":" .. t.tier] ~= nil
end
function ns.EarnedTitles()
    local out = {}
    for _, t in ipairs(ns.TITLES) do if ns.TitleEarned(t) then out[#out + 1] = t end end
    return out
end
function ns.TitledName()
    local name = UnitName("player") or ""
    local id = ns.settings and ns.settings.title
    if not id then return name end
    for _, t in ipairs(ns.TITLES) do
        if t.id == id and ns.TitleEarned(t) then
            return t.prefix and (t.text .. " " .. name) or (name .. " " .. t.text)
        end
    end
    return name
end
function ns.CycleTitle(dir)
    local list = ns.EarnedTitles()
    if #list == 0 then ns.settings.title = nil; return nil end
    local cur = ns.settings.title
    local idx = 0
    for i, t in ipairs(list) do if t.id == cur then idx = i end end
    idx = (idx + (dir or 1)) % (#list + 1)   -- 0 = no title
    if idx == 0 then ns.settings.title = nil else ns.settings.title = list[idx].id end
    return ns.settings.title
end

-- ------------------------------------------------------------ character sheet
function ns.CharacterSheet()
    local v = ns.char
    local c = v.c
    local I = ns.FormatInt
    local function n(k) return I(c[k] or 0) end
    local L = {}
    local function add(s) L[#L + 1] = s end
    local _, class = UnitClass("player")
    add(string.format("== %s ==", ns.TitledName()))
    add(string.format("Level %d %s %s · %s", UnitLevel("player") or 0, UnitRace and (UnitRace("player")) or "", UnitClass("player") or "", GetRealmName() or ""))
    add(string.format("Counting since %s · %s played", date("%b %d, %Y", v.meta.created or time()), ns.FormatTime(c.played_server or 0)))
    add("")
    add("-- Travels --")
    add(string.format("Steps %s · jumps %s · distance %s yd · flight paths found %s · hearth locations %s",
        I(ns.Steps(v)), n("jumps"), n("dist_total"), n("flightpaths_found"), I((v.un.bindspots) or 0)))
    add("-- Battles --")
    add(string.format("Kills %s (players %s, rares %s, elites %s) · critters %s · deaths %s · corpse runs %s",
        I(ns.Kills(v)), n("kills_pvp"), n("kills_rare"), n("kills_elite"), n("critter_kills"), n("deaths"), n("corpse_runs")))
    add("-- Life --")
    add(string.format("Times drunk %s · campfires %s · nights camped %s · books read %s · potions %s · critters loved %s",
        n("times_drunk"), n("campfires"), n("nights_camped"), n("books_read"), n("potions"), n("critters_loved")))
    add("-- Deeds --")
    add(string.format("Quests %s · dungeon bosses %s · raid bosses %s · gold earned %s",
        n("quests_done"), n("boss_kills_party"), n("boss_kills_raid"), (ns.FormatMoney(c.money_in or 0):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))))
    local e, t, pts = ns.AchTotals(v)
    add(string.format("Achievements %d of %d · %s points", e, t, I(pts)))
    add("")
    add("-- Recent journal --")
    local j = v.journal or {}
    for i = math.max(1, #j - 7), #j do add(date("%b %d", j[i][1]) .. "  " .. j[i][2]) end
    add("")
    add("LifeTimeStats " .. ns.VERSION)
    return table.concat(L, "\n")
end

-- 1.9.3: melee was stored as "Attack"; fold it into "Melee".
On("PLAYER_ENTERING_WORLD", function()
    if not ns.char or not ns.char.t then return end
    for _, id in ipairs({ "spelldamage", "hurtbyspell" }) do
        local t = ns.char.t[id]
        if t and t.Attack then t.Melee = (t.Melee or 0) + t.Attack; t.Attack = nil end
    end
end)

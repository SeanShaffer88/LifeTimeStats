-- LifeTimeStats - Core
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local ADDON, ns = ...

ns.ADDON = ADDON
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.VERSION = (GetMeta and GetMeta(ADDON, "Version")) or "1.0.0"
ns.SCHEMA = 1

-- Odometer theme
ns.THEME = {
    bg      = { 0x17 / 255, 0x19 / 255, 0x1c / 255, 0.97 },
    tile    = { 0x24 / 255, 0x27 / 255, 0x2b / 255, 1 },
    tileHi  = { 0x2e / 255, 0x32 / 255, 0x37 / 255, 1 },
    edge    = { 0x33 / 255, 0x36 / 255, 0x3b / 255, 1 },
    text    = { 0xef / 255, 0xe6 / 255, 0xd2 / 255, 1 },
    dim     = { 0x9b / 255, 0x94 / 255, 0x86 / 255, 1 },
    amber   = { 1, 0xb2 / 255, 0x38 / 255, 1 },
}
ns.GOLD  = "|cffffb238" -- amber accent (name kept for brevity)
ns.GREEN = "|cffefe6d2" -- cream highlight
ns.GREY  = "|cff9b9486"

local DEFAULTS = {
    minimap      = { hide = false, angle = 215 },
    window       = { point = "CENTER", x = 0, y = 0 },
    showSession  = true,
    lockWindow   = false,
    classColor   = true,
    recap        = true,
    recapWindow  = true,
    deathPins    = true,
    itemTooltips = true,
    achAnnounce  = "off", -- off | chat | toast | both
    countPet     = true,
    milestones   = false,
    recordMoments = true,
    lastCategory = "dashboard",
    scope        = "char",
    range        = "lifetime",
    theme        = "auto",
    levelMsg     = true,
    tooltipKills = true,
    shotLevel    = false,
    shotBoss     = false,
    shotAch      = false,
}

ns.events = {}

-- Forever (Midnight rules) hands addons "secret values" for some data, mostly inside
-- instances. They can be passed around but not read; touching them raises an error.
function ns.IsSecret(v)
    local f = issecretvalue
    return f ~= nil and v ~= nil and f(v) and true or false
end

-- Secret-safe true/false: a hidden boolean counts as false instead of raising an error.
function ns.Bool(v)
    if ns.IsSecret(v) then
        ns.src.secretBool = (ns.src.secretBool or 0) + 1
        return false
    end
    return v and true or false
end

-- Wraps per-frame scripts so one unreadable value can never spam errors or stop tracking.
function ns.Guard(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then ns.LogError(name, err) end
    end
end

-- Which data sources have been seen this session (for /lts debug).
ns.src = {}
local frame = CreateFrame("Frame")
ns.frame = frame
frame:SetScript("OnEvent", function(_, event, ...)
    local list = ns.events[event]
    if not list then return end
    if not ns.char and event ~= "ADDON_LOADED" then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then ns.LogError(event, err) end
    end
end)

-- Forever (Midnight rules) forbids addons from even registering the combat log event:
-- doing so raises ADDON_ACTION_FORBIDDEN. Skip it whenever the client uses those rules.
local RESTRICTED = { COMBAT_LOG_EVENT_UNFILTERED = true, COMBAT_LOG_EVENT = true }
function ns.CombatLogRestricted()
    return (C_CombatLogSecure ~= nil) or (issecretvalue ~= nil) or (type(CombatLogGetCurrentEventInfo) ~= "function")
end
function ns.ShouldRegister(event)
    if RESTRICTED[event] and ns.CombatLogRestricted() then return false end
    return true
end

ns.eventStatus = {}
function ns.On(event, fn)
    local list = ns.events[event]
    if not list then
        list = {}
        ns.events[event] = list
        -- Some events may not exist on every client build; never let that break load.
        if ns.ShouldRegister(event) then
            local ok, result = pcall(frame.RegisterEvent, frame, event)
            ns.eventStatus[event] = ok and result ~= false and "registered" or "rejected"
        else
            ns.eventStatus[event] = "restricted"
        end
    end
    list[#list + 1] = fn
end

-- Forever hides Lua errors; keep the last few so /lts errors can show them.
ns.errors = {}
local lastErr, lastErrCount = nil, 0
function ns.LogError(where, err)
    local e = ns.errors
    local msg = tostring(where) .. ": " .. (ns.IsSecret(err) and "unreadable error" or tostring(err))
    if #msg > 2048 then msg = msg:sub(1, 2048) .. "…" end
    if msg == lastErr then
        lastErrCount = lastErrCount + 1
        e[#e] = date("%H:%M:%S") .. " " .. msg .. " (x" .. lastErrCount .. ")"
        return
    end
    lastErr, lastErrCount = msg, 1
    e[#e + 1] = date("%H:%M:%S") .. " " .. msg
    if #e > 30 then table.remove(e, 1) end
end

function ns.Print(msg)
    if ns.capture then ns.capture[#ns.capture + 1] = tostring(msg) return end
    DEFAULT_CHAT_FRAME:AddMessage(ns.GOLD .. "LifeTimeStats|r: " .. tostring(msg))
end

-- Run fn and show what it prints in a copyable text window (falls back to chat).
function ns.PrintToWindow(title, hint, fn)
    ns.capture = {}
    local ok, err = pcall(fn)
    local lines = ns.capture
    ns.capture = nil
    if not ok then lines[#lines + 1] = "Error: " .. tostring(err) end
    local text = table.concat(lines, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if ns.ShowText then ns.ShowText(title, hint, text)
    else for _, l in ipairs(lines) do ns.Print(l) end end
end

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local SECTIONS = { "c", "r", "t", "u", "un", "f", "fw", "fd", "first", "firstd", "days", "months", "qa", "ach", "achr", "journal", "lvlsnap", "zonelog", "rh", "runlog", "bestiary", "people", "reps", "items", "goals", "quests", "skills", "deathlog" }

local function NewCharRecord()
    local rec = { meta = { rev = 0, created = time() }, run = nil }
    for _, k in ipairs(SECTIONS) do rec[k] = {} end
    -- c counters · r records (max) · t tallies · u unique sets · un unique counts
    -- f fastest (min) · fw/fd label/date · first/firstd firsts · days daily counters · months monthly totals of pruned days · qa quest accept times · rh record history
    return rec
end
ns.NewCharRecord = NewCharRecord

local function Valid(rec)
    return type(rec) == "table" and type(rec.meta) == "table" and type(rec.c) == "table"
        and type(rec.r) == "table" and type(rec.t) == "table"
end
ns.ValidRecord = Valid

-- LTS1/LTS2 backup paths have always represented unique IDs as text.
function ns.UniqueKey(key)
    if type(key) == "number" then return tostring(key) end
    return key
end

-- Upgrades a 1.0 record in place and recounts unique sets.
local function Ensure(rec)
    for _, k in ipairs(SECTIONS) do
        if type(rec[k]) ~= "table" then rec[k] = {} end
    end
    for set in pairs(rec.un) do
        if type(rec.u[set]) ~= "table" then rec.un[set] = nil end
    end
    for set, t in pairs(rec.u) do
        if type(set) ~= "string" or set == "" or type(t) ~= "table" then
            rec.u[set], rec.un[set] = nil, nil
        else
            local n, numeric = 0, nil
            for key, value in pairs(t) do
                local kind = type(key)
                if not value or (kind ~= "string" and kind ~= "number") or key == ""
                    or (kind == "number" and (key == math.huge or key == -math.huge)) then
                    t[key] = nil
                elseif kind == "number" then
                    numeric = numeric or {}
                    numeric[#numeric + 1] = key
                else
                    n = n + 1
                end
            end
            if numeric then
                for _, key in ipairs(numeric) do
                    local canonical = ns.UniqueKey(key)
                    if t[canonical] == nil then n = n + 1 end
                    t[key], t[canonical] = nil, true
                end
            end
            rec.un[set] = n
        end
    end
    return rec
end
ns.EnsureRecord = Ensure

local function NewSession(rec)
    local id
    local closing = { zones = {}, bosses = {}, notes = 0, complete = rec ~= nil }
    if rec then
        local serial = rec.meta.sessionSerial
        id = (ns.BadNumber(serial) and 0 or serial) + 1
        rec.meta.sessionSerial = id
        local zone = ns.GetJournalZone and ns.GetJournalZone()
        if zone then closing.zones[1] = zone else closing.complete = false end
    end
    return { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, rh = {},
        id = id, start = GetTime(), wallStart = time(),
        closing = closing }
end
ns.session = NewSession()

local MAX_REVISION = 9007199254740990
local function Revision(value)
    if value == nil then return 0 end
    if type(value) == "number" and value >= 0 and value <= MAX_REVISION and value == math.floor(value) then
        return value
    end
end

local function RecoveryCandidate(rec, name, realm)
    if not Valid(rec) or not Revision(rec.meta.rev) then return false end
    if rec.meta.name and name and rec.meta.name ~= name then return false end
    if rec.meta.realm and rec.meta.realm ~= realm then return false end
    for bucketName, bucket in pairs(rec.t) do
        if type(bucket) ~= "table" then return false end
        for _, n in pairs(bucket) do
            if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then return false end
        end
    end
    return true
end

-- Keep one detached generation of the record that successfully loaded, not a
-- second reference to the live table. This budget bounds the additional copy;
-- it is an estimate, not the size of WoW's serialized file.
local RECOVERY_BYTES, RECOVERY_NODES = 2 * 1024 * 1024, 50000
local function CopyRecoveryRecord(rec)
    local bytes, nodes, active = 0, 0, {}
    local function Copy(value, depth)
        local kind = type(value)
        if kind == "string" or kind == "number" or kind == "boolean" then return value end
        if kind ~= "table" or depth > 12 or active[value] or getmetatable(value) then error("invalid recovery data", 0) end
        active[value] = true
        local result = {}
        for key, item in pairs(value) do
            local kt = type(key)
            if kt ~= "string" and kt ~= "number" and kt ~= "boolean" then error("invalid recovery key", 0) end
            nodes = nodes + 1
            bytes = bytes + 24 + (kt == "string" and #key or 0) + (type(item) == "string" and #item or 0)
            if bytes > RECOVERY_BYTES or nodes > RECOVERY_NODES then error("recovery budget exceeded", 0) end
            result[key] = Copy(item, depth + 1)
        end
        active[value] = nil
        return result
    end
    local ok, copy = pcall(Copy, rec, 0)
    if ok then return copy end
end

function ns.InitDB()
    if type(LifeTimeStatsDB) ~= "table" then LifeTimeStatsDB = {} end
    local db = LifeTimeStatsDB
    local schema = db.schema
    if type(schema) == "number" and schema > 3 then
        ns.Print("This save was written by a newer LifeTimeStats version. Install that version to use it.")
        return
    end
    if type(db.settings) ~= "table" then db.settings = {} end
    CopyDefaults(DEFAULTS, db.settings)
    if type(db.chars) ~= "table" then db.chars = {} end
    ns.db, ns.settings = db, db.settings

    local name = UnitName("player")
    local realm = GetRealmName() or "?"
    ns.charKey = realm .. "-" .. (name or "?")

    -- Two copies are kept (account file + per-character file). Whichever has the
    -- higher revision wins, so a single lost/unloaded SavedVariables file does
    -- not wipe lifetime totals.
    local primary = db.chars[ns.charKey]
    local backup = type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB.data or nil
    ns.restoredFromBackup = nil
    if not RecoveryCandidate(primary, name, realm) then primary = nil end
    if not RecoveryCandidate(backup, name, realm) then backup = nil end
    local rec
    if primary and backup then
        rec = (Revision(backup.meta.rev) > Revision(primary.meta.rev)) and backup or primary
        if rec == backup and rec ~= primary then ns.restoredFromBackup = true end
    else
        rec = primary or backup
        if rec == backup and backup then ns.restoredFromBackup = true end
    end
    local charDB = type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB or {}
    local previous = charDB.previousGood
    if not rec and RecoveryCandidate(previous, name, realm) then
        rec = CopyRecoveryRecord(previous)
        if rec then ns.restoredFromBackup = true end
    end
    local isNew = rec == nil
    if rec then
        local generation = CopyRecoveryRecord(rec)
        if generation then charDB.previousGood = generation end
    else
        rec = NewCharRecord()
    end
    Ensure(rec)
    if ns.Measurement then ns.Measurement.Initialize(rec, isNew) end
    if ns.Retention then ns.Retention.Repair(rec) end
    for _, other in pairs(db.chars) do if Valid(other) then
        Ensure(other)
        if ns.Retention then ns.Retention.Repair(other) end
    end end
    db.chars[ns.charKey] = rec
    LifeTimeStatsCharDB = charDB
    LifeTimeStatsCharDB.data = rec

    -- Session survives /reload: restored here, reset on a real login (PLAYER_ENTERING_WORLD isLogin).
    local saved = LifeTimeStatsCharDB.session
    if type(saved) == "table" and type(saved.c) == "table" and not ns.BadNumber(saved.savedAt) then
        local sess = NewSession()
        for k in pairs(sess) do if type(saved[k]) == "table" then sess[k] = saved[k] end end
        sess.closing = ns.CopySessionClosing(saved.closing)
        local elapsed = ns.BadNumber(saved.elapsed) and 0 or math.max(0, saved.elapsed)
        sess.start = GetTime() - elapsed
        sess.wallStart = ns.BadNumber(saved.wallStart) and math.floor(saved.savedAt - elapsed) or saved.wallStart
        if not ns.BadNumber(saved.id) and saved.id > 0 then
            sess.id = saved.id
            local serial = rec.meta.sessionSerial
            if ns.BadNumber(serial) or serial < sess.id then rec.meta.sessionSerial = sess.id end
        else
            sess.id = NewSession(rec).id
            local log = rec.sessionlog
            local entry = type(log) == "table" and log[#log]
            if type(entry) == "table" and entry.id == nil and entry.s == sess.wallStart then entry.id = sess.id end
        end
        ns.session = sess
        ns.savedFightCorrelation = saved.fightCorrelation
    else
        ns.session = NewSession(rec)
        ns.savedFightCorrelation = nil
    end
    LifeTimeStatsCharDB.session = nil

    local meta = rec.meta
    meta.name = name
    meta.realm = realm
    local _, class = UnitClass("player")
    meta.class = class
    meta.level = UnitLevel("player")
    meta.created = meta.created or time()
    ns.char = rec
    db.schema = 3
    ns.InvalidateAccount()
end

local function RecapText(c, elapsed, top)
    local function n(k) return ns.FormatInt(c[k] or 0) end
    local s = string.format("%s steps · %s kills · %s deaths · %s quests · %s XP",
        ns.FormatInt((c.dist_foot or 0) * (ns.YARDS_TO_STEPS or 1.22)), ns.FormatInt((c.kills_npc or 0) + (c.kills_pvp or 0)),
        n("deaths"), n("quests_done"), n("xp"))
    if (c.dmg_done or 0) > 0 then s = s .. " · " .. n("dmg_done") .. " damage" end
    if (c.heal_done or 0) > 0 then s = s .. " · " .. n("heal_done") .. " healing" end
    if top then s = s .. " · top spell " .. top end
    return s .. " · " .. ns.FormatTime(elapsed or c.time_online or 0)
end
local function SessionTopSpell()
    local t = ns.session and ns.session.t and ns.session.t.spelldamage
    local best, bv
    if t then for k, v in pairs(t) do if not bv or v > bv then best, bv = k, v end end end
    return best
end
ns.SessionTopSpell = SessionTopSpell
ns.RecapText = RecapText

function ns.Save()
    if not ns.char then return end
    ns.char.meta.rev = math.min(MAX_REVISION, (Revision(ns.char.meta.rev) or 0) + 1)
    ns.char.meta.saved = time()
    ns.char.meta.level = UnitLevel("player")
    if type(LifeTimeStatsCharDB) ~= "table" then return end
    local db, session = LifeTimeStatsCharDB, ns.session
    local elapsed, savedAt = GetTime() - session.start, time()
    db.data = ns.char
    db.session = { c = session.c, r = session.r, t = session.t, u = session.u, un = session.un,
        f = session.f, fw = session.fw, fd = session.fd, first = session.first, firstd = session.firstd,
        rh = session.rh, id = session.id, wallStart = session.wallStart, elapsed = elapsed, savedAt = savedAt,
        closing = ns.CopySessionClosing(session.closing) }
    if ns.SaveFightCorrelation then
        local ok, value = pcall(ns.SaveFightCorrelation)
        if ok then db.session.fightCorrelation = value else ns.LogError("save:fight correlation", value) end
    end
    local ok, recap = pcall(function()
        return { c = session.c, elapsed = elapsed, at = savedAt, top = SessionTopSpell(),
            highlights = ns.SessionRecordHighlights and ns.SessionRecordHighlights(session.rh, 3) or {},
            closing = ns.CopySessionClosing(session.closing) }
    end)
    if ok then db.lastSession = recap
    else db.lastSession = nil; ns.LogError("save:recap", recap) end
end

-- ---------------------------------------------------------------- accent colour
-- Replaces the amber accent with the player's class colour (in place, so every
-- widget that holds a reference to THEME.amber picks it up). Needs /reload to undo.
function ns.ApplyAccent()
    if not ns.settings.classColor then return end
    local _, class = UnitClass("player")
    local cc = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if not cc or not cc.r then return end
    local r, g, b = cc.r, cc.g, cc.b
    -- Very light class colours (Priest) would blend with cream text: tint them slightly darker.
    if r + g + b > 2.6 then r, g, b = r * 0.82, g * 0.82, b * 0.82 end
    -- On the notebook's paper, class colours are inked: darker so they read like ink.
    if ns.Paper and ns.Paper() and ns.W and ns.W.InkRGB then r, g, b = ns.W.InkRGB(r, g, b) end
    local a = ns.THEME.amber
    a[1], a[2], a[3] = r, g, b
    ns.accent2 = { r * 0.78, g * 0.78, b * 0.78, 1 }
    ns.GOLD = string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

-- ---------------------------------------------------------------- day key
local todayKey, nextDayCheck = nil, 0
function ns.Today()
    local now = GetTime()
    if not todayKey or now >= nextDayCheck then
        todayKey = date("%Y%m%d")
        nextDayCheck = now + 20
    end
    return todayKey
end

-- ---------------------------------------------------------------- counters
local milestoneSteps = { 100, 1000, 10000, 100000, 1000000, 10000000 }

local HUGE = math.huge
local function Bad(n) return type(n) ~= "number" or n ~= n or n == HUGE or n == -HUGE end
ns.BadNumber = Bad

-- Keep only recent, validated record breakthroughs. The history is local to
-- the character/session and never contains arbitrary API objects or secret data.
local HISTORY_CAP = 200
ns.RECORD_HISTORY_CAP = HISTORY_CAP
local movementMilestones = setmetatable({}, { __mode = "k" })
local baseEnsureRecord = ns.EnsureRecord
function ns.EnsureRecord(rec)
    baseEnsureRecord(rec)
    local clean = {}
    for i = math.max(1, #(rec.rh or {}) - HISTORY_CAP + 1), #(rec.rh or {}) do
        local e = rec.rh[i]
        if type(e) == "table" and not ns.IsSecret(e) and type(e.k) == "string" and e.k ~= ""
            and type(e.v) == "number" and not Bad(e.v)
            and type(e.at) == "number" and not Bad(e.at)
            and (e.d == "max" or e.d == "min") then
            clean[#clean + 1] = {
                k = e.k, v = e.v, at = e.at, d = e.d,
                w = type(e.w) == "string" and e.w:sub(1, 100) or nil,
            }
        end
    end
    rec.rh = clean
    return rec
end

local function MovementMilestone(history, key, value)
    local minStep
    if key:match("^ex_longest_") then minStep = 10
    elseif key:match("^ex_farthest_") then minStep = 50 end
    if not minStep then return true end
    local anchors = movementMilestones[history]
    if not anchors then
        anchors = {}
        for _, entry in ipairs(history) do
            if type(entry) == "table" and entry.d == "max" and type(entry.k) == "string" and not Bad(entry.v) then
                anchors[entry.k] = math.max(anchors[entry.k] or 0, entry.v)
            end
        end
        movementMilestones[history] = anchors
    end
    local previous = anchors[key] or 0
    if value - previous < math.max(minStep, previous * 0.05) then return false end
    anchors[key] = value
    return true
end

function ns.AddRecordHistory(rec, key, value, label, direction)
    if not rec or type(key) ~= "string" or ns.IsSecret(value) or Bad(value)
        or (direction ~= "max" and direction ~= "min") then return end
    if type(rec.rh) ~= "table" then rec.rh = {} end
    local at = time()
    if ns.IsSecret(at) or Bad(at) then return end
    if direction == "max" and not MovementMilestone(rec.rh, key, value) then return end
    local event = { k = key, v = value, at = at, d = direction }
    if not ns.IsSecret(label) and type(label) == "string" and label ~= "" then event.w = label:sub(1, 100) end
    local log = rec.rh
    log[#log + 1] = event
    while #log > HISTORY_CAP do
        if ns.Retention then ns.Retention.Mark(rec, "h", "rh") end
        table.remove(log, 1)
    end
    return event
end

local function StatKey(key)
    return type(key) == "string" and not ns.IsSecret(key) and key ~= ""
end

local function CounterValue(value)
    return not ns.IsSecret(value) and not Bad(value) and value or 0
end

function ns.Add(key, n)
    n = n or 1
    local ch = ns.char
    if not ch or not StatKey(key) or ns.IsSecret(n) or n == 0 or Bad(n) then return end
    local old = CounterValue(ch.c[key])
    local new = old + n
    local s = ns.session.c
    local d = ns.Today()
    local day = ch.days[d]
    local sessionValue = CounterValue(s[key]) + n
    local dayValue = CounterValue(type(day) == "table" and day[key]) + n
    if Bad(new) or Bad(sessionValue) or Bad(dayValue) then return end
    if type(day) ~= "table" then day = {}; ch.days[d] = day end
    ch.c[key], s[key], day[key] = new, sessionValue, dayValue
    if ns.settings.milestones and ns.milestoneKeys and ns.milestoneKeys[key] then
        for i = 1, #milestoneSteps do
            local m = milestoneSteps[i]
            if old < m and new >= m then
                ns.Print(ns.milestoneKeys[key] .. ": " .. ns.GREEN .. BreakUpLargeNumbers(m) .. "|r!")
            end
        end
    end
end

-- ns.quietRecords: the value still updates, but no history entry or Journal moment is made.
-- Used while a running interval grows, so one long stretch is one record, not one every 10 s.
function ns.Max(key, v, label)
    if not ns.char or not StatKey(key) or ns.IsSecret(v) or Bad(v) then return end
    if ns.IsSecret(label) then label = nil end
    local r = ns.char.r
    local improved = false
    if v > CounterValue(r[key]) then
        r[key] = v
        improved = true
        r[key .. "_what"] = label and tostring(label) or nil
        if not ns.quietRecords then
            local event = ns.AddRecordHistory(ns.char, key, v, label, "max")
            if event and ns.RecordMoment then pcall(ns.RecordMoment, event) end
        end
    end
    local s = ns.session.r
    if v > CounterValue(s[key]) then
        s[key] = v
        s[key .. "_what"] = label and tostring(label) or nil
        if not ns.quietRecords then ns.AddRecordHistory(ns.session, key, v, label, "max") end
    end
    return improved
end

-- Fastest / shortest records: lower is better.
function ns.Min(key, v, label)
    if not ns.char or not StatKey(key) or ns.IsSecret(v) or Bad(v) or v <= 0 then return end
    if ns.IsSecret(label) then label = nil end
    local lifetime, session = ns.char, ns.session
    local cur = lifetime.f[key]
    if CounterValue(cur) <= 0 or v < cur then
        lifetime.f[key] = v
        lifetime.fw[key] = label and tostring(label) or nil
        lifetime.fd[key] = time()
        local event = ns.AddRecordHistory(lifetime, key, v, label, "min")
        if event and ns.RecordMoment then pcall(ns.RecordMoment, event) end
    end
    cur = session.f[key]
    if CounterValue(cur) <= 0 or v < cur then
        session.f[key] = v
        session.fw[key] = label and tostring(label) or nil
        session.fd[key] = time()
        ns.AddRecordHistory(session, key, v, label, "min")
    end
end

function ns.First(key, label, eventZone)
    if not ns.char or not StatKey(key) then return end
    if ns.IsSecret(label) then label = nil end
    local ch = ns.char
    if ch.first[key] then return end
    ch.first[key] = label and tostring(label) or "yes"
    ch.firstd[key] = time()
    if ns.Journal and ns.FIRST_LABEL then
        local lbl = ns.FIRST_LABEL[key]
        if lbl then ns.Journal(lbl .. ((label and label ~= "yes") and (": " .. tostring(label)) or ""), "first", eventZone) end
    end
end

-- Unique sets: returns true when the key is new. Each set stops growing at
-- UNIQUE_CAP entries to keep SavedVariables small (count then stays at the cap).
local UNIQUE_CAP = 20000
ns.UNIQUE_CAP = UNIQUE_CAP
function ns.Unique(set, key)
    if not ns.char or not StatKey(set) or ns.IsSecret(key) then return false end
    if not StatKey(key) and Bad(key) then return false end
    key = ns.UniqueKey(key)
    local ch = ns.char
    local u = ch.u[set]
    if type(u) ~= "table" then u = {}; ch.u[set], ch.un[set] = u, 0 end
    if u[key] then return false end
    if CounterValue(ch.un[set]) >= UNIQUE_CAP then
        if ns.Retention then ns.Retention.Mark(ch, "u", set) end
        return false
    end
    u[key] = true
    ch.un[set] = CounterValue(ch.un[set]) + 1
    local s = ns.session
    s.un[set] = CounterValue(s.un[set]) + 1
    return true
end

local TALLY_CAP, DAY_KEEP = 400, 40
local tallySizes = setmetatable({}, { __mode = "k" })

local tallyVersions = setmetatable({}, { __mode = "k" })
local tallyMembership = setmetatable({}, { __mode = "k" })
function ns.TallyVersion(bucket)
    return bucket and tallyVersions[bucket] or 0
end

function ns.TallyMembershipVersion(bucket)
    return bucket and tallyMembership[bucket] or 0
end

function ns.MarkTallyChanged(bucket, membershipChanged)
    tallyVersions[bucket] = (tallyVersions[bucket] or 0) + 1
    if membershipChanged then tallyMembership[bucket] = (tallyMembership[bucket] or 0) + 1 end
end

local function AddTally(bucket, name, n, record, bucketName)
    local isNew = bucket[name] == nil
    if isNew then
        local size = tallySizes[bucket]
        if not size then
            size = 0
            for _ in pairs(bucket) do size = size + 1 end
        end
        if size >= TALLY_CAP then
            tallySizes[bucket] = size
            if ns.Retention then ns.Retention.Mark(record, "t", bucketName) end
            return
        end
        tallySizes[bucket] = size + 1
    end
    local value = CounterValue(bucket[name]) + n
    if not Bad(value) and bucket[name] ~= value then
        bucket[name] = value
        ns.MarkTallyChanged(bucket, isNew)
    end
end

function ns.Tally(tbl, name, n)
    if not ns.char or not StatKey(tbl) or ns.IsSecret(name) or ns.IsSecret(n) then return end
    if not StatKey(name) and Bad(name) then return end
    n = n or 1
    if Bad(n) then return end
    local t = ns.char.t[tbl]
    if type(t) ~= "table" then t = {}; ns.char.t[tbl] = t end
    AddTally(t, name, n, ns.char, tbl)
    local st = ns.session.t[tbl]
    if type(st) ~= "table" then st = {}; ns.session.t[tbl] = st end
    AddTally(st, name, n, ns.session, tbl)
end

-- Keep day history bounded (performance + SavedVariables size).
ns.DAY_KEEP = DAY_KEEP

-- Days older than the newest DAY_KEEP are folded into monthly totals instead of being
-- deleted, so long-term history survives. meta.monthsThrough remembers the newest day
-- already folded: a day that comes back later (from a backup) is dropped, not counted twice.
function ns.RollUpDays(rec)
    if type(rec.days) ~= "table" then rec.days = {} end
    if type(rec.months) ~= "table" then rec.months = {} end
    rec.meta = type(rec.meta) == "table" and rec.meta or {}
    local through = type(rec.meta.monthsThrough) == "string" and rec.meta.monthsThrough or ""
    local keys = {}
    for k, day in pairs(rec.days) do
        if type(k) ~= "string" or not k:match("^%d%d%d%d%d%d%d%d$") or type(day) ~= "table" then
            rec.days[k] = nil
        elseif k <= through then
            rec.days[k] = nil -- already part of a monthly total
        else
            keys[#keys + 1] = k
        end
    end
    if #keys <= DAY_KEEP then return 0 end
    table.sort(keys)
    local folded = #keys - DAY_KEEP
    if ns.Retention then ns.Retention.Mark(rec, "h", "days") end
    for i = 1, folded do
        local k = keys[i]
        local m = k:sub(1, 6)
        local month = rec.months[m]
        if type(month) ~= "table" then month = {}; rec.months[m] = month end
        for stat, n in pairs(rec.days[k]) do
            if type(n) == "number" and not Bad(n) then month[stat] = (month[stat] or 0) + n end
        end
        rec.days[k] = nil
    end
    rec.meta.monthsThrough = keys[folded]
    return folded
end

-- Total of a counter for one month ("YYYYMM"): folded monthly total plus the days still kept.
local function MonthBucket(view, field)
    local value = view and view[field]
    return type(value) == "table" and value or nil
end

local function AddMonthValue(old, value)
    old = CounterValue(old)
    local sum = old + CounterValue(value)
    return Bad(sum) and old or sum
end

local function AddMonthBucket(out, source)
    if type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if not ns.IsSecret(value) and not Bad(value) then out[key] = AddMonthValue(out[key], value) end
    end
end

function ns.MonthTotal(view, key, month)
    local months = MonthBucket(view, "months")
    local folded = months and months[month]
    local total = CounterValue(type(folded) == "table" and folded[key])
    for d, day in pairs(MonthBucket(view, "days") or {}) do
        if type(d) == "string" and d:sub(1, 6) == month and type(day) == "table" then
            total = AddMonthValue(total, day[key])
        end
    end
    return total
end

function ns.MonthRecord(view, month)
    local out, months = {}, MonthBucket(view, "months")
    AddMonthBucket(out, months and months[month])
    for d, day in pairs(MonthBucket(view, "days") or {}) do
        if type(d) == "string" and d:sub(1, 6) == month then AddMonthBucket(out, day) end
    end
    return out
end

local function MonthKeys(n)
    local out, now = {}, time()
    local y, m = tonumber(date("%Y", now)), tonumber(date("%m", now))
    for i = n - 1, 0, -1 do
        local index = y * 12 + m - 1 - i
        out[#out + 1] = string.format("%04d%02d", math.floor(index / 12), index % 12 + 1)
    end
    return out
end

-- Fold retained days into every requested month in a single traversal.
function ns.MonthRecords(view, n)
    local out, byMonth, months = {}, {}, MonthBucket(view, "months")
    for i, key in ipairs(MonthKeys(n)) do
        local row = {}
        AddMonthBucket(row, months and months[key])
        out[i], byMonth[key] = { m = key, v = row }, row
    end
    for d, day in pairs(MonthBucket(view, "days") or {}) do
        local row = type(d) == "string" and byMonth[d:sub(1, 6)]
        if row then AddMonthBucket(row, day) end
    end
    return out
end

function ns.MonthSeries(view, key, n)
    local out, byMonth, months = {}, {}, MonthBucket(view, "months")
    for i, month in ipairs(MonthKeys(n)) do
        local folded = months and months[month]
        local row = { m = month, v = CounterValue(type(folded) == "table" and folded[key]) }
        out[i], byMonth[month] = row, row
    end
    for d, day in pairs(MonthBucket(view, "days") or {}) do
        local row = type(d) == "string" and byMonth[d:sub(1, 6)]
        if row and type(day) == "table" then row.v = AddMonthValue(row.v, day[key]) end
    end
    return out
end

function ns.TrimTallyBuckets(rec)
    for bucketName, bucket in pairs(rec.t) do
        if type(bucket) == "table" then
            local count, changed = 0, false
            for key, value in pairs(bucket) do
                if Bad(value) then bucket[key], changed = nil, true else count = count + 1 end
            end
            if count > TALLY_CAP then
                if ns.Retention then ns.Retention.Mark(rec, "t", bucketName) end
                changed = true
                local list = {}
                for key, value in pairs(bucket) do list[#list + 1] = { key, value } end
                table.sort(list, function(a, b)
                    if a[2] == b[2] then return tostring(a[1]) < tostring(b[1]) end
                    return a[2] > b[2]
                end)
                for i = TALLY_CAP + 1, count do bucket[list[i][1]] = nil end
            end
            tallySizes[bucket] = math.min(count, TALLY_CAP)
            if changed then ns.MarkTallyChanged(bucket, true) end
        end
    end
end

function ns.PruneTallies(rec)
    ns.TrimTallyBuckets(rec)
    ns.RollUpDays(rec)
    if type(rec.qa) ~= "table" then rec.qa = {} end
    local cutoff = time() - 30 * 86400
    for q, t in pairs(rec.qa) do if Bad(t) or t < cutoff then rec.qa[q] = nil end end
end

-- ---------------------------------------------------------------- views
local EMPTY = { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {} }

local function MergeAccount()
    local empty = {}
    local function Table(value) return type(value) == "table" and value or empty end
    local function AddBucket(dst, src)
        for k, n in pairs(Table(src)) do if not Bad(n) then dst[k] = (dst[k] or 0) + n end end
    end
    local v = { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {}, months = {}, ach = {}, achr = {}, meta = {}, rh = {}, bestiary = {} }
    for _, rec in pairs(ns.db.chars) do
        if Valid(rec) then
            for k, n in pairs(rec.c) do
                if not Bad(n) then v.c[k] = (v.c[k] or 0) + n end
            end
            if ns.Retention then ns.Retention.MergeFlags(v, rec) end
            for k, n in pairs(rec.r) do
                if type(k) == "string" and not Bad(n) and n > (v.r[k] or 0) then
                    v.r[k] = n
                    v.r[k .. "_what"] = rec.r[k .. "_what"]
                end
            end
            for tn, t in pairs(rec.t) do
                local dst = v.t[tn] or {}
                v.t[tn] = dst
                AddBucket(dst, t)
            end
            for set, t in pairs(type(rec.u) == "table" and rec.u or empty) do
                local dst = v.u[set] or {}
                v.u[set] = dst
                for k in pairs(type(t) == "table" and t or empty) do
                    k = ns.UniqueKey(k)
                    if not dst[k] then dst[k] = true; v.un[set] = (v.un[set] or 0) + 1 end
                end
            end
            for k, n in pairs(type(rec.f) == "table" and rec.f or empty) do
                if not Bad(n) and n > 0 and (not v.f[k] or n < v.f[k]) then
                    v.f[k], v.fw[k], v.fd[k] = n, Table(rec.fw)[k], Table(rec.fd)[k]
                end
            end
            for k, when in pairs(type(rec.firstd) == "table" and rec.firstd or empty) do
                if not Bad(when) and (not v.firstd[k] or when < v.firstd[k]) then
                    v.firstd[k], v.first[k] = when, Table(rec.first)[k]
                end
            end
            for k, when in pairs(type(rec.ach) == "table" and rec.ach or empty) do
                if not Bad(when) and (not v.ach[k] or when < v.ach[k]) then v.ach[k] = when end
            end
            for d, day in pairs(type(rec.days) == "table" and rec.days or empty) do
                local dst = v.days[d] or {}
                v.days[d] = dst
                AddBucket(dst, day)
            end
            for name, e in pairs(type(rec.bestiary) == "table" and rec.bestiary or empty) do
                if type(e) == "table" and not Bad(e.k) then
                    local first, last = not Bad(e.f) and e.f or nil, not Bad(e.l) and e.l or nil
                    local dst = v.bestiary[name]
                    if not dst then
                        v.bestiary[name] = { k = e.k, f = first, l = last, z = e.z, ty = e.ty, cl = e.cl, who = rec.meta.name }
                    else
                        dst.k = dst.k + e.k
                        if first and first < (dst.f or math.huge) then dst.f, dst.z, dst.who = first, e.z or dst.z, rec.meta.name end
                        if last and last > (dst.l or 0) then dst.l = last end
                        dst.ty, dst.cl = dst.ty or e.ty, dst.cl or e.cl
                    end
                end
            end
            for m, month in pairs(type(rec.months) == "table" and rec.months or empty) do
                local dst = v.months[m] or {}
                v.months[m] = dst
                AddBucket(dst, month)
            end
            for _, entry in ipairs(Table(rec.rh)) do
                if type(entry) == "table" and not Bad(entry.at) and not Bad(entry.v) then
                    v.rh[#v.rh + 1] = {
                        k = entry.k, v = entry.v, at = entry.at, d = entry.d, w = entry.w,
                        character = type(rec.meta.name) == "string" and rec.meta.name or nil,
                    }
                end
            end
        end
    end
    table.sort(v.rh, function(a, b) return (a.at or 0) > (b.at or 0) end)
    while #v.rh > HISTORY_CAP do table.remove(v.rh) end
    return v
end

local accountCache, accountTime = nil, -100
function ns.InvalidateAccount() accountCache = nil end
-- scope: "char" | "account"; range: "lifetime" | "session" | "today" | "week" | "month"
function ns.GetView(scope, range)
    if range == "session" or scope == "session" then return ns.session end
    local base
    if scope == "account" then
        if not accountCache or GetTime() - accountTime > 5 then
            accountCache, accountTime = MergeAccount(), GetTime()
        end
        base = accountCache
    else
        base = ns.char
    end
    local days = type(base.days) == "table" and base.days or EMPTY.days
    if range == "today" then
        local day = days[ns.Today()]
        if type(day) ~= "table" then day = EMPTY.days end
        return { c = day, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = base.days, months = base.months, rh = base.rh, today = true }
    end
    if range == "week" or range == "month" then
        -- sum of the daily buckets: last 7 or 30 days including today
        local n = range == "week" and 7 or 30
        local sum, now = {}, time()
        for i = 0, n - 1 do
            local day = days[date("%Y%m%d", now - i * 86400)]
            if type(day) == "table" then for k, v in pairs(day) do if not Bad(v) then sum[k] = (sum[k] or 0) + v end end end
        end
        return { c = sum, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = base.days, months = base.months, rh = base.rh, today = true, span = n }
    end
    return base
end

-- Daily series for the last n days (oldest first) of a counter, or of a function(day).
function ns.DaySeries(view, key, n)
    local out, days = {}, (view and type(view.days) == "table" and view.days) or EMPTY.days
    local now = time()
    for i = n - 1, 0, -1 do
        local d = date("%Y%m%d", now - i * 86400)
        local day = days[d]
        if type(day) ~= "table" then day = nil end
        local v
        if type(key) == "function" then v = key(day or {})
        else
            v = day and day[key]
            if Bad(v) then v = 0 end
        end
        out[#out + 1] = { d = d, v = v }
    end
    return out
end

-- A class colour as { r, g, b }, inked for paper on the notebook skin.
function ns.ClassRGB(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c or not c.r then return nil end
    local r, g, b = c.r, c.g, c.b
    if ns.W and ns.W.InkRGB then r, g, b = ns.W.InkRGB(r, g, b) end
    return { r, g, b, 1 }
end

function ns.CharCount()
    local n = 0
    for _, rec in pairs(ns.db.chars) do if Valid(rec) then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------- lifecycle
ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON then return end
    ns.InitDB()
    if not ns.char then return end
    if ns.ApplyTheme then ns.ApplyTheme() else ns.ApplyAccent() end
    if ns.OnInit then ns.OnInit() end
end)

ns.On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if not isLogin then return end
    local last = type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB.lastSession
    ns.ResetSession()
    if ns.settings.recap and type(last) == "table" and type(last.c) == "table"
        and not Bad(last.elapsed) and last.elapsed > 60 then
        local ok, message = pcall(function()
            local highlights = type(last.highlights) == "table" and #last.highlights > 0
                and (" · new records: " .. table.concat(last.highlights, "; ")) or ""
            return "Last session: " .. RecapText(last.c, last.elapsed, last.top) .. highlights
        end)
        if ok then ns.Print(message) else ns.LogError("login:recap", message) end
    end
end)

-- Each logout step runs on its own so a failure in one can never skip ns.Save(),
-- which bumps the revision that decides which stored copy wins at the next login.
local function LogoutStep(name, fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then ns.LogError("logout:" .. name, err) end
end
ns.On("PLAYER_LOGOUT", function()
    LogoutStep("flush", ns.FlushCombatDamage)
    LogoutStep("hooks", ns.OnLogout)
    if ns.char then LogoutStep("prune", ns.PruneTallies, ns.char) end
    LogoutStep("save", ns.Save)
end)

-- Slash commands
SLASH_LIFETIMESTATS1 = "/lts"
SLASH_LIFETIMESTATS2 = "/lifetimestats"
SlashCmdList.LIFETIMESTATS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if not ns.char then ns.Print("Character data is not available."); return end
    local cmd = msg:match("^(%S*)")
    if cmd == "" or cmd == "show" then
        ns.ToggleWindow()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        ns.OpenOptions()
    elseif cmd == "minimap" then
        local arg = msg:match("^%S+%s+(.+)$")
        if arg == "reset" then
            ns.ResetMinimapButton()
            ns.Print("Minimap button shown again at the bottom-left of the minimap.")
        elseif arg == "square" or arg == "round" then
            ns.settings.minimap.square = arg == "square"
            ns.UpdateMinimapButton()
            ns.Print("Minimap button placed for a " .. arg .. " minimap.")
        elseif not arg or arg == "toggle" then
            ns.settings.minimap.hide = not ns.settings.minimap.hide
            ns.UpdateMinimapButton()
            ns.Print("Minimap button " .. (ns.settings.minimap.hide and "hidden" or "shown") .. ". /lts minimap reset brings it back; /lts minimap square or round sets the shape.")
        else
            ns.Print("Usage: /lts minimap [toggle|reset|square|round]")
        end
    elseif msg == "resetwindow" then
        ns.ResetWindow()
        ns.Print("Window centered and fitted to the current UI canvas.")
    elseif (cmd == "size" and msg:match("^%S+%s+%S")) or cmd == "fill" or cmd == "normal" then
        local arg = cmd == "size" and msg:match("^%S+%s+(%S+)") or cmd
        if arg == "fill" or arg == "normal" then
            if not ns.SetWindowSize(arg) then ns.Print("The window is already " .. (arg == "fill" and "filling the screen." or "at its normal size.")) end
        else
            ns.Print("/lts size fill makes the window fill the screen; /lts size normal returns it to 1140 x 740.")
        end
    elseif cmd == "share" then
        ns.ShareCommand(msg:match("^share%s*(.*)$"))
    elseif cmd == "compare" then
        if not ns.ShowPage then ns.ToggleWindow() end
        ns.OpenPage("compare")
    elseif msg == "export" or cmd == "backup" then
        ns.ShowExport()
    elseif cmd == "import" or cmd == "restore" then
        ns.ShowImport()
    elseif cmd == "session" then
        ns.ResetSession()
        ns.Print("Session counters reset.")
    elseif cmd == "dm" then
        ns.PrintToWindow("Damage meter dump", "What Forever's damage meter gives addons. Ctrl+A, Ctrl+C to copy and send it to the developer.", ns.DumpDamageMeter)
    elseif cmd == "sheet" then
        ns.ShowSheet()
    elseif cmd == "title" then
        local t = ns.CycleTitle()
        ns.Print("Title: " .. ns.TitledName() .. (t and "" or " (no title)"))
        if ns.RefreshWindow then ns.RefreshWindow() end
    elseif cmd == "score" then
        ns.ShowText("Adventurer score", "How your score is made. Ctrl+A, Ctrl+C to copy.", ns.ScoreText())
    elseif cmd == "csv" or cmd == "sessions" then
        ns.ShowText("Session history (CSV)", "One line per play session. Ctrl+A, Ctrl+C and paste into a spreadsheet.", ns.SessionCSV())
    elseif cmd == "goal" or cmd == "goals" then
        ns.GoalCommand(msg:match("^%S+%s*(.-)$"))
    elseif cmd == "size" then
        local lines = ns.SizeReport()
        if ns.ShowText then ns.ShowText("Saved data size", "Estimated size of each character's saved data.", table.concat(lines, "\n")) end
    elseif cmd == "snapshot" or cmd == "snapshots" then
        ns.SnapshotCommand(msg:match("^%S+%s*(.-)$"))
    elseif cmd == "deathpins" then
        ns.settings.deathPins = ns.settings.deathPins == false
        if ns.RefreshDeathPins then pcall(ns.RefreshDeathPins) end
        ns.Print("Death skulls on the world map " .. (ns.settings.deathPins and "shown" or "hidden") .. ".")
    elseif cmd == "summary" then
        ns.ShowSessionSummary(true)
    elseif cmd == "export" and msg:match("^%S+%s+(%S+)") then
        local kind, args = msg:match("^%S+%s+(%S+)%s*(.*)$")
        local days = args:match("^days%s+(%d+)$")
        days = days and tonumber(days)
        if not ns.EXPORTS[kind] or (args ~= "" and (not days or days < 1 or days > 3650)) then
            ns.Print("Usage: /lts export items|quests|runs|deaths [days 1-3650]")
        else
            local title, text, count = ns.ExportCSV(kind, false, days and time() - days * 86400)
            local range = days and ("last " .. days .. (days == 1 and " day" or " days")) or "all retained history"
            ns.ShowText(title .. " (CSV)", string.format("%d rows · %s. Ctrl+A, Ctrl+C and paste into a spreadsheet.", count, range), text)
        end
    elseif cmd == "compendium" then
        ns.ShowText("Compendium (CSV)", "Every statistic for every character, plus the account total. Ctrl+A, Ctrl+C and paste into a spreadsheet.", ns.CompendiumCSV())
    elseif cmd == "recap" then
        ns.Print("This session: " .. RecapText(ns.session.c, GetTime() - ns.session.start, SessionTopSpell()))
    elseif cmd == "debug" then
        ns.PrintToWindow("Data sources", "Which game data sources work this session. Ctrl+A, Ctrl+C to copy.", ns.PrintDebug)
    elseif cmd == "errors" then
        ns.PrintToWindow("Recent Lua errors", "Forever hides addon errors; LifeTimeStats keeps the last 30 here. Ctrl+A, Ctrl+C to copy.", function()
            if #ns.errors == 0 then ns.Print("No errors recorded.") end
            for _, e in ipairs(ns.errors) do ns.Print(e) end
        end)
    else
        ns.Print("Commands:")
        ns.Print("/lts - open or close the window")
        ns.Print("/lts settings - open settings")
        ns.Print("/lts resetwindow - center and fit the window, even when it is hidden")
        ns.Print("/lts size fill|normal - fill the screen or use the normal window size (applies after /reload)")
        ns.Print("/lts minimap - show/hide minimap button · /lts minimap reset · /lts minimap square|round")
        ns.Print("/lts session - reset session counters")
        ns.Print("/lts export | import - backup or restore this character")
        ns.Print("/lts share [s|p|r|g|i] [topic] - share a stat line (no channel = preview first)")
        ns.Print("/lts compare - compare your characters")
        ns.Print("/lts errors - recent Lua errors (Forever hides them)")
        ns.Print("/lts debug - which game data sources are working")
        ns.Print("/lts sheet - character sheet you can copy · /lts title - cycle earned titles")
        ns.Print("/lts score - your Adventurer score and how it is made")
        ns.Print("/lts csv - your play sessions as CSV for a spreadsheet")
        ns.Print("/lts export - every statistic for every character as CSV")
        ns.Print("/lts goal <words> <target> - set a goal · /lts goal list · /lts goal remove <n>")
        ns.Print("/lts summary - this session at a glance")
        ns.Print("/lts export items|quests|runs|deaths - one log as CSV · /lts size - saved data size")
        ns.Print("/lts snapshot - the last 3 daily snapshots (show / restore) · /lts deathpins - map skulls on/off")
    end
end

function ns.ResetSession()
    local previous = ns.session
    if previous and GetTime() - previous.start >= 5 then
        if ns.LogSession then ns.LogSession() end
        if type(LifeTimeStatsCharDB) == "table" then
            local counters = {}
            for key, value in pairs(previous.c or {}) do counters[key] = value end
            LifeTimeStatsCharDB.lastSession = {
                c = counters, elapsed = GetTime() - previous.start, at = time(), top = SessionTopSpell(),
                highlights = ns.SessionRecordHighlights and ns.SessionRecordHighlights(previous.rh, 3) or {},
                closing = ns.CopySessionClosing(previous.closing),
            }
        end
    end
    ns.session = NewSession(ns.char)
    if ns.RefreshWindow then ns.RefreshWindow() end
end

function ns.PrintDebug()
    local src = ns.src
    local function yn(v) return v and (ns.GREEN .. "yes|r") or (ns.GREY .. "no|r") end
    ns.Print("Data sources this session:")
    local unavailable = {}
    for event, status in pairs(ns.eventStatus) do
        if status ~= "registered" then unavailable[#unavailable + 1] = event .. " (" .. status .. ")" end
    end
    table.sort(unavailable)
    if #unavailable > 0 then ns.Print("  Events not registered: " .. table.concat(unavailable, ", ")) end
    ns.Print("  Combat log events: " .. (src.cleu or 0) .. (ns.CombatLogRestricted() and "  (not registered: Forever forbids it for addons)" or ""))
    ns.Print("  Kills from XP messages: " .. (src.xpKills or 0) .. " · from watched units: " .. (src.unitKills or 0) .. " · honor kills: " .. (src.honorKills or 0) .. " · critters: " .. (src.critterKills or 0))
    ns.Print("  UNIT_COMBAT on you: " .. (src.ucPlayer or 0) .. " · on your target: " .. (src.ucTarget or 0) .. " (target only counted while solo)")
    ns.Print("  Hit sizes readable: " .. yn(src.amountReadable) .. " · your health readable: " .. yn(src.hpReadable))
    ns.Print("  Movement: speed readable " .. yn(src.speedReadable) .. " · position ticks used " .. (src.posDistance or 0) .. " · ticks skipped " .. (src.moveSkipped or 0))
    ns.Print("  Falls detected from health: " .. (src.falls or 0) .. " · secret values skipped: " .. (src.secret or 0) .. " · hidden yes/no checks: " .. (src.secretBool or 0))
    ns.Print("  Critters: engaged " .. (src.critterEngaged or 0) .. " · killed " .. (src.critterKills or 0) .. " · type readable " .. (src.critterTypeRead or 0) .. " / hidden " .. (src.critterTypeHidden or 0))
    ns.Print("  Emotes: from hooks " .. (src.emoteHook or 0) .. " · from chat lines " .. (src.emoteText or 0))
    ns.Print("  Quests: events " .. (src.questEvents or 0) .. " · chat lines " .. (src.questChat or 0))
    ns.Print("  Gold: money events " .. (src.moneyEvents or 0) .. " · hidden " .. yn(src.moneySecret) .. " · loot-money lines " .. (src.moneyChat or 0))
    ns.Print("  Deaths seen " .. (src.deathEvents or 0) .. " · appearances " .. (src.appearances or 0))
    local dm = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "table" and (k:find("DamageMeter") or k:find("^C_Damage") or k:find("^C_Combat")) then dm[#dm + 1] = k end
    end
    table.sort(dm)
    if type(C_DamageMeter) == "table" then
        local fns = {}
        for k, v in pairs(C_DamageMeter) do if type(v) == "function" then fns[#fns + 1] = k end end
        table.sort(fns)
        ns.Print("  C_DamageMeter functions: " .. (#fns > 0 and table.concat(fns, ", ") or "none"))
    end
    ns.Print("  Damage meter readable: " .. (src.dmReadable and "yes" or (ns.settings.dmReadable and "yes (seen before; no fight read yet this session)" or "no")) .. (src.dmSecret and " (values hidden)" or "") .. " · fights read " .. (src.dmSessions or 0) .. (src.dmCall and (" · via " .. src.dmCall) or ""))
    do
        local meter, counted = nil, nil
        if ns.DMGap then meter, counted = ns.DMGap() end
        local keys = {}
        for k in pairs(src.dmDetailKeys or {}) do keys[#keys + 1] = k end
        table.sort(keys)
        ns.Print("  Meter check: overall since login " .. (meter and ns.FormatInt(meter) or "?") .. " · counted " .. ns.FormatInt(counted or src.dmCounted or 0)
            .. ((meter and counted and meter - counted > 0) and (" · gap " .. ns.FormatInt(meter - counted)) or ""))
        ns.Print("  Death cause: from recap " .. (src.recapDeaths or 0) .. " · from meter " .. (src.dmKiller or 0) .. " · biggest-hit field: " .. (src.dmHitKey or "none") .. (#keys > 0 and (" · detail fields: " .. table.concat(keys, ", ")) or ""))
        ns.Print("  Theme: " .. (ns.ThemeName and ns.ThemeName(ns.settings.theme or "auto") or "?") .. (ns.themeLive and " (live colours)" or ""))
        ns.Print("  DungeonJournal: " .. (src.dj or "not installed") .. (src.djGlobals and (" · tables: " .. src.djGlobals) or ""))
    end
    ns.Print("  Damage-meter APIs: " .. (#dm > 0 and table.concat(dm, ", ") or "none found"))
    ns.Print("  Loot messages matched: " .. (src.loot or 0) .. " · quality read: " .. yn(src.quality))
    ns.Print("  Lua errors logged: " .. #ns.errors .. "  (/lts errors)")
end

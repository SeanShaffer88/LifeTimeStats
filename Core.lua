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
    achAnnounce  = "off", -- off | chat | toast | both
    countPet     = true,
    milestones   = false,
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

function ns.On(event, fn)
    local list = ns.events[event]
    if not list then
        list = {}
        ns.events[event] = list
        -- Some events may not exist on every client build; never let that break load.
        if ns.ShouldRegister(event) then pcall(frame.RegisterEvent, frame, event) end
    end
    list[#list + 1] = fn
end

-- Forever hides Lua errors; keep the last few so /lts errors can show them.
ns.errors = {}
local lastErr, lastErrCount = nil, 0
function ns.LogError(where, err)
    local e = ns.errors
    local msg = tostring(where) .. ": " .. tostring(err)
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

local SECTIONS = { "c", "r", "t", "u", "un", "f", "fw", "fd", "first", "firstd", "days", "qa", "ach", "achr", "journal", "lvlsnap", "zonelog" }

local function NewCharRecord()
    local rec = { meta = { rev = 0, created = time() }, run = nil }
    for _, k in ipairs(SECTIONS) do rec[k] = {} end
    -- c counters · r records (max) · t tallies · u unique sets · un unique counts
    -- f fastest (min) · fw/fd label/date · first/firstd firsts · days daily counters · qa quest accept times
    return rec
end
ns.NewCharRecord = NewCharRecord

local function Valid(rec)
    return type(rec) == "table" and type(rec.meta) == "table" and type(rec.c) == "table"
        and type(rec.r) == "table" and type(rec.t) == "table"
end
ns.ValidRecord = Valid

-- Upgrades a 1.0 record in place and recounts unique sets.
local function Ensure(rec)
    for _, k in ipairs(SECTIONS) do
        if type(rec[k]) ~= "table" then rec[k] = {} end
    end
    for set, t in pairs(rec.u) do
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        rec.un[set] = n
    end
    return rec
end
ns.EnsureRecord = Ensure

local function NewSession()
    return { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, start = GetTime() }
end
ns.session = NewSession()

function ns.InitDB()
    if type(LifeTimeStatsDB) ~= "table" then LifeTimeStatsDB = {} end
    local db = LifeTimeStatsDB
    db.schema = 2
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
    if not Valid(primary) then primary = nil end
    if not Valid(backup) then backup = nil end
    local rec
    if primary and backup then
        rec = ((backup.meta.rev or 0) > (primary.meta.rev or 0)) and backup or primary
        if rec == backup and rec ~= primary then ns.restoredFromBackup = true end
    else
        rec = primary or backup
        if rec == backup and backup then ns.restoredFromBackup = true end
    end
    if not rec then rec = NewCharRecord() end
    Ensure(rec)
    for _, other in pairs(db.chars) do if Valid(other) then Ensure(other) end end
    db.chars[ns.charKey] = rec
    if type(LifeTimeStatsCharDB) ~= "table" then LifeTimeStatsCharDB = {} end
    LifeTimeStatsCharDB.data = rec

    -- Session survives /reload: restored here, reset on a real login (PLAYER_ENTERING_WORLD isLogin).
    local saved = LifeTimeStatsCharDB.session
    if type(saved) == "table" and type(saved.c) == "table" and type(saved.savedAt) == "number" and time() - saved.savedAt < 900 then
        local sess = NewSession()
        for k in pairs(sess) do if type(saved[k]) == "table" then sess[k] = saved[k] end end
        sess.start = GetTime() - (saved.elapsed or 0)
        ns.session = sess
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
    if type(LifeTimeStatsCharDB) == "table" then
        LifeTimeStatsCharDB.lastSession = { c = ns.session.c, elapsed = GetTime() - ns.session.start, at = time(), top = SessionTopSpell() }
    end
    if type(LifeTimeStatsCharDB) == "table" then
        local s = ns.session
        LifeTimeStatsCharDB.session = { c = s.c, r = s.r, t = s.t, u = s.u, un = s.un, f = s.f, fw = s.fw, fd = s.fd,
            first = s.first, firstd = s.firstd, elapsed = GetTime() - s.start, savedAt = time() }
    end
    ns.char.meta.rev = (ns.char.meta.rev or 0) + 1
    ns.char.meta.saved = time()
    ns.char.meta.level = UnitLevel("player")
    if type(LifeTimeStatsCharDB) == "table" then LifeTimeStatsCharDB.data = ns.char end
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

function ns.Add(key, n)
    n = n or 1
    local ch = ns.char
    if not ch or ns.IsSecret(n) or ns.IsSecret(key) or n == 0 or Bad(n) or key == nil then return end
    local old = ch.c[key] or 0
    local new = old + n
    ch.c[key] = new
    local s = ns.session.c
    s[key] = (s[key] or 0) + n
    local d = ns.Today()
    local day = ch.days[d]
    if not day then day = {}; ch.days[d] = day end
    day[key] = (day[key] or 0) + n
    if ns.settings.milestones and ns.milestoneKeys and ns.milestoneKeys[key] then
        for i = 1, #milestoneSteps do
            local m = milestoneSteps[i]
            if old < m and new >= m then
                ns.Print(ns.milestoneKeys[key] .. ": " .. ns.GREEN .. BreakUpLargeNumbers(m) .. "|r!")
            end
        end
    end
end

function ns.Max(key, v, label)
    if not ns.char or ns.IsSecret(v) or Bad(v) then return end
    if ns.IsSecret(label) then label = nil end
    local r = ns.char.r
    if v > (r[key] or 0) then
        r[key] = v
        if label then r[key .. "_what"] = tostring(label) end
    end
    local s = ns.session.r
    if v > (s[key] or 0) then
        s[key] = v
        if label then s[key .. "_what"] = tostring(label) end
    end
end

-- Fastest / shortest records: lower is better.
function ns.Min(key, v, label)
    if not ns.char or ns.IsSecret(v) or Bad(v) or v <= 0 then return end
    if ns.IsSecret(label) then label = nil end
    for _, rec in ipairs({ ns.char, ns.session }) do
        local cur = rec.f[key]
        if not cur or v < cur then
            rec.f[key] = v
            rec.fw[key] = label and tostring(label) or nil
            rec.fd[key] = time()
        end
    end
end

function ns.First(key, label)
    if not ns.char then return end
    if ns.IsSecret(label) then label = nil end
    local ch = ns.char
    if ch.first[key] then return end
    ch.first[key] = label and tostring(label) or "yes"
    ch.firstd[key] = time()
    if ns.Journal and ns.FIRST_LABEL then
        local lbl = ns.FIRST_LABEL[key]
        if lbl then ns.Journal(lbl .. ((label and label ~= "yes") and (": " .. tostring(label)) or "")) end
    end
end

-- Unique sets: returns true when the key is new. Each set stops growing at
-- UNIQUE_CAP entries to keep SavedVariables small (count then stays at the cap).
local UNIQUE_CAP = 20000
ns.UNIQUE_CAP = UNIQUE_CAP
function ns.Unique(set, key)
    if not ns.char or key == nil or ns.IsSecret(key) or key == "" then return false end
    local ch = ns.char
    local u = ch.u[set]
    if not u then u = {}; ch.u[set] = u end
    if u[key] then return false end
    if (ch.un[set] or 0) >= UNIQUE_CAP then return false end
    u[key] = true
    ch.un[set] = (ch.un[set] or 0) + 1
    local s = ns.session
    s.un[set] = (s.un[set] or 0) + 1
    return true
end

function ns.Tally(tbl, name, n)
    if not ns.char or not name or ns.IsSecret(name) or ns.IsSecret(n) or name == "" then return end
    n = n or 1
    if Bad(n) then return end
    local t = ns.char.t[tbl]
    if not t then t = {}; ns.char.t[tbl] = t end
    t[name] = (t[name] or 0) + n
    local st = ns.session.t[tbl]
    if not st then st = {}; ns.session.t[tbl] = st end
    st[name] = (st[name] or 0) + n
end

-- Keep tally tables and day history bounded (performance + SavedVariables size).
local TALLY_CAP, DAY_KEEP = 400, 40
function ns.PruneTallies(rec)
    for _, t in pairs(rec.t) do
        if type(t) == "table" then
            local n, list = 0, {}
            for k, v in pairs(t) do n = n + 1; list[n] = { k, v } end
            if n > TALLY_CAP then
                table.sort(list, function(a, b) return a[2] > b[2] end)
                for i = TALLY_CAP + 1, n do t[list[i][1]] = nil end
            end
        end
    end
    local keys = {}
    for k in pairs(rec.days) do keys[#keys + 1] = k end
    if #keys > DAY_KEEP then
        table.sort(keys)
        for i = 1, #keys - DAY_KEEP do rec.days[keys[i]] = nil end
    end
    rec.qa = rec.qa or {}
    local cutoff = time() - 30 * 86400
    for q, t in pairs(rec.qa) do if t < cutoff then rec.qa[q] = nil end end
end

-- ---------------------------------------------------------------- views
local EMPTY = { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {} }

local function MergeAccount()
    local v = { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {}, ach = {}, achr = {}, meta = {} }
    for _, rec in pairs(ns.db.chars) do
        if Valid(rec) then
            Ensure(rec)
            for k, n in pairs(rec.c) do
                if type(n) == "number" then v.c[k] = (v.c[k] or 0) + n end
            end
            for k, n in pairs(rec.r) do
                if type(n) == "number" and n > (v.r[k] or 0) then
                    v.r[k] = n
                    v.r[k .. "_what"] = rec.r[k .. "_what"]
                end
            end
            for tn, t in pairs(rec.t) do
                local dst = v.t[tn] or {}
                v.t[tn] = dst
                for k, n in pairs(t) do dst[k] = (dst[k] or 0) + n end
            end
            for set, t in pairs(rec.u) do
                local dst = v.u[set] or {}
                v.u[set] = dst
                for k in pairs(t) do
                    if not dst[k] then dst[k] = true; v.un[set] = (v.un[set] or 0) + 1 end
                end
            end
            for k, n in pairs(rec.f) do
                if not v.f[k] or n < v.f[k] then
                    v.f[k], v.fw[k], v.fd[k] = n, rec.fw[k], rec.fd[k]
                end
            end
            for k, when in pairs(rec.firstd) do
                if not v.firstd[k] or when < v.firstd[k] then
                    v.firstd[k], v.first[k] = when, rec.first[k]
                end
            end
            for k, when in pairs(rec.ach) do
                if not v.ach[k] or when < v.ach[k] then v.ach[k] = when end
            end
            for d, day in pairs(rec.days) do
                local dst = v.days[d] or {}
                v.days[d] = dst
                for k, n in pairs(day) do dst[k] = (dst[k] or 0) + n end
            end
        end
    end
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
    if range == "today" then
        local day = base.days[ns.Today()] or {}
        return { c = day, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = base.days, today = true }
    end
    if range == "week" or range == "month" then
        -- sum of the daily buckets: last 7 or 30 days including today
        local n = range == "week" and 7 or 30
        local sum, now = {}, time()
        for i = 0, n - 1 do
            local day = base.days[date("%Y%m%d", now - i * 86400)]
            if day then for k, v in pairs(day) do sum[k] = (sum[k] or 0) + v end end
        end
        return { c = sum, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = base.days, today = true, span = n }
    end
    return base
end

-- Daily series for the last n days (oldest first) of a counter, or of a function(day).
function ns.DaySeries(view, key, n)
    local out, days = {}, (view and view.days) or EMPTY.days
    local now = time()
    for i = n - 1, 0, -1 do
        local d = date("%Y%m%d", now - i * 86400)
        local day = days[d]
        local v
        if type(key) == "function" then v = key(day or {})
        else v = day and day[key] or 0 end
        out[#out + 1] = { d = d, v = v }
    end
    return out
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
    if ns.ApplyTheme then ns.ApplyTheme() else ns.ApplyAccent() end
    if ns.OnInit then ns.OnInit() end
end)

ns.On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if not isLogin then return end
    local last = type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB.lastSession
    if ns.settings.recap and type(last) == "table" and type(last.c) == "table" and (last.elapsed or 0) > 60 then
        ns.Print("Last session: " .. RecapText(last.c, last.elapsed, last.top))
    end
    ns.ResetSession()
end)

ns.On("PLAYER_LOGOUT", function()
    if ns.OnLogout then ns.OnLogout() end
    if ns.char then ns.PruneTallies(ns.char) end
    ns.Save()
end)

-- Slash commands
SLASH_LIFETIMESTATS1 = "/lts"
SLASH_LIFETIMESTATS2 = "/lifetimestats"
SlashCmdList.LIFETIMESTATS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local cmd = msg:match("^(%S*)")
    if cmd == "" or cmd == "show" then
        ns.ToggleWindow()
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        ns.OpenOptions()
    elseif cmd == "minimap" then
        ns.settings.minimap.hide = not ns.settings.minimap.hide
        ns.UpdateMinimapButton()
        ns.Print("Minimap button " .. (ns.settings.minimap.hide and "hidden" or "shown") .. ".")
    elseif cmd == "share" then
        ns.ShareCommand(msg:match("^share%s*(.*)$"))
    elseif cmd == "compare" then
        if not ns.ShowPage then ns.ToggleWindow() end
        ns.OpenPage("compare")
    elseif cmd == "export" or cmd == "backup" then
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
    elseif cmd == "recap" then
        ns.Print("This session: " .. RecapText(ns.session.c, GetTime() - ns.session.start, SessionTopSpell()))
    elseif cmd == "debug" then
        ns.PrintToWindow("Data sources", "Which game data sources work this session. Ctrl+A, Ctrl+C to copy.", ns.PrintDebug)
    elseif cmd == "errors" then
        ns.PrintToWindow("Recent Lua errors", "Forever hides addon errors; LifeTimeStats keeps the last 30 here. Ctrl+A, Ctrl+C to copy.", function()
            if #ns.errors == 0 then ns.Print("No errors recorded.") end
            for _, e in ipairs(ns.errors) do ns.Print(e) end
        end)
    elseif cmd == "summary" then
        ns.PrintSummary()
    else
        ns.Print("Commands:")
        ns.Print("/lts - open or close the window")
        ns.Print("/lts summary - print a few headline stats")
        ns.Print("/lts settings - open settings")
        ns.Print("/lts minimap - show/hide minimap button")
        ns.Print("/lts session - reset session counters")
        ns.Print("/lts export | import - backup or restore this character")
        ns.Print("/lts share [s|p|r|g|i] [topic] - share a stat line (no channel = preview first)")
        ns.Print("/lts compare - compare your characters")
        ns.Print("/lts errors - recent Lua errors (Forever hides them)")
        ns.Print("/lts debug - which game data sources are working")
        ns.Print("/lts sheet - character sheet you can copy · /lts title - cycle earned titles")
        ns.Print("/lts score - your Adventurer score and how it is made")
        ns.Print("/lts csv - your play sessions as CSV for a spreadsheet")
    end
end

function ns.ResetSession()
    ns.session = NewSession()
    if ns.RefreshWindow then ns.RefreshWindow() end
end

function ns.PrintDebug()
    local src = ns.src
    local function yn(v) return v and (ns.GREEN .. "yes|r") or (ns.GREY .. "no|r") end
    ns.Print("Data sources this session:")
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

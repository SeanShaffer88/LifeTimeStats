-- LifeTimeStats - character: session history, active time, peak character stats, reputation
-- standings, battleground scoreboard and the Adventurer Score.
-- Ideas from TimePlayed+, PlayedTracker, PvP Stats Tracker, Classic Score, Siouxx Classic Stats,
-- Extended Character Stats and CharacterStatsClassic (public descriptions only, no code).
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Tally, On = ns.Add, ns.Max, ns.Tally, ns.On
local S = ns.IsSecret
local SESSION_KEEP = 300

local function N(v) if type(v) == "number" and not S(v) and v == v then return v end end

-- ------------------------------------------------------------ session history
-- One entry per session, updated in memory every five minutes and at logout.
-- WoW writes it with the character's SavedVariables on normal saves.
function ns.LogSession()
    if not ns.char or not ns.session then return end
    local ch, s = ns.char, ns.session
    ch.sessionlog = ch.sessionlog or {}
    local log = ch.sessionlog
    local start = s.wallStart
    local dur = math.floor(GetTime() - s.start)
    if dur < 5 then return end
    local e = log[#log]
    if not (e and e.id == s.id) then
        e = { id = s.id, s = start }
        log[#log + 1] = e
        while #log > SESSION_KEEP do if ns.Retention then ns.Retention.Mark(ch, "h", "sessionlog") end; table.remove(log, 1) end
    end
    local c = s.c
    e.d = dur
    e.afk = math.floor(c.time_afk or 0)
    e.l = UnitLevel("player") or e.l
    e.steps = math.floor((c.dist_foot or 0) * (ns.YARDS_TO_STEPS or 1.2))
    e.k = (c.kills_npc or 0) + (c.kills_pvp or 0)
    e.de = c.deaths or 0
    e.q = c.quests_done or 0
    e.xp = c.xp or 0
    e.dmg = c.dmg_done or 0
    e.z = ns.GetZone and ns.GetZone() or e.z
    if ns.LogSessionFarming then ns.LogSessionFarming(e, c) end
    Max("max_session_time", dur, date("%b %d", start))
end
On("PLAYER_LOGOUT", function() pcall(ns.LogSession) end)
On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(300, function() pcall(ns.LogSession) end) end
end)

-- Averages over the session log: sessions, mean length, daily mean, last 7 days.
function ns.SessionStats(v)
    local log = (v or ns.char or {}).sessionlog or {}
    local n, total, days, week = #log, 0, {}, 0
    local now = time()
    for _, e in ipairs(log) do
        total = total + (e.d or 0)
        days[date("%Y-%m-%d", e.s or 0)] = true
        if now - (e.s or 0) < 7 * 86400 then week = week + (e.d or 0) end
    end
    local nd = 0
    for _ in pairs(days) do nd = nd + 1 end
    return {
        n = n, total = total, avg = n > 0 and total / n or 0,
        perDay = nd > 0 and total / nd or 0, week = week, weekPerDay = week / 7, days = nd,
    }
end

-- CSV for /lts csv (copy into a spreadsheet).
function ns.SessionCSV()
    local lines = { "date,start,duration_min,afk_min,level,zone,steps,kills,deaths,quests,xp,damage" }
    for _, e in ipairs((ns.char and ns.char.sessionlog) or {}) do
        lines[#lines + 1] = string.format("%s,%s,%.1f,%.1f,%d,%q,%d,%d,%d,%d,%d,%d",
            date("%Y-%m-%d", e.s or 0), date("%H:%M", e.s or 0), (e.d or 0) / 60, (e.afk or 0) / 60, e.l or 0,
            e.z or "", e.steps or 0, e.k or 0, e.de or 0, e.q or 0, e.xp or 0, e.dmg or 0)
    end
    return table.concat(lines, "\n")
end

-- Every statistic, fastest time, unique count and first for every character and the account,
-- one row each, as raw numbers a spreadsheet can sort (times in seconds, money in copper,
-- distances in yards, firsts as Unix time).
local function CSVField(v) return ns.CSVField(v, true) end
local function CSVNumber(v)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "" end
    if v == math.floor(v) then return string.format("%.0f", v) end
    return string.format("%.3f", v)
end
function ns.CompendiumCSV()
    local cols, names = {}, {}
    for key, rec in pairs(ns.db.chars or {}) do
        if ns.ValidRecord(rec) then cols[#cols + 1] = { key = key, rec = rec } end
    end
    table.sort(cols, function(a, b) return a.key < b.key end)
    local header = { "section", "statistic", "unit" }
    for _, c in ipairs(cols) do header[#header + 1] = CSVField(c.key) end
    header[#header + 1] = "account"
    local account = ns.GetView("account", "lifetime")
    local views = {}
    for i, c in ipairs(cols) do views[i] = c.rec end
    views[#views + 1] = account
    local lines = { table.concat(header, ",") }
    local metadataRows = {}
    local function Row(section, label, unit, fn, stat)
        local parts = { CSVField(section), CSVField(label), CSVField(unit or "") }
        local statuses = {}
        for i, v in ipairs(views) do
            local ok, value = pcall(fn, v)
            local status = stat and ns.Measurement.Resolve(stat, v, { scope = i == #views and "account" or "character" })
            parts[#parts + 1] = ok and (not status or status.availability ~= "unavailable") and CSVNumber(value) or ""
            statuses[i] = status and ns.Measurement.Text(status) or "Derived provider; historical source coverage unknown."
        end
        metadataRows[#metadataRows + 1] = { section, label, statuses }
        lines[#lines + 1] = table.concat(parts, ",")
    end
    for _, cat in ipairs(ns.CATEGORIES) do
        for _, st in ipairs(ns.STATS[cat.id] or {}) do
            Row(cat.name, st.label, st.fmt, function(v) return (ns.StatValue(st, v)) end, st)
        end
    end
    for _, f in ipairs(ns.FASTEST or {}) do
        Row("Fastest", f.label, "time", function(v) local x = v.f[f.key] return type(x) == "table" and x.v or x end, f)
    end
    for _, u in ipairs(ns.UNIQUES or {}) do
        Row("Uniques", u.label, "int", function(v) return (v.un and v.un[u.set]) or 0 end, u)
    end
    for _, f in ipairs(ns.FIRSTS or {}) do
        Row("Firsts", f.label, "unix time", function(v) return v.firstd[f.key] end, f)
    end
    for _, l in ipairs(ns.LISTS or {}) do
        Row("Top lists", l.name .. " (entries)", "int", function(v)
            if l.count then return l.count(v) end
            local n = 0 for _ in pairs((v.t or {})[l.id] or {}) do n = n + 1 end return n
        end, l)
    end
    if ns.Score then Row("Score", "Adventurer score", "int", function(v) return (ns.Score(v)) end) end
    for _, row in ipairs(metadataRows) do
        local parts = { CSVField(row[1]), CSVField(row[2] .. " [measurement]"), CSVField("status/source/window/retention") }
        for _, value in ipairs(row[3]) do parts[#parts + 1] = CSVField(value:gsub("\n", " | ")) end
        lines[#lines + 1] = table.concat(parts, ",")
    end
    return table.concat(lines, "\n")
end

-- ------------------------------------------------------------ peak character stats
local STAT_KEYS = { "max_str", "max_agi", "max_sta", "max_int", "max_spi" }
local RES = { [2] = "max_res_fire", [3] = "max_res_nature", [4] = "max_res_frost", [5] = "max_res_shadow", [6] = "max_res_arcane" }

local function AvgItemLevel()
    if not GetInventoryItemLink then return nil end
    local sum, n = 0, 0
    for slot = 1, 18 do
        if slot ~= 4 then -- shirt
            local link = GetInventoryItemLink("player", slot)
            if link and not S(link) then
                local lvl
                if C_Item and C_Item.GetDetailedItemLevelInfo then lvl = N((C_Item.GetDetailedItemLevelInfo(link))) end
                if not lvl and GetItemInfo then lvl = N((select(4, GetItemInfo(link)))) end
                if lvl and lvl > 0 then sum = sum + lvl; n = n + 1 end
            end
        end
    end
    if n == 0 then return nil end
    return math.floor(sum / n * 10 + 0.5) / 10, n
end
ns.AvgItemLevel = AvgItemLevel

local pending = false
local function ScanStats()
    pending = false
    if not ns.char then return end
    for i = 1, 5 do
        local ok, _, eff = pcall(UnitStat, "player", i)
        if ok then Max(STAT_KEYS[i], N(eff) or 0) end
    end
    local ok, _, armor = pcall(UnitArmor, "player")
    if ok then Max("max_armor", N(armor) or 0) end
    local okH, hp = pcall(UnitHealthMax, "player"); if okH then Max("max_health", N(hp) or 0) end
    local okA, base, pos, neg = pcall(UnitAttackPower, "player")
    if okA and N(base) then Max("max_ap", (N(base) or 0) + (N(pos) or 0) + (N(neg) or 0)) end
    if GetCritChance then local c = N(GetCritChance()); if c then Max("max_crit_pct", math.floor(c * 100 + 0.5) / 100) end end
    if GetDodgeChance then local c = N(GetDodgeChance()); if c then Max("max_dodge_pct", math.floor(c * 100 + 0.5) / 100) end end
    if GetParryChance then local c = N(GetParryChance()); if c then Max("max_parry_pct", math.floor(c * 100 + 0.5) / 100) end end
    if GetBlockChance then local c = N(GetBlockChance()); if c then Max("max_block_pct", math.floor(c * 100 + 0.5) / 100) end end
    local sp, sc = 0, 0
    for school = 2, 7 do
        if GetSpellBonusDamage then local v = N(GetSpellBonusDamage(school)); if v and v > sp then sp = v end end
        if GetSpellCritChance then local v = N(GetSpellCritChance(school)); if v and v > sc then sc = v end end
    end
    if sp > 0 then Max("max_spellpower", sp) end
    if sc > 0 then Max("max_spellcrit_pct", math.floor(sc * 100 + 0.5) / 100) end
    if GetSpellBonusHealing then local v = N(GetSpellBonusHealing()); if v then Max("max_healpower", v) end end
    for i, key in pairs(RES) do
        local okR, _, total = pcall(UnitResistance, "player", i)
        if okR then Max(key, N(total) or 0) end
    end
    local il, slots = AvgItemLevel()
    if il and slots >= 3 then Max("max_ilvl", il) end
end
local function Queue()
    if pending or not C_Timer then return end
    pending = true
    C_Timer.After(2, function() local ok = pcall(ScanStats) if not ok then pending = false end end)
end
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "UNIT_INVENTORY_CHANGED" }) do
    On(ev, function(_, unit) if ev ~= "UNIT_INVENTORY_CHANGED" or unit == "player" then Queue() end end)
end
ns.ScanCharacterStats = ScanStats

-- ------------------------------------------------------------ reputation standings
-- Forever runs the Retail client: GetNumFactions/GetFactionInfo are gone, C_Reputation has them.
local function FactionStanding(i)
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
        local ok, data = pcall(C_Reputation.GetFactionDataByIndex, i)
        if ok and type(data) == "table" and not S(data) then
            return N(data.reaction), data.isHeader and not data.isHeaderWithRep
        end
        return nil
    end
    if GetFactionInfo then
        local ok, _, _, standing, _, _, _, _, _, isHeader, _, hasRep = pcall(GetFactionInfo, i)
        if ok then return N(standing), isHeader and not hasRep end
    end
end
function ns.OnFactionStandings(counts, total)
    ns.src.reputation = total
    Max("max_friendly", counts[5]); Max("max_honored", counts[6]); Max("max_revered", counts[7]); Max("max_exalted", counts[8])
end
local function ScanReputation()
    if not ns.char then return end
    local numFn = (C_Reputation and C_Reputation.GetNumFactions) or GetNumFactions
    if not numFn then return end
    local okN, total = pcall(numFn)
    if not okN or type(total) ~= "number" or S(total) then return end
    local counts = { [5] = 0, [6] = 0, [7] = 0, [8] = 0 }
    for i = 1, total do
        local standing, headerOnly = FactionStanding(i)
        if standing and not headerOnly then
            for s = 5, 8 do if standing >= s then counts[s] = counts[s] + 1 end end
        end
    end
    ns.OnFactionStandings(counts, total)
end
ns.ScanCharacterReputation = ScanReputation

-- ------------------------------------------------------------ battlegrounds
-- Called by Trackers when a battleground's winner is known.
function ns.OnBattlegroundEnd(run, won)
    if not run then return end
    local m = ns.char.meta
    Tally(won and "bgwins" or "bglosses", run.name or "?")
    if won then
        m.bgStreak = (m.bgStreak or 0) + 1
        Max("max_bg_streak", m.bgStreak, run.name)
    else
        m.bgStreak = 0
    end
    -- your scoreboard row: killing blows, honorable kills, deaths, honor, objectives
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    C_Timer.After(1, function()
        if not GetNumBattlefieldScores or not GetBattlefieldScore then return end
        local me = UnitName("player")
        for i = 1, GetNumBattlefieldScores() do
            local ok, name, kb, hk, deaths, honor = pcall(GetBattlefieldScore, i)
            if ok and type(name) == "string" and not S(name) and (name == me or name:match("^([^-]+)") == me) then
                kb, hk, deaths, honor = N(kb) or 0, N(hk) or 0, N(deaths) or 0, N(honor) or 0
                Add("bg_killing_blows", kb); Add("bg_hks", hk); Add("bg_deaths", deaths); Add("bg_honor", honor)
                Max("max_bg_kb", kb, run.name); Max("max_bg_hks", hk, run.name)
                if GetNumBattlefieldStats and GetBattlefieldStatInfo and GetBattlefieldStatData then
                    for j = 1, GetNumBattlefieldStats() do
                        local okI, label = pcall(GetBattlefieldStatInfo, j)
                        local okD, val = pcall(GetBattlefieldStatData, i, j)
                        val = okD and N(val)
                        if okI and type(label) == "string" and not S(label) and val and val > 0 then
                            Tally("bgobjectives", label, val)
                        end
                    end
                end
                return
            end
        end
    end)
end

-- Flag captures and returns from the battleground system messages.
local function BGSystem(_, msg)
    if type(msg) ~= "string" or S(msg) then return end
    local me = UnitName("player")
    if not me or not msg:find(me, 1, true) then return end
    local l = msg:lower()
    if l:find("captured the") then Add("bg_flags_captured")
    elseif l:find("returned the") then Add("bg_flags_returned")
    elseif l:find("picked up") then Add("bg_flags_picked")
    elseif l:find("assaulted") or l:find("claims the") or l:find("has taken") then Add("bg_bases_assaulted")
    elseif l:find("defended") then Add("bg_bases_defended") end
end
for _, ev in ipairs({ "CHAT_MSG_BG_SYSTEM_ALLIANCE", "CHAT_MSG_BG_SYSTEM_HORDE", "CHAT_MSG_BG_SYSTEM_NEUTRAL" }) do On(ev, BGSystem) end

-- ------------------------------------------------------------ Adventurer Score
-- A single number for how far this character has come. Parts and weights:
ns.SCORE_PARTS = {
    { "Level",        function(v) return ((v.meta and v.meta.level) or 0) * 100 end, "100 per level" },
    { "Quests",       function(v) return ((v.c and v.c.quests_done) or 0) * 10 end, "10 per quest" },
    { "Exploration",  function(v) return ((v.un and v.un.zones) or 0) * 25 + ((v.un and v.un.subzones) or 0) * 5 end, "25 per zone, 5 per subzone" },
    { "Dungeons",     function(v) return ((v.un and v.un.dungeons_cleared) or 0) * 200 + ((v.c and v.c.dj_bosses_found) or 0) * 20 + ((v.c and v.c.boss_kills_raid) or 0) * 50 end, "200 per dungeon cleared, 20 per boss found, 50 per raid boss" },
    { "Achievements", function(v) local _, _, pts = ns.AchTotals(v) return pts or 0 end, "1 per achievement point" },
    { "Professions",  function(v) local n = 0 for _, x in pairs((v.t and v.t.skills) or {}) do n = n + x end return n * 2 end, "2 per skill-up" },
    { "Gear",         function(v) return math.floor(((v.r and v.r.max_ilvl) or 0) * 10) end, "10 per point of your best average item level" },
    { "Wealth",       function(v) return math.floor(((v.c and v.c.money_in) or 0) / 10000) * 2 end, "2 per gold earned" },
    { "Deaths",       function(v) return -((v.c and v.c.deaths) or 0) * 25 end, "-25 per death" },
}
function ns.Score(v)
    v = v or ns.char
    if not v then return 0, {} end
    local total, parts = 0, {}
    for i, p in ipairs(ns.SCORE_PARTS) do
        local ok, val = pcall(p[2], v)
        val = ok and math.floor(val or 0) or 0
        parts[i] = { p[1], val, p[3] }
        total = total + val
    end
    return math.max(0, total), parts
end
function ns.ScoreText(v)
    local total, parts = ns.Score(v)
    local out = { "Adventurer score: " .. ns.FormatInt(total), "" }
    for _, p in ipairs(parts) do out[#out + 1] = p[1] .. ": " .. ns.FormatInt(p[2]) .. "   · " .. p[3] end
    return table.concat(out, "\n")
end

-- ------------------------------------------------------------ one-time data repairs
-- 1.12.2: (a) all-caps internal spells (e.g. LOGINEFFECT) and "Attack" in the cast list;
-- (b) deaths wrongly blamed on Fatigue by versions before 1.5 (mirror timer bug) move to Unknown;
-- (c) the level you installed on gets a starting mark and snapshot so per-level tables show it.
local function Repair()
    local ch = ns.char
    if not ch then return end
    local m = ch.meta
    m.repairs = m.repairs or {}
    if not m.repairs.spells then
        m.repairs.spells = true
        local t = ch.t.spells
        if t then
            for k, v in pairs(t) do
                if type(k) == "string" and k:match("^%u+$") then t[k] = nil; ch.c.casts = math.max(0, (ch.c.casts or 0) - v) end
            end
            for _, old in ipairs({ "Attack", "Auto Attack" }) do
                if t[old] then t.Melee = (t.Melee or 0) + t[old]; t[old] = nil end
            end
        end
    end
    if not m.repairs.fatigue then
        m.repairs.fatigue = true
        local n = ch.c.deaths_fatigue or 0
        local killers = ch.t.killers or {}
        if n > 0 then
            ch.c.deaths_fatigue = 0
            ch.c.deaths_npc = (ch.c.deaths_npc or 0) + n
            local f = killers.Fatigue or 0
            if f > 0 then killers.Fatigue = nil; killers.Unknown = (killers.Unknown or 0) + f end
            for _, d in pairs(ch.days or {}) do
                if d.deaths_fatigue then d.deaths_npc = (d.deaths_npc or 0) + d.deaths_fatigue; d.deaths_fatigue = nil end
            end
        end
        local fd = ch.first and ch.first.death
        if fd == "Fatigue" then ch.first.death = "Unknown" end
        if type(fd) == "table" and fd[1] == "Fatigue" then fd[1] = "Unknown" end
        if type(fd) == "table" and fd.v == "Fatigue" then fd.v = "Unknown" end
        for _, e in ipairs(ch.journal or {}) do
            if type(e[2]) == "string" then e[2] = e[2]:gsub("^Died to Fatigue", "Died"):gsub(": Fatigue$", ": Unknown") end
        end
    end
    local lvl = UnitLevel("player")
    if lvl and lvl > 0 and not m.levelMark then
        m.levelMark, m.levelMarkLevel, m.levelMarkPartial = ch.c.time_online or 0, lvl, true
    end
    ch.lvlsnap = ch.lvlsnap or {}
    if lvl and not ch.lvlsnap[tostring(lvl)] and next(ch.lvlsnap) == nil and ns.LevelSnapshotQuiet then
        ns.LevelSnapshotQuiet(lvl, true)
    end
end
On("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload) if isLogin or isReload then pcall(Repair) end end)
ns.RepairData = Repair

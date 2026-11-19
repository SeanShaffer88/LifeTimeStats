-- LifeTimeStats - text backup / restore
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
-- Format: "LTS2|<checksum>|" then "section.key=value" (flat) or "section.group.key=value"
-- (nested) entries joined by ";". Values are numbers, or text written as "s:<escaped>".
-- Importing only ever stores numbers and plain text, so it can never run code.
local _, ns = ...

local FLAT = { "c", "r", "f", "fw", "fd", "first", "firstd", "ach", "achr" }
local NESTED = { "t", "u", "days", "rh" }
local IS_FLAT, IS_NESTED = {}, {}
for _, k in ipairs(FLAT) do IS_FLAT[k] = true end
for _, k in ipairs(NESTED) do IS_NESTED[k] = true end

local function Esc(s)
    return (tostring(s):gsub("[%%;=%.|:%s]", function(ch) return string.format("%%%02X", ch:byte()) end))
end
local function Unesc(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function Checksum(s, progress)
    local sum = 0
    for i = 1, #s do
        sum = (sum * 31 + s:byte(i)) % 16777213
        if progress and i % 16384 == 0 then progress("Checking checksum", i, #s) end
    end
    return string.format("%06x", sum)
end

local function Val(v)
    if type(v) == "boolean" then return v and "1" or "0" end
    if type(v) == "string" then return "s:" .. Esc(v) end
    if v == math.floor(v) then return string.format("%.0f", v) end
    return string.format("%.3f", v)
end

local function SortedKeys(t)
    local keys = {}
    for k, v in pairs(t) do
        local tv = type(v)
        if tv == "number" or tv == "string" or tv == "boolean" or tv == "table" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function CaptureLegacyBody(rec)
    local parts = {}
    for _, sec in ipairs(FLAT) do
        local t = rec[sec] or {}
        for _, k in ipairs(SortedKeys(t)) do
            if type(t[k]) ~= "table" then parts[#parts + 1] = sec .. "." .. Esc(k) .. "=" .. Val(t[k]) end
        end
    end
    for _, sec in ipairs(NESTED) do
        local t = rec[sec] or {}
        for _, g in ipairs(SortedKeys(t)) do
            local inner = t[g]
            if type(inner) == "table" then
                for _, k in ipairs(SortedKeys(inner)) do
                    if type(inner[k]) ~= "table" then
                        parts[#parts + 1] = sec .. "." .. Esc(g) .. "." .. Esc(k) .. "=" .. Val(inner[k])
                    end
                end
            end
        end
    end
    return table.concat(parts, ";")
end

local function EncodeLegacyBody(body, progress)
    return "LTS2|" .. Checksum(body, progress) .. "|" .. body
end

function ns.Serialize(rec)
    return EncodeLegacyBody(CaptureLegacyBody(rec))
end

local function ParseValue(raw)
    if raw:sub(1, 2) == "s:" then return Unesc(raw:sub(3)) end
    if not raw:match("^%-?%d+%.?%d*$") then return nil end
    local n = tonumber(raw)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

-- Returns a record-like table, entry count — or nil, error.
local MAX_LEGACY_INPUT, MAX_LEGACY_ENTRIES = 8 * 1024 * 1024, 250000
local function LegacyString(value)
    return #value <= 4096 and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

function ns.Deserialize(str, progress)
    if type(str) ~= "string" or ns.IsSecret(str) then return nil, "empty" end
    if #str > MAX_LEGACY_INPUT then return nil, "backup is too large" end
    str = str:gsub("%s", "")
    local head, sum, body = str:match("^(LTS%d+)|(%x+)|(.*)$")
    if head ~= "LTS1" and head ~= "LTS2" then return nil, "not a LifeTimeStats backup" end
    if Checksum(body, progress) ~= sum then return nil, "checksum mismatch (text was cut off or edited)" end
    local out = {}
    for _, k in ipairs(FLAT) do out[k] = {} end
    for _, k in ipairs(NESTED) do out[k] = {} end
    local n = 0
    for entry in body:gmatch("[^;]+") do
        if n >= MAX_LEGACY_ENTRIES then return nil, "too many backup entries" end
        local path, raw = entry:match("^([^=]+)=(.+)$")
        if not path then return nil, "malformed entry" end
        local val = ParseValue(raw)
        if val == nil or (type(val) == "string" and not LegacyString(val)) then return nil, "malformed value" end
        local a, b, c = path:match("^([^%.]+)%.([^%.]+)%.?([^%.]*)$")
        if b then b, c = Unesc(b), Unesc(c) end
        if not b or b == "" or not LegacyString(b) or not LegacyString(c) then return nil, "malformed key" end
        if IS_FLAT[a] and c == "" then
            if a == "f" and (type(val) ~= "number" or val <= 0) then return nil, "invalid duration" end
            if (a == "c" or a == "fd" or a == "firstd" or a == "ach") and type(val) ~= "number" then
                return nil, "invalid numeric field"
            end
            out[a][b] = val
        elseif IS_NESTED[a] and c ~= "" then
            if (a == "days" or a == "t" or a == "u") and type(val) ~= "number" then return nil, "invalid numeric entry" end
            if a == "days" and not b:match("^%d%d%d%d%d%d%d%d$") then return nil, "invalid day" end
            local g = b
            if a == "rh" and g:match("^%d+$") then g = tonumber(g) end
            out[a][g] = out[a][g] or {}
            if a == "u" then out[a][g][c] = val ~= 0 and true or nil
            else out[a][g][c] = val end
        else
            return nil, "malformed entry"
        end
        n = n + 1
        if progress and n % 512 == 0 then progress("Reading entries", n) end
    end
    return out, n
end

-- The coroutine owns only private backup state and never mutates the character. A
-- canceled job releases that state immediately, even if a timer is still queued.
local function RunBackupJob(input, operation, sync, finished, status)
    local worker = coroutine.create(function()
        return operation(input, coroutine.yield)
    end)
    local function Step()
        if not worker then return end
        local ok, value, count, total = coroutine.resume(worker)
        if not ok or coroutine.status(worker) == "dead" then
            worker = nil
            if ok then finished(value, count) else finished(nil, value) end
            return
        end
        if status then status(value, count, total) end
        C_Timer.After(0, Step)
    end
    if not C_Timer or not C_Timer.After then
        worker = nil
        finished(sync(input))
    else
        Step()
    end
    return function() worker = nil end
end

function ns.ReadLegacyBackup(text, finished, status)
    return RunBackupJob(text, ns.Deserialize, ns.Deserialize, finished, status)
end

function ns.WriteLegacyBackup(rec, finished, status)
    -- Capture without yielding so counters cannot change during collection.
    local ok, body = pcall(CaptureLegacyBody, rec)
    if not ok then finished(nil, body); return end
    return RunBackupJob(body, EncodeLegacyBody, EncodeLegacyBody, finished, status)
end

local function MergeHistory(dst, src)
    local records, seen = {}, {}
    local function Collect(history, imported)
        for _, entry in ipairs(history) do
            if type(entry) == "table" and type(entry.k) == "string" and entry.k ~= ""
                and not ns.BadNumber(entry.v) and not ns.BadNumber(entry.at)
                and (entry.d == "max" or entry.d == "min") then
                -- Use the precision already used by LTS2 so a record's own
                -- rounded backup value does not become a second milestone.
                local key = entry.d .. ":" .. Val(entry.at) .. ":" .. Val(entry.v) .. ":" .. entry.k
                if not seen[key] then
                    seen[key] = true
                    records[#records + 1] = { entry = entry, order = #records + 1, imported = imported }
                end
            end
        end
    end
    Collect(dst.rh, false)
    Collect(src.rh or {}, true)
    table.sort(records, function(a, b)
        if a.entry.at == b.entry.at then return a.order < b.order end
        return a.entry.at < b.entry.at
    end)
    local latest, changed = {}, 0
    for i = math.max(1, #records - ns.RECORD_HISTORY_CAP + 1), #records do
        local record = records[i]
        latest[#latest + 1] = record.entry
        if record.imported then changed = changed + 1 end
    end
    dst.rh = latest
    return changed
end

-- Counters/records/tallies keep the larger number,
-- unique sets are unioned, fastest times keep the smaller time, firsts keep the earliest.
function ns.MergeMax(dst, src)
    ns.EnsureRecord(dst)
    local changed = 0
    for k, v in pairs(src.c or {}) do
        if type(v) == "number" and v > (dst.c[k] or 0) then dst.c[k] = v; changed = changed + 1 end
    end
    for k, v in pairs(src.r or {}) do
        if type(v) == "number" then
            if v > (dst.r[k] or 0) then
                dst.r[k] = v
                dst.r[k .. "_what"] = src.r[k .. "_what"]
                changed = changed + 1
            end
        end
    end
    for tn, t in pairs(src.t or {}) do
        dst.t[tn] = dst.t[tn] or {}
        for k, v in pairs(t) do
            if type(v) == "number" and v > (dst.t[tn][k] or 0) then dst.t[tn][k] = v; changed = changed + 1 end
        end
    end
    for set, t in pairs(src.u or {}) do
        dst.u[set] = dst.u[set] or {}
        for k in pairs(t) do
            k = ns.UniqueKey(k)
            if not dst.u[set][k] then dst.u[set][k] = true; changed = changed + 1 end
        end
    end
    for k, v in pairs(src.f or {}) do
        if type(v) == "number" and (not dst.f[k] or v < dst.f[k]) then
            dst.f[k], dst.fw[k], dst.fd[k] = v, (src.fw or {})[k], (src.fd or {})[k]
            changed = changed + 1
        end
    end
    for k, when in pairs(src.firstd or {}) do
        if type(when) == "number" and (not dst.firstd[k] or when < dst.firstd[k]) then
            dst.firstd[k], dst.first[k] = when, (src.first or {})[k]
            changed = changed + 1
        end
    end
    for k, when in pairs(src.ach or {}) do
        if type(when) == "number" and (not dst.ach[k] or when < dst.ach[k]) then
            dst.ach[k] = when
            dst.achr[k] = (src.achr or {})[k] and true or nil
            changed = changed + 1
        end
    end
    for d, day in pairs(src.days or {}) do
        dst.days[d] = dst.days[d] or {}
        for k, v in pairs(day) do
            if type(v) == "number" and v > (dst.days[d][k] or 0) then dst.days[d][k] = v; changed = changed + 1 end
        end
    end
    changed = changed + MergeHistory(dst, src)
    ns.EnsureRecord(dst) -- recount unique sets
    return changed
end

-- Legacy restores prepare a private copy of only the fields the merge can change.
function ns.MergeLegacyBackup(parsed, preview)
    if type(parsed) ~= "table" then return nil, "invalid backup" end
    local dst = ns.char
    if not dst then return nil, "no active character" end
    local function Copy(value, depth)
        if type(value) ~= "table" then return value end
        if depth == 0 then error("invalid existing record structure", 0) end
        local copy = {}
        for k, v in pairs(value) do copy[k] = Copy(v, depth - 1) end
        return copy
    end
    local fields = { "c", "r", "f", "fw", "fd", "first", "firstd", "ach", "achr", "t", "u", "days", "rh", "un" }
    local staged = {}
    local ok, changed = pcall(function()
        for _, key in ipairs(fields) do staged[key] = Copy(dst[key], 4) end
        local result = ns.MergeMax(staged, parsed)
        ns.TrimTallyBuckets(staged)
        for _, count in pairs(staged.un) do
            if count > ns.UNIQUE_CAP then error("merged unique set exceeds the retention limit", 0) end
        end
        return result
    end)
    if not ok then return nil, changed end
    if preview then return changed end
    for _, key in ipairs(fields) do dst[key] = staged[key] end
    ns.InvalidateAccount()
    return changed
end

function ns.RestoreLegacyBackup(text)
    local parsed, why = ns.Deserialize(text)
    if not parsed then return nil, why end
    return ns.MergeLegacyBackup(parsed)
end

-- LTS3 full snapshots use an ASCII-only, length-prefixed tree of maps, text,
-- numbers and booleans. The checksum detects accidental changes to the text.
-- Only the durable character fields below can cross the restore boundary.
local FULL_HEADER = "LTS3|"
local MAX_FULL_BYTES = 8 * 1024 * 1024
local MAX_FULL_INPUT = MAX_FULL_BYTES + 64 * 1024
local MAX_FULL_NODES = 700000
local MAX_FULL_DEPTH = 6
local MAX_TEXT_BYTES = 4096
local MAX_ID = 9007199254740990
local MAX_IMPORTED_SESSION_ID = MAX_ID - 65536
local MAX_TIMESTAMP = 4102444800 -- 2100-01-01
local IsSecret = ns.IsSecret

local function Require(condition, message)
    if not condition then error(message, 0) end
end

local function Attempt(operation)
    local ok, result = pcall(operation)
    if not ok then return nil, result end
    return result
end

local function PlainTable(value)
    return type(value) == "table" and not IsSecret(value) and getmetatable(value) == nil
end

local function Number(value)
    return not IsSecret(value) and not ns.BadNumber(value)
end

local function Integer(value, minimum, maximum)
    return Number(value) and value >= minimum and value <= maximum and value % 1 == 0
end

local function Timestamp(value) return Integer(value, 0, MAX_TIMESTAMP) end
local function Nonnegative(value) return Number(value) and value >= 0 end
local function Duration(value) return Number(value) and value > 0 and value <= MAX_TIMESTAMP end
local function Level(value) return Integer(value, 0, 1000) end
local function ID(value) return Integer(value, 1, MAX_ID) end
local function Boolean(value) return type(value) == "boolean" and not IsSecret(value) end
local function Text(value)
    return type(value) == "string" and not IsSecret(value) and #value <= MAX_TEXT_BYTES
        and not value:find("[%z\1-\8\11\12\14-\31\127]")
end

local function Key(value)
    return Text(value) and value ~= "" and not value:find("[\n\r\t]")
end

local function Note(value)
    if not Text(value) or not value:find("%S") or value:find("[\r\t]") then return false end
    local limit = ns.JOURNAL_NOTE_LIMIT or 500
    if #value > limit * 4 then return false end
    local index, count = 1, 0
    while index <= #value do
        local lead = value:byte(index)
        local width
        if lead < 128 then width = 1
        elseif lead >= 194 and lead <= 223 then width = 2
        elseif lead >= 224 and lead <= 239 then width = 3
        elseif lead >= 240 and lead <= 244 then width = 4
        else return false end
        if width > 1 then
            local second = value:byte(index + 1) or 0
            if (lead == 224 and second < 160) or (lead == 237 and second > 159)
                or (lead == 240 and second < 144) or (lead == 244 and second > 143) then return false end
            for offset = 1, width - 1 do
                local byte = value:byte(index + offset) or 0
                if byte < 128 or byte > 191 then return false end
            end
        end
        index, count = index + width, count + 1
        if count > limit then return false end
    end
    return true
end

local function MonthKey(value)
    if type(value) ~= "string" or IsSecret(value) then return false end
    local year, month = value:match("^(%d%d%d%d)(%d%d)$")
    year, month = tonumber(year), tonumber(month)
    return year ~= nil and year >= 1970 and year <= 2100 and month >= 1 and month <= 12
end

local function DayKey(value)
    if type(value) ~= "string" or IsSecret(value) then return false end
    local year, month, day = value:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or year < 1970 or year > 2100 or month < 1 or month > 12 or day < 1 then return false end
    local days = ({ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[month]
    if month == 2 and year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then days = 29 end
    return day <= days
end

local FULL_META = {
    created = Timestamp, achInit = Boolean, achUnseen = Nonnegative, levelMark = Nonnegative,
    levelMarkLevel = Level, levelMarkPartial = Boolean, bgStreak = Nonnegative, repairs = true,
    monthsThrough = function(value) return DayKey(value) end,
}
local FULL_FIELDS = {
    "c", "r", "t", "u", "f", "fw", "fd", "first", "firstd", "days", "months", "ach", "achr",
    "rh", "journal", "lvlsnap", "zonelog", "sessionlog", "runlog", "bestiary", "people", "reps", "items", "goals", "quests", "skills", "deathlog", "meta",
}
local FULL_FIELD_SET = {}
for _, field in ipairs(FULL_FIELDS) do FULL_FIELD_SET[field] = true end

local JOURNAL_KINDS = { first = true, boss = true, death = true, personalBest = true }
local JOURNAL_ROW = {
    [1] = Timestamp, [2] = function(value) return Text(value) and value ~= "" end,
    [3] = Level, zone = Key, note = Note,
    kind = function(value) return Key(value) and JOURNAL_KINDS[value] end,
}
local RECORD_ROW = {
    k = Key, v = Number, at = Timestamp, w = Text,
    d = function(value) return not IsSecret(value) and (value == "min" or value == "max") end,
}
local LEVEL_ROW = {
    t = Timestamp, partial = Boolean, dist_foot = Nonnegative, jumps = Nonnegative, kills_npc = Nonnegative,
    kills_pvp = Nonnegative, deaths = Nonnegative, quests_done = Nonnegative, money_in = Nonnegative,
    time_online = Nonnegative, critter_kills = Nonnegative, times_drunk = Nonnegative,
    gold = Nonnegative, il = Nonnegative, played = Nonnegative, zone = Text,
    str = Nonnegative, agi = Nonnegative, sta = Nonnegative, int = Nonnegative, spi = Nonnegative,
}
local ZONE_ROW = { [1] = Timestamp, [2] = Level, [3] = Timestamp }
local RUN_ROW = {
    s = Timestamp, e = Timestamp, n = Text, k = Key, l = Level, b = Nonnegative, de = Nonnegative,
    w = Nonnegative, g = Nonnegative, m = Text, c = Boolean, loot = Nonnegative,
}
local BESTIARY_ROW = {
    k = Nonnegative, f = Timestamp, l = Timestamp, z = Text, ty = Text, cl = Text, lo = Level, hi = Level,
}
local SESSION_ROW = {
    id = function(value) return Integer(value, 1, MAX_IMPORTED_SESSION_ID) end,
    s = Timestamp, d = Timestamp, afk = Timestamp, l = Level, steps = Nonnegative,
    k = Nonnegative, de = Nonnegative, q = Nonnegative, xp = Nonnegative, dmg = Nonnegative, z = Text,
    g = Number, mi = Nonnegative, lv = Nonnegative, it = Nonnegative, gh = Nonnegative,
}
local function StandingDates(value)
    if type(value) ~= "table" or IsSecret(value) or getmetatable(value) ~= nil then return false end
    for k, v in pairs(value) do
        if not Integer(k, 1, 8) or not Timestamp(v) then return false end
    end
    return true
end
local REP_ROW = { s = function(v) return Integer(v, 1, 8) end, c = Nonnegative, m = Nonnegative, f = Timestamp, u = Timestamp, h = StandingDates, war = Boolean }
local ITEM_ROW = { t = Timestamp, n = Text, id = Nonnegative, q = function(v) return Integer(v, 0, 8) end, src = Key, from = Text, z = Text, l = Level, il = Nonnegative, c = Nonnegative }
local GOAL_ROW = { id = Key, target = Nonnegative, t = Timestamp, done = Timestamp }
local QUEST_ROW = { t = Timestamp, id = Nonnegative, n = Text, z = Text, l = Level, xp = Nonnegative, g = Nonnegative, d = Nonnegative }
local function Fraction(v) return Number(v) and v >= -0.5 and v <= 1.5 end
local DEATH_ROW = { t = Timestamp, m = Nonnegative, x = Fraction, y = Fraction, z = Text, c = Text, l = Level }
local function RankDates(value)
    if type(value) ~= "table" or IsSecret(value) or getmetatable(value) ~= nil then return false end
    for k, v in pairs(value) do
        if not Integer(k, 0, 1000) or not Timestamp(v) then return false end
    end
    return true
end
local SKILL_ROW = { f = Timestamp, r = Nonnegative, h = RankDates }
local PERSON_ROW = {
    f = Timestamp, l = Timestamp, n = Nonnegative, t = Nonnegative, cls = Key, lvl = Level, z = Text,
}

local function StageFullSnapshot(snapshot, exportLegacy, progress)
    Require(PlainTable(snapshot) and Key(snapshot.character) and Timestamp(snapshot.savedAt)
        and PlainTable(snapshot.record), "The full backup has an invalid header.")
    for key in pairs(snapshot) do
        Require(key == "character" or key == "savedAt" or key == "record" or key == "noteCount",
            "The full backup has unexpected header fields.")
    end
    local source = snapshot.record
    local record, fields, noteCount = {}, 0, 0
    for key in pairs(source) do
        Require(FULL_FIELD_SET[key], "The full backup has unknown character fields.")
    end

    local section
    local function Check(value)
        if not value then error("The full backup has invalid " .. section .. " data.", 0) end
    end
    local function CountField()
        fields = fields + 1
        if progress and fields % 512 == 0 then progress("Validating character data", fields) end
        Require(fields <= MAX_FULL_NODES, "The full backup contains too many entries.")
    end
    local function Map(input, validKey, convertValue)
        Check(PlainTable(input))
        local result = {}
        for key, value in pairs(input) do
            CountField()
            Check(validKey(key))
            result[key] = convertValue(value, key)
        end
        return result
    end
    local function Scalar(rule)
        return function(value)
            Check(rule(value))
            return value
        end
    end
    local function Row(input, rules, required)
        local result = Map(input, function(key) return not IsSecret(key) and rules[key] ~= nil end, function(value, key)
            Check(rules[key](value))
            return value
        end)
        for _, key in ipairs(required) do Check(result[key] ~= nil) end
        return result
    end
    local function Sequence(input, limit, convertRow)
        Check(PlainTable(input))
        local count = 0
        for key in pairs(input) do
            Check(Integer(key, 1, limit))
            count = count + 1
        end
        local result = {}
        for index = 1, count do
            CountField()
            result[index] = convertRow(input[index], index)
        end
        return result
    end
    local function StringOrID(value) return Key(value) or ID(value) end

    section = "counters"; record.c = Map(source.c, Key, Scalar(Number))
    section = "records"; record.r = Map(source.r, Key, function(value, key)
        if key:sub(-5) == "_what" then Check(Text(value)) else Check(Number(value)) end
        return value
    end)
    section = "tallies"; record.t = Map(source.t, Key, function(tally) return Map(tally, StringOrID, Scalar(Number)) end)
    section = "unique discoveries"; record.u = Map(source.u, Key, function(set)
        Check(PlainTable(set))
        local result = {}
        for key, value in pairs(set) do
            CountField()
            Check(StringOrID(key) and not IsSecret(value) and (value == true or value == 1))
            result[ns.UniqueKey(key)] = true
        end
        return result
    end)
    section = "fastest times"; record.f = Map(source.f, Key, Scalar(Duration))
    section = "fastest time labels"; record.fw = Map(source.fw, Key, Scalar(Text))
    section = "fastest time dates"; record.fd = Map(source.fd, Key, Scalar(Timestamp))
    local legacyDeathDate
    section = "first milestones"; record.first = Map(source.first, Key, function(value, key)
        if not exportLegacy or key ~= "death" or not PlainTable(value) then
            Check(Text(value))
            return value
        end
        -- Older saves can carry the first-death label in a tuple or a v
        -- field. Export it in the current shape without editing the save.
        local label
        for field, fieldValue in pairs(value) do
            CountField()
            if field == 1 or field == "v" then
                Check(Text(fieldValue) and (label == nil or label == fieldValue))
                label = fieldValue
            else
                Check((field == 2 or field == "at" or field == "t") and Timestamp(fieldValue)
                    and (legacyDeathDate == nil or legacyDeathDate == fieldValue))
                legacyDeathDate = fieldValue
            end
        end
        Check(label ~= nil)
        return label
    end)
    section = "first milestone dates"; record.firstd = Map(source.firstd, Key, Scalar(Timestamp))
    if legacyDeathDate then
        Check(record.firstd.death == nil or record.firstd.death == legacyDeathDate)
        record.firstd.death = legacyDeathDate
    end
    section = "daily history"; record.days = Map(source.days, DayKey, function(day) return Map(day, Key, Scalar(Number)) end)
    -- Monthly totals arrived in 1.15; older full backups simply have none.
    section = "monthly history"; record.months = Map(source.months == nil and {} or source.months, MonthKey,
        function(month) return Map(month, Key, Scalar(Number)) end)
    section = "achievement dates"; record.ach = Map(source.ach, Key, Scalar(Timestamp))
    section = "retroactive achievements"; record.achr = Map(source.achr, Key, Scalar(Boolean))
    section = "personal-best history"; record.rh = Sequence(source.rh, ns.RECORD_HISTORY_CAP or 200, function(row)
        return Row(row, RECORD_ROW, { "k", "v", "at", "d" })
    end)
    section = "Journal"; record.journal = Sequence(source.journal, 600, function(row)
        local result = Row(row, JOURNAL_ROW, { 1, 2, 3 })
        if result.note then noteCount = noteCount + 1 end
        return result
    end)
    section = "level history"; record.lvlsnap = Map(source.lvlsnap, function(key)
        return Key(key) and key:match("^%d+$") and Level(tonumber(key))
    end, function(row) return Row(row, LEVEL_ROW, { "t" }) end)
    section = "travel log"; record.zonelog = Map(source.zonelog, Key, function(row) return Row(row, ZONE_ROW, { 1, 2 }) end)
    -- Run history and bestiary arrived in 1.15; older full backups have neither.
    section = "dungeon run history"; record.runlog = Sequence(source.runlog == nil and {} or source.runlog, ns.RUNLOG_CAP or 200, function(row)
        return Row(row, RUN_ROW, { "s" })
    end)
    -- Reputation history, item log and goals arrived in 1.19.
    section = "reputation history"; record.reps = Map(source.reps == nil and {} or source.reps, Key, function(row)
        return Row(row, REP_ROW, { "s" })
    end)
    section = "item log"; record.items = Sequence(source.items == nil and {} or source.items, ns.ITEM_LOG_CAP or 1000, function(row)
        return Row(row, ITEM_ROW, { "t" })
    end)
    -- Quest history, profession history and the death log arrived in 1.20.
    section = "quest history"; record.quests = Sequence(source.quests == nil and {} or source.quests, ns.QUEST_LOG_CAP or 1000, function(row)
        return Row(row, QUEST_ROW, { "t" })
    end)
    section = "profession history"; record.skills = Map(source.skills == nil and {} or source.skills, Key, function(row)
        return Row(row, SKILL_ROW, {})
    end)
    section = "death log"; record.deathlog = Sequence(source.deathlog == nil and {} or source.deathlog, ns.DEATH_LOG_CAP or 500, function(row)
        return Row(row, DEATH_ROW, { "t" })
    end)
    section = "goals"; record.goals = Sequence(source.goals == nil and {} or source.goals, ns.GOAL_CAP or 20, function(row)
        return Row(row, GOAL_ROW, { "id", "target" })
    end)
    section = "people you grouped with"; record.people = Map(source.people == nil and {} or source.people, Key, function(row)
        return Row(row, PERSON_ROW, {})
    end)
    section = "bestiary"; record.bestiary = Map(source.bestiary == nil and {} or source.bestiary, Key, function(row)
        return Row(row, BESTIARY_ROW, { "k" })
    end)
    local sessionIDs = {}
    section = "session history"; record.sessionlog = Sequence(source.sessionlog, 300, function(row)
        local result = Row(row, SESSION_ROW, { "s", "d" })
        if result.id then
            Check(not sessionIDs[result.id])
            sessionIDs[result.id] = true
        end
        return result
    end)
    section = "character history settings"; record.meta = Map(source.meta, function(key)
        return Key(key) and FULL_META[key] ~= nil
    end, function(value, key)
        if key == "repairs" then return Map(value, Key, Scalar(Boolean)) end
        return Scalar(FULL_META[key])(value)
    end)
    return { character = snapshot.character, savedAt = snapshot.savedAt, record = record, noteCount = noteCount }
end

local function FullChecksum(body, progress)
    local a, b = 1, 0
    for i = 1, #body do
        a = (a + body:byte(i)) % 65521
        b = (b + a) % 65521
        if progress and i % 16384 == 0 then progress("Checking checksum", i, #body) end
    end
    -- Format two safe 16-bit values so the result is independent of C int size.
    return string.format("%04x%04x", b, a)
end

local function FullEscape(value)
    return (value:gsub("[|%z\1-\32\127-\255%%]", function(byte)
        return string.format("%%%02X", byte:byte())
    end))
end

local DECIMAL_POINT = string.format("%.1f", 0.5):match("^0(.+)5$") or "."
local function FullNumber(value)
    local text = string.format("%.17g", value)
    if DECIMAL_POINT ~= "." then
        local separator = text:find(DECIMAL_POINT, 1, true)
        if separator then
            text = text:sub(1, separator - 1) .. "." .. text:sub(separator + #DECIMAL_POINT)
        end
    end
    return text
end

local function FullKeyLess(a, b)
    if type(a) ~= type(b) then return type(a) == "number" end
    if type(a) == "number" then return a < b end
    -- Compare text keys byte-for-byte for the same output in every locale.
    for index = 1, math.min(#a, #b) do
        local left, right = a:byte(index), b:byte(index)
        if left ~= right then return left < right end
    end
    return #a < #b
end

local function EncodeFull(root, progress)
    local parts, active, size, nodes = {}, {}, 0, 0
    local function Emit(part)
        size = size + #part
        Require(size <= MAX_FULL_BYTES, "This character is too large for a full text backup.")
        parts[#parts + 1] = part
    end
    local function Value(value, depth)
        nodes = nodes + 1
        if progress and nodes % 512 == 0 then progress("Encoding character backup", nodes) end
        Require(nodes <= MAX_FULL_NODES and depth <= MAX_FULL_DEPTH, "The full backup contains too many entries.")
        local kind = type(value)
        if kind == "table" then
            Require(PlainTable(value) and not active[value], "The full backup contains invalid data.")
            active[value] = true
            local keys = {}
            for key in pairs(value) do
                Require(Key(key) or ID(key), "The full backup contains an invalid key.")
                keys[#keys + 1] = key
            end
            table.sort(keys, FullKeyLess)
            Emit("m" .. #keys .. ":")
            for _, key in ipairs(keys) do
                Value(key, depth + 1)
                Value(value[key], depth + 1)
            end
            active[value] = nil
        elseif kind == "string" then
            Require(Text(value), "The full backup contains invalid text.")
            local ascii = FullEscape(value)
            Emit("s" .. #ascii .. ":" .. ascii)
        elseif kind == "number" then
            Require(Number(value), "The full backup contains an invalid number.")
            Emit("n" .. FullNumber(value) .. ";")
        else
            Require(Boolean(value), "The full backup has an invalid value.")
            Emit(value and "t" or "f")
        end
    end
    Value(root, 1)
    return table.concat(parts)
end

local function DecodeFull(body, progress)
    local position, nodes = 1, 0
    local malformed = "The full backup text is malformed."
    local function Size(limit)
        local separator = body:find(":", position, true)
        Require(separator and separator > position and separator - position <= 8, malformed)
        local digits = body:sub(position, separator - 1)
        Require(digits:match("^%d+$"), malformed)
        local size = tonumber(digits)
        Require(size <= limit, "The full backup contains too many entries.")
        position = separator + 1
        return size
    end
    local function Value(depth)
        nodes = nodes + 1
        Require(nodes <= MAX_FULL_NODES and depth <= MAX_FULL_DEPTH, "The full backup contains too many entries.")
        if progress and nodes % 512 == 0 then progress("Reading character backup", position - 1, #body) end
        local tag = body:sub(position, position)
        position = position + 1
        if tag == "m" then
            local count = Size(math.floor((MAX_FULL_NODES - nodes) / 2))
            local result = {}
            for _ = 1, count do
                local key = Value(depth + 1)
                Require((Key(key) or ID(key)) and result[key] == nil, "The full backup contains an invalid or duplicate key.")
                result[key] = Value(depth + 1)
            end
            return result
        end
        if tag == "s" then
            local size = Size(MAX_TEXT_BYTES * 3)
            Require(position + size - 1 <= #body, malformed)
            local ascii = body:sub(position, position + size - 1)
            position = position + size
            Require(not ascii:gsub("%%(%x%x)", ""):find("%%"), malformed)
            local value = Unesc(ascii)
            Require(Text(value), "The full backup contains invalid text.")
            return value
        end
        if tag == "n" then
            local separator = body:find(";", position, true)
            Require(separator and separator > position and separator - position <= 32, malformed)
            local text = body:sub(position, separator - 1)
            position = separator + 1
            Require(text:match("^%-?%d+%.?%d*$") or text:match("^%-?%d+%.?%d*[eE][+%-]?%d+$"), malformed)
            if DECIMAL_POINT ~= "." then text = text:gsub("%.", function() return DECIMAL_POINT end, 1) end
            local value = tonumber(text)
            Require(Number(value), "The full backup contains an invalid number.")
            return value
        end
        if tag == "t" then return true end
        if tag == "f" then return false end
        error(malformed, 0)
    end
    local result = Value(1)
    Require(position == #body + 1, "The full backup has unexpected trailing text.")
    return result
end

function ns.IsFullBackup(text)
    return type(text) == "string" and not IsSecret(text) and text:match("^%s*LTS3|") ~= nil
end

local function CaptureFullSnapshot()
    Require(ns.ValidRecord(ns.char) and Key(ns.charKey), "The active character is unavailable.")
    local record = { meta = {} }
    for _, field in ipairs(FULL_FIELDS) do
        if field ~= "meta" then
            local value = ns.char[field]
            record[field] = value == nil and {} or value
        end
    end
    for field in pairs(FULL_META) do record.meta[field] = ns.char.meta[field] end
    local snapshot = StageFullSnapshot({ character = ns.charKey, savedAt = time(), record = record }, true)
    snapshot.noteCount = nil -- Derived during preview, never trusted from a pasted backup.
    return snapshot
end

local function EncodeFullSnapshot(snapshot, progress)
    local body = EncodeFull(snapshot, progress)
    return FULL_HEADER .. FullChecksum(body, progress) .. "|" .. body
end

function ns.SerializeFullBackup()
    return Attempt(function() return EncodeFullSnapshot(CaptureFullSnapshot()) end)
end

function ns.WriteFullBackup(finished, status)
    -- Validation makes a detached snapshot. Only encoding that copy may yield.
    local snapshot, why = Attempt(CaptureFullSnapshot)
    if not snapshot then finished(nil, why); return end
    return RunBackupJob(snapshot, EncodeFullSnapshot, function(input)
        return Attempt(function() return EncodeFullSnapshot(input) end)
    end, finished, status)
end

-- Do not yield through Attempt/pcall on Lua 5.1. The job runner catches
-- decoder errors at coroutine.resume; synchronous callers still use Attempt.
local function ReadFullSnapshot(text, progress)
    Require(type(text) == "string" and not IsSecret(text) and #text <= MAX_FULL_INPUT, "The full backup is missing or too large.")
    local checksum, body = text:gsub("%s", ""):match("^LTS3|(%x%x%x%x%x%x%x%x)|(.+)$")
    Require(checksum and #body <= MAX_FULL_BYTES and not body:find("[^!-~]")
        and not body:find("|", 1, true), "The full backup text is malformed.")
    Require(FullChecksum(body, progress) == checksum:lower(), "The full backup checksum does not match.")
    local decoded = DecodeFull(body, progress)
    Require(PlainTable(decoded) and decoded.noteCount == nil, "The full backup has unexpected header fields.")
    local snapshot = StageFullSnapshot(decoded, nil, progress)
    Require(snapshot.character == ns.charKey, "This full backup belongs to a different character.")
    return snapshot
end

function ns.DeserializeFullBackup(text)
    return Attempt(function() return ReadFullSnapshot(text) end)
end

function ns.ReadFullBackup(text, finished, status)
    return RunBackupJob(text, ReadFullSnapshot, ns.DeserializeFullBackup, finished, status)
end

function ns.RestoreFullBackup(snapshot)
    local destination, character = ns.char, ns.charKey
    local staged, reason = Attempt(function()
        Require(ns.ValidRecord(destination) and Key(character) and type(ns.db) == "table"
            and type(ns.db.chars) == "table" and type(LifeTimeStatsCharDB) == "table", "The active character is unavailable.")
        Require(PlainTable(snapshot) and snapshot.character == character, "This full backup belongs to a different character.")
        return StageFullSnapshot(snapshot).record
    end)
    if not staged then return false, reason end

    local uniqueCounts = {}
    for set, values in pairs(staged.u) do
        local count = 0
        for _ in pairs(values) do count = count + 1 end
        uniqueCounts[set] = count
    end
    local session = ns.session
    local liveID = session and ID(session.id) and session.id
    local serial = ID(destination.meta.sessionSerial) and destination.meta.sessionSerial or 0
    if liveID then serial = math.max(serial, liveID) end
    local collision = false
    for index, row in ipairs(staged.sessionlog) do
        if row.id then
            serial = math.max(serial, row.id)
            if row.id == liveID and (row.s ~= session.wallStart or index < #staged.sessionlog) then
                collision = true
            end
        end
    end
    if serial > MAX_ID - (collision and 2 or 1) then
        return false, "The full backup contains an out-of-range session ID."
    end
    if collision then serial = serial + 1 end

    -- Swap only durable fields in place. Runs, quest timers, identity,
    -- revision and account settings remain on the existing character object.
    if ns.char ~= destination or ns.charKey ~= character then return false, "The active character changed." end
    for _, field in ipairs(FULL_FIELDS) do
        if field ~= "meta" then destination[field] = staged[field] end
    end
    for field in pairs(FULL_META) do destination.meta[field] = staged.meta[field] end
    destination.un, destination.meta.sessionSerial = uniqueCounts, serial
    if collision then session.id = serial end
    ns.db.chars[character] = destination
    LifeTimeStatsCharDB.data = destination
    ns.InvalidateAccount()
    return true
end

-- Portable account preferences, deliberately separate from character backups.
-- Do not include geometry, identity, notes, diagnostic flags or screenshot settings.
local PREFS = {
    { "theme", "Theme", function(v) return v == "auto" or ns.THEME_BY_ID[v] ~= nil end },
    { "achAnnounce", "Achievement alerts", function(v) return v == "off" or v == "chat" or v == "toast" or v == "both" end },
    { "classColor", "Class colour" }, { "countPet", "Pet tracking" },
    { "deathPins", "Death pins" }, { "itemTooltips", "Item tooltips" },
    { "levelMsg", "Level-up messages" }, { "milestones", "Milestones" },
    { "recap", "Login recap" }, { "recordMoments", "Journal records" },
}
local PREF_INDEX = {}
for _, def in ipairs(PREFS) do PREF_INDEX[def[1]] = def end
local PREF_HEADER = "LTSP1|"

function ns.IsPreferencesBackup(text)
    return type(text) == "string" and not ns.IsSecret(text) and text:match("^%s*LTSP1|") ~= nil
end

function ns.SerializePreferences()
    local entries = {}
    for _, def in ipairs(PREFS) do
        local key, rule = def[1], def[3]
        local value = ns.settings[key]
        if (rule and type(value) == "string" and rule(value)) or (not rule and type(value) == "boolean") then
            entries[#entries + 1] = key .. "=" .. tostring(value)
        end
    end
    local body = table.concat(entries, ";")
    return PREF_HEADER .. Checksum(body) .. "|" .. body
end

function ns.DeserializePreferences(text)
    if not ns.IsPreferencesBackup(text) or #text > 2048 then return nil, "Invalid preferences backup." end
    local sum, body = text:match("^%s*LTSP1|(%x%x%x%x%x%x)|([%w=;]+)%s*$")
    if not sum or Checksum(body) ~= sum then return nil, "Preferences backup checksum does not match." end
    local result = {}
    for entry in (body .. ";"):gmatch("(.-);") do
        local key, value = entry:match("^(%w+)=(%w+)$")
        local def = key and PREF_INDEX[key]
        if not def or result[key] ~= nil then return nil, "Unexpected or repeated preference." end
        if def[3] then
            if not def[3](value) then return nil, "Invalid preference value." end
            result[key] = value
        elseif value == "true" or value == "false" then
            result[key] = value == "true"
        else
            return nil, "Invalid preference value."
        end
    end
    return result
end

function ns.PreferenceChanges(values)
    local changes = {}
    for _, def in ipairs(PREFS) do
        local key = def[1]
        if values[key] ~= nil and values[key] ~= ns.settings[key] then
            changes[#changes + 1] = { key = key, label = def[2], value = values[key], before = ns.settings[key] }
        end
    end
    return changes
end

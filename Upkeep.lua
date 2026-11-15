-- LifeTimeStats - upkeep: how big each character's saved data is, three rotating daily
-- snapshots per character (a bad save can never take a whole lifetime with it), CSV exports
-- of the item log, quests, runs and deaths, and the start of a locale table.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local On = ns.On

-- ------------------------------------------------------------ locale
-- English is the default text; a translation only has to fill in ns.L[...] for its locale.
-- Missing keys fall back to the key itself, so untranslated text still reads in English.
ns.L = setmetatable({}, { __index = function(_, key) return key end })
local LOCALES = {
    -- deDE = { ["Characters"] = "Charaktere", ... },   -- ready for translators
}
do
    local locale = GetLocale and GetLocale() or "enUS"
    for k, v in pairs(LOCALES[locale] or {}) do rawset(ns.L, k, v) end
end

-- ------------------------------------------------------------ saved data size
-- An estimate of the bytes a record takes in SavedVariables (keys, values and punctuation).
local WARN_BYTES = 4 * 1024 * 1024
ns.SIZE_WARN_BYTES = WARN_BYTES
function ns.RecordSize(rec)
    local bytes, nodes, seen = 0, 0, {}
    local function Walk(t, depth)
        if seen[t] or depth > 12 then return end
        seen[t] = true
        for k, v in pairs(t) do
            nodes = nodes + 1
            bytes = bytes + (type(k) == "string" and (#k + 6) or 8)
            local tv = type(v)
            if tv == "table" then bytes = bytes + 4; Walk(v, depth + 1)
            elseif tv == "string" then bytes = bytes + #v + 4
            else bytes = bytes + 10 end
        end
    end
    if type(rec) == "table" then Walk(rec, 0) end
    return bytes, nodes
end

-- The biggest parts of a record, largest first: { { section, bytes } ... }
function ns.RecordSections(rec)
    local out = {}
    for k, v in pairs(rec or {}) do
        if type(v) == "table" then out[#out + 1] = { k, (ns.RecordSize(v)) } end
    end
    table.sort(out, function(a, b) return a[2] > b[2] end)
    return out
end

local function KB(b) return string.format("%.0f KB", b / 1024) end
ns.FormatKB = KB

function ns.SizeReport()
    local lines, total = {}, 0
    for key, rec in pairs((ns.db and ns.db.chars) or {}) do
        if ns.ValidRecord(rec) then
            local b, n = ns.RecordSize(rec)
            total = total + b
            local top = ns.RecordSections(rec)
            local parts = {}
            for i = 1, math.min(4, #top) do parts[#parts + 1] = top[i][1] .. " " .. KB(top[i][2]) end
            lines[#lines + 1] = string.format("%s: %s (%s entries) · largest: %s", key, KB(b), ns.FormatInt(n), table.concat(parts, ", "))
        end
    end
    table.sort(lines)
    table.insert(lines, 1, "Account total: " .. KB(total) .. "  (warning at " .. KB(WARN_BYTES) .. " per character)")
    return lines, total
end

On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if not isLogin or not ns.char or not C_Timer then return end
    C_Timer.After(8, function()
        local b = ns.RecordSize(ns.char)
        ns.char.meta.size = math.floor(b)
        if b > WARN_BYTES and ns.Print then
            ns.Print("This character's saved data is " .. KB(b) .. ". Type /lts size to see what takes the most space.")
        end
    end)
end)

-- ------------------------------------------------------------ rotating snapshots
-- One LTS2 text (statistics, tallies, records, firsts, daily history) per day, newest three kept
-- in this character's own SavedVariables file, so it survives a broken account-wide file.
local KEEP = 3
ns.SNAPSHOT_KEEP = KEEP
function ns.TakeDailySnapshot(force)
    if not ns.char or type(LifeTimeStatsCharDB) ~= "table" or not ns.Serialize then return nil end
    local list = LifeTimeStatsCharDB.snapshots
    if type(list) ~= "table" then list = {}; LifeTimeStatsCharDB.snapshots = list end
    local today = date("%Y%m%d")
    local ok, text = pcall(ns.Serialize, ns.char)
    if not ok or type(text) ~= "string" then return nil end
    local last = list[#list]
    if last and last.d == today and not force then
        last.t, last.text = time(), text
    else
        list[#list + 1] = { d = today, t = time(), text = text }
        while #list > KEEP do table.remove(list, 1) end
    end
    return list[#list]
end
On("PLAYER_LOGOUT", function() pcall(ns.TakeDailySnapshot) end)
On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin and C_Timer then C_Timer.After(20, function() pcall(ns.TakeDailySnapshot) end) end
end)

function ns.SnapshotCommand(args)
    local sub, n = (args or ""):match("^(%S*)%s*(%d*)")
    local list = (type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB.snapshots) or {}
    n = tonumber(n)
    if sub == "" or sub == "list" then
        if #list == 0 then ns.Print("No snapshots yet; one is kept each day you play (the newest " .. KEEP .. ").") return end
        for i, s in ipairs(list) do
            ns.Print(i .. ". " .. date("%b %d, %Y %H:%M", s.t or 0) .. " · " .. KB(#(s.text or "")))
        end
        ns.Print("/lts snapshot show <n> copies it as a backup text · /lts snapshot restore <n> merges it back (keeps the higher of each value)")
        return
    end
    local s = n and list[n]
    if not s then ns.Print("No snapshot number " .. tostring(n) .. ".") return end
    if sub == "show" then
        if ns.ShowText then ns.ShowText("Snapshot " .. n, "A stats backup from " .. date("%b %d, %Y %H:%M", s.t or 0) .. ". Paste it into Restore to merge.", s.text) end
    elseif sub == "restore" then
        local data, why = ns.Deserialize(s.text)
        if not data then ns.Print("That snapshot could not be read: " .. tostring(why)) return end
        local changed = ns.MergeMax(ns.char, data)
        ns.InvalidateAccount()
        ns.Print("Snapshot " .. n .. " merged (" .. tostring(changed or 0) .. " values raised).")
    else
        ns.Print("/lts snapshot list · show <n> · restore <n>")
    end
end

-- ------------------------------------------------------------ more CSV exports
local function Field(v)
    if v == nil then return "" end
    v = tostring(v)
    if v:find('[,"\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
    return v
end
local function Rows(header, list, fn)
    local out = { table.concat(header, ",") }
    for _, e in ipairs(list or {}) do
        if type(e) == "table" then
            local row, cells = fn(e), {}
            -- empty fields are nil, so walk every column instead of ipairs
            for i = 1, #header do cells[i] = Field(row[i]) end
            out[#out + 1] = table.concat(cells, ",")
        end
    end
    return table.concat(out, "\n")
end
local function Day(t) return t and date("%Y-%m-%d %H:%M", t) or "" end
ns.EXPORTS = {
    items = { "Item log", function(ch)
        return Rows({ "date", "item", "item_id", "quality", "item_level", "source", "from", "zone", "level", "count" }, ch.items,
            function(e) return { Day(e.t), e.n, e.id, e.q, e.il, e.src, e.from, e.z, e.l, e.c or 1 } end)
    end },
    quests = { "Quest history", function(ch)
        return Rows({ "date", "quest", "quest_id", "zone", "level", "xp", "money_copper", "seconds_to_complete" }, ch.quests,
            function(e) return { Day(e.t), e.n, e.id, e.z, e.l, e.xp, e.g, e.d } end)
    end },
    runs = { "Run history", function(ch)
        return Rows({ "start", "end", "instance", "level", "bosses", "deaths", "wipes", "group_size", "members", "full_clear", "items" }, ch.runlog,
            function(e) return { Day(e.s), Day(e.e), e.n, e.l, e.b, e.de, e.w, e.g, e.m, e.c and "yes" or "", e.loot } end)
    end },
    deaths = { "Deaths", function(ch)
        return Rows({ "date", "cause", "zone", "level", "map_id", "x", "y" }, ch.deathlog,
            function(e) return { Day(e.t), e.c, e.z, e.l, e.m, e.x and string.format("%.4f", e.x), e.y and string.format("%.4f", e.y) } end)
    end },
}
function ns.ExportCSV(kind)
    local def = ns.EXPORTS[kind]
    if not def or not ns.char then return nil end
    return def[1], def[2](ns.char)
end

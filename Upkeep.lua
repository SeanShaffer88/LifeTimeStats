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
    deDE = {
        ["Appearance"] = "Aussehen",
        ["Screenshots"] = "Screenshots",
        ["Chat and display"] = "Chat und Anzeige",
        ["Tracking and title"] = "Erfassung und Titel",
        ["Your data"] = "Deine Daten",
        ["Theme"] = "Design",
        ["Applies after /reload"] = "Wird nach /reload angewendet",
        ["Window size"] = "Fenstergröße",
        ["Window scale"] = "Fensterskalierung",
        ["Normal"] = "Normal",
        ["Fill screen"] = "Bildschirm füllen",
        ["Lock window"] = "Fenster sperren",
        ["Minimap button"] = "Minikartenknopf",
        ["Achievement alerts"] = "Erfolgsmeldungen",
        ["Class colour accent"] = "Klassenfarbe",
        ["Off"] = "Aus",
        ["Chat"] = "Chat",
        ["Toast"] = "Hinweis",
        ["Both"] = "Beides",
        ["Open window"] = "Fenster öffnen",
        ["Reset window"] = "Fenster zurücksetzen",
        ["Reload now"] = "Neu laden",
        ["Backup"] = "Backup",
        ["Restore"] = "Wiederherstellen",
        ["Title"] = "Titel",
        ["Encoding statistics"] = "Statistik wird kodiert",
        ["Counting discoveries"] = "Entdeckungen werden gezählt",
        ["Character"] = "Charakter",
        ["Account"] = "Konto",
        ["Lifetime"] = "Gesamt",
        ["Session"] = "Sitzung",
        ["Today"] = "Heute",
        ["Week"] = "Woche",
        ["Month"] = "Monat",
        ["Review backup"] = "Backup prüfen",
        ["Cancel"] = "Abbrechen",
        ["Close"] = "Schließen",
        ["Edit paste"] = "Text ändern",
        ["Stats only"] = "Nur Statistik",
        ["Full character"] = "Ganzer Charakter",
        ["Account preferences"] = "Kontoeinstellungen",
        ["Restore - %s"] = "Wiederherstellen – %s",
        ["Backup - %s"] = "Backup – %s",
        ["Preparing backup…"] = "Backup wird vorbereitet…",
        ["Paste a LifeTimeStats backup with Ctrl+V. Review the backup before merging statistics or replacing history."] =
            "Füge ein LifeTimeStats-Backup mit Strg+V ein. Prüfe es, bevor du Statistiken zusammenführst oder den Verlauf ersetzt.",
        ["Checking checksum"] = "Prüfsumme wird geprüft",
        ["Reading entries"] = "Einträge werden gelesen",
        ["Reading character backup"] = "Charakter-Backup wird gelesen",
        ["Validating character data"] = "Charakterdaten werden geprüft",
        ["Encoding character backup"] = "Charakter-Backup wird kodiert",
        ["%s: %d / %d bytes"] = "%s: %d / %d Bytes",
        ["%s: %d processed"] = "%s: %d verarbeitet",
        ["Restore account preferences"] = "Kontoeinstellungen wiederherstellen",
        ["Apply preferences"] = "Übernehmen",
        ["Merge statistics"] = "Zusammenführen",
        ["Replace history"] = "Verlauf ersetzen",
    },
}
do
    local locale = GetLocale and GetLocale() or "enUS"
    for k, v in pairs(LOCALES[locale] or {}) do rawset(ns.L, k, v) end
end

-- ------------------------------------------------------------ saved data size
-- An estimate of the bytes a record takes in SavedVariables (keys, values and punctuation).
local WARN_BYTES = 4 * 1024 * 1024
ns.SIZE_WARN_BYTES = WARN_BYTES
function ns.RecordSize(rec, breakdown)
    local bytes, nodes, seen, sections = 0, 0, {}, breakdown and {} or nil
    local function Walk(t, depth)
        if seen[t] or depth > 12 then return end
        seen[t] = true
        for k, v in pairs(t) do
            nodes = nodes + 1
            bytes = bytes + (type(k) == "string" and (#k + 6) or 8)
            local tv = type(v)
            if tv == "table" then
                bytes = bytes + 4
                local start = bytes
                Walk(v, depth + 1)
                if sections and depth == 0 then sections[#sections + 1] = { k, bytes - start } end
            elseif tv == "string" then bytes = bytes + #v + 4
            else bytes = bytes + 10 end
        end
    end
    if type(rec) == "table" then Walk(rec, 0) end
    if sections then table.sort(sections, function(a, b) return a[2] > b[2] end) end
    return bytes, nodes, sections
end

-- Count shared tables once, attributing them to the first section visited.
function ns.RecordSections(rec)
    local _, _, sections = ns.RecordSize(rec, true)
    return sections
end

local function KB(b) return string.format("%.0f KB", b / 1024) end
ns.FormatKB = KB

function ns.SizeReport()
    local lines, total = {}, 0
    for key, rec in pairs((ns.db and ns.db.chars) or {}) do
        if ns.ValidRecord(rec) then
            local b, n, top = ns.RecordSize(rec, true)
            total = total + b
            local parts = {}
            for i = 1, math.min(4, #top) do parts[#parts + 1] = top[i][1] .. " " .. KB(top[i][2]) end
            lines[#lines + 1] = string.format("%s: %s (%s entries) · largest: %s", key, KB(b), ns.FormatInt(n), table.concat(parts, ", "))
        end
    end
    if ns.Retention and ns.char then
        for _, line in ipairs(ns.Retention.Report(ns.char)) do lines[#lines + 1] = line end
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
local KEEP, SNAPSHOT_BYTES = 3, 4 * 1024 * 1024
ns.SNAPSHOT_KEEP = KEEP
local function ValidSnapshot(entry)
    return type(entry) == "table" and type(entry.d) == "string" and entry.d:match("^%d%d%d%d%d%d%d%d$")
        and not ns.BadNumber(entry.t) and entry.t >= 0 and entry.t <= 4102444800
        and type(entry.text) == "string" and #entry.text <= SNAPSHOT_BYTES
        and entry.text:match("^LTS[12]|") ~= nil
end

function ns.TakeDailySnapshot(force)
    if not ns.char or type(LifeTimeStatsCharDB) ~= "table" or not ns.Serialize then return nil end
    local list = LifeTimeStatsCharDB.snapshots
    if type(list) ~= "table" then list = {}; LifeTimeStatsCharDB.snapshots = list end
    local today = date("%Y%m%d")
    local ok, text = pcall(ns.Serialize, ns.char)
    if not ok or type(text) ~= "string" or #text > SNAPSHOT_BYTES then return nil end
    local last = list[#list]
    if type(last) == "table" and last.d == today and not force then
        last.t, last.text = time(), text
    else
        list[#list + 1] = { d = today, t = time(), text = text }
    end
    local bytes, count = 0, 0
    local kept = {}
    for i = #list, math.max(1, #list - KEEP + 1), -1 do
        local entry = list[i]
        if ValidSnapshot(entry) then
            local size = #entry.text
            if bytes + size > SNAPSHOT_BYTES then break end
            bytes, count = bytes + size, count + 1
            kept[count] = entry
        end
    end
    local ordered = {}
    for i = count, 1, -1 do ordered[#ordered + 1] = kept[i] end
    LifeTimeStatsCharDB.snapshots = ordered
    return ordered[#ordered]
end
On("PLAYER_LOGOUT", function() pcall(ns.TakeDailySnapshot) end)
On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin and C_Timer then C_Timer.After(20, function() pcall(ns.TakeDailySnapshot) end) end
end)

function ns.SnapshotCommand(args)
    args = (args or ""):match("^%s*(.-)%s*$")
    local list = type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB.snapshots
    if type(list) ~= "table" then list = {} end
    local help = "/lts snapshot list · show <n> · restore <n>"
    if args == "" or args == "list" then
        local count = 0
        for i = 1, math.min(#list, KEEP) do
            local entry = list[i]
            if ValidSnapshot(entry) then
                ns.Print(i .. ". " .. date("%b %d, %Y %H:%M", entry.t) .. " · " .. KB(#entry.text))
                count = count + 1
            end
        end
        if count == 0 then ns.Print("No readable snapshots yet.") end
        ns.Print(help)
        return
    end
    local sub, number = args:match("^(%a+)%s+(%d+)$")
    if sub ~= "show" and sub ~= "restore" then ns.Print(help); return end
    local n = tonumber(number)
    local entry = n and n <= KEEP and list[n]
    if not ValidSnapshot(entry) then ns.Print("No readable snapshot number " .. tostring(n) .. "."); return end
    if sub == "show" then
        ns.ShowText("Snapshot " .. n, "A stats backup from " .. date("%b %d, %Y %H:%M", entry.t) .. ". Paste it into Restore to merge.", entry.text)
    else
        ns.ShowImport(entry.text)
    end
end

-- ------------------------------------------------------------ more CSV exports
function ns.CSVField(v, spreadsheetSafe)
    if ns.IsSecret(v) or (type(v) ~= "string" and type(v) ~= "boolean" and ns.BadNumber(v)) then return "" end
    if spreadsheetSafe and type(v) == "string" and (v:find("^%s*[=+@%-]") or v:find("^[\t\r\n]")) then
        v = "'" .. v
    end
    v = tostring(v)
    if v:find('[,"\r\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
    return v
end
local function Rows(header, list, fn, spreadsheetSafe, since, timeKey)
    local baseColumns = #header
    local historyName = timeKey == "s" and "runlog" or (header[2] == "item" and "items" or (header[2] == "quest" and "quests" or "deathlog"))
    local retained = ns.Retention.History(ns.char, historyName)
    header[#header + 1] = "retained_count"
    header[#header + 1] = "retained_limit"
    header[#header + 1] = "retained_oldest"
    header[#header + 1] = "retained_newest"
    header[#header + 1] = "retention_status"
    local out = { table.concat(header, ",") }
    for _, e in ipairs(type(list) == "table" and list or {}) do
        if type(e) == "table" and (not since or (not ns.IsSecret(e[timeKey]) and not ns.BadNumber(e[timeKey]) and e[timeKey] >= since)) then
            local row, cells = fn(e), {}
            -- empty fields are nil, so walk every column instead of ipairs
            for i = 1, baseColumns do cells[i] = ns.CSVField(row[i], spreadsheetSafe) end
            for _, value in ipairs({ retained.kept, retained.limit, retained.oldest or "", retained.newest or "", retained.text }) do
                cells[#cells + 1] = ns.CSVField(value, spreadsheetSafe)
            end
            out[#out + 1] = table.concat(cells, ",")
        end
    end
    return table.concat(out, "\n"), #out - 1
end
local function Day(t)
    if ns.IsSecret(t) or ns.BadNumber(t) or t < 0 or t > 4102444800 then return "" end
    local ok, label = pcall(date, "%Y-%m-%d %H:%M", t)
    return ok and label or ""
end
local function Coordinate(value) return not ns.IsSecret(value) and not ns.BadNumber(value) and string.format("%.4f", value) or "" end
ns.EXPORTS = {
    items = { "Item log", function(ch, safe, since)
        return Rows({ "date", "item", "item_id", "quality", "item_level", "source", "from", "zone", "level", "count" }, ch.items,
            function(e) return { Day(e.t), e.n, e.id, e.q, e.il, e.src, e.from, e.z, e.l, e.c or 1 } end, safe, since, "t")
    end },
    quests = { "Quest history", function(ch, safe, since)
        return Rows({ "date", "quest", "quest_id", "zone", "level", "xp", "money_copper", "seconds_to_complete" }, ch.quests,
            function(e) return { Day(e.t), e.n, e.id, e.z, e.l, e.xp, e.g, e.d } end, safe, since, "t")
    end },
    runs = { "Run history", function(ch, safe, since)
        return Rows({ "start", "end", "instance", "level", "bosses", "deaths", "wipes", "group_size", "members", "full_clear", "items" }, ch.runlog,
            function(e) return { Day(e.s), Day(e.e), e.n, e.l, e.b, e.de, e.w, e.g, e.m, e.c and "yes" or "", e.loot } end, safe, since, "s")
    end },
    deaths = { "Deaths", function(ch, safe, since)
        return Rows({ "date", "cause", "zone", "level", "map_id", "x", "y" }, ch.deathlog,
            function(e) return { Day(e.t), e.c, e.z, e.l, e.m, Coordinate(e.x), Coordinate(e.y) } end, safe, since, "t")
    end },
}
function ns.ExportCSV(kind, raw, since)
    local def = ns.EXPORTS[kind]
    if not def or not ns.char then return nil end
    return def[1], def[2](ns.char, not raw, since)
end

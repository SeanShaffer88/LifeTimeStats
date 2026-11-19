"""Offline tests for 1.20: quest/level/profession/death history, play habits, item tooltips,
map pins, saved-data size, rotating snapshots, CSV exports, the locale table and Dashboard goals."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.452, 0.631 end } end
function UnitStat(_, i) return 10 + i, 20 + i end
tooltipHooks = {}
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) tooltipHooks[#tooltipHooks + 1] = fn end }
''')
for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
    name = name.strip()
    if name.endswith(".lua"):
        chunk = lua.eval("function(src, name) return assert(loadstring(src, name)) end")(
            (ROOT / name).read_text(encoding="utf-8"), name
        )
        chunk("LifeTimeStats", lua.globals().ns)

lua.execute(r'''
local checks = 0
local function eq(got, expected, msg)
    checks = checks + 1
    if got ~= expected then error(msg .. ": got " .. tostring(got) .. ", expected " .. tostring(expected), 2) end
end
local function fire(event, ...) local f = ns.frame; f.scripts.OnEvent(f, event, ...) end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
NOW = NOW + 30; RunTimers()
local ch = ns.char

-- ------------------------------------------------------------ quest history
ch.qa[777] = time() - 600
fire("QUEST_TURNED_IN", 777, 450, 125)
local q = ch.quests[#ch.quests]
eq(q.id, 777, "quest id")
eq(q.n, "Lazy Peons", "quest title")
eq(q.xp, 450, "quest XP")
eq(q.g, 125, "quest money")
eq(q.d, 600, "accept to turn-in time")
eq(q.z, "Durotar", "quest zone")
eq(ch.t.questzones.Durotar >= 1, true, "quests by zone")

-- ------------------------------------------------------------ level snapshots with extras
ns.LevelSnapshot(11)
local s = ch.lvlsnap["11"]
eq(s.gold, state.money, "gold at level-up")
eq(s.str, 21, "strength at level-up")
eq(s.zone, "Durotar", "zone at level-up")

-- ------------------------------------------------------------ profession history
fire("CHAT_MSG_SKILL", "Your skill in Herbalism has increased to 74.")
NOW = NOW + 60
local j0 = #ch.journal
fire("CHAT_MSG_SKILL", "Your skill in Herbalism has increased to 75.")
eq(ch.skills.Herbalism.r, 75, "skill rank")
eq(type(ch.skills.Herbalism.h[75]), "number", "date of rank 75")
eq(ch.c.skill_milestones, 1, "milestone counted")
eq(ch.journal[#ch.journal][2], "Herbalism reached 75", "milestone journal line")
ch.skills.Herbalism.h[1] = ch.skills.Herbalism.h[75] - 3600
eq(ns.SkillSpan(ch.skills.Herbalism, 1, 75), 3600, "1-75 span")

-- ------------------------------------------------------------ deaths with positions, map pins
state.dead = true
fire("PLAYER_DEAD")
NOW = NOW + 1; RunTimers()
state.dead = false
fire("PLAYER_ALIVE")
local d = ch.deathlog[#ch.deathlog]
eq(d.m, 1411, "death map")
eq(math.floor(d.x * 1000 + 0.5), 452, "death x")
eq(math.floor(d.y * 1000 + 0.5), 631, "death y")
eq(ch.c.deaths_located, 1, "located deaths")
local canvas = CreateFrame("Frame"); canvas.wdt, canvas.h = 1000, 600
WorldMapFrame.GetMapID = function() return 1411 end
WorldMapFrame.GetCanvas = function() return canvas end
WorldMapFrame.shown = true
eq(ns.RefreshDeathPins(), 1, "one skull on Durotar's map")
WorldMapFrame.GetMapID = function() return 1 end
eq(ns.RefreshDeathPins(), 0, "no skull on another map")
ns.settings.deathPins = false
WorldMapFrame.GetMapID = function() return 1411 end
eq(ns.RefreshDeathPins(), 0, "skulls off")
SlashCmdList.LIFETIMESTATS("deathpins")
eq(ns.settings.deathPins, true, "/lts deathpins turns them on")

-- ------------------------------------------------------------ play habits
ns.PlayTick()
NOW = NOW + 30
ns.PlayTick()
local key = string.format("%d-%02d", tonumber(os.date("%w")), tonumber(os.date("%H")))
eq((ch.t.playhours or {})[key] ~= nil, true, "time by weekday-hour")

-- ------------------------------------------------------------ item tooltips
ns.OnBossKill("Taragaman the Hungerer", "party")
fire("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:4444|h[Hungerer Ring]|h|r.")
local line = ns.ItemTooltipLine(4444)
eq(line ~= nil and line:find("Boss from Taragaman the Hungerer", 1, true) ~= nil, true, "tooltip names the source: " .. tostring(line))
eq(#tooltipHooks, 1, "tooltip post-call registered")
local added = {}
tooltipHooks[1](GameTooltip, { id = 4444 })
eq(ns.ItemTooltipLine(9999), nil, "unknown item has no line")
ns.settings.itemTooltips = false
eq(ns.ItemTooltipLine(4444), nil, "setting off")
ns.settings.itemTooltips = true

-- ------------------------------------------------------------ size, snapshots, exports
local bytes, nodes = ns.RecordSize(ch)
eq(bytes > 1000 and nodes > 50, true, "record size estimated")
local lines = ns.SizeReport()
eq(lines[1]:find("Account total", 1, true) ~= nil, true, "size report")
SlashCmdList.LIFETIMESTATS("size")
local snap = ns.TakeDailySnapshot()
eq(type(snap.text), "string", "snapshot taken")
eq(#LifeTimeStatsCharDB.snapshots, 1, "one snapshot today")
ns.TakeDailySnapshot()
eq(#LifeTimeStatsCharDB.snapshots, 1, "same day replaces")
for i = 1, 4 do ns.TakeDailySnapshot(true) end
eq(#LifeTimeStatsCharDB.snapshots, 3, "only three kept")
local jumps = ch.c.jumps or 0
ch.c.jumps = 0
SlashCmdList.LIFETIMESTATS("snapshot restore 3")
eq(ch.c.jumps, 0, "preview does not merge immediately")
local button = ns.backupDialog.action
button.scripts.OnClick(button)
eq(ch.c.jumps, jumps, "restore merges the higher value back")
local snapshots = LifeTimeStatsCharDB.snapshots
LifeTimeStatsCharDB.snapshots = { false, { d = "20261119", t = "bad", text = snap.text }, snapshots[3] }
local dialogBefore = ns.backupDialog.mode
SlashCmdList.LIFETIMESTATS("snapshot list")
SlashCmdList.LIFETIMESTATS("snapshot restore 3 extra")
SlashCmdList.LIFETIMESTATS("snapshot show 2")
eq(ns.backupDialog.mode, dialogBefore, "malformed snapshot rows and commands do not open dialogs")
LifeTimeStatsCharDB.snapshots = snapshots
local oddField = "  =2+2"
eq(ns.CSVField(oddField, true), "'" .. oddField, "spreadsheet formula-like text neutralized")
eq(ns.CSVField("a\rb", true), '"a\rb"', "bare CR quoted")
eq(ns.CSVField(-2, true), "-2", "numeric negative preserved")
-- A large preview reports progress, can be canceled, and never applies by itself.
local source = ns.NewCharRecord()
source.c.jumps = jumps + 100
for i = 1, 1600 do source.u.quests = source.u.quests or {}; source.u.quests[tostring(i)] = true end
local largeText = ns.Serialize(source)
local queued = {}
local originalAfter = C_Timer.After
C_Timer.After = function(_, fn) queued[#queued + 1] = fn end
ns.ShowImport(largeText)
local dialog = ns.backupDialog
eq(#queued, 1, "large read yields and queues its next batch")
eq(dialog.hint:GetText():find("checksum", 1, true) ~= nil, true, "read reports progress")
dialog:Hide()
dialog.scripts.OnHide(dialog)
queued[1]()
eq(dialog.previewLegacy, false, "canceled batch cannot publish a preview")
eq(ch.c.jumps, jumps, "canceled job leaves stats unchanged")
queued = {}
ns.ShowImport(largeText)
for _, resume in ipairs(queued) do resume() end
eq(dialog.previewLegacy ~= nil, true, "resumed read produces a preview")
eq(ch.c.jumps, jumps, "finished parse still requires confirmation")
button.scripts.OnClick(button)
eq(ch.c.jumps, jumps + 100, "confirmed staged import applies")
local full = assert(ns.SerializeFullBackup())
queued = {}
ns.ShowImport(full)
eq(#queued, 1, "large full backup queues its next batch")
local phases = {}
for _, resume in ipairs(queued) do
    phases[dialog.hint:GetText():match("^([^:]+)")] = true
    resume()
end
eq(phases["Reading character backup"], true, "full decode reports progress")
eq(phases["Validating character data"], true, "full validation reports progress")
eq(dialog.previewSnapshot.character, ns.charKey, "full preview uses decoded snapshot")
ch.c.jumps = jumps + 150
button.scripts.OnClick(button)
eq(ch.c.jumps, jumps + 100, "confirmed full restore replaces stats")
queued = {}
ns.ShowImport(full)
dialog:Hide()
dialog.scripts.OnHide(dialog)
queued[1]()
eq(dialog.previewSnapshot, false, "canceled full read cannot publish a preview")
queued = {}
ns.ShowExport()
eq(#queued, 1, "large stats export schedules checksum batches")
local statsBatch = queued[1]
local fullButton = dialog.exportModes.buttons[2]
fullButton.scripts.OnClick(fullButton)
eq(#queued, 2, "switching format starts a full export")
statsBatch()
eq(dialog.eb:GetText(), "", "superseded export cannot publish text")
local capturedJumps = ch.c.jumps
ch.c.jumps = capturedJumps + 77
for i = 2, 1000 do
    if not queued[i] then break end
    queued[i]()
end
local exported = assert(ns.DeserializeFullBackup(dialog.eb:GetText()))
eq(exported.record.c.jumps, capturedJumps, "export uses the snapshot at request time")
queued = {}
ns.ShowExport()
dialog:Hide()
dialog.scripts.OnHide(dialog)
queued[1]()
eq(dialog.eb:GetText(), "", "closed export does not publish text")
C_Timer.After = originalAfter
SlashCmdList.LIFETIMESTATS("snapshot list")
SlashCmdList.LIFETIMESTATS("snapshot show 1")
for _, kind in ipairs({ "items", "quests", "runs", "deaths" }) do
    local title, text = ns.ExportCSV(kind)
    eq(type(title), "string", kind .. " export title")
    eq(text:find("\n", 1, true) ~= nil or kind == "runs", true, kind .. " export has rows")
    SlashCmdList.LIFETIMESTATS("export " .. kind)
end
eq(select(2, ns.ExportCSV("quests")):find("Lazy Peons", 1, true) ~= nil, true, "quest CSV row")

local fixture = { t = time() - 8 * 86400, n = "Old filtered quest", id = 9999 }
local recent = { t = time() - 1, n = "Recent filtered quest", id = 10000 }
ch.quests[#ch.quests + 1], ch.quests[#ch.quests + 2] = fixture, recent
local _, csv, count = ns.ExportCSV("quests", false, time() - 7 * 86400)
eq(csv:find(fixture.n, 1, true), nil, "filtered CSV skips old rows")
eq(csv:find(recent.n, 1, true) ~= nil, true, "filtered CSV includes recent rows")
local _, separators = csv:gsub("\n", "")
eq(count, separators, "filtered CSV count excludes header")
SlashCmdList.LIFETIMESTATS("export quests days 7")
eq(ns.backupDialog.eb:GetText(), csv, "slash export applies the date filter")

local deathsBefore = ch.deathlog
ch.deathlog = { { t = "bad", x = "bad", y = math.huge, c = "Malformed death" } }
local _, tolerantCSV, tolerantCount = ns.ExportCSV("deaths")
eq(tolerantCount, 1, "CSV retains row with unreadable date and coordinates")
eq(tolerantCSV:find("\n,Malformed death,,,,,", 1, true) ~= nil, true, "unreadable CSV cells are blank")
ch.deathlog = false
local _, _, emptyCount = ns.ExportCSV("deaths")
eq(emptyCount, 0, "malformed history list exports header only")
ch.deathlog = deathsBefore

eq(ns.CSVField(math.huge, true), "", "CSV omits nonfinite cell")
eq(ns.CSVField({}, true), "", "CSV omits malformed table cell")
local secretCheck = ns.IsSecret
ns.IsSecret = function(value) return value == "hidden" end
eq(ns.CSVField("hidden", true), "", "CSV omits restricted cell")
ns.IsSecret = secretCheck

-- ------------------------------------------------------------ locale
eq(ns.L["Quest history"], "Quest history", "missing translations fall back to English")

-- ------------------------------------------------------------ Dashboard goal on a pinned stat
local g = ns.AddGoal("times jumped", 1000000)
eq(ns.GoalFor(g.id), g, "goal for a catalog id")

-- ------------------------------------------------------------ Characters page sections render
ns.OpenPage("roster")
local p = ns.rosterPage
local function Has(rows, text)
    for _, r in ipairs(rows) do if type(r[2]) == "string" and r[2]:find(text, 1, true) then return true end end
    return false
end
for _, id in ipairs({ "quests", "levels", "skills", "deathmap", "habits" }) do
    p.sectionButtons[id].scripts.OnClick(p.sectionButtons[id])
    eq(#p.list.data > 0, true, id .. " rows")
end
eq(Has(ns.RosterRows({ section = "quests" }), "Lazy Peons"), true, "quest row")
eq(Has(ns.RosterRows({ section = "levels" }), "Level 11"), true, "level row")
eq(Has(ns.RosterRows({ section = "skills" }), "Herbalism"), true, "skill row")
eq(Has(ns.RosterRows({ section = "habits" }), "Monday"), true, "weekday rows")

-- ------------------------------------------------------------ full backup round trip
local text = assert(ns.SerializeFullBackup())
local snapB = assert(ns.DeserializeFullBackup(text))
eq(#snapB.record.quests >= 1, true, "quests in backup")
eq(snapB.record.skills.Herbalism.r, 75, "skills in backup")
eq(#snapB.record.deathlog >= 1, true, "death log in backup")
eq(snapB.record.lvlsnap["11"].str, 21, "level snapshot extras in backup")
ch.quests, ch.skills, ch.deathlog = {}, {}, {}
eq(ns.RestoreFullBackup(snapB), true, "restore")
eq(ns.char.skills.Herbalism.r, 75, "skills restored")

-- Preferences are separate, allowlisted and never change without review.
ns.settings.theme, ns.settings.classColor = "ledger", false
local savedPrefs = ns.SerializePreferences()
local prefs = assert(ns.DeserializePreferences(savedPrefs))
eq(prefs.classColor, false, "false preference round trips")
eq(prefs.window, nil, "geometry excluded")
eq(prefs.shotLevel, nil, "screenshot setting excluded")
eq(ns.DeserializePreferences(savedPrefs .. "x"), nil, "changed preference payload fails checksum")
ns.settings.theme, ns.settings.classColor = "auto", true
local position = ns.settings.window
local record = ns.char
ns.ShowImport(savedPrefs)
eq(ns.settings.theme, "auto", "review does not change settings")
eq(#ns.backupDialog.previewPreferences, 2, "review lists only changed settings")
ns.settings.theme = "notebook"
button.scripts.OnClick(button)
eq(ns.settings.theme, "notebook", "settings changed during preview require fresh confirmation")
button.scripts.OnClick(button)
eq(ns.settings.theme, "ledger", "confirmed theme restored")
eq(ns.settings.classColor, false, "confirmed false restored")
eq(ns.settings.window, position, "restore leaves window settings intact")
eq(ns.char, record, "restore leaves character record intact")
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("HISTORY PASS: " .. checks .. " assertions")
''')

# Exercise the active locale at load time, not just catalog entries in isolation.
german = lua51.LuaRuntime(unpack_returned_tuples=True)
german.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
german.execute('ns = {}; function GetLocale() return "deDE" end')
for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
    name = name.strip()
    if name.endswith(".lua"):
        german.execute((ROOT / name).read_text(encoding="utf-8"), "LifeTimeStats", german.globals().ns)
german.execute('''
local frame = ns.frame
frame.scripts.OnEvent(frame, "ADDON_LOADED", "LifeTimeStats")
ns.ShowImport()
assert(ns.backupDialog.action.text:GetText() == "Backup prüfen")
assert(ns.backupDialog.close.text:GetText() == "Abbrechen")
assert(ns.backupDialog.title:GetText():find(ns.charKey, 1, true))
assert(ns.L["Quest history"] == "Quest history", "untranslated keys keep the English fallback")
ns.ShowExport()
assert(ns.backupDialog.exportModes.buttons[3].text:GetText() == "Kontoeinstellungen")
assert(ns.backupDialog.eb:GetText():match("^LTS2|"), "localization does not change the backup format")
''')

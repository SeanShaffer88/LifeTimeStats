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
SlashCmdList.LIFETIMESTATS("snapshot list")
SlashCmdList.LIFETIMESTATS("snapshot show 1")
for _, kind in ipairs({ "items", "quests", "runs", "deaths" }) do
    local title, text = ns.ExportCSV(kind)
    eq(type(title), "string", kind .. " export title")
    eq(text:find("\n", 1, true) ~= nil or kind == "runs", true, kind .. " export has rows")
    SlashCmdList.LIFETIMESTATS("export " .. kind)
end
eq(select(2, ns.ExportCSV("quests")):find("Lazy Peons", 1, true) ~= nil, true, "quest CSV row")

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

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("HISTORY PASS: " .. checks .. " assertions")
''')

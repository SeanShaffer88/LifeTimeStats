"""Offline regression tests for the Adventure Guide (boss pages, runs, deaths, loot, bestiary, atlas, chapters, group)."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute("ns = {}")
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
local function fire(event, ...)
    local f = ns.frame
    f.scripts.OnEvent(f, event, ...)
end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
NOW = NOW + 11; RunTimers()
local ch = ns.char
state.level = 14

-- ------------------------------------------------------------ a dungeon run
state.group = 3
units.party1 = { name = "Thrall" }
units.party2 = { name = "Jaina" }
state.inInst, state.itype, state.iname, state.mapid = true, "party", "Ragefire Chasm", 389
fire("ZONE_CHANGED_NEW_AREA")
eq(#ch.runlog, 1, "run logged on entry")
local run = ch.runlog[1]
eq(run.n, "Ragefire Chasm", "run dungeon name")
eq(run.l, 14, "run level")
eq(run.g, 3, "group size")
eq(run.m, "Thrall, Jaina", "group members")
eq(ch.c.guide_runs_trio, 1, "trio run counter")
eq(ch.t.guide_grouprun.Thrall, 1, "run together tally")

fire("ENCOUNTER_START", 1, "Taragaman the Hungerer", 1, 5)
eq(ns.GuideEngaged().label, "Taragaman the Hungerer", "engaged boss label")
NOW = NOW + 30
fire("ENCOUNTER_END", 1, "Taragaman the Hungerer", 1, 5, 0)
eq(ch.c.guide_wipes, 1, "wipe counted")
eq(ch.t.guide_bosswipe["Taragaman the Hungerer"], 1, "wipe per boss")
eq(run.w, 1, "wipe on the run")
eq(ch.r.max_wipe_fight, 30, "longest lost fight")

fire("ENCOUNTER_START", 1, "Taragaman the Hungerer", 1, 5)
state.dead = true
fire("PLAYER_DEAD")
NOW = NOW + 1; RunTimers()
state.dead = false
fire("PLAYER_ALIVE")
eq(ch.c.guide_boss_deaths, 1, "death during boss fight")
eq(ch.t.guide_bossdeath["Taragaman the Hungerer"], 1, "death per boss")
eq(run.de, 1, "death on the run")
eq(ch.t.guide_rundeath["Ragefire Chasm"], 1, "deaths by dungeon")
eq(ch.c.guide_run_deaths, 1, "deaths inside instances")
NOW = NOW + 44
fire("ENCOUNTER_END", 1, "Taragaman the Hungerer", 1, 5, 1)
eq(ch.t.guide_bosskill["Taragaman the Hungerer"], 1, "boss kill per boss")
eq(ch.t.guide_bosspull["Taragaman the Hungerer"], 2, "two pulls")
eq(ch.f["bossfast:Taragaman the Hungerer"], 45, "fastest kill time")
eq(ch.first["gboss:Taragaman the Hungerer"] ~= nil, true, "first kill recorded")
eq(ch.first["gbossgrp:Taragaman the Hungerer"], "Thrall, Jaina", "first kill group")
eq(ch.t.guide_firstkillmates.Jaina, 1, "there for the first kill")
eq(ch.c.guide_boss_kills_trio, 1, "trio boss kill")
eq(run.b, 1, "boss on the run")
eq(((ch.u.djseen_rfc) or {})["Taragaman the Hungerer"], true, "boss seen in the book")

fire("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:1|h[Hungerer's Fang]|h|r.")
eq(ch.t["gloot:Taragaman the Hungerer"]["Hungerer's Fang"], 1, "boss loot attributed")
eq(ch.c.guide_boss_loot, 1, "boss loot counter")
eq(run.loot, 1, "loot on the run")
NOW = NOW + 200
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2|h[Linen Cloth]|h|r.")
eq(ch.t["gloot:Taragaman the Hungerer"]["Linen Cloth"], nil, "late loot is not the boss's")
eq(ch.t.zoneloot ~= nil, true, "zone loot tallied")

-- a world boss is tallied apart
ns.OnBossKill("Azuregos", "world")
eq(ch.t.guide_worldbosses.Azuregos, 1, "world boss")

-- ------------------------------------------------------------ bestiary
local realInfo = ns.RecentUnitInfo
ns.RecentUnitInfo = function(name) if name == "Ragefire Trogg" then return { ctype = "Humanoid", class = "elite", level = 13 } end end
ns.RecordKill("Creature-0-1-1-1-11318-1", "Ragefire Trogg")
ns.RecordKill("Creature-0-1-1-1-11318-2", "Ragefire Trogg")
ns.RecentUnitInfo = realInfo
local trogg = ch.bestiary["Ragefire Trogg"]
eq(trogg.k, 2, "bestiary kill count")
eq(trogg.ty, "Humanoid", "bestiary type")
eq(trogg.cl, "elite", "bestiary classification")
eq(trogg.lo, 13, "bestiary level")
eq(ch.c.bestiary_entries, 1, "one bestiary entry")
eq(ch.t.creaturetypes.Humanoid, 2, "kills by type")
eq(ch.t.creatureclass.elite, 2, "kills by classification")

-- ------------------------------------------------------------ zone atlas
state.inInst = false; state.itype = "none"
fire("ZONE_CHANGED_NEW_AREA")
eq(ch.t.zonevisits.Durotar >= 1, true, "zone visit")
fire("QUEST_TURNED_IN", 1, 100, 0)
eq(ch.t.zonequests.Durotar, 1, "quest by zone")
local zones = ns.GuideZones(ch)
eq(#zones > 0, true, "atlas has zones")

-- ------------------------------------------------------------ suggestions and chapters
local sug = ns.GuideSuggestions(ch)
eq(#sug > 0, true, "suggestions exist")
local hasRfc = false
for _, s in ipairs(sug) do if s.dkey == "rfc" then hasRfc = true end end
eq(hasRfc, true, "Ragefire Chasm suggested (bosses left)")
local chapters = ns.GuideChapters()
eq(#chapters > 0, true, "chronicle chapters")
eq(ns.GuideChapterText(chapters[1], 1):match("^Chapter 1: Levels") ~= nil, true, "chapter text")

-- ------------------------------------------------------------ every guide view renders
local function RenderAll(view, tag)
    local n = 0
    for _, s in ipairs(ns.GUIDE_SECTIONS) do
        local rows = ns.GuideRows(view, { section = s.id })
        eq(type(rows), "table", tag .. " section " .. s.id)
        n = n + #rows
    end
    for _, d in ipairs(ns.DUNGEONS) do
        local rows = ns.GuideRows(view, { section = "dungeon", dkey = d.key })
        eq(rows[1].back, "book", tag .. " dungeon back row " .. d.key)
        for _, r in ipairs(rows) do
            if r.boss then ns.GuideRows(view, { section = "dungeon", dkey = d.key, boss = r.boss }) end
        end
    end
    eq(#ns.GuideChapterRows(view, { section = "suggest" }), #ns.GUIDE_SECTIONS + #ns.DUNGEONS, tag .. " chapter column")
    return n
end
eq(RenderAll(ch, "char") > 10, true, "character guide has rows")
local page = ns.GuideRows(ch, { section = "dungeon", dkey = "rfc", boss = "Taragaman the Hungerer" })
local sawLoot = false
for _, r in ipairs(page) do if r[2] == "Hungerer's Fang" then sawLoot = true end end
eq(sawLoot, true, "boss page lists loot")

-- account scope: a second character's runs and bestiary appear, tagged with its name
ns.db.chars["Forever-Alt"] = { meta = { rev = 1, name = "Altie", created = 1 }, c = {}, r = {}, t = { guide_bosskill = { ["Oggleflint"] = 3 } }, u = {}, un = {},
    f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {}, months = {}, runlog = { { s = 100, e = 400, n = "Ragefire Chasm", b = 2 } },
    bestiary = { ["Ragefire Trogg"] = { k = 5, f = 50 } } }
ns.settings.scope = "account"
ns.InvalidateAccount()
local acct = ns.GetView("account", "lifetime")
eq(#ns.GuideRuns(), 2, "account runs from both characters")
eq(ns.GuideRuns()[2].who, "Altie", "older run tagged with its character")
eq(acct.bestiary["Ragefire Trogg"].k, 7, "bestiary merged")
eq(acct.bestiary["Ragefire Trogg"].who, "Altie", "first killer across characters")
eq(ns.GuideBoss(acct, "Oggleflint").kills, 3, "alt boss kills")
RenderAll(acct, "account")
ns.settings.scope = "char"

-- the page itself builds and refreshes for every section
ns.OpenPage("guide")
local p = ns.guidePage
eq(p ~= nil, true, "guide page built")
for _, s in ipairs(ns.GUIDE_SECTIONS) do p.state.section = s.id; p.state.boss = nil; ns.RefreshWindow() end
p.state.section, p.state.dkey, p.state.boss = "dungeon", "rfc", "Taragaman the Hungerer"
ns.RefreshWindow()
eq(p.title.text, "TARAGAMAN THE HUNGERER", "boss page title")

-- ------------------------------------------------------------ full backup keeps runs and bestiary
local text = assert(ns.SerializeFullBackup())
local snap = assert(ns.DeserializeFullBackup(text))
eq(#snap.record.runlog, 1, "runlog in full backup")
eq(snap.record.bestiary["Ragefire Trogg"].k, 2, "bestiary in full backup")
ch.runlog, ch.bestiary = {}, {}
eq(ns.RestoreFullBackup(snap), true, "full restore")
eq(#ns.char.runlog, 1, "runlog restored")
eq(ns.char.bestiary["Ragefire Trogg"].ty, "Humanoid", "bestiary restored")

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("GUIDE PASS: " .. checks .. " assertions")
''')

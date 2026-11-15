"""Offline tests for the Characters page: snapshots, the people log and farming rates."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
function UnitRace() return "Tauren" end
function GetGuildInfo() return "Hoofprints", "Officer" end
function GetXPExhaustion() return 1500 end
function GetProfessions() return 1, 2, nil, 4, nil end
local profs = { [1] = { "Herbalism", 120, 150 }, [2] = { "Alchemy", 95, 150 }, [4] = { "Cooking", 60, 75 } }
function GetProfessionInfo(i) local p = profs[i] return p[1], nil, p[2], p[3] end
function GetNumSavedInstances() return 1 end
function GetSavedInstanceInfo() return "Onyxia's Lair", 1, 3600, 1, true, false, 0, true, 40, "Normal", 1, 1 end
C_Container.GetContainerNumFreeSlots = function(bag) return bag == 0 and 4 or 2 end
function GetCurrentTitle() return 0 end
C_Reputation = {
    GetNumFactions = function() return 3 end,
    GetFactionDataByIndex = function(i)
        return ({ { name = "Horde", isHeader = true }, { name = "Thunder Bluff", reaction = 7 }, { name = "Orgrimmar", reaction = 6 } })[i]
    end,
}
C_Item = { GetItemInfo = function(link)
    if link:find("Boar Ribs", 1, true) then return "Boar Ribs", link, 1, 5, 1, "", "", 20, 0, 0, 25 end
end }
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
NOW = NOW + 11; RunTimers()
local ch = ns.char

-- ------------------------------------------------------------ snapshot
local snap = ns.TakeSnapshot()
eq(snap.race, "Tauren", "race")
eq(snap.class, "DRUID", "class file")
eq(snap.guild, "Hoofprints", "guild")
eq(snap.guildRank, "Officer", "guild rank")
eq(snap.gold, state.money, "gold")
eq(snap.rested, 1500, "rested XP")
eq(snap.hearth, "Razor Hill", "hearth")
eq(#snap.profs, 3, "three professions")
eq(snap.profs[1].n, "Herbalism", "profession name")
eq(snap.profs[1].r, 120, "profession rank")
eq(#snap.locks, 1, "one lockout")
eq(snap.locks[1].n, "Onyxia's Lair", "lockout name")
eq(snap.locks[1].e, time() + 3600, "lockout expiry")
eq(snap.bagFree, 12, "free bag slots")
eq(snap.bagTotal, 10, "bag slots from the harness")
eq(snap.rep.n, "Thunder Bluff", "best reputation")
eq(snap.rep.r, 7, "best reputation standing")
state.money = state.money + 500
fire("PLAYER_MONEY")
eq(ch.snap.gold, state.money, "gold follows PLAYER_MONEY")

-- ------------------------------------------------------------ people
state.group = 3
units.party1 = { name = "Thrall", guid = "Player-1-T" }
units.party2 = { name = "Jaina", guid = "Player-1-J" }
fire("GROUP_ROSTER_UPDATE")
eq(ch.people.Thrall.n, 1, "joined once")
eq(ch.c.people_met, 2, "two people met")
fire("GROUP_ROSTER_UPDATE")
eq(ch.people.Thrall.n, 1, "roster refresh is not a new grouping")
local tick
for _, f in ipairs(frames) do if f.scripts.OnUpdate then tick = f end end
local people
for _, f in ipairs(frames) do
    if f.scripts.OnUpdate then
        local before = ch.people.Thrall.t or 0
        f.scripts.OnUpdate(f, 5)
        if (ch.people.Thrall.t or 0) > before then people = f end
    end
end
eq(people ~= nil, true, "people ticker found")
local t0 = ch.people.Thrall.t
people.scripts.OnUpdate(people, 5)
eq(ch.people.Thrall.t, t0 + 5, "grouped seconds")
units.party2 = nil; state.group = 2
fire("GROUP_ROSTER_UPDATE")
units.party2 = { name = "Jaina", guid = "Player-1-J" }; state.group = 3
fire("GROUP_ROSTER_UPDATE")
eq(ch.people.Jaina.n, 2, "rejoining counts again")
eq(ch.c.people_groupings, 3, "three joinings")
local list = ns.RosterPeople()
eq(#list, 2, "people list")

-- ------------------------------------------------------------ loot value and farming rates
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2677|h[Boar Ribs]|hx3.")
eq(ch.c.loot_value, 75, "vendor value of loot")
eq(ch.r.max_loot_value, 75, "most valuable loot")
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:9|h[Mystery]|h.")
eq(ch.c.loot_unpriced, 1, "unpriced loot counted")
ns.session.start = GetTime() - 3600
ns.session.c.money_in = (ns.session.c.money_in or 0) + 10000
ns.LogSession()
local e = ch.sessionlog[#ch.sessionlog]
eq(e.lv >= 75, true, "session loot value")
eq(e.it >= 2, true, "session items")
local r = ns.SessionRates(e)
eq(r.active > 0, true, "active time")
eq(ch.r.max_gold_per_hour ~= nil, true, "best gold per hour recorded")

-- ------------------------------------------------------------ the page
ns.db.chars["Forever-Alt"] = { meta = { rev = 1, name = "Altie", realm = "Forever", class = "MAGE", level = 12, created = 1 },
    c = { played_server = 7200 }, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {}, months = {},
    runlog = {}, bestiary = {}, people = { Thrall = { f = 10, l = 20, n = 4, t = 600, cls = "SHAMAN" } },
    snap = { t = 50, level = 12, gold = 1234, played = 7200, class = "MAGE", className = "Mage" } }
local totals = ns.RosterTotals()
eq(totals.chars, 2, "two characters")
eq(totals.gold, state.money + 1234, "account gold")
ns.OpenPage("roster")
local p = ns.rosterPage
eq(p ~= nil, true, "roster page")
for _, s in ipairs(ns.ROSTER_SECTIONS) do p.state.section = s.id; ns.RefreshWindow() end
for _, c in ipairs(ns.RosterCharacters()) do
    p.state.section, p.state.key = "char", c.key
    ns.RefreshWindow()
    local rows = ns.RosterRows(p.state)
    eq(rows[1].back, "all", "character page back row " .. c.key)
end
local mine = ns.RosterRows({ section = "char", key = ns.charKey })
local sawProf, sawLock = false, false
for _, row in ipairs(mine) do
    if row[2] == "Herbalism" then sawProf = true end
    if type(row[2]) == "string" and row[2]:find("Onyxia", 1, true) then sawLock = true end
end
eq(sawProf, true, "profession row")
eq(sawLock, true, "lockout row")
ns.settings.scope = "account"
local merged = ns.RosterPeople()
local thrall
for _, m in ipairs(merged) do if m.name == "Thrall" then thrall = m end end
eq(thrall.n, 5, "people merged across characters")
eq(thrall.f, 10, "earliest first meeting")
R = ns.RosterRows({ section = "farming" })
ns.settings.scope = "char"

-- ------------------------------------------------------------ full backup keeps people and farming fields
local text = assert(ns.SerializeFullBackup())
local snapB = assert(ns.DeserializeFullBackup(text))
eq(snapB.record.people.Thrall.n, 1, "people in full backup")
eq(snapB.record.sessionlog[#snapB.record.sessionlog].lv ~= nil, true, "farming fields in full backup")
ch.people = {}
eq(ns.RestoreFullBackup(snapB), true, "full restore")
eq(ns.char.people.Jaina.n, 2, "people restored")

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("ROSTER PASS: " .. checks .. " assertions")
''')

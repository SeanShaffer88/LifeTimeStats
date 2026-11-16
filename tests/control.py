"""Offline tests for crowd control suffered, cinematics and talent respecs (Control.lua)."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
locData = {}
C_LossOfControl = {
    GetActiveLossOfControlDataByUnit = function(unit, i) if unit == "player" then return locData[i] end end,
}
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(id) return ({ [853] = "Hammer of Justice", [5782] = "Fear", [118] = "Polymorph" })[id] end
C_ClassTalents = { LoadConfig = function() end }
function ConfirmTalentWipe() end
function CinematicFrame_CancelCinematic() end
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
local c = ch.c

-- ------------------------------------------------------------ crowd control
locData[1] = { locType = "STUN_MECHANIC", spellID = 853, duration = 6 }
fire("LOSS_OF_CONTROL_ADDED", "player", 1)
locData[1] = { locType = "FEAR", spellID = 5782, duration = 8 }
fire("LOSS_OF_CONTROL_ADDED", "player", 1)
locData[1] = { locType = "CONFUSE", spellID = 118, duration = 10 }
fire("LOSS_OF_CONTROL_ADDED", 1) -- older clients pass only the index
locData[1] = { locType = "SOMETHING_NEW", displayText = "Dazed", duration = 2 }
fire("LOSS_OF_CONTROL_ADDED", "player", 1)
fire("LOSS_OF_CONTROL_ADDED", "target", 1) -- not the player
locData[1] = { locType = "ROOT", spellID = 853 } -- no duration
fire("LOSS_OF_CONTROL_ADDED", "player", 1)
locData[2] = nil
fire("LOSS_OF_CONTROL_ADDED", "player", 2) -- nothing there

eq(c.cc_taken, 5, "five effects on the player")
eq(c.cc_stun, 1, "stun mechanic counts as a stun")
eq(c.cc_fear, 1, "fear")
eq(c.cc_confuse, 1, "polymorph counts as incapacitated")
eq(c.cc_other, 1, "unknown types go to other")
eq(c.cc_root, 1, "root without a duration still counts")
eq(c.cc_time, 26, "total controlled time")
eq(c.cc_time_fear, 8, "time feared")
eq(c.cc_time_root, nil, "no time for an effect without a duration")
eq(ch.r.cc_longest, 10, "longest effect")
eq(ch.r.cc_longest_what, "Polymorph", "longest effect names its spell")
eq(ch.t.cc_spells["Hammer of Justice"], 2, "by spell")
eq(ch.t.cc_spells.Dazed, 1, "falls back to the alert text")
eq(ch.t.cc_spell_time.Fear, 8, "time by spell")
eq(ns.session.c.cc_taken, 5, "session counts too")

-- unreadable (non-number, unknown) values are skipped, not guessed
ns.IsSecret = function(v) return v == "SECRET" end
locData[1] = { locType = "SECRET", spellID = "SECRET", duration = "SECRET" }
fire("LOSS_OF_CONTROL_ADDED", "player", 1)
eq(c.cc_taken, 6, "a hidden effect still counts once")
eq(c.cc_other, 2, "a hidden type is other")
eq(c.cc_time, 26, "a hidden duration adds no time")
ns.IsSecret = function() return false end

-- ------------------------------------------------------------ cinematics
fire("CINEMATIC_START")
NOW = NOW + 42
fire("CINEMATIC_STOP")
fire("CINEMATIC_START")
NOW = NOW + 5
hooks.CinematicFrame_CancelCinematic()
fire("CINEMATIC_STOP")
fire("PLAY_MOVIE", 16)
NOW = NOW + 120
fire("STOP_MOVIE")
fire("CINEMATIC_STOP") -- a stray stop changes nothing
eq(c.cinematics_seen, 2, "cinematics seen")
eq(c.movies_seen, 1, "movies seen")
eq(c.cinematics_finished, 2, "watched to the end")
eq(c.cinematics_skipped, 1, "skipped")
eq(c.cinematic_time, 167, "time watching")
eq(ch.r.cinematic_longest, 120, "longest scene")

-- ------------------------------------------------------------ respecs and loadouts
fire("CONFIRM_TALENT_WIPE", 50000)
hooks.ConfirmTalentWipe()
fire("CONFIRM_TALENT_WIPE", 100000)
hooks.ConfirmTalentWipe()
hooks.ConfirmTalentWipe() -- no new price shown: counts, costs nothing
eq(c.respecs, 3, "respecs")
eq(c.respec_gold, 150000, "gold on respecs")
eq(ch.r.respec_cost_max, 100000, "most expensive respec")
hooks.LoadConfig(1)
eq(c.talent_loadouts, 1, "loadout loaded")
fire("PLAYER_SPECIALIZATION_CHANGED", "player")
fire("PLAYER_SPECIALIZATION_CHANGED", "party1")
eq(c.spec_changes, 1, "only the player's spec changes")

-- ------------------------------------------------------------ catalog and achievements
local found = {}
for _, rows in pairs(ns.STATS) do for _, row in ipairs(rows) do found[row.key or row.rec or ""] = row end end
for _, key in ipairs({ "cc_taken", "cc_time", "cc_stun", "cc_time_other", "cc_longest", "cinematics_seen",
    "cinematics_skipped", "cinematic_longest", "respecs", "respec_gold", "respec_cost_max", "talent_loadouts", "spec_changes" }) do
    eq(found[key] ~= nil, true, "catalog row " .. key)
end
eq(found.respec_gold.fmt, "money", "respec gold is money")
local lists = {}
for _, l in ipairs(ns.LISTS) do lists[l.id] = l end
eq(lists.cc_spells ~= nil and lists.cc_spell_time.fmt == "time", true, "crowd-control top lists")
local ach = {}
for _, d in ipairs(ns.ACHIEVEMENTS) do ach[d.id] = d end
eq(ach.stunned.value(ch), 1, "Seeing Stars reads stuns")
eq(ach.puppet.value(ch), 26, "Puppet on a String reads controlled time")
eq(ach.cinema.value(ch), 2, "Front Row Seat reads finished scenes")
eq(ach.respec.value(ch), 3, "Change of Heart reads respecs")

-- the window still builds with the new rows
ns.ToggleWindow()
for _, id in ipairs({ "combat", "life", "records", "lists" }) do ns.ShowPage(id) end
print("CONTROL PASS: " .. checks .. " assertions")
''')

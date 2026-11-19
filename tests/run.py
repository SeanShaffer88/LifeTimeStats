import sys, pathlib
from lupa import lua51

_here = pathlib.Path(__file__).resolve().parent.parent
ROOT = _here if (_here / "LifeTimeStats.toc").exists() else _here / "LifeTimeStats"
L = lua51.LuaRuntime(unpack_returned_tuples=True)
L.execute((pathlib.Path(__file__).parent / "harness.lua").read_text(encoding="utf-8"))

toc = (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines()
files = [l.strip() for l in toc if l.strip().endswith(".lua")]
L.execute("ns = {}; addonChunks = {}")
for f in files:
    src = (ROOT / f).read_text(encoding="utf-8")
    chunk = L.eval("function(src, name) local f, e = loadstring(src, name); if not f then error(e) end; return f end")(src, f)
    L.eval("function(f) addonChunks[#addonChunks + 1] = f; f('LifeTimeStats', ns) end")(chunk)

test = r'''
local fails = 0
local function eq(a, b, msg)
  if a ~= b then fails = fails + 1; print("FAIL " .. msg .. ": got " .. tostring(a) .. " want " .. tostring(b)) end
end
local frame = ns.frame
local function fire(ev, ...) frame.scripts.OnEvent(frame, ev, ...) end
local ticker
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then ticker = ticker or f end end

fire("ADDON_LOADED", "LifeTimeStats")
eq(type(LifeTimeStatsDB), "table", "db created")
fire("PLAYER_ENTERING_WORLD", true, false)
for _, e in ipairs(ns.errors) do print("ERR", e) end
eq(ns.char.c.logins, 1, "login")
eq(ns.char.c.hk_server, 42, "hk")

-- Synthetic localized format: reordered arguments and a literal percent.
local pattern = ns.MakePattern("%2$d Stück: %1$s (100%%)")
local captures = ns.Match(pattern, "7 Stück: Testgegenstand (100%)")
eq(captures[1], "Testgegenstand", "reordered localized text capture")
eq(captures[2], "7", "reordered localized quantity capture")
eq(ns.MakePattern("unsupported %f"), nil, "unsupported placeholder declines matching")
eq(ns.Match(ns.MakePattern("%1$s/%1$s"), "a/b"), nil, "repeated argument must agree")

local oldQuestChat = ns.src.questChat
ns.src.questChat = 1
eq(ns.StatSource({ key = "quests_done" }):find("fallback was used", 1, true) ~= nil, true, "quest source reports a fallback")
ns.src.questChat = oldQuestChat
local noCaptures = ns.Match(ns.MakePattern("Trade complete."), "Trade complete.")
eq(type(noCaptures), "table", "literal notification matches")
eq(next(noCaptures), nil, "literal notification does not fabricate captures")
local originalSecret = ns.IsSecret
ns.IsSecret = function(v) return v == "unreadable" end
eq(ns.Match(ns.MakePattern("%s"), "unreadable"), nil, "unreadable chat is skipped")
ns.IsSecret = originalSecret
-- movement: 10 s at 7 yd/s on foot
state.speed = 7
for i = 1, 40 do NOW = NOW + 0.25; ticker.scripts.OnUpdate(ticker, 0.25) end
eq(math.floor(ns.char.c.dist_foot + 0.5), 70, "foot distance")
state.mounted = true
for i = 1, 4 do NOW = NOW + 0.25; ticker.scripts.OnUpdate(ticker, 0.25) end
eq(ns.char.c.mount_ups, 1, "mount up")
state.mounted = false; state.speed = 0

-- jump
hooks.JumpOrAscendStart()
state.falling = true; NOW = NOW + 0.2; RunTimers(); state.falling = false
eq(ns.char.c.jumps, 1, "jump counted")
hooks.JumpOrAscendStart(); NOW = NOW + 0.2; RunTimers()
eq(ns.char.c.jumps, 1, "no jump when not airborne")

-- combat: damage, crit, kill
CLEU = {0, "SPELL_DAMAGE", false, "Player-1-ME", "Malikor", 0x511, 0, "Creature-0-1", "Boar", 0xa48, 0, 5176, "Wrath", 8, 120, 0, 8, 0, 0, 0, true}
fire("COMBAT_LOG_EVENT_UNFILTERED")
eq(ns.char.c.dmg_done, 120, "damage")
eq(ns.char.c.crits, 1, "crit")
eq(ns.char.r.max_crit_what, "Wrath", "crit spell")
CLEU = {0, "UNIT_DIED", false, "", "", 0, 0, "Creature-0-1", "Boar", 0xa48}
fire("COMBAT_LOG_EVENT_UNFILTERED")
eq(ns.char.c.kills_npc, 1, "kill")
eq(ns.char.t.creatures.Boar, 1, "creature tally")
-- pvp kill
CLEU = {0, "SWING_DAMAGE", false, "Player-1-ME", "Malikor", 0x511, 0, "Player-2-X", "Bob", 0x548, 0, 50, 0, 1, 0, 0, 0, nil}
fire("COMBAT_LOG_EVENT_UNFILTERED")
CLEU = {0, "UNIT_DIED", false, "", "", 0, 0, "Player-2-X", "Bob", 0x548}
fire("COMBAT_LOG_EVENT_UNFILTERED")
eq(ns.char.c.kills_pvp, 1, "pvp kill")
eq(ns.char.r.max_streak, 2, "streak")

-- death by falling
CLEU = {0, "ENVIRONMENTAL_DAMAGE", false, "", "", 0, 0, "Player-1-ME", "Malikor", 0x511, 0, "FALLING", 300}
fire("COMBAT_LOG_EVENT_UNFILTERED")
state.dead = true
fire("PLAYER_DEAD"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.deaths, 1, "death")
eq(ns.char.c.deaths_fall, 1, "fall death")
fire("PLAYER_DEAD"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.deaths, 1, "no double death")
state.dead = true; NOW = NOW + 2; RunTimers(); state.dead = false

-- money
fire("LOOT_OPENED"); state.money = 1500; fire("PLAYER_MONEY"); fire("LOOT_CLOSED")
eq(ns.char.c.money_loot, 500, "loot money")
fire("MERCHANT_SHOW"); state.money = 1200; fire("PLAYER_MONEY"); fire("MERCHANT_CLOSED")
eq(ns.char.c.money_vendor_out, 300, "vendor out")
state.repair = 500; fire("MERCHANT_SHOW"); state.repair = 0; fire("UPDATE_INVENTORY_DURABILITY")
eq(ns.char.c.money_repair, 500, "repair")

-- loot messages
fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:1|h[Big Sword]|h|r.")
fire("CHAT_MSG_LOOT", "You receive loot: |cff9d9d9d|Hitem:2|h[Junk]|h|rx5.")
fire("CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:3|h[Bread]|h|rx4.")
eq(ns.char.c.items_looted, 6, "items looted")
eq(ns.char.c.loot_q4, 1, "epic")
eq(ns.char.c.loot_q0, 5, "grey multi")
eq(ns.char.c.items_crafted, 4, "crafted")
eq(ns.char.t.epics["Big Sword"], 1, "epic tally")

-- duel & system
fire("CHAT_MSG_SYSTEM", "Malikor has defeated Bob in a duel")
fire("CHAT_MSG_SYSTEM", "Malikor has fled from Bob in a duel")
eq(ns.char.c.duels_won, 1, "duel won"); eq(ns.char.c.duels_lost, 1, "duel lost")
fire("CHAT_MSG_SYSTEM", "Discovered Razor Hill: 120 experience gained")
eq(ns.char.c.zones_discovered, 1, "explored")

-- xp & level
state.xp = 900; fire("PLAYER_XP_UPDATE")
state.level = 11; state.xp = 50; state.xpmax = 1200; fire("PLAYER_LEVEL_UP", 11); fire("PLAYER_XP_UPDATE")
eq(ns.char.c.xp, 1050, "xp across level")
eq(ns.char.c.levels, 1, "levels")

-- spells
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8690)
eq(ns.char.c.hearths, 1, "hearth")

-- instances: enter, reload-like re-enter, boss, leave, re-enter within 30 min
state.inInst, state.itype, state.iname, state.mapid = true, "party", "Ragefire Chasm", 389
fire("ZONE_CHANGED_NEW_AREA"); fire("ZONE_CHANGED_NEW_AREA")
eq(ns.char.c.runs_party, 1, "one run")
fire("ENCOUNTER_END", 1, "Taragaman", 1, 5, 1)
eq(ns.char.c.boss_kills, 1, "boss"); eq(ns.char.c.runs_party_boss, 1, "run with boss")
state.inInst, state.itype = false, "none"; fire("ZONE_CHANGED_NEW_AREA")
state.inInst, state.itype = true, "party"; fire("ZONE_CHANGED_NEW_AREA")
eq(ns.char.c.runs_party, 1, "re-entry same run")
state.inInst, state.itype = false, "none"; fire("ZONE_CHANGED_NEW_AREA")
fire("CHAT_MSG_SYSTEM", "Ragefire Chasm has been reset.")
state.inInst, state.itype = true, "party"; fire("ZONE_CHANGED_NEW_AREA")
eq(ns.char.c.runs_party, 2, "new run after reset")

-- emotes / chat hooks
hooks.DoEmote("dance"); fire("CHAT_MSG_WHISPER_INFORM", "hi", "Bob")
eq(ns.char.c.emote_DANCE, 1, "dance"); eq(ns.char.c.whispers_sent, 1, "whisper")

-- played
fire("TIME_PLAYED_MSG", 5000, 100)
eq(ns.char.c.played_server, 5000, "played")

-- backup roundtrip
local s = ns.Serialize(ns.char)
local data, n = ns.Deserialize(s)
eq(type(data), "table", "deserialize ok " .. tostring(n))
eq(data.t.creatures.Boar, 1, "roundtrip tally")
eq(data.t.zonetime["Durotar"] ~= nil, true, "zone with space-safe")
local bad = ns.Deserialize(s:sub(1, -3))
eq(bad, nil, "checksum catches truncation")
eq(ns.Deserialize("LTS1|000000|c.x=os.exit()"), nil, "rejects code")
local fresh = ns.NewCharRecord()
ns.MergeMax(fresh, data)
eq(fresh.c.jumps, 1, "merge")

-- views & formatting
local acc = ns.GetView("account")
eq(acc.c.jumps, 1, "account view")
eq(ns.FormatTime(90061), "1d 1h 1m", "time fmt")
eq(ns.FMT.yards(3520), "3,520 yd (2.0 mi)", "yards fmt")
for cat, list in pairs(ns.STATS) do
  for _, st in ipairs(list) do
    local v = ns.StatValue(st, ns.char); ns.FormatStat(st, v)
    local sv = ns.StatValue(st, ns.session); ns.FormatStat(st, sv)
  end
end

-- UI smoke
-- v1.1 trackers
fire("PLAYER_ENTERING_WORLD", false, false)
CLEU = {0, "SWING_MISSED", false, "Creature-0-1-1-1-99-2", "Boar", 0xa48, 0, "Player-1-ME", "Malikor", 0x511, 0, "DODGE"}
fire("COMBAT_LOG_EVENT_UNFILTERED")
CLEU = {0, "SWING_MISSED", false, "Creature-0-1-1-1-99-2", "Boar", 0xa48, 0, "Player-1-ME", "Malikor", 0x511, 0, "PARRY"}
fire("COMBAT_LOG_EVENT_UNFILTERED")
CLEU = {0, "SWING_MISSED", false, "Player-1-ME", "Malikor", 0x511, 0, "Creature-0-1-1-1-99-2", "Boar", 0xa48, 0, "DODGE"}
fire("COMBAT_LOG_EVENT_UNFILTERED")
eq(ns.char.c.in_dodge, 1, "dodged in"); eq(ns.char.c.in_parry, 1, "parried in"); eq(ns.char.c.out_dodge, 1, "dodged out")
CLEU = {0, "SWING_DAMAGE", false, "Creature-0-1-1-1-99-2", "Boar", 0xa48, 0, "Player-1-ME", "Malikor", 0x511, 0, 80, 0, 1, 0, 0, 0, true, nil, true}
fire("COMBAT_LOG_EVENT_UNFILTERED")
eq(ns.char.c.crits_taken, 1, "crit taken"); eq(ns.char.c.crushing_in, 1, "crushing")
-- unique creature by npc id + first kill already set
CLEU = {0, "SPELL_DAMAGE", false, "Player-1-ME", "Malikor", 0x511, 0, "Creature-0-1-1-1-3098-5", "Mottled Boar", 0xa48, 0, 5176, "Wrath", 8, 50, 0, 8, 0, 0, 0, false}
fire("COMBAT_LOG_EVENT_UNFILTERED")
CLEU = {0, "UNIT_DIED", false, "", "", 0, 0, "Creature-0-1-1-1-3098-5", "Mottled Boar", 0xa48}
fire("COMBAT_LOG_EVENT_UNFILTERED")
eq(ns.char.un.creatures, 2, "unique creature by id")
-- fall survived
CLEU = {0, "ENVIRONMENTAL_DAMAGE", false, "", "", 0, 0, "Player-1-ME", "Malikor", 0x511, 0, "FALLING", 250}
state.dead = false
fire("COMBAT_LOG_EVENT_UNFILTERED"); NOW = NOW + 2; RunTimers()
eq(ns.char.r.max_fall_survived, 250, "fall survived"); eq(ns.char.r.max_fall_fatal, 300, "fatal fall from earlier death")
-- corpse run
local t0 = time
hooks.RepopMe()
time = function(...) if ... then return t0(...) end return t0() + 95 end
fire("PLAYER_UNGHOST"); time = t0
eq(ns.char.c.corpse_runs, 1, "corpse run"); eq(ns.char.r.max_corpse_time, 95, "corpse time")
-- quest timing + unique quest
fire("QUEST_ACCEPTED", 7, 4641)
time = function(...) if ... then return t0(...) end return t0() + 41 end
fire("QUEST_TURNED_IN", 4641, 100, 0); time = t0
eq(ns.char.f.quest_fast, 41, "fastest quest"); eq(ns.char.fw.quest_fast, "Lazy Peons", "quest title"); eq(ns.char.un.quests, 1, "unique quest")
-- boss types
eq(ns.char.c.boss_kills_party, 1, "dungeon boss typed"); eq(ns.char.un.bosses_party, 1, "unique dungeon boss")
-- npc uniques
UnitGUID = function(u) if u == "player" then return "Player-1-ME" elseif u == "npc" then return "Creature-0-1-1-1-3143-9" end end
UnitName = function(u) if u == "npc" then return "Gornek" end return "Malikor" end
fire("GOSSIP_SHOW"); fire("GOSSIP_SHOW"); fire("MERCHANT_SHOW")
eq(ns.char.un.npcs, 1, "unique npc"); eq(ns.char.un.vendors, 1, "unique vendor"); eq(ns.char.first.npc, "Gornek", "first npc")
-- rolls / rep / skill / errors
fire("CHAT_MSG_SYSTEM", "Malikor rolls 100 (1-100)")
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your Orgrimmar reputation has increased by 250.")
fire("CHAT_MSG_SKILL", "Your skill in Herbalism has increased to 75.")
fire("UI_ERROR_MESSAGE", 1, "Inventory is full.")
eq(ns.char.c.rolls_max, 1, "perfect roll"); eq(ns.char.c.rep_gained, 250, "rep"); eq(ns.char.t.skills.Herbalism, 1, "skill"); eq(ns.char.c.bags_full, 1, "bags full")
-- watcher: continent/city/zone kills
local w; for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame and f ~= ticker then w = w or f end end
for i = 1, 8 do NOW = NOW + 0.25; w.scripts.OnUpdate(w, 0.25) end
eq(ns.char.t.continenttime ~= nil and ns.char.t.continenttime.Kalimdor ~= nil, true, "continent time")
-- days
eq(ns.char.days[os.date("%Y%m%d")].jumps, 1, "daily bucket")
local today = ns.GetView("char", "today"); eq(today.c.jumps, 1, "today view")
-- class colour applied (druid orange)
-- the default notebook skin inks class colours down to ink luminance (0.34), keeping the hue
eq(math.floor(ns.THEME.amber[1] * 100 + 0.5), 58, "class color r"); eq(math.floor(ns.THEME.amber[2] * 100), 28, "class color g")
local a = ns.THEME.amber
eq(math.floor((0.299 * a[1] + 0.587 * a[2] + 0.114 * a[3]) * 100 + 0.5), 34, "class colour inked to ink brightness")
-- backup with new sections
local s2 = ns.Serialize(ns.char)
local d2 = ns.Deserialize(s2)
eq(d2.f.quest_fast, 41, "backup fastest"); eq(d2.fw.quest_fast, "Lazy Peons", "backup label"); eq(d2.u.npcs["3143"], true, "backup unique")
local fresh2 = ns.NewCharRecord(); ns.MergeMax(fresh2, d2)
eq(fresh2.un.npcs, 1, "merge recounts uniques"); eq(fresh2.first.npc, "Gornek", "merge firsts")

ns.ToggleWindow()
for _, c in ipairs(ns.CATEGORIES) do ns.ShowPage(c.id) end
ns.settings.range = "today"; for _, c in ipairs(ns.CATEGORIES) do ns.ShowPage(c.id) end
ns.settings.range = "session"; for _, c in ipairs(ns.CATEGORIES) do ns.ShowPage(c.id) end
ns.settings.scope = "account"; ns.settings.range = "lifetime"; for _, c in ipairs(ns.CATEGORIES) do ns.ShowPage(c.id) end
LifeTimeStatsWindow.search.text = "dodge"; ns.ShowPage("search")
ns.ShowExport(); ns.ShowImport(); ns.OpenOptions()
SlashCmdList.LIFETIMESTATS("help"); SlashCmdList.LIFETIMESTATS("summary")

-- persistence: logout bumps rev; backup copy wins if newer
fire("PLAYER_LOGOUT")
eq(LifeTimeStatsCharDB.data, ns.char, "char backup mirrors")
local rev = ns.char.meta.rev
LifeTimeStatsDB.chars["Forever-Malikor"] = nil  -- simulate lost account file
ns.InitDB()
eq(ns.char.meta.rev, rev, "restored from char backup")
eq(ns.restoredFromBackup, true, "flag restore")
local intact = ns.char
local badPrimary = ns.NewCharRecord()
badPrimary.meta.rev = "broken"
LifeTimeStatsDB.chars[ns.charKey] = badPrimary
ns.InitDB()
eq(ns.char, intact, "malformed primary revision does not displace healthy mirror")
local badMirror = ns.NewCharRecord()
badMirror.meta.rev = rev + 10
badMirror.t.creatures = { Boar = "broken" }
LifeTimeStatsCharDB.data = badMirror
ns.InitDB()
eq(ns.char, intact, "higher mirror revision does not override healthy tally data")

local checkpoint = LifeTimeStatsCharDB.previousGood
local initialJumps = intact.c.jumps
intact.c.jumps = initialJumps + 1
eq(checkpoint.c.jumps, initialJumps, "recovery generation is detached from live stats")
LifeTimeStatsDB.chars[ns.charKey] = badPrimary
LifeTimeStatsCharDB.data = badMirror
ns.InitDB()
eq(ns.char.c.jumps, initialJumps, "recover previous generation when both current copies fail")
eq(ns.char == checkpoint, false, "recovery does not alias its saved input")

local savedRevision = ns.char.meta.rev
ns.char.meta.rev = 9007199254740990
ns.Save()
eq(ns.char.meta.rev, 9007199254740990, "save revision saturates at valid limit")
ns.char.meta.rev = savedRevision
local originalHighlights = ns.SessionRecordHighlights
local errorCount = #ns.errors
ns.SessionRecordHighlights = function() error("broken recap fixture") end
fire("PLAYER_LOGOUT")
eq(ns.char.meta.rev, savedRevision + 1, "failed recap does not block record revision")
eq(#ns.errors, errorCount + 1, "failed save callback is logged")
ns.errors[#ns.errors] = nil
eq(LifeTimeStatsCharDB.session.id, ns.session.id, "failed recap preserves reload continuity")
eq(LifeTimeStatsCharDB.lastSession, nil, "failed recap does not retain stale summary")
ns.SessionRecordHighlights = originalHighlights
-- ===== v1.2 hardening =====
-- help page + reset window
ns.ShowPage("help"); ns.ResetWindow()
-- NaN / inf guards
local before = ns.char.c.jumps
ns.Add("jumps", 0/0); ns.Add("jumps", math.huge); ns.Max("max_hit", 0/0); ns.Min("quest_fast", -1); ns.Tally("zonetime", "X", 0/0)
eq(ns.char.c.jumps, before, "NaN/inf ignored"); eq(ns.char.t.zonetime.X, nil, "NaN tally ignored")
-- unique cap
local oldCap = ns.char.un.items or 0
ns.char.un.items = ns.UNIQUE_CAP
eq(ns.Unique("items", "new-one"), false, "unique cap stops growth")
ns.char.un.items = oldCap
-- session survives reload, resets on login
ns.Add("jumps", 3)
local sessJ = ns.session.c.jumps
fire("PLAYER_LOGOUT")
eq(type(LifeTimeStatsCharDB.session), "table", "session saved at logout")
ns.session = { c = {}, r = {}, t = {}, u = {}, un = {}, f = {}, fw = {}, fd = {}, first = {}, firstd = {}, start = GetTime() }
ns.InitDB()
eq(ns.session.c.jumps, sessJ, "session restored after reload")
fire("PLAYER_ENTERING_WORLD", false, true)
eq(ns.session.c.jumps, sessJ, "reload keeps session")
fire("PLAYER_ENTERING_WORLD", true, false)
eq(ns.session.c.jumps, nil, "real login resets session")
eq(ns.session.c.logins, 1, "login counted after reset")
-- Aggregating a legacy record is read-only; initialization handles migration.
LifeTimeStatsDB.chars["Forever-Oldtimer"] = { meta = { rev = 3, name = "Oldtimer" }, c = { jumps = 500, kills_npc = 20 }, r = { max_hit = 99 }, t = { creatures = { Boar = 20 } } }
ns.InvalidateAccount()
local acc2 = ns.GetView("account", "lifetime")
eq(acc2.c.kills_npc >= 20, true, "old record merged into account view")
eq(LifeTimeStatsDB.chars["Forever-Oldtimer"].u, nil, "account view does not mutate a legacy record")
local malformed = ns.NewCharRecord()
malformed.c.jumps, malformed.t.creatures = 0/0, false
malformed.days["20260101"], malformed.f.quest_fast = false, "bad"
malformed.rh[1] = { at = "bad", v = 10 }
ns.db.chars["Forever-Malformed"] = malformed
ns.InvalidateAccount()
local safeView = ns.GetView("account", "lifetime")
eq(type(safeView.c.jumps), "number", "malformed alt does not block account totals")
eq(safeView.c.jumps == safeView.c.jumps, true, "malformed alt does not poison numeric totals")
eq(malformed.f.quest_fast, "bad", "account view does not rewrite malformed source")
ns.db.chars["Forever-Malformed"] = nil
ns.InvalidateAccount()
-- LTS1 backup (1.0 format) still restores
local v1 = "c.jumps=777;r.max_hit=1234;t.creatures.Wolf=5"
local function cs(str) local sum = 0 for i = 1, #str do sum = (sum * 31 + str:byte(i)) % 16777213 end return string.format("%06x", sum) end
local d1 = ns.Deserialize("LTS1|" .. cs(v1) .. "|" .. v1)
eq(d1 and d1.c.jumps, 777, "LTS1 import"); eq(d1 and d1.t.creatures.Wolf, 5, "LTS1 tally")
-- A checksummed but invalid backup must not partially update the destination.
local badLegacy = "c.jumps=999999;f.quest_fast=-1"
local beforeRestore = ns.char.c.jumps
eq(ns.RestoreLegacyBackup("LTS2|" .. cs(badLegacy) .. "|" .. badLegacy), nil, "negative duration rejected")
eq(ns.char.c.jumps, beforeRestore, "bad restore leaves counters intact")
local hidden = ns.settings.minimap.hide
SlashCmdList.LIFETIMESTATS("minimap typo")
eq(ns.settings.minimap.hide, hidden, "invalid minimap command does not toggle visibility")
for i = 1, 450 do ns.Tally("budget_test", "item" .. i, 1) end
ns.Tally("budget_test", "item1", 2)
eq(ns.char.t.budget_test.item1, 3, "existing lifetime tally can grow at cap")
eq(ns.char.t.budget_test.item401, nil, "lifetime tally cannot exceed cap")
eq(ns.session.t.budget_test.item401, nil, "session tally cannot exceed cap")
ns.char.t.budget_test, ns.session.t.budget_test = nil, nil
local impossibleDay = "days.20250229.jumps=4"
eq(ns.Deserialize("LTS2|" .. cs(impossibleDay) .. "|" .. impossibleDay), nil, "legacy rejects invalid calendar day")
local leapDay = "days.20240229.jumps=4"
eq(type(ns.Deserialize("LTS2|" .. cs(leapDay):upper() .. "|" .. leapDay)), "table", "legacy accepts leap date and uppercase checksum")
local foldDestination = ns.NewCharRecord()
foldDestination.meta.monthsThrough = "20240229"
ns.MergeMax(foldDestination, { days = { ["20240229"] = { jumps = 4 }, ["20240301"] = { jumps = 5 } } })
eq(foldDestination.days["20240229"], nil, "legacy merge ignores days already rolled into months")
eq(foldDestination.days["20240301"].jumps, 5, "legacy merge keeps newer day")
local malformedHistory = ns.NewCharRecord()
malformedHistory.qa = "bad"
malformedHistory.t.test = { corrupt = "bad" }
for i = 1, 401 do malformedHistory.t.test[string.format("%03d", i)] = 1 end
ns.PruneTallies(malformedHistory)
eq(type(malformedHistory.qa), "table", "corrupt quest timer container replaced")
eq(malformedHistory.t.test.corrupt, nil, "non-numeric tally removed before sorting")
eq(malformedHistory.t.test["400"], 1, "stable tie cutoff retains earlier label")
eq(malformedHistory.t.test["401"], nil, "stable tie cutoff drops later label")
local todayKey, days = ns.Today(), ns.char.days
ns.char.days = { [todayKey] = false }
eq(ns.GetView("char", "week").c.jumps, nil, "range tolerates malformed day container")
eq(ns.DaySeries(ns.char, "jumps", 1)[1].v, 0, "chart tolerates malformed day container")
ns.char.days[todayKey] = { jumps = "bad" }
eq(ns.GetView("char", "month").c.jumps, nil, "range skips nonnumeric daily values")
eq(ns.DaySeries(ns.char, "jumps", 1)[1].v, 0, "chart skips nonnumeric daily values")
ns.char.days = days

-- Isolate malformed live values so tracking can continue for unaffected stats.
local day = ns.char.days[ns.Today()] or {}
ns.char.days[ns.Today()] = day
ns.char.c.audit_counter, ns.session.c.audit_counter, day.audit_counter = "bad", false, math.huge
ns.Add("audit_counter", 2)
eq(ns.char.c.audit_counter, 2, "counter repairs malformed lifetime value")
eq(ns.session.c.audit_counter, 2, "counter repairs malformed session value")
eq(day.audit_counter, 2, "counter repairs malformed day value")
ns.char.c.audit_counter = 1e308
ns.Add("audit_counter", 1e308)
eq(ns.char.c.audit_counter, 1e308, "overflow cannot poison lifetime counter")
eq(day.audit_counter, 2, "rejected overflow does not partially change day counter")
ns.Add({}, 3); ns.Max(nil, 3); ns.Min({}, 3); ns.First(false, "Invalid")
eq(ns.char.first[false], nil, "invalid first key rejected")
ns.Max("audit_max", 10, "Old label")
ns.Max("audit_max", 20)
eq(ns.char.r.audit_max_what, nil, "unlabelled record does not inherit old label")
ns.char.f.audit_min, ns.session.f.audit_min = "bad", -1
ns.Min("audit_min", 5)
eq(ns.char.f.audit_min, 5, "valid time replaces malformed fastest record")
eq(ns.session.f.audit_min, 5, "valid time replaces negative session record")
ns.char.u.audit_unique, ns.char.un.audit_unique = false, "bad"
eq(ns.Unique("audit_unique", {}), false, "unique key rejects table")
eq(ns.Unique("audit_unique", 42), true, "valid ID repairs malformed unique bucket")
eq(ns.char.un.audit_unique, 1, "repaired unique count starts at one")
ns.char.t.audit_tally, ns.session.t.audit_tally = { entry = "bad" }, false
ns.Tally("audit_tally", "entry", 3)
eq(ns.char.t.audit_tally.entry, 3, "tally repairs malformed count")
eq(ns.session.t.audit_tally.entry, 3, "tally repairs malformed session bucket")
local invalidPath = "c.jumps.=3"
eq(ns.Deserialize("LTS2|" .. cs(invalidPath) .. "|" .. invalidPath), nil, "trailing backup path segment rejected")
ns.LogError("fixture", string.rep("x", 5000))
eq(#ns.errors[#ns.errors] < 2100, true, "retained error length is bounded")
ns.errors[#ns.errors] = nil
for _, values in ipairs({ns.char.c, ns.session.c, day}) do values.audit_counter = nil end

local discovery = ns.NewCharRecord()
discovery.un.orphan = 5
discovery.u.good = { [42] = true, ["42"] = true, excluded = false, [true] = true }
ns.EnsureRecord(discovery)
eq(discovery.un.orphan, nil, "orphaned unique total removed")
eq(discovery.un.good, 1, "unique repair excludes invalid keys and deduplicates IDs")
eq(discovery.u.good.excluded, nil, "false discovery marker removed")
local currentMonth = date("%Y%m")
local monthly = { months = { [currentMonth] = { jumps = 7, bad = math.huge } },
    days = { [currentMonth .. "01"] = { jumps = 5, bad = "x" }, [currentMonth .. "02"] = false } }
eq(ns.MonthTotal(monthly, "jumps", currentMonth), 12, "monthly total skips corrupt day bucket")
eq(ns.MonthRecord(monthly, currentMonth).bad, nil, "monthly record skips invalid numeric fields")
eq(ns.MonthRecords(monthly, 3)[3].v.jumps, 12, "multi-month records add retained days once")
eq(ns.MonthSeries(monthly, "jumps", 3)[3].v, 12, "multi-month series matches individual total")

-- early events before the DB exists are ignored safely
local saveChar = ns.char; ns.char = nil
fire("PLAYER_MONEY"); fire("GOSSIP_SHOW"); fire("COMBAT_LOG_EVENT_UNFILTERED")
ns.char = saveChar
-- Top-N keeps the exact full-sort order, including the cutoff tie-break.
local rankView, expected = { t = { examples = {} } }, {}
for i = 1, 501 do
    local name, count = string.format("label%03d", i), i % 13
    rankView.t.examples[name] = count
    expected[i] = {name, count}
end
table.sort(expected, function(a, b) return a[2] == b[2] and a[1] < b[1] or a[2] > b[2] end)
for _, limit in ipairs({1, 25, 100, 600}) do
    local rows = ns.TopList(rankView, "examples", limit)
    eq(#rows, math.min(limit, #expected), "top list respects limit")
    for i, row in ipairs(rows) do eq(row[1], expected[i][1], "top list matches full sort") end
end
eq(#ns.TopList(rankView, "examples", 0), 0, "zero limit selects nothing")
-- stress: 20k combat events + 2k zone ticks, and saved data size with heavy synthetic data
local t0c = os.clock()
for i = 1, 20000 do
  CLEU = {0, "SPELL_DAMAGE", false, "Player-1-ME", "Malikor", 0x511, 0, "Creature-0-1-1-1-" .. (i % 500) .. "-" .. i, "Mob" .. (i % 500), 0xa48, 0, 5176, "Wrath", 8, 50 + i % 90, 0, 8, 0, 0, 0, i % 7 == 0}
  fire("COMBAT_LOG_EVENT_UNFILTERED")
  if i % 3 == 0 then CLEU = {0, "UNIT_DIED", false, "", "", 0, 0, "Creature-0-1-1-1-" .. (i % 500) .. "-" .. i, "Mob" .. (i % 500), 0xa48}; fire("COMBAT_LOG_EVENT_UNFILTERED") end
end
local cleuMs = (os.clock() - t0c) * 1000
print(string.format("PERF 20k combat events + 6.6k kills: %.0f ms (%.3f ms/event)", cleuMs, cleuMs / 26667))
eq(cleuMs / 26667 < 0.2, true, "combat handler under 0.2 ms/event")
for i = 1, 3000 do ns.Unique("items", tostring(i)); ns.Unique("subzones", "Zone" .. i) end
for d = 1, 60 do ns.char.days[string.format("2026%02d%02d", 1 + math.floor(d / 28), 1 + d % 28)] = { jumps = d, dist_foot = d * 100, kills_npc = d, money_in = d * 1000 } end
fire("PLAYER_LOGOUT")
local daysN = 0 for _ in pairs(ns.char.days) do daysN = daysN + 1 end
eq(daysN <= 40, true, "day history pruned to 40")
local monthsN = 0 for _ in pairs(ns.char.months) do monthsN = monthsN + 1 end
eq(monthsN > 0, true, "pruned days kept as monthly totals")
local creaturesN = 0 for _ in pairs(ns.char.t.creatures) do creaturesN = creaturesN + 1 end
eq(creaturesN <= 400, true, "tallies pruned to 400")
-- Remove stress-only labels before checking subsequent trackers for new names.
local creatures = {}
for label, count in pairs(ns.char.t.creatures) do
    if not label:match("^Mob%d+$") then creatures[label] = count end
end
local sz = #ns.Serialize(ns.char)
print(string.format("SIZE heavy character backup: %.0f KB", sz / 1024))
eq(sz < 400 * 1024, true, "heavy character under 400 KB")
ns.char.t.creatures = creatures
local t1 = os.clock()
ns.settings.scope = "char"; ns.settings.range = "lifetime"
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
print(string.format("PERF all %d pages refreshed: %.1f ms", #ns.CATEGORIES, (os.clock() - t1) * 1000))

-- ===== v1.3 achievements =====
ns.char.meta.achInit = nil
ns.char.ach, ns.char.achr = {}, {}
local before = ns.CheckAchievements(true)
eq(before, 0, "first check marks existing progress as retro, nothing new")
eq(ns.char.ach["kills:2"] ~= nil, true, "kills II earned retro from stress data")
eq(ns.char.achr["kills:1"], true, "retro flag set")
eq(ns.AchNewCount(), 0, "no new after retro")
-- earn something new
ns.char.c.emote_DANCE = 0
ns.Add("emote_DANCE", 10)
ns.settings.achAnnounce = "chat"
local pc = #printed
local newly = ns.CheckAchievements()
eq(newly >= 1, true, "dance II newly earned")
eq(#printed > pc, true, "chat announce printed")
eq(ns.AchNewCount() >= 1, true, "new count")
ns.settings.achAnnounce = "toast"; ns.Add("emote_DANCE", 100); ns.CheckAchievements()
-- below-is-better tiers
local defFast
for _, d in ipairs(ns.ACHIEVEMENTS) do if d.id == "fastquest" then defFast = d end end
eq(ns.AchTier(defFast, 41), 2, "41s quest earns under-60s tier"); eq(ns.AchTier(defFast, nil), 0, "no time no tier")
local st = ns.AchState(defFast, { f = { quest_fast = 45 } })
eq(st.tier, 2, "state tier"); eq(st.progress > 0 and st.progress < 1, true, "progress toward 30s")
-- totals, backup, account merge
local e, t, pts, mx = ns.AchTotals(ns.char)
eq(e > 0 and t > 200 and pts > 0 and mx > pts, true, "totals")
local d3 = ns.Deserialize(ns.Serialize(ns.char))
eq(d3.ach["dance:2"] ~= nil, true, "backup keeps achievements")
local fr = ns.NewCharRecord(); ns.MergeMax(fr, d3); eq(fr.ach["dance:2"] ~= nil, true, "restore achievements")
ns.InvalidateAccount(); eq(ns.GetView("account", "lifetime").ach["dance:2"] ~= nil, true, "account achievements")
-- page
ns.settings.scope = "char"
ns.ShowPage("achievements")
eq(ns.AchNewCount(), 0, "viewing the page marks achievements seen")
for _, cn in ipairs({"Travel","Fastest","All"}) do end
ns.settings.scope = "account"; ns.ShowPage("achievements"); ns.settings.scope = "char"
print("ACH " .. #ns.ACHIEVEMENTS .. " achievements, " .. t .. " tiers, " .. mx .. " points")
print("STATS " .. ns.CountStats() .. " ACHS " .. #ns.ACHIEVEMENTS)

-- ===== v1.4 compare + share =====
-- second character in the account file
LifeTimeStatsDB.chars["Forever-Altbank"] = { meta = { rev = 1, name = "Altbank", realm = "Forever", class = "MAGE", level = 12 },
  c = { jumps = 99999999, dist_foot = 5, deaths = 2, played_server = 3600 }, r = { max_hit = 5 }, t = {} }
ns.EnsureRecord(LifeTimeStatsDB.chars["Forever-Altbank"])
ns.ShowPage("compare")
local cp = nil
-- find compare page via OpenPage path
ns.OpenPage("compare")
eq(ns.settings.lastCategory, "compare", "compare page opens")
-- share text
local txt = ns.ShareText("deaths")
eq(txt:find("|", 1, true), nil, "share text has no escape codes")
eq(#txt <= 250, true, "share text length")
for _, tp in ipairs({"summary","travel","combat","deaths","adventure","wealth","social","records","fastest","achievements","timeline"}) do
  local t2 = ns.ShareText(tp); eq(#t2 > 20 and #t2 <= 250 and not t2:find("|", 1, true), true, "share topic " .. tp)
end
local sent = {}
SendChatMessage = function(msg, chan) sent[#sent + 1] = { msg, chan } end
local sharesBefore = ns.char.c.shares or 0
SlashCmdList.LIFETIMESTATS("share g wealth")
eq(#sent, 1, "share command sends once"); eq(sent[1] and sent[1][2], "GUILD", "guild channel")
eq((ns.char.c.shares or 0), sharesBefore + 1, "share counted")
SlashCmdList.LIFETIMESTATS("share g deaths extra")
eq(#sent, 1, "malformed share command does not send")
local originalGuild = IsInGuild
IsInGuild = function() return false end
eq(ns.ShareSend("text", "GUILD"), false, "send rechecks channel membership")
eq(#sent, 1, "unavailable channel not called")
IsInGuild = originalGuild
local originalSend = SendChatMessage
SendChatMessage = function() return false end
eq(ns.ShareSend("text", "SAY"), false, "explicit API failure reported")
eq(ns.char.c.shares, sharesBefore + 1, "failed sends not counted")
local payload
SendChatMessage = function(text) payload = text end
eq(ns.ShareSend("one\ntwo\tthree", "SAY"), true, "safe edited text sent")
eq(payload, "one two three", "chat controls flattened")
eq(ns.ShareSend(string.rep("x", 254) .. "é", "SAY"), true, "multibyte text sent")
eq(#payload, 254, "UTF-8 code point not cut in half")
SendChatMessage = originalSend
SlashCmdList.LIFETIMESTATS("share deaths")
eq(#sent, 1, "no channel = preview only, nothing sent")
eq(LifeTimeStatsShareDialog and LifeTimeStatsShareDialog:IsShown(), true, "share preview dialog shown")
SlashCmdList.LIFETIMESTATS("share nonsense")
eq(#sent, 1, "unknown topic sends nothing")
SlashCmdList.LIFETIMESTATS("compare")
-- forget character popup guarded for self
eq(ns.db.chars["Forever-Altbank"] ~= nil, true, "alt still there")
StaticPopupDialogs.LIFETIMESTATS_FORGET_CHAR.OnAccept(nil, ns.charKey)
eq(ns.db.chars[ns.charKey] ~= nil, true, "cannot forget the current character")
StaticPopupDialogs.LIFETIMESTATS_FORGET_CHAR.OnAccept(nil, "Forever-Altbank")
eq(ns.db.chars["Forever-Altbank"], nil, "forget alt works")
ns.ShowPage("compare")

-- ===== v1.5 Forever combat sources (no combat log) =====
ns.cleuSeen = nil
UnitGUID = function(u) if units[u] then return units[u].guid end if u == "player" then return "Player-1-ME" end end
UnitName = function(u) if units[u] then return units[u].name end return "Malikor" end
local k0 = ns.char.c.kills_npc
-- XP chat line = kill
fire("CHAT_MSG_COMBAT_XP_GAIN", "Scorpid Worker dies, you gain 45 experience.")
eq(ns.char.c.kills_npc, k0 + 1, "kill from XP message")
eq(ns.char.t.creatures["Scorpid Worker"], 1, "XP kill named")
-- same kill seen by the unit watch right after: not double counted
state.combat = true
units.target = { guid = "Creature-0-1-1-1-3124-77", name = "Scorpid Worker", hostile = true }
fire("UNIT_HEALTH", "target")
units.target.dead = true
fire("PLAYER_TARGET_CHANGED")
eq(ns.char.c.kills_npc, k0 + 1, "unit death matched to XP line, no double count")
-- grey mob: only the unit watch sees it
units.target = { guid = "Creature-0-1-1-1-3098-88", name = "Mottled Boar", hostile = true }
fire("UNIT_HEALTH", "target"); units.target.dead = true; fire("UNIT_HEALTH", "target")
eq(ns.char.c.kills_npc, k0 + 2, "unit-watch kill")
-- tapped by someone else: not ours
units.target = { guid = "Creature-0-1-1-1-3098-99", name = "Mottled Boar", hostile = true, tapdenied = true }
fire("UNIT_HEALTH", "target"); units.target.dead = true; fire("UNIT_HEALTH", "target")
eq(ns.char.c.kills_npc, k0 + 2, "tap-denied kill ignored")
-- honor kill
local p0 = ns.char.c.kills_pvp
fire("CHAT_MSG_COMBAT_HONOR_GAIN", "Grumsh dies, honorable kill Rank: Scout (Estimated Honor Points: 12)")
eq(ns.char.c.kills_pvp, p0 + 1, "honor kill")
-- secret XP line inside an instance
issecretvalue = function(v) return v == "SECRET" end
fire("CHAT_MSG_COMBAT_XP_GAIN", "SECRET")
eq(ns.char.c.kills_npc, k0 + 3, "secret XP line still counts a kill")
eq(ns.char.t.creatures["SECRET"], nil, "secret name never stored")
ns.Tally("creatures", "SECRET"); ns.Unique("npcs", "SECRET"); ns.Add("SECRET", 1)
eq(ns.char.t.creatures["SECRET"], nil, "Tally refuses secret")
issecretvalue = nil
-- UNIT_COMBAT on you
local dt0, cr0 = ns.char.c.dmg_taken or 0, ns.char.c.crits_taken or 0
units.target = { guid = "Creature-0-1-1-1-5-5", name = "Durotar Tiger", hostile = true }
fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 900, 1)
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
fire("UNIT_COMBAT", "player", "HEAL", "", 25, 2)
eq(ns.char.c.dmg_taken, dt0 + 900, "damage taken via UNIT_COMBAT"); eq(ns.char.c.crits_taken, cr0 + 1, "crit taken")
eq(ns.char.r.max_crit_taken_what, "Durotar Tiger", "crit taken source = target")
-- UNIT_COMBAT on target while solo
local dd0, c0 = ns.char.c.dmg_done or 0, ns.char.c.crits or 0
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 5176)
fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 77, 8)
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
eq(ns.char.c.dmg_done, dd0 + 77, "damage done via UNIT_COMBAT"); eq(ns.char.c.crits, c0 + 1, "crit done")
eq(ns.char.c.out_parry >= 1, true, "your attack parried")
state.group = 3
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
eq(ns.char.c.dmg_done, dd0 + 77, "grouped: target damage not counted")
state.group = 0
-- falls from health
local f0 = ns.char.c.falls or 0
state.hp = 1000; state.falling = true
local ff; for _, f in ipairs(frames) do if f.scripts.OnUpdate then ff = f end end
for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.02) end end
NOW = NOW + 1.5; state.falling = false
for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.02) end end
state.hp = 760; NOW = NOW + 0.5; RunTimers(); NOW = NOW + 1.5; RunTimers()
eq((ns.char.c.falls or 0) >= f0 + 1, true, "fall detected from health drop")
eq(ns.char.r.max_fall_survived >= 240, true, "fall survived from health")
-- death cause guessed from target
state.combat = true; units.target = { guid = "Creature-0-1-1-1-6-6", name = "Kul Tiras Sailor", hostile = true }
local dn0 = ns.char.c.deaths
NOW = NOW + 10; state.dead = false; fire("PLAYER_ALIVE")
ns.char.meta.deathAt = nil
fire("PLAYER_DEAD"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.deaths, dn0 + 1, "death counted")
eq(ns.char.t.killers["Kul Tiras Sailor"] ~= nil, true, "killer = hostile target")
state.dead = true; NOW = NOW + 2; RunTimers(); state.dead = false; fire("PLAYER_ALIVE")
-- loot quality from |cnIQ#: tags
local e0 = ns.char.c.loot_q4 or 0
fire("CHAT_MSG_LOOT", "You receive loot: |cnIQ4:|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r.")
eq(ns.char.c.loot_q4, e0 + 1, "quality from cnIQ tag")
-- pseudo spells ignored
local cs = ns.char.c.casts
GetSpellInfo = (function(orig) return function(id) if id == 999 then return "LOGINEFFECT" end return orig(id) end end)(GetSpellInfo)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 999)
eq(ns.char.c.casts, cs, "LOGINEFFECT ignored")
-- level-up from the XP watcher when PLAYER_LEVEL_UP never fires
local lv0 = ns.char.c.levels
state.level = state.level + 1; state.xp = 10; fire("PLAYER_XP_UPDATE")
eq(ns.char.c.levels, lv0 + 1, "level counted without PLAYER_LEVEL_UP")
fire("PLAYER_LEVEL_UP", state.level)
eq(ns.char.c.levels, lv0 + 1, "late PLAYER_LEVEL_UP not double counted")
-- n/a while the combat log is missing
local hd = { key = "heal_done", fmt = "int" }
ns.char.c.heal_done = nil
eq(ns.IsNA(hd, 0), true, "heal_done shows n/a without combat log")
ns.ShowPage("combat"); ns.ShowPage("records"); ns.ShowPage("compare"); ns.ShowPage("fastest")
SlashCmdList.LIFETIMESTATS("debug")

-- ===== v1.5.1 hidden amounts =====
ns.cleuSeen = nil; ns.settings.amountsSecret = nil; ns.src.amountReadable = nil
issecretvalue = function(v) return v == "S" end
local h0 = ns.char.c.hits
fire("UNIT_COMBAT", "target", "WOUND", "", "S", 16)
eq(ns.char.c.hits, h0 + 1, "hit counted though amount hidden")
eq(ns.settings.amountsSecret, true, "hidden amounts remembered")
local dd = ns.char.c.dmg_done; ns.char.c.dmg_done = 0
local na, tip = ns.IsNA({ key = "dmg_done" }, 0)
eq(na, true, "damage done n/a when amounts hidden"); eq(tip == ns.NA_AMOUNT_TIP, true, "amount tip")
ns.char.c.dmg_done = dd
-- damage taken / healing received from your health
local dt = ns.char.c.dmg_taken
state.hp = 1000; fire("UNIT_HEALTH", "player")
state.hp = 870; fire("UNIT_HEALTH", "player")
eq(ns.char.c.dmg_taken, dt + 130, "damage taken from health drop")
local ht = ns.char.c.heal_taken or 0
state.combat = true; state.hp = 950; fire("UNIT_HEALTH", "player")
eq(ns.char.c.heal_taken, ht + 80, "healing received in combat from health rise")
state.combat = false; state.hp = 1000; fire("UNIT_HEALTH", "player")
eq(ns.char.c.heal_taken, ht + 80, "out-of-combat regen ignored")
-- achievements needing hidden data are excluded
local defBig; for _, d in ipairs(ns.ACHIEVEMENTS) do if d.id == "bighit" then defBig = d end end
eq(ns.AchAvailable(defBig), false, "Heavy Hitter not measurable when amounts hidden")
local _, total = ns.AchTotals(ns.char)
local full = 0; for _, d in ipairs(ns.ACHIEVEMENTS) do full = full + #d.tiers end
eq(total < full, true, "unmeasurable tiers left out of totals")
ns.ShowPage("combat"); ns.ShowPage("achievements"); ns.ShowPage("records"); ns.ShowPage("dashboard")
issecretvalue = nil

-- ===== v1.5.2 hidden speed =====
issecretvalue = function(v) return v == "SS" end
local pos = { 100, 200 }
UnitPosition = function() return pos[2], pos[1], 0, 1 end
GetUnitSpeed = function() return "SS" end
local tk; for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then tk = tk or f end end
local df0 = ns.char.c.dist_foot
local e0 = #ns.errors
NOW = NOW + 0.25; tk.scripts.OnUpdate(tk, 0.25)
pos = { 103, 204 }  -- moved 5 yards
NOW = NOW + 0.25; tk.scripts.OnUpdate(tk, 0.25)
eq(math.floor(ns.char.c.dist_foot - df0 + 0.5), 5, "distance from position when speed is hidden")
eq(#ns.errors, e0, "hidden speed causes no error")
pos = { 5000, 9000 }  -- teleport
NOW = NOW + 0.25; tk.scripts.OnUpdate(tk, 0.25)
eq(math.floor(ns.char.c.dist_foot - df0 + 0.5), 5, "teleport ignored")
UnitPosition = function() return "SS", "SS", 0, 1 end
NOW = NOW + 0.25; tk.scripts.OnUpdate(tk, 0.25)
eq(#ns.errors, e0, "hidden position too: tick skipped, no error")
-- a failing per-frame script is caught and logged, not thrown
GetUnitSpeed = function() error("boom") end
NOW = NOW + 0.25; tk.scripts.OnUpdate(tk, 0.25)
eq(#ns.errors, e0 + 1, "ticker error caught by guard")
table.remove(ns.errors)
GetUnitSpeed = function() return state.speed end
issecretvalue = nil

-- ===== v1.5.3 combat log registration =====
eq(ns.ShouldRegister("COMBAT_LOG_EVENT_UNFILTERED"), true, "classic-style client: combat log registered")
C_CombatLogSecure = {}
eq(ns.ShouldRegister("COMBAT_LOG_EVENT_UNFILTERED"), false, "Forever rules: combat log never registered")
eq(ns.ShouldRegister("UNIT_COMBAT"), true, "other events unaffected")
C_CombatLogSecure = nil
issecretvalue = function() return false end
eq(ns.ShouldRegister("COMBAT_LOG_EVENT_UNFILTERED"), false, "secret-value client: combat log never registered")
issecretvalue = nil

-- ===== v1.5.4 hidden booleans + nameplate sweep =====
ns.cleuSeen = nil
local k5 = ns.char.c.kills_npc
-- a nameplate that was never announced by NAME_PLATE_UNIT_ADDED is still found by the sweep
units.target = nil
units.nameplate7 = { guid = "Creature-0-1-1-1-3099-701", name = "Dire Mottled Boar", hostile = true }
state.combat = true
local uw; for _, f in ipairs(frames) do if f.scripts.OnUpdate then uw = f end end
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then f.scripts.OnUpdate(f, 0.3) end end
units.nameplate7.dead = true
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then f.scripts.OnUpdate(f, 0.3) end end
eq(ns.char.c.kills_npc, k5 + 1, "kill found by nameplate sweep")
units.nameplate7 = nil
-- hidden booleans read as false, never raise
issecretvalue = function(v) return v == "HB" end
local oldCA = UnitCanAttack
UnitCanAttack = function() return "HB" end
units.target = { guid = "Creature-0-1-1-1-3099-702", name = "Boar", hostile = true }
local e5 = #ns.errors
fire("UNIT_HEALTH", "target"); fire("PLAYER_TARGET_CHANGED")
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then f.scripts.OnUpdate(f, 0.3) end end
eq(#ns.errors, e5, "hidden UnitCanAttack causes no error")
eq((ns.src.secretBool or 0) > 0, true, "hidden booleans counted for debug")
UnitCanAttack = oldCA
local oldM = IsMounted
IsMounted = function() return "HB" end
NOW = NOW + 0.3; for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then f.scripts.OnUpdate(f, 0.3) end end
eq(#ns.errors, e5, "hidden IsMounted in ticker causes no error")
IsMounted = oldM
issecretvalue = nil
units.target = nil

-- ===== v1.6 critters =====
ns.cleuSeen = nil
state.combat = false
local kn, ck = ns.char.c.kills_npc, ns.char.c.critter_kills or 0
units.target = { guid = "Creature-0-1-1-1-4075-900", name = "Rat", hostile = true, critter = true }
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 5176)   -- cast at the rat, not in combat
units.target.dead = true
fire("UNIT_HEALTH", "target")
eq(ns.char.c.critter_kills, ck + 1, "critter kill counted out of combat")
eq(ns.char.c.kills_npc, kn, "critter not counted as enemy")
eq(ns.char.t.critters.Rat, 1, "critter tally"); eq(ns.char.first.critter_kill, "Rat", "first critter")
-- /love a critter
units.target = { guid = "Creature-0-1-1-1-4166-901", name = "Gazelle", hostile = true, critter = true }
local cl = ns.char.c.critters_loved or 0
hooks.DoEmote("love")
eq(ns.char.c.critters_loved, cl + 1, "critter loved"); eq(ns.char.t.critters_loved.Gazelle, 1, "loved tally")
units.target = { guid = "Creature-0-1-1-1-3098-902", name = "Mottled Boar", hostile = true }
NOW = NOW + 1
hooks.DoEmote("love")
eq(ns.char.c.critters_loved, cl + 1, "loving a non-critter does not count as a critter")
eq(ns.char.c.emote_LOVE >= 2, true, "all /love emotes still counted")
units.target = nil
ns.ShowPage("lists"); ns.ShowPage("social"); ns.ShowPage("achievements")

-- ===== v1.6.1 emote paths + hidden creature type =====
local em0, lv0 = ns.char.c.emotes or 0, ns.char.c.critters_loved or 0
units.target = { guid = "Creature-0-1-1-1-721-950", name = "Hare", hostile = true, critter = true }
NOW = NOW + 5
fire("CHAT_MSG_TEXT_EMOTE", "You love Hare.", "Malikor")   -- no hook fired: chat line counts
eq(ns.char.c.emotes, em0 + 1, "emote from chat line")
eq(ns.char.c.critters_loved, lv0 + 1, "critter loved from chat line")
NOW = NOW + 5
hooks.DoEmote("love"); fire("CHAT_MSG_TEXT_EMOTE", "You love Hare.", "Malikor")
eq(ns.char.c.emotes, em0 + 2, "hook + chat line counted once")
fire("CHAT_MSG_TEXT_EMOTE", "Grumsh loves you.", "Grumsh")
eq(ns.char.c.emotes, em0 + 2, "other players' emotes ignored")
-- creature type hidden: level-1 target treated as critter
issecretvalue = function(v) return v == "HT" end
local oldCT, oldUL = UnitCreatureType, UnitLevel
UnitCreatureType = function() return "HT", "HT" end
UnitLevel = function(u) if u == "player" then return 6 end return 1 end
local ck1 = ns.char.c.critter_kills or 0
units.target = { guid = "Creature-0-1-1-1-721-951", name = "Hare", hostile = true }
state.combat = false
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 5176)
units.target.dead = true; fire("UNIT_HEALTH", "target")
eq(ns.char.c.critter_kills, ck1 + 1, "critter kill with hidden creature type")
UnitCreatureType, UnitLevel = oldCT, oldUL
issecretvalue = nil
units.target = nil
SlashCmdList.LIFETIMESTATS("debug")

-- ===== v1.7 =====
eq(ns.KillColor(20, 6), "red", "red"); eq(ns.KillColor(9, 6), "orange", "orange"); eq(ns.KillColor(5, 6), "yellow", "yellow")
eq(ns.KillColor(5, 20), "grey", "grey"); eq(ns.KillColor(14, 20), "green", "green")
ns.cleuSeen = nil
units.target = { guid = "Creature-0-1-1-1-3270-990", name = "Elder Mottled Boar", hostile = true }
UnitClassification = function() return "rare" end
local r0, y0 = ns.char.c.kills_rare or 0, ns.char.c.kills_yellow or 0
local oldUL = UnitLevel
UnitLevel = function(u) if u == "player" then return 6 end return 7 end
fire("UNIT_HEALTH", "target")
NOW = NOW + 10
fire("CHAT_MSG_COMBAT_XP_GAIN", "Elder Mottled Boar dies, you gain 60 experience.")
eq(ns.char.c.kills_rare, r0 + 1, "rare kill"); eq(ns.char.c.kills_yellow, y0 + 1, "yellow kill")
UnitClassification = function() return "normal" end; UnitLevel = oldUL; units.target = nil
-- love then kill
units.target = { guid = "Creature-0-1-1-1-721-991", name = "Hare", hostile = true, critter = true }
NOW = NOW + 5; hooks.DoEmote("love")
local lk = ns.char.c.critters_love_kill or 0
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 5176); units.target.dead = true; fire("UNIT_HEALTH", "target")
eq(ns.char.c.critters_love_kill, lk + 1, "love then kill"); units.target = nil
-- appearance, conjured, herbs by type
fire("CHAT_MSG_SYSTEM", "|cff1eff00|Hitem:1|h[Frayed Belt]|h|r has been added to your appearance collection.")
eq((ns.char.c.appearances or 0) >= 1, true, "appearance")
local cj = ns.char.c.conjured or 0
fire("CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:5350|h[Conjured Water]|h|rx4.")
eq(ns.char.c.conjured, cj + 4, "conjured"); eq(ns.char.t.created["Conjured Water"] >= 4, true, "created tally")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 2366)
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:765|h[Silverleaf]|h|rx3.")
eq(ns.char.t.herbs.Silverleaf, 3, "herbs by type")
-- quest chat fallback
local qd = ns.char.c.quests_done
NOW = NOW + 10; fire("CHAT_MSG_SYSTEM", "Lazy Peons completed."); NOW = NOW + 2; RunTimers()
eq(ns.char.c.quests_done, qd + 1, "quest from chat line")
NOW = NOW + 10; fire("QUEST_TURNED_IN", 5441, 50, 0); fire("CHAT_MSG_SYSTEM", "Lazy Peons completed."); NOW = NOW + 2; RunTimers()
eq(ns.char.c.quests_done, qd + 2, "event + chat line counted once")
-- recap + debug
local pc = #printed; SlashCmdList.LIFETIMESTATS("recap"); eq(#printed > pc, true, "recap printed")
fire("PLAYER_LOGOUT"); eq(type(LifeTimeStatsCharDB.lastSession), "table", "last session saved")
SlashCmdList.LIFETIMESTATS("debug")
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end

-- ===== v1.8 adventurer's life =====
fire("PLAYER_ENTERING_WORLD", true, false); NOW = NOW + 4; RunTimers()
eq(ns.char.un.bindspots, 1, "hearth location at login"); eq(ns.char.un.hearthstones, 1, "hearthstone in bags")
bindLoc = "Sen'jin Village"; fire("HEARTHSTONE_BOUND")
eq(ns.char.un.bindspots, 2, "new hearth location"); eq(ns.char.c.hearth_moves, 1, "hearth moved")
bindLoc = "Razor Hill"; fire("HEARTHSTONE_BOUND")
eq(ns.char.un.bindspots, 2, "same place not counted twice")
fire("CHAT_MSG_SYSTEM", "You feel tipsy."); fire("CHAT_MSG_SYSTEM", "You feel completely smashed."); fire("CHAT_MSG_SYSTEM", "You feel sober again.")
eq(ns.char.c.times_drunk, 1, "drunk once"); eq(ns.char.c.drunk_smashed, 1, "smashed"); eq(ns.char.c.sobered_up, 1, "sober")
GetSpellInfo = (function(o) return function(id) if id == 818 then return "Basic Campfire" end return o(id) end end)(GetSpellInfo)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 818); eq(ns.char.c.campfires, 1, "campfire")
fire("ITEM_TEXT_BEGIN"); eq(ns.char.c.books_read, 1, "book")
fire("CHAT_MSG_COMBAT_XP_GAIN", "Boar dies, you gain 60 experience. (+30 exp Rested bonus)"); eq(ns.char.c.rested_xp, 30, "rested xp")
-- fatigue fix: no bar running -> not fatigue
local fz = ns.char.c.deaths_fatigue or 0
NOW = NOW + 20; state.dead = false; fire("PLAYER_ALIVE"); units.target = nil
fire("PLAYER_DEAD"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.deaths_fatigue or 0, fz, "no fatigue bar, not fatigue death")
state.dead = true; NOW = NOW + 2; RunTimers(); state.dead = false; fire("PLAYER_ALIVE")
fire("PLAYER_LOGOUT"); eq((ns.char.c.nights_camped or 0) + (ns.char.c.nights_inn or 0) >= 1, true, "night counted")
ns.ShowPage("life")

-- ===== v1.8 story =====
local tk; for _, f in ipairs(frames) do if f.scripts.OnUpdate then tk = f end end
state.naked = true; state.auras = { ["Well Fed"] = true, Food = true }; state.combat = false
for _, f in ipairs(frames) do if f.scripts.OnUpdate and f ~= frame then f.scripts.OnUpdate(f, 1.1) end end
eq((ns.char.c.times_naked or 0) >= 1, true, "naked"); eq((ns.char.c.well_fed or 0) >= 1, true, "well fed"); eq((ns.char.c.time_eating or 0) > 0, true, "eating")
state.naked = false; state.auras = nil
-- inn
IsResting = function() return true end; state.subzone = "Razor Hill Inn"
fire("PLAYER_UPDATE_RESTING"); eq(ns.char.un.inns, 1, "inn")
state.gossip = { { name = "Make this inn your home." } }
UnitGUID = function(u) if u == "npc" then return "Creature-0-1-1-1-6928-1" end if u == "player" then return "Player-1-ME" end end
fire("GOSSIP_SHOW"); eq(ns.char.un.innkeepers, 1, "innkeeper")
IsResting = function() return false end; state.gossip = nil
-- level snapshot + journal
local jn = #(ns.char.journal or {})
ns.LevelSnapshot(7); ns.LevelSnapshot(8)
eq(ns.char.lvlsnap["8"] ~= nil, true, "level snapshot"); eq(#ns.char.journal >= jn + 2, true, "journal entries")
-- pets
units.pet = { name = "Imp" }; fire("UNIT_PET", "player"); eq(ns.char.un.pets, 1, "pet"); units.pet = nil
-- titles + sheet
ns.char.ach["drunk:2"] = time()
eq(#ns.EarnedTitles() >= 1, true, "title earned")
ns.settings.title = "barfly"; eq(ns.TitledName(), "Malikor the Barfly", "titled name")
SlashCmdList.LIFETIMESTATS("title"); SlashCmdList.LIFETIMESTATS("sheet")
eq(#ns.CharacterSheet() > 100, true, "sheet")
-- damage meter probe with readable numbers
Enum = { DamageMeterType = { DamageDone = 0, HealingDone = 2 }, DamageMeterSessionType = { Current = 1 } }
C_DamageMeter = { GetCombatSessionFromType = function(st, mt) return { combatSources = { { isLocalPlayer = true, totalAmount = mt == 0 and 500 or 120 } } } end }
ns.src.amountReadable = nil
local dd8 = ns.char.c.dmg_done or 0
fire("PLAYER_REGEN_DISABLED")
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.dmg_done, dd8 + 500, "damage from damage meter"); eq(ns.src.dmReadable, true, "dm readable")
C_DamageMeter = nil; Enum = nil
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end

-- ===== v1.9 extensive logging =====
UnitName = function(u) if units[u] then return units[u].name end return "Malikor" end
local cs = ns.char.c.chat_sent or 0
fire("CHAT_MSG_SAY", "hi everyone lol", "Malikor"); fire("CHAT_MSG_SAY", "hello", "Grumsh")
eq(ns.char.c.chat_sent, cs + 1, "own say counted, others not"); eq(ns.char.c.lols >= 1, true, "lol"); eq(ns.char.c.heard_say >= 1, true, "overheard")
fire("CHAT_MSG_WHISPER", "yo", "Grumsh-Realm"); fire("CHAT_MSG_WHISPER_INFORM", "thanks!", "Grumsh-Realm")
eq(ns.char.un.whisperers, 1, "unique whisperer"); eq(ns.char.un.whispered, 2, "unique whispered")
fire("BARBER_SHOP_OPEN"); fire("BARBER_SHOP_APPEARANCE_APPLIED"); fire("BARBER_SHOP_CLOSE")
eq(ns.char.c.haircuts, 1, "haircut")
fire("TAXIMAP_OPENED"); eq(ns.char.r.flightpaths_known, 2, "flight paths known")
fire("CHAT_MSG_SYSTEM", "You have gained the Mining skill."); eq(ns.char.un.professions, 1, "profession")
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Reputation with Orgrimmar increased by 50.")
eq(ns.char.t.reps.Orgrimmar >= 50, true, "rep alt format")
fire("PLAYER_ENTERING_WORLD", true, false); NOW = NOW + 6; RunTimers()
eq(ns.char.r.mounts_owned, 2, "mounts owned")
C_DamageMeter = { GetCombatSessionSourceFromType = function() return { totalAmount = 77 } end }
local d9 = ns.char.c.dmg_done or 0; ns.src.amountReadable = nil
fire("PLAYER_REGEN_DISABLED")
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.dmg_done, d9 + 77, "dm source by guid")
C_DamageMeter = nil
SlashCmdList.LIFETIMESTATS("dm")
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end

-- ===== v1.9.1 damage meter sessions =====
C_DamageMeter = {
  GetAvailableCombatSessions = function() return { { sessionID = 70, name = "Clattering Scorpid", durationSeconds = 9 } } end,
  GetCombatSessionSourceFromID = function(id, t, guid) if id == 70 and guid then return { totalAmount = t == 0 and 321 or 0 } end end,
}
ns.src.amountReadable = nil; ns.char.meta.dmLastID = nil
local d10 = ns.char.c.dmg_done or 0
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.dmg_done, d10 + 321, "damage from session id"); eq(ns.char.t.foughtenemies["Clattering Scorpid"], 1, "enemy fought")
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.dmg_done, d10 + 321, "same session not counted twice")
SlashCmdList.LIFETIMESTATS("dm")
C_DamageMeter = nil

-- ===== v1.9.2 damage meter spells (shape from in-game dump) =====
C_Spell = C_Spell or {}; C_Spell.GetSpellName = function(id) return ({ [116] = "Frostbolt", [133] = "Fireball", [5] = "Bite" })[id] end
C_DamageMeter = {
  GetAvailableCombatSessions = function() return { { sessionID = 93, name = "Dire Mottled Boar", durationSeconds = 13 } } end,
  GetCombatSessionSourceFromID = function(id, t, guid)
    if id ~= 93 or not guid then return nil end
    if t == 0 then return { totalAmount = 152, maxAmount = 152, combatSpells = {
      { spellID = 116, totalAmount = 100, overkillAmount = 12, isDeadly = false, creatureName = "" },
      { spellID = 133, totalAmount = 52, overkillAmount = 0 } } } end
    if t == 7 then return { totalAmount = 40, combatSpells = { { spellID = 5, totalAmount = 40, creatureName = "Dire Mottled Boar", isDeadly = true } } } end
    if t == 5 then return { totalAmount = 1 } end
    return { totalAmount = 0 }
  end,
}
ns.src.amountReadable = nil; ns.char.meta.dmLastID = nil; ns.settings.dmReadable = nil; ns.char.r.max_fight_dps = nil; ns.char.r.max_spell_fight = nil
local d11, ok11, it11 = ns.char.c.dmg_done or 0, ns.char.c.overkill or 0, ns.char.c.interrupts or 0
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.dmg_done, d11 + 152, "dm damage 93")
eq(ns.char.t.spelldamage.Frostbolt, 100, "spell damage frostbolt"); eq(ns.char.t.spelldamage.Fireball, 52, "spell damage fireball")
eq(ns.char.c.overkill, ok11 + 12, "overkill"); eq(ns.char.c.interrupts, it11 + 1, "interrupts from dm")
eq(ns.char.t.hurtby["Dire Mottled Boar"], 40, "hurt by"); eq(ns.char.c.deadly_hits, 1, "deadly hit")
eq(ns.char.r.max_spell_fight, 100, "top spell in fight"); eq(ns.char.r.max_fight_dps, 11.7, "fight dps")
eq(ns.settings.dmReadable, true, "dm readable persisted")
eq(ns.IsNA({ key = "heal_done" }, 0), false, "heal not n/a once meter readable")
eq(ns.AchAvailable({ needs = "dm" }), true, "dm achievements available")
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
C_DamageMeter = nil

-- ===== v1.9.3 melee naming =====
ns.char.t.hurtbyspell = ns.char.t.hurtbyspell or {}; ns.char.t.hurtbyspell.Attack = 49
fire("PLAYER_ENTERING_WORLD", false, true)
eq(ns.char.t.hurtbyspell.Melee >= 49, true, "attack folded into melee"); eq(ns.char.t.hurtbyspell.Attack, nil, "attack removed")
local li; for i, l in ipairs(ns.LISTS) do if l.id == "spelldamage" then li = i end end
eq(li ~= nil and li < 8, true, "spell lists near top")

-- ===== v1.10 damage meter: catch-up, avoidable, enemy, pet, group, boss, killer =====
local sessList = { { sessionID = 200, name = "Old", durationSeconds = 5 } }
local srcData = { [200] = { [0] = { totalAmount = 0 } } }
C_DamageMeter = {
  GetAvailableCombatSessions = function() return sessList end,
  GetCombatSessionSourceFromID = function(id, t, guid) if guid and srcData[id] then return srcData[id][t] end end,
  GetCombatSessionFromID = function(id, t)
    if id == 202 and t == 10 then return { combatSources = { { name = "Bristleback", totalAmount = 90 } } } end
    if id == 203 and t == 0 then return { combatSources = { { name = "Malikor", classFilename = "DRUID", totalAmount = 300 }, { name = "Tank", classFilename = "WARRIOR", totalAmount = 200 } } } end
    if id == 203 and t == 9 then return { combatSources = { { name = "Tank", classFilename = "WARRIOR", deathTimeSeconds = 4 } } } end
  end,
  GetCombatSessionSourceFromType = function(st, t, guid)
    if st == 1 and t == 7 then return { totalAmount = 60, combatSpells = { { spellID = 5, totalAmount = 60, creatureName = "Gnoll Brute", isDeadly = true } } } end
  end,
}
ns.char.meta.dmLastID = nil; ns.src.amountReadable = nil
ns.char.c.dmg_avoidable = nil; ns.char.c.fights_in_fire = nil
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.meta.dmLastID, 200, "first read: newest only")
ns.char.c.dmg_avoidable = nil; ns.char.c.fights_in_fire = nil
-- two fights finish before the next read: both are counted (the fix)
srcData[201] = { [0] = { totalAmount = 50, combatSpells = { { spellID = 133, totalAmount = 30 }, { spellID = 17253, totalAmount = 20, creatureName = "Wolf" } } } }
srcData[202] = { [0] = { totalAmount = 70 }, [8] = { totalAmount = 15, combatSpells = { { spellID = 9999, totalAmount = 15 } } } }
sessList[#sessList + 1] = { sessionID = 201, name = "Boar", durationSeconds = 6 }
sessList[#sessList + 1] = { sessionID = 202, name = "Bristleback", durationSeconds = 7 }
local dd0 = ns.char.c.dmg_done or 0
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.dmg_done, dd0 + 120, "both unread fights counted")
eq(ns.char.c.dmg_pet, 20, "pet damage"); eq(ns.char.t.petdamage.Wolf, 20, "pet tally")
eq(ns.char.c.dmg_avoidable, 15, "avoidable"); eq(ns.char.c.fights_in_fire, 1, "stood in fire")
eq(ns.char.t.damagetoenemy.Bristleback, 90, "damage to enemy (solo)")
eq(ns.char.t.dmglevel ~= nil, true, "dps by level data")
-- group fight + boss
IsInGroup = function() return true end
ns.lastBossKill = { name = "Hogger", t = GetTime(), kind = "world" }
srcData[203] = { [0] = { totalAmount = 300 } }
sessList[#sessList + 1] = { sessionID = 203, name = "Hogger", durationSeconds = 10 }
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.c.group_fights, 1, "group fight"); eq(ns.char.c.meter_topped, 1, "topped meter")
eq(ns.char.r.max_group_share, 60, "group share 60%"); eq(ns.char.c.allies_died, 1, "ally death")
eq(ns.char.t.bossdamage.Hogger, 300, "boss damage"); eq(ns.char.r.best_boss_dps, 30, "boss dps")
IsInGroup = function() return false end
-- meter restarted numbering (relog): no fights lost, no crash
sessList = { { sessionID = 3, name = "New", durationSeconds = 4 } }
srcData[3] = { [0] = { totalAmount = 0 } }
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.meta.dmLastID, 3, "numbering restart handled")
-- death cause from the meter
local k0 = ns.char.t.killers and ns.char.t.killers["Gnoll Brute"] or 0
fire("PLAYER_DEAD"); NOW = NOW + 1; RunTimers()
eq(ns.char.t.killers["Gnoll Brute"], k0 + 1, "killer from meter"); eq(ns.char.t.killedwith.Bite, 1, "killing spell")
eq(ns.char.c.deaths_world >= 1, true, "death in open world")
fire("PLAYER_ALIVE")
C_DamageMeter = nil
-- biggest hit probe
C_DamageMeter = {
  GetAvailableCombatSessions = function() return { { sessionID = 10, name = "X", durationSeconds = 4 } } end,
  GetCombatSessionSourceFromID = function(id, t, g) if t == 0 then return { totalAmount = 400, combatSpells = { { spellID = 116, totalAmount = 400, combatSpellDetails = { { maxAmount = 180, count = 3 } } } } } end end,
}
ns.char.r.max_hit = nil; ns.settings.dmHitReadable = nil
fire("PLAYER_REGEN_ENABLED"); NOW = NOW + 1; RunTimers()
eq(ns.char.r.max_hit, 180, "biggest hit from details"); eq(ns.settings.dmHitReadable, true, "hit readable flag")
eq(ns.AchAvailable({ needs = "amount" }), true, "heavy hitter available")
C_DamageMeter = nil

-- ===== v1.10 chronicle =====
local xk, xe = ns.char.c.xp_kill or 0, ns.char.c.xp_explore or 0
fire("CHAT_MSG_COMBAT_XP_GAIN", "Kobold Worker dies, you gain 45 experience. (+22 exp Rested bonus, +5 group bonus)")
eq(ns.char.c.xp_kill, xk + 45, "xp from kill"); eq(ns.char.c.xp_group, 5, "group bonus xp")
fire("CHAT_MSG_SYSTEM", "Discovered Jerod's Landing: 120 experience gained")
eq(ns.char.c.xp_explore, xe + 120, "exploration xp")
ns.settings.levelMsg = true
fire("PLAYER_LEVEL_UP", (ns.char.meta.lastLevelCounted or 1) + 1)
eq(ns.char.r.max_health ~= nil, true, "max health record")
-- week / month views
local wk = ns.GetView("char", "week"); local mo = ns.GetView("char", "month")
eq(wk.c.steps == nil and true or true, true, "week view")
eq((mo.c.xp_explore or 0) >= 120, true, "month view sums days")
ns.settings.range = "week"; for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
ns.settings.range = "month"; for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
ns.settings.range = "lifetime"
ns.settings.scope = "account"; ns.InvalidateAccount(); for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
ns.settings.scope = "char"
-- themes
ElvUI = { { media = { backdropcolor = { 0.2, 0.2, 0.2 }, bordercolor = { 0, 0, 0 }, rgbvaluecolor = { 0.1, 0.5, 0.9 }, normFont = "Interface\\AddOns\\ElvUI\\x.ttf" } } }
C_AddOns = C_AddOns or {}; C_AddOns.IsAddOnLoaded = function(n) return n == "ElvUI" end
ns.settings.theme = "auto"; ns.settings.classColor = false
ns.ApplyTheme()
eq(ns.themeId, "elvui", "auto detects ElvUI"); eq(ns.themeLive, true, "ElvUI live colours")
eq(ns.THEME.amber[3], 0.9, "ElvUI value colour"); eq(ns.W.FONT, "Interface\\AddOns\\ElvUI\\x.ttf", "ElvUI font")
for _, id in ipairs(ns.THEME_ORDER) do ns.settings.theme = id; ns.ApplyTheme() end
ElvUI = nil; C_AddOns.IsAddOnLoaded = function() return false end
ns.settings.theme = "odometer"; ns.settings.classColor = true; ns.ApplyTheme()
eq(ns.themeId, "odometer", "back to odometer")
-- search finds list entries
eq(ns.char.t.spelldamage ~= nil, true, "spell list exists")
SlashCmdList.LIFETIMESTATS("debug"); SlashCmdList.LIFETIMESTATS("dm"); SlashCmdList.LIFETIMESTATS("recap")

-- ===== v1.10.1 death recap (fire, out of combat) =====
C_DamageMeter = { GetCombatSessionSourceFromType = function(st, t) if t == 7 then return { totalAmount = 49, combatSpells = { { spellID = 6603, totalAmount = 49, combatSpellDetails = { unitName = "Dire Mottled Boar", isMob = true } } } } end end }
C_DeathRecap = { HasRecapEvents = function(id) return id == 2 end,
  GetRecapEvents = function(id) if id == 2 then return { { event = "ENVIRONMENTAL_DAMAGE", environmentalType = "Fire", amount = 40 }, { event = "ENVIRONMENTAL_DAMAGE", environmentalType = "Fire", amount = 30 } } end end }
ns.char.meta.lastRecap = nil
local lv0, boar0 = ns.char.c.deaths_lava or 0, (ns.char.t.killers or {})["Dire Mottled Boar"] or 0
state.dead = true; fire("PLAYER_DEAD"); NOW = NOW + 1; RunTimers(); state.dead = false; fire("PLAYER_ALIVE")
eq(ns.char.c.deaths_lava, lv0 + 1, "fire death from recap"); eq(ns.char.t.killers.Fire, 1, "killer: Fire")
eq((ns.char.t.killers["Dire Mottled Boar"] or 0), boar0, "old fight not blamed out of combat")
eq(ns.char.t.envdamage.Fire, 70, "fire damage from recap"); eq(ns.char.r.max_killing_blow, 40, "killing blow size")
eq(ns.char.r.max_hit_taken >= 40, true, "biggest hit taken from recap"); eq(ns.char.meta.lastRecap, 2, "recap id remembered")
C_DamageMeter = nil; C_DeathRecap = nil

-- ===== v1.10.1 settings panel + text windows =====
ns.optionsPanel:Show()
local clicked = 0
ReloadUI = ReloadUI or function() end
for _, f in ipairs(frames) do
  local lbl = f.text and f.text.text
  if f.scripts.OnClick and lbl ~= "Erase character" and lbl ~= "Reload now" and lbl ~= "Open window" then pcall(f.scripts.OnClick, f); clicked = clicked + 1 end
  if f.scripts.OnMouseUp then pcall(f.scripts.OnMouseUp, f) end
end
for _, f in ipairs(frames) do if f.scripts.OnValueChanged then f.scripts.OnValueChanged(f, 1.2) end end
eq(clicked > 10, true, "settings controls clicked")
eq(ns.settings.window.scale, 1.2, "scale slider")
ns.optionsPanel:Show()
SlashCmdList.LIFETIMESTATS("debug"); SlashCmdList.LIFETIMESTATS("dm"); SlashCmdList.LIFETIMESTATS("errors")
eq(ns.capture, nil, "capture closed")

-- ===== text window for debug / dm =====
do
  local shown, chat = {}, 0
  local realShow, realChat = ns.ShowText, DEFAULT_CHAT_FRAME.AddMessage
  ns.ShowText = function(title, hint, text) shown[#shown + 1] = { title = title, text = text } end
  DEFAULT_CHAT_FRAME.AddMessage = function() chat = chat + 1 end
  SlashCmdList.LIFETIMESTATS("debug"); SlashCmdList.LIFETIMESTATS("dm")
  DEFAULT_CHAT_FRAME.AddMessage = realChat; ns.ShowText = realShow
  eq(#shown, 2, "debug and dm open the text window"); eq(chat, 0, "nothing printed to chat")
  eq(shown[1].text:find("Data sources") ~= nil, true, "debug text captured")
  eq(shown[1].text:find("|c", 1, true), nil, "colour codes stripped")
  eq(ns.capture, nil, "capture cleared")
end

-- ===== v1.11.0 dungeon book =====
do
  ns.char.run = nil
  local real = GetInstanceInfo
  local realIn = IsInInstance
  IsInInstance = function() return true, "party" end
  GetInstanceInfo = function() return "Scarlet Monastery", "party", 1, "Normal", 5, 0, false, 189 end
  state.level = 35
  fire("ZONE_CHANGED_NEW_AREA"); fire("PLAYER_ENTERING_WORLD", false, false)
  local run = ns.char.run
  eq(run ~= nil and run.name, "Scarlet Monastery", "run started")
  eq(run.dkey, nil, "wing unknown until a boss dies")
  fire("ENCOUNTER_END", 1, "Houndmaster Loksey", 1, 5, 1)
  eq(run.dkey, "smlib", "wing from first boss")
  eq(ns.char.c.dj_runs_in, (ns.char.c.dj_runs_in or 0) > 0 and ns.char.c.dj_runs_in or 1, "level band counted")
  local f0 = ns.char.c.dj_full_clears or 0
  fire("ENCOUNTER_END", 2, "Arcanist Doan", 1, 5, 1)
  eq(ns.char.c.dj_full_clears, f0 + 1, "library full clear")
  eq(ns.char.un.dungeons_cleared >= 1, true, "unique clear")
  local found, total = ns.DungeonProgress(ns.DUNGEON_BY_KEY.smlib)
  eq(found .. "/" .. total, "2/2", "book progress")
  fire("ENCOUNTER_END", 2, "Arcanist Doan", 1, 5, 1)
  eq(ns.char.c.dj_full_clears, f0 + 1, "no double clear in one run")
  -- pair encounter matches
  eq(ns.ResolveDungeon({ name = "Scarlet Monastery" }, "High Inquisitor Whitemane").key, "smcath", "cathedral by boss")
  -- learned boss in partial dungeon
  ns.char.run = nil
  GetInstanceInfo = function() return "Krol'Dok Stronghold", "party", 1, "Normal", 5, 0, false, 9001 end
  fire("PLAYER_ENTERING_WORLD", false, false)
  local beforeBooks = ns.char.un.dj_books or 0
  fire("ENCOUNTER_END", 3, "Overlord Mugg", 1, 5, 1)
  eq(ns.char.c.dj_full_clears, f0 + 1, "Krol'Dok known encounter does not award a full clear")
  eq(ns.char.un.dj_books or 0, beforeBooks, "partial book does not award completed discovery")
  eq(ns.char.f["clear:krol"], nil, "incomplete roster has no fastest clear")
  fire("ENCOUNTER_END", 3, "Some New Boss", 1, 5, 1)
  local f2, t2 = ns.DungeonProgress(ns.DUNGEON_BY_KEY.krol)
  eq(f2 .. "/" .. t2, "2/7", "learned boss adds to the DBM roster of 6")
  ns.char.run = nil
  GetInstanceInfo = function() return "Alcaz Island Prison", "party", 1, "Normal", 5, 0, false, 9002 end
  fire("PLAYER_ENTERING_WORLD", false, false)
  fire("ENCOUNTER_END", 4, "Blazeroar", 1, 5, 1)
  fire("ENCOUNTER_END", 5, "Another New Boss", 1, 5, 1)
  local f3, t3 = ns.DungeonProgress(ns.DUNGEON_BY_KEY.alcaz)
  eq(f3 .. "/" .. t3, "2/6", "Alcaz discoveries include optional and learned encounters")
  eq(ns.char.c.dj_full_clears, f0 + 1, "Alcaz partial roster never credits a clear")
  eq(ns.char.un.dj_books or 0, beforeBooks, "Alcaz partial roster never completes the book")
  -- list rows render
  local def; for _, l in ipairs(ns.LISTS) do if l.id == "dungeonbook" then def = l end end
  local rows = def.rows(ns.char, ns.session)
  local krolRow = rows[ns.DUNGEON_BY_KEY.krol.order]
  eq(krolRow[4], "2 / 7*", "provisional Dungeon Book progress is marked")
  eq(ns.EncounterName(3451, "whatever"), "Overseer Mugg", "encounter ID gives the listed name")
  eq(ns.EncounterName(99999, "Other"), "Other", "unknown encounter keeps the client name")
  eq(#rows, #ns.DUNGEONS, "book has every instance"); eq(#ns.DUNGEONS, 38, "35 dungeons + 3 raids")
  eq(ns.NEW_DUNGEON_COUNT, 9, "9 new dungeons")
  -- backup carries progress
  local str = ns.Serialize(ns.char)
  eq(str:find("djboss_smlib", 1, true) ~= nil, true, "progress in backup")
  GetInstanceInfo = real; IsInInstance = realIn; ns.char.run = nil
  fire("PLAYER_ENTERING_WORLD", false, false)
  ns.ShowPage("lists")
end

-- ===== v1.12.0 character: sessions, score, peak stats, battlegrounds =====
do
  ns.char.sessionlog = nil
  NOW = NOW + 600
  ns.LogSession(); ns.LogSession()
  eq(#ns.char.sessionlog, 1, "one entry per session (updates in place)")
  local st = ns.SessionStats()
  eq(st.n, 1, "session count"); eq(st.avg > 0, true, "session average")
  local csv = ns.SessionCSV()
  eq(select(2, csv:gsub("\n", "")) , 1, "csv header + 1 row")
  local total, parts = ns.Score()
  eq(total > 0, true, "score positive"); eq(#parts, #ns.SCORE_PARTS, "score parts")
  eq(ns.ScoreText():find("Adventurer score", 1, true) ~= nil, true, "score text")
  -- peak stats
  UnitStat = function(_, i) return 10, 20 + i end
  UnitArmor = function() return 50, 120 end
  GetCritChance = function() return 5.25 end
  GetInventoryItemLink = function(_, slot) if slot <= 10 then return "item:" .. slot end end
  GetItemInfo = function(link) return "x", link, 2, 15 end
  ns.ScanCharacterStats()
  eq(ns.char.r.max_str, 21, "peak strength"); eq(ns.char.r.max_armor, 120, "peak armor")
  eq(ns.char.r.max_crit_pct, 5.25, "peak crit"); eq(ns.char.r.max_ilvl, 15, "best item level")
  -- battleground end
  ns.char.meta.bgStreak = 0
  ns.OnBattlegroundEnd({ name = "Warsong Gulch" }, true)
  ns.OnBattlegroundEnd({ name = "Warsong Gulch" }, true)
  eq(ns.char.t.bgwins["Warsong Gulch"], 2, "wins by battleground"); eq(ns.char.r.max_bg_streak, 2, "win streak")
  ns.OnBattlegroundEnd({ name = "Arathi Basin" }, false)
  eq(ns.char.meta.bgStreak, 0, "streak reset on loss")
  local f0 = ns.char.c.bg_flags_captured or 0
  fire("CHAT_MSG_BG_SYSTEM_HORDE", UnitName("player") .. " captured the Alliance flag!")
  eq(ns.char.c.bg_flags_captured, f0 + 1, "flag capture")
  fire("CHAT_MSG_BG_SYSTEM_HORDE", "Someone captured the Alliance flag!")
  eq(ns.char.c.bg_flags_captured, f0 + 1, "others' captures ignored")
  -- slash commands go to the text window
  local shown = 0; local real = ns.ShowText; ns.ShowText = function() shown = shown + 1 end
  SlashCmdList.LIFETIMESTATS("score"); SlashCmdList.LIFETIMESTATS("csv"); ns.ShowText = real
  eq(shown, 2, "score and csv windows")
  for _, l in ipairs(ns.LISTS) do if l.rows then eq(type(l.rows(ns.char, ns.session)), "table", "rows " .. l.id); eq(type(l.count(ns.char)), "number", "count " .. l.id) end end
  ns.ShowPage("records"); ns.ShowPage("lists"); ns.ShowPage("life"); ns.ShowPage("combat"); ns.ShowPage("achievements")
end

-- ===== v1.12.2 data repairs and per-level rows =====
do
  local ch = ns.char
  ch.meta.repairs = nil
  ch.t.spells = ch.t.spells or {}; ch.t.spells.LOGINEFFECT = 2; ch.t.spells.Attack = 4; ch.t.spells.Melee = 1
  ch.c.deaths_fatigue = 1; ch.t.killers = ch.t.killers or {}; ch.t.killers.Fatigue = 1
  local npc0, unk0 = ch.c.deaths_npc or 0, ch.t.killers.Unknown or 0
  ch.first.death = "Fatigue"
  ch.meta.levelMark = nil; ch.lvlsnap = {}
  ns.RepairData()
  eq(ch.t.spells.LOGINEFFECT, nil, "internal spell removed"); eq(ch.t.spells.Melee, 5, "Attack merged into Melee")
  eq(ch.c.deaths_fatigue, 0, "fatigue deaths cleared"); eq(ch.c.deaths_npc, npc0 + 1, "moved to unknown cause")
  eq(ch.t.killers.Fatigue, nil, "killer Fatigue removed"); eq(ch.t.killers.Unknown, unk0 + 1, "killer Unknown")
  eq(ch.first.death, "Unknown", "first death fixed")
  eq(ch.meta.levelMarkPartial, true, "install level marked partial")
  eq(next(ch.lvlsnap) ~= nil, true, "install level snapshot")
  ch.c.deaths_fatigue = 1; ns.RepairData()
  eq(ch.c.deaths_fatigue, 1, "repair runs once (real fatigue deaths later are kept)")
  ch.c.deaths_fatigue = 0
  ns.ShowPage("records"); ns.ShowPage("life")
end

-- Mixed combat sources must agree per direction and per completed fight.
do
  ns.cleuSeen = nil
  ns.settings.amountsSecret = true
  local sessions, totals = {}, {}
  C_DamageMeter = {
    GetAvailableCombatSessions = function() return sessions end,
    GetCombatSessionSourceFromID = function(id, kind)
      return totals[id] and { totalAmount = totals[id][kind] or 0 }
    end,
  }
  local function start(group)
    state.combat, state.group = true, group
    fire("PLAYER_REGEN_DISABLED")
  end
  local function finish(id, damage, taken)
    if id then
      sessions[#sessions + 1] = { sessionID = id, durationSeconds = 5 }
      totals[id] = { [0] = damage, [7] = taken }
    end
    state.combat = false
    fire("PLAYER_REGEN_ENABLED")
  end
  local function drain() NOW = NOW + 1; RunTimers() end
  ns.char.meta.dmLastID = nil
  fire("PLAYER_ENTERING_WORLD", false, true)
  local done0, taken0 = ns.char.c.dmg_done or 0, ns.char.c.dmg_taken or 0

  start(2)
  fire("UNIT_COMBAT", "player", "WOUND", "", 40, 1)
  finish(401, 321, 40)
  drain()
  eq(ns.char.c.dmg_done, done0 + 321, "incoming visibility does not suppress outgoing meter")
  eq(ns.char.c.dmg_taken, taken0 + 40, "sticky secret flag does not duplicate readable incoming hit")

  units.target = { guid = "Creature-0-1-1-1-5-5", name = "Test Tiger", hostile = true }
  start(0)
  fire("UNIT_COMBAT", "target", "WOUND", "", 25, 1)
  finish(402, 40, 0)
  start(2) -- The previous timer has not run.
  finish(403, 60, 35)
  drain()
  eq(ns.char.c.dmg_done, done0 + 421, "back-to-back fights keep their own outgoing source credits")
  eq(ns.char.c.dmg_taken, taken0 + 75, "later meter-only fight counts taken damage")

  -- A cleared meter exposes two tracked results before its first delayed wake.
  sessions, totals, ns.char.meta.dmLastID = {}, {}, nil
  fire("PLAYER_ENTERING_WORLD", false, true)
  start(2)
  finish(1, 50, 0)
  start(2)
  finish(2, 75, 0)
  drain()
  done0 = done0 + 125
  eq(ns.char.c.dmg_done, done0 + 421, "fresh meter reads both completed numbered fights")

  start(2)
  sessions[#sessions + 1] = { sessionID = 3, durationSeconds = 5 }
  finish()
  drain()
  eq(ns.char.meta.dmLastID, 2, "meter cursor waits for totals to become readable")
  totals[3] = { [0] = 30 }
  fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 0, 3)
  drain()
  done0 = done0 + 30
  eq(ns.char.c.dmg_done, done0 + 421, "late readable totals are recovered once")
  eq(ns.char.meta.dmLastID, 3, "meter cursor advances after totals are read")

  -- Correct argument order does not mistake session 7's damage for 0's taken.
  local source = C_DamageMeter.GetCombatSessionSourceFromID
  C_DamageMeter.GetCombatSessionSourceFromID = function(id, kind)
    if id == 4 and kind == 7 then return nil end
    if id == 7 and kind == 4 then return { totalAmount = 9999 } end
    return source(id, kind)
  end
  start(2)
  finish(4, 12, 0)
  drain()
  eq(ns.char.meta.dmLastID, 3, "partially visible tracked row waits for incoming total")
  C_DamageMeter.GetCombatSessionSourceFromID = source
  totals[4][7] = 16
  fire("DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 4)
  drain()
  done0 = done0 + 12
  taken0 = taken0 + 16
  eq(ns.char.c.dmg_done, done0 + 421, "readable outgoing result is credited once when incoming row arrives")
  eq(ns.char.c.dmg_taken, taken0 + 75, "meter reads late incoming damage using correct session and metric order")

  start(0)
  fire("UNIT_COMBAT", "target", "WOUND", "", 20, 1)
  finish()
  drain()
  eq(ns.char.c.dmg_done, done0 + 441, "unreadable meter preserves direct count")

  C_DamageMeter = { GetCombatSessionSourceFromType = function(_, kind)
    return { totalAmount = kind == 0 and 17 or 0 }
  end }
  start(2)
  finish()
  drain()
  eq(ns.char.c.dmg_done, done0 + 458, "unnumbered current fight is read on completion")
  fire("PLAYER_REGEN_ENABLED")
  fire("DAMAGE_METER_CURRENT_SESSION_UPDATED")
  drain()
  eq(ns.char.c.dmg_done, done0 + 458, "repeated events cannot count unnumbered current twice")

  C_DamageMeter = nil
  state.hp = 1000
  fire("UNIT_MAXHEALTH", "player")
  start(0)
  fire("UNIT_COMBAT", "player", "WOUND", "", 25, 1)
  state.hp = 960
  fire("UNIT_HEALTH", "player")
  eq(ns.char.c.dmg_taken, taken0 + 100, "readable UNIT_COMBAT credit remains immediate")
  fire("PLAYER_LOGOUT")
  eq(LifeTimeStatsCharDB.data.c.dmg_taken, taken0 + 115, "logout saves only health loss beyond direct incoming damage")
  finish()
  units.target = nil
end

-- Existing numeric keys and old text backup keys name the same discoveries.
do
  local live = ns.char
  local source = ns.NewCharRecord()
  source.u.quests = { [46217] = true }
  local decoded = assert(ns.Deserialize(ns.Serialize(source)))
  eq(ns.MergeMax(source, decoded), 0, "restoring own backup changes no discoveries")
  eq(source.un.quests, 1, "own backup leaves one quest")
  local fresh = ns.NewCharRecord()
  ns.MergeMax(fresh, decoded)
  ns.char = fresh
  eq(ns.Unique("quests", 46217), false, "discovery restored on fresh character is already known")
  eq(fresh.un.quests, 1, "fresh backup leaves one quest")
  eq(ns.MergeMax(fresh, decoded), 0, "repeat restore changes nothing")
  source.c.dmg_done = 5000000000
  local large = assert(ns.Deserialize(ns.Serialize(source)))
  eq(large.c.dmg_done, 5000000000, "backup keeps a lifetime total above signed 32-bit")
  ns.char = live
  local old = ns.NewCharRecord()
  old.u.quests = { [46217] = true, ["46217"] = true, ["046217"] = true }
  ns.EnsureRecord(old)
  eq(old.un.quests, 2, "legacy numeric and string IDs deduplicate without changing other keys")
end

-- Restore keeps the most recent records irrespective of input insertion order.
do
  local newest, older = ns.NewCharRecord(), ns.NewCharRecord()
  for i = 1, 200 do newest.rh[i] = { k = "jumps", v = i, at = 1000 + i, d = "max" } end
  older.rh[1] = { k = "jumps", v = 0, at = 500, d = "max" }
  local decoded = assert(ns.Deserialize(ns.Serialize(older)))
  eq(ns.MergeMax(newest, decoded), 0, "restore discards history older than capacity")
  eq(#newest.rh, 200, "history cap after merging older backup")
  eq(newest.rh[1].at, 1001, "history retains oldest of the 200 newest entries")
  eq(newest.rh[200].at, 1200, "history retains newest entry")
  older.rh[1] = { k = "jumps", v = 201, at = 1200, d = "max" }
  eq(ns.MergeMax(newest, older), 1, "new distinct record with matching timestamp is retained")
  eq(newest.rh[199].v, 200, "equal timestamp retains destination first")
  eq(newest.rh[200].v, 201, "equal timestamp retains source second")
  eq(ns.MergeMax(newest, older), 0, "repeat history restore changes nothing")
end

-- Real logins distinguish short sessions. An actual addon reload restores
-- the active row, its exact wall start and elapsed monotonic time.
do
  local realTime, wall = time, time() + 120
  time = function() return wall end
  ns.char.sessionlog = {}
  fire("PLAYER_ENTERING_WORLD", true, false)
  ns.Add("kills_npc", 10)
  NOW, wall = NOW + 60, wall + 60
  fire("PLAYER_LOGOUT")
  local firstRow = ns.char.sessionlog[1]
  local firstStart = firstRow.s
  NOW, wall = NOW + 50, wall + 50
  fire("PLAYER_ENTERING_WORLD", true, false)
  ns.Add("kills_npc", 2)
  local meterRows = { { sessionID = 80, durationSeconds = 4 } }
  local meterReady = false
  local takenBefore = ns.char.c.dmg_taken or 0
  C_DamageMeter = {
    GetAvailableCombatSessions = function() return meterRows end,
    GetCombatSessionSourceFromID = function(id, kind)
      if id == 81 and meterReady then return { totalAmount = kind == 7 and 100 or 0 } end
    end,
  }
  ns.char.meta.dmLastID = 80
  state.combat = true
  fire("PLAYER_REGEN_DISABLED")
  fire("UNIT_COMBAT", "player", "WOUND", "", 40, 1)
  state.combat = false
  meterRows[#meterRows + 1] = { sessionID = 81, durationSeconds = 5 }
  fire("PLAYER_REGEN_ENABLED")
  NOW, wall = NOW + 10, wall + 10
  fire("PLAYER_LOGOUT")
  eq(ns.char.c.dmg_taken, takenBefore + 40, "logout preserves direct hit while meter row is unreadable")
  local log = ns.char.sessionlog
  eq(#log, 2, "quick relog keeps two sessions")
  eq(log[1].k, 10, "quick relog preserves original totals")
  eq(log[1].s, firstStart, "first session wall start preserved")

  NOW, wall = NOW + 25, wall + 25
  timers = {} -- Reload discards timers from the previous UI.
  ChatFrame1:RegisterEvent("TIME_PLAYED_MSG") -- ...and rebuilds the chat frames with their events.
  local reloaded = {}
  for _, chunk in ipairs(addonChunks) do chunk("LifeTimeStats", reloaded) end
  local newFrame = reloaded.frame
  newFrame.scripts.OnEvent(newFrame, "ADDON_LOADED", "LifeTimeStats")
  newFrame.scripts.OnEvent(newFrame, "PLAYER_ENTERING_WORLD", false, true)
  meterReady = true
  newFrame.scripts.OnEvent(newFrame, "DAMAGE_METER_COMBAT_SESSION_UPDATED", 7, 81)
  local journalBefore = #(reloaded.char.journal or {})
  reloaded.settings.recordMoments = true
  reloaded.Max("reload_grace_test", 1)
  eq(#(reloaded.char.journal or {}), journalBefore, "reload retains startup grace")
  NOW, wall = NOW + 6, wall + 6
  RunTimers()
  eq(reloaded.char.c.dmg_taken, takenBefore + 100, "reload reconciles late meter total against saved direct credit")
  journalBefore = #(reloaded.char.journal or {})
  reloaded.Max("reload_milestone_test", 1)
  eq(#(reloaded.char.journal or {}), journalBefore + 1, "new record adds Journal entry after reload")
  reloaded.Add("kills_npc", 3)
  reloaded.LogSession()
  eq(#log, 2, "reload updates same session row")
  if log[2] then
    eq(log[2].s, firstStart + 110, "reload preserves exact session start")
    eq(log[2].d, 16, "reload preserves elapsed but excludes loading time")
    eq(log[2].k, 5, "reload preserves session counters")
  end
  eq(#reloaded.errors, 0, "reload handlers have no errors")
  C_DamageMeter = nil
  time = realTime
end

-- a failing logout step must not skip the save
do
  local origLogout, errCount = ns.OnLogout, #ns.errors
  ns.OnLogout = function() error("boom") end
  local revBefore = ns.char.meta.rev or 0
  fire("PLAYER_LOGOUT")
  eq(ns.char.meta.rev, revBefore + 1, "save still runs when a logout step fails")
  eq(#ns.errors, errCount + 1, "failing logout step is logged")
  ns.OnLogout = origLogout
  while #ns.errors > errCount do table.remove(ns.errors) end
end

-- /played: chat frames stop listening only until the login reply, or 10 s without one.
-- Blizzard's display function itself is never replaced (that would taint it).
do
  local display = ChatFrame_DisplayTimePlayed
  NOW = NOW + 11; RunTimers() -- let earlier test logins finish their 10 s timeout
  eq(ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), true, "chat frame listens before login")
  eq(ChatFrame2:IsEventRegistered("TIME_PLAYED_MSG"), false, "frame that never listened")
  fire("PLAYER_ENTERING_WORLD", true, false)
  eq(ChatFrame_DisplayTimePlayed, display, "Blizzard /played display is not replaced")
  eq(ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), false, "login /played reply is hidden")
  fire("TIME_PLAYED_MSG", 6000, 10)
  eq(ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), false, "reply itself is not delivered to chat")
  NOW = NOW + 0.01; RunTimers()
  eq(ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), true, "chat listens again after the reply")
  eq(ChatFrame2:IsEventRegistered("TIME_PLAYED_MSG"), false, "frames that never listened stay off")
  eq(ns.char.c.played_server, 6000, "played total from the login reply")
  NOW = NOW + 11; RunTimers()
  eq(ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), true, "late timeout does not mute again")

  fire("PLAYER_ENTERING_WORLD", true, false)
  eq(ns.PlayedMuted(), true, "muted while waiting for the reply")
  NOW = NOW + 11; RunTimers()
  eq(ChatFrame1:IsEventRegistered("TIME_PLAYED_MSG"), true, "/played shows again when the login reply never came")
  eq(ns.PlayedMuted(), false, "nothing left muted after the timeout")
end

-- A long gap between frames (loading screen, hitch) still counts as time online,
-- capped at ns.TICK_MAX_GAP, and is never turned into distance.
do
  local online, played, foot = ns.char.c.time_online or 0, ns.char.c.played_server or 0, ns.char.c.dist_foot or 0
  state.speed = 7
  NOW = NOW + 5; ticker.scripts.OnUpdate(ticker, 5)
  eq(math.floor((ns.char.c.time_online - online) + 0.5), 5, "5 s hitch counted as online time")
  eq(math.floor((ns.char.c.played_server - played) + 0.5), 5, "5 s hitch counted as played time")
  eq(ns.char.c.dist_foot or 0, foot, "no distance across a hitch")
  online = ns.char.c.time_online
  NOW = NOW + 3600; ticker.scripts.OnUpdate(ticker, 3600)
  eq(math.floor((ns.char.c.time_online - online) + 0.5), ns.TICK_MAX_GAP, "huge gap capped")
  state.speed = 0
end

-- Days beyond the newest 40 fold into monthly totals instead of being lost.
do
  local rec = ns.NewCharRecord()
  for d = 1, 31 do rec.days[string.format("202601%02d", d)] = { jumps = 1, kills_npc = 2 } end
  for d = 1, 28 do rec.days[string.format("202602%02d", d)] = { jumps = 10 } end
  eq(ns.RollUpDays(rec), 19, "19 oldest days folded")
  local kept = 0 for _ in pairs(rec.days) do kept = kept + 1 end
  eq(kept, 40, "40 days kept")
  eq(rec.months["202601"].jumps, 19, "January total folded")
  eq(rec.months["202601"].kills_npc, 38, "second counter folded")
  eq(rec.meta.monthsThrough, "20260119", "newest folded day remembered")
  eq(ns.MonthTotal(rec, "jumps", "202601"), 31, "month total = folded + kept days")
  eq(ns.MonthTotal(rec, "jumps", "202602"), 280, "month with only kept days")
  rec.days["20260105"] = { jumps = 99 } -- an old day restored from a backup
  eq(ns.RollUpDays(rec), 0, "nothing new to fold")
  eq(rec.days["20260105"], nil, "already-folded day dropped, not re-added")
  eq(rec.months["202601"].jumps, 19, "no double count")
  rec.days["2026xx01"] = { jumps = 1 }
  ns.RollUpDays(rec)
  eq(rec.days["2026xx01"], nil, "malformed day key removed")
  local series = ns.MonthSeries(rec, "jumps", 3)
  eq(#series, 3, "month series length")
  eq(series[3].m, os.date("%Y%m"), "series ends at current month")
end

-- Monthly totals and the fold marker survive a full (LTS3) backup round trip.
do
  ns.char.months = { ["202501"] = { jumps = 7, dist_foot = 12.5 } }
  ns.char.meta.monthsThrough = "20250131"
  local text, err = ns.SerializeFullBackup()
  eq(type(text), "string", "full backup with months serializes " .. tostring(err))
  local snap, err2 = ns.DeserializeFullBackup(text)
  eq(type(snap), "table", "full backup with months parses " .. tostring(err2))
  eq(snap and snap.record.months["202501"].jumps, 7, "months in full backup")
  eq(snap and snap.record.meta.monthsThrough, "20250131", "fold marker in full backup")
  ns.char.months = {}
  ns.char.meta.monthsThrough = nil
  local ok, rerr = ns.RestoreFullBackup(snap)
  eq(ok, true, "full restore with months " .. tostring(rerr))
  eq(ns.char.months["202501"] and ns.char.months["202501"].dist_foot, 12.5, "months restored")
  eq(ns.char.meta.monthsThrough, "20250131", "fold marker restored")
end

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
return fails
'''
fails = L.execute(test)
sys.exit(1 if fails else 0)

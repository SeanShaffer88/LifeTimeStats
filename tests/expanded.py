"""Lua 5.1 regression tests for the additive statistics expansion (no game client)."""
from pathlib import Path
from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text())
lua.execute("ns = {}; baseCounts = {}; beforeExpandedFrames = 0")
for name in (ROOT / "LifeTimeStats.toc").read_text().splitlines():
    name = name.strip()
    if not name.endswith(".lua"):
        continue
    if name == "Expanded.lua":
        lua.execute("""
            for k, rows in pairs(ns.STATS) do baseCounts[k] = #rows end
            baseCount = ns.CountStats()
            for _, f in ipairs(frames) do
                if f.scripts.OnUpdate then beforeExpandedFrames = beforeExpandedFrames + 1 end
            end
        """)
    chunk = lua.eval("function(s,n) local f,e=loadstring(s,n); assert(f,e); return f end")(
        (ROOT / name).read_text(), name
    )
    chunk("LifeTimeStats", lua.globals().ns)
    if name == "Expanded.lua":
        lua.execute("""
            expandedFrameDelta = 0
            for _, f in ipairs(frames) do if f.scripts.OnUpdate then expandedFrameDelta = expandedFrameDelta + 1 end end
            expandedFrameDelta = expandedFrameDelta - beforeExpandedFrames
        """)

lua.execute(r'''
local checks = 0
local function eq(got, want, name)
    checks = checks + 1
    assert(got == want, name .. ": got " .. tostring(got) .. ", expected " .. tostring(want))
end
local function near(got, want, name)
    checks = checks + 1
    assert(math.abs(got - want) < 0.000001, name .. ": " .. tostring(got))
end
local function count(key) return ns.char.c[key] or 0 end
local function fire(ev, ...) ns.frame.scripts.OnEvent(ns.frame, ev, ...) end
UnitIsGhost = function() return state.ghost end
IsInGroup = function() return state.grouped end
UnitIsAFK = function() return state.afk end
IsResting = function() return state.rest end
IsIndoors = function() return state.indoor end
IsOutdoors = function() return not state.indoor end
UnitHealth = function() return state.hp or 100 end
UnitHealthMax = function() return 100 end
UnitCastingInfo = function() return state.casting and "Frostbolt" or nil end
UnitChannelInfo = function() return state.channeling and "Evocation" or nil end
AcceptXPLoss = function() end
state.ghost, state.dead, state.grouped, state.afk = false, false, false, false
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_ENTERING_WORLD", true, false)
ns.ToggleWindow()
eq(expandedFrameDelta, 0, "module adds no polling frame")
eq(baseCount, 616, "baseline catalog measured")
eq(ns.EXPANDED_STAT_COUNT, 222, "222 new catalog entries")
eq(ns.CountStats(), 839, "complete catalog")

local function tick(n, distance, speed)
    for i = 1, n do
        NOW = NOW + 0.25
        ns.TrackExpandedSample(0.25, distance, speed)
    end
end
tick(40, 1.75, 7)
near(count("ex_time_moving"), 10, "movement time")
near(count("ex_moving_distance"), 70, "matching new-version distance window")
near(count("ex_time_foot_moving"), 10, "on foot")
near(count("ex_dist_world_moving"), 70, "open world")
near(count("ex_dist_solo_moving"), 70, "solo distance")
near(ns.char.r.ex_longest_moving, 10, "continuous moving record")
near(ns.session.c.ex_time_moving, 10, "session counters")
near(ns.GetView("char", "today").c.ex_time_moving, 10, "daily counters")
near(ns.GetView("account").c.ex_time_moving, 10, "account aggregation")

state.combat = true
tick(4, nil, 0)
near(count("ex_time_stationary"), 1, "stationary time")
near(count("ex_time_combat_stationary"), 1, "stationary combat")
near(ns.char.r.ex_longest_moving, 10, "idle ends movement streak")
state.grouped, state.afk, state.rest, state.indoor = true, true, true, true
state.inInst, state.itype = true, "party"
tick(4, 1.75, 7)
near(count("ex_dist_combat_moving"), 7, "combat distance")
near(count("ex_dist_group_moving"), 7, "group distance")
near(count("ex_dist_dungeon_moving"), 7, "dungeon distance")
near(count("ex_dist_afk_moving"), 7, "AFK movement")
near(count("ex_dist_rest_moving"), 7, "rest-area movement")
near(count("ex_dist_indoor_moving"), 7, "indoor movement")
near(count("ex_time_combat_moving"), 1, "moving combat")
state.hp = 20
tick(4, nil, 0)
near(count("ex_time_low_health"), 1, "low health observed")
state.hp = 25
tick(4, nil, 0)
near(count("ex_time_low_health"), 1, "threshold strictly below 25 percent")
state.casting = true; tick(4, 1.75, 7); state.casting = false
state.channeling = true; tick(4, nil, 0); state.channeling = false
near(count("ex_time_casting"), 1, "casting time")
near(count("ex_dist_casting"), 7, "moving cast distance")
near(count("ex_time_channeling"), 1, "channeling time")

-- Overlapping windows are independent; repeated events are not extra visits.
fire("MERCHANT_SHOW"); fire("MERCHANT_SHOW"); fire("BANKFRAME_OPENED")
tick(4, nil, 0)
fire("MERCHANT_CLOSED"); fire("MERCHANT_CLOSED")
tick(4, nil, 0)
fire("BANKFRAME_CLOSED")
near(count("ex_visit_time_merchant"), 1, "merchant sampled duration")
near(count("ex_visit_completed_merchant"), 1, "merchant completed duration")
eq(count("ex_visits_merchant"), 1, "deduplicated merchant visit")
near(count("ex_visit_time_bank"), 2, "overlapping bank duration")
local function row(category, label)
    for _, r in ipairs(ns.STATS[category]) do if r.label == label then return r end end
    error("missing row: " .. label)
end
near(row("wealth", "Vendor: average observed visit").get(ns.char), 1, "visit average")
fire("MAIL_SHOW"); tick(4, nil, 0)
local beforePause = count("ex_visit_time_mail")
ns.TrackExpandedSample(60, 1000, 7)
near(count("ex_visit_time_mail"), beforePause, "loading hitch excluded")
fire("PLAYER_LEAVING_WORLD"); fire("MAIL_CLOSED")
eq(count("ex_visits_mail"), 1, "loading closes visit once")

-- Confirmed recovery: button clicks do not end it; only public revival does.
state.combat, state.inInst, state.grouped, state.afk = false, false, false, false
state.rest, state.indoor, state.hp = false, false, 100
state.dead, state.ghost = true, false
tick(4, 1.75, 7)
near(count("ex_recovery_distance"), 0, "dead-body movement is not corpse recovery")
near(count("ex_dead_body_time"), 1, "waiting before ghost release")
hooks.RepopMe(); hooks.RepopMe()
state.ghost = true
fire("PLAYER_ALIVE"); fire("PLAYER_ALIVE")
tick(4, 1.75, 7); tick(4, nil, 0)
eq(count("ex_recovery_started"), 1, "deduplicated recovery start")
near(count("ex_recovery_distance"), 7, "en-route corpse distance")
near(count("ex_recovery_time"), 2, "recovery time")
near(count("ex_recovery_moving_time"), 1, "recovery moving")
near(count("ex_recovery_idle_time"), 1, "recovery waiting")
hooks.RetrieveCorpse(); hooks.RetrieveCorpse()
eq(count("ex_retrieval_confirmed"), 0, "request not success")
state.ghost, state.dead = false, false
fire("PLAYER_UNGHOST"); fire("PLAYER_UNGHOST")
eq(count("ex_retrieval_confirmed"), 1, "confirmed corpse retrieval")
eq(count("ex_recovery_completed"), 1, "deduplicated ending")
eq(count("ex_recovery_full"), 1, "fully observed interval")
near(count("ex_retrieval_distance"), 7, "confirmed retrieval distance")
near(ns.char.f.ex_retrieval_fastest, 2, "fastest actual confirmed recovery")
near(row("deaths", "Average fully observed recovery distance").get(ns.char), 7, "average recovery distance")

-- Reload keeps the current interval; offline/loading seconds are never added.
state.dead = true; hooks.RepopMe(); state.ghost = true; fire("PLAYER_ALIVE")
tick(4, 1.75, 7)
local starts = count("ex_recovery_started")
fire("PLAYER_ENTERING_WORLD", false, true)
eq(count("ex_recovery_started"), starts, "reload continuation not new run")
tick(4, 1.75, 7)
hooks.AcceptXPLoss()
state.dead, state.ghost = false, false; fire("PLAYER_UNGHOST")
eq(count("ex_spirit_confirmed"), 1, "spirit resurrection separated")
eq(count("ex_retrieval_confirmed"), 1, "spirit healer not corpse retrieval")
near(count("ex_recovery_full_distance"), 21, "full-run distances accumulated")
near(row("deaths", "Average fully observed recovery distance").get(ns.char), 10.5, "full-run mean")

-- Already a ghost at login: partial and excluded from full-run records.
state.dead, state.ghost = true, true
fire("PLAYER_ENTERING_WORLD", false, false)
tick(4, 1.75, 7)
hooks.AcceptResurrect()
state.dead, state.ghost = false, false; fire("PLAYER_UNGHOST")
eq(count("ex_recovery_partial"), 1, "partial ghost login")
eq(count("ex_ghost_rez_confirmed"), 1, "accepted other-player ghost resurrection")
eq(count("ex_recovery_full"), 2, "partial excluded from full-run averages")
near(count("ex_recovery_full_distance"), 21, "partial distance excluded")

-- Missing/secret APIs: no arithmetic, false completion or false stationary time.
local secret = setmetatable({}, { __add=function() error("secret arithmetic") end,
    __sub=function() error("secret arithmetic") end, __lt=function() error("secret compare") end })
issecretvalue = function(v) return v == secret end
local oldGhost, oldHealth, oldCombat, oldCasting = UnitIsGhost, UnitHealth, UnitAffectingCombat, UnitCastingInfo
state.dead = true; hooks.RepopMe(); state.ghost = true; fire("PLAYER_ALIVE")
tick(4, 1.75, 7)
local recoveryBefore = count("ex_recovery_distance")
local stationaryBefore, healthBefore = count("ex_time_stationary"), count("ex_time_low_health")
UnitIsGhost, UnitHealth, UnitAffectingCombat, UnitCastingInfo =
    function() return secret end, function() return secret end, function() return secret end, function() return secret end
ns.TrackExpandedSample(0.25, secret, secret)
fire("PLAYER_UNGHOST")
eq(ns.char.meta.expRecovery ~= nil, true, "secret ghost state cannot complete interval")
near(count("ex_recovery_distance"), recoveryBefore, "secret movement skipped")
near(count("ex_time_stationary"), stationaryBefore, "unknown speed not stationary")
near(count("ex_time_low_health"), healthBefore, "secret health skipped")
UnitIsGhost, UnitHealth, UnitAffectingCombat, UnitCastingInfo = oldGhost, oldHealth, oldCombat, oldCasting
hooks.RetrieveCorpse()
local realTime = time
time = function() return realTime() + 60 end
state.dead, state.ghost = false, false; fire("PLAYER_UNGHOST"); time = realTime
eq(count("ex_recovery_unknown_end"), 1, "stale retrieval request stays unknown")
local sampleBefore = count("ex_sample_time")
for _, dt in ipairs({0, -1, 3, math.huge}) do ns.TrackExpandedSample(dt, 100, 7) end
ns.TrackExpandedSample(secret, 100, 7)
near(count("ex_sample_time"), sampleBefore, "invalid elapsed rejected")
local publicHealth = UnitHealth; UnitHealth = nil; ns.src.expandedHealth = nil
tick(1, nil, 0)
eq(ns.IsNA(row("combat", "Below 25% health: observed time"), 0), true, "missing health is n/a")
UnitHealth = publicHealth
ns.char.meta.expRecovery = { distance = "broken" }
tick(1, nil, 0)
eq(ns.char.meta.expRecovery, nil, "malformed saved progress repaired")
eq(ns.src.expandedRecoveryInvalid, 1, "malformed progress noted")

-- Complete paired combat events, not repeated enter/leave or interrupted fights.
state.combat = true; fire("PLAYER_REGEN_DISABLED"); fire("PLAYER_REGEN_DISABLED")
tick(4, 1.75, 7); tick(4, nil, 0)
ns.Add("kills_npc"); ns.Add("casts", 3)
state.combat = false; fire("PLAYER_REGEN_ENABLED"); fire("PLAYER_REGEN_ENABLED")
eq(count("ex_fights_observed"), 1, "fight ending dedup")
eq(count("ex_fights_survived"), 1, "fight survived")
eq(count("ex_fights_liveness_observed"), 1, "known fight outcome")
eq(count("ex_fights_npc_kill"), 1, "fight NPC kill")
near(ns.char.r.ex_fight_distance, 7, "fight distance record")
near(ns.char.r.ex_fight_casts, 3, "fight successful casts record")
state.combat = true; fire("PLAYER_REGEN_DISABLED"); fire("PLAYER_LEAVING_WORLD")
fire("PLAYER_REGEN_ENABLED"); state.combat = false
eq(count("ex_fights_incomplete"), 1, "partial fight explicitly tracked")
eq(count("ex_fights_observed"), 1, "partial not recorded as complete")

-- Every new getter is finite at zero and formats in every existing category.
-- Personal records are dated, bounded, saveable and visible in the chronicle.
local priorJournal = #(ns.char.journal or {})
ns.settings.recordMoments = false
for i = 1, 220 do ns.Max("expanded_history_cap", i, "Test arena") end
eq(#ns.char.rh, 200, "lifetime record history cap")
eq(#ns.session.rh, 200, "session record history cap")
local newest = ns.char.rh[#ns.char.rh]
eq(newest.k, "expanded_history_cap", "latest record retained")
eq(newest.d, "max", "maximum improvement direction")
eq(newest.w, "Test arena", "record context retained")
local savedName, savedEnabled = ns.settings.recordMoments, ns.loggedIn
ns.settings.recordMoments, ns.loggedIn = true, true
ns.Max("expanded_journal_test", 9, "North gate")
eq(#ns.char.journal, priorJournal + 1, "personal best adds local Journal moment")
eq(string.find(ns.char.journal[#ns.char.journal][2], "North gate", 1, true) ~= nil, true, "Journal record context")
ns.Max("expanded_journal_test", 9, "duplicate record")
eq(#ns.char.journal, priorJournal + 1, "unchanged record does not repeat")
local originalRefresh, liveRefreshes = ns.RefreshWindow, 0
ns.RefreshWindow = function(...) liveRefreshes = liveRefreshes + 1; return originalRefresh(...) end
ns.activePage = "journal"
ns.Journal("Live-zone refresh fixture")
eq(liveRefreshes, 1, "open chronicle refreshes when the player acts")
ns.activePage = "dashboard"
ns.RefreshWindow = originalRefresh
local sessionHighlights = ns.SessionRecordHighlights(ns.session.rh, 3)
eq(#sessionHighlights <= 3, true, "session recap highlight limit")
eq(type(sessionHighlights[1]), "string", "session highlights formatted")
local historyList
for _, def in ipairs(ns.LISTS) do if def.id == "recordhistory" then historyList = def end end
eq(type(historyList), "table", "personal best history list")
eq(historyList.count(ns.char), 200, "visible history count")
eq(#historyList.rows(ns.char, ns.session), 100, "history list row cap")
ns.Save()
eq(#LifeTimeStatsCharDB.session.rh, 200, "session history saved")
eq(#LifeTimeStatsCharDB.lastSession.highlights <= 3, true, "last-session highlights saved")
local decodedHistory = ns.Deserialize(ns.Serialize(ns.char))
eq(#decodedHistory.rh, #ns.char.rh, "record history backup roundtrip")
local restoredHistory = ns.NewCharRecord()
ns.MergeMax(restoredHistory, decodedHistory)
eq(#restoredHistory.rh, #ns.char.rh, "backup restore keeps record history")
ns.settings.recordMoments, ns.loggedIn = savedName, savedEnabled

local zero = { c = {}, r = {}, t = {}, u = {}, un = {}, f = {} }
local labels = {}
for category, rows in pairs(ns.STATS) do
    for i = (baseCounts[category] or 0) + 1, #rows do
        local st = rows[i]
        local identity = category .. ":" .. st.label
        eq(labels[identity], nil, "unique new label " .. identity); labels[identity] = true
        local value = ns.StatValue(st, zero)
        eq(ns.BadNumber(value), false, "finite empty stat " .. st.label)
        eq(type(ns.FormatStat(st, value)), "string", "format " .. st.label)
    end
end
local speedRow = row("travel", "Average moving speed (yd/s)")
local survivalRow = row("combat", "Observed fight survival rate (known outcomes)")
near(survivalRow.get(ns.char), 100, "known-outcome survival denominator")
local oldTotal = count("dist_total")
ns.char.c.dist_total = 99999999
near(speedRow.get(ns.char), count("ex_moving_distance") / count("ex_time_moving"), "speed excludes historical pre-upgrade distance")
ns.char.c.dist_total = oldTotal
for _, category in ipairs(ns.CATEGORIES) do ns.ShowPage(category.id) end
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("EXPANDED PASS: " .. checks .. " assertions; " .. ns.EXPANDED_STAT_COUNT .. " additions; " .. ns.CountStats() .. " total entries")
''')

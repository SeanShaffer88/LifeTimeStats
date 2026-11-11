-- LifeTimeStats - observed activity, corpse recovery, interaction timings and ratios
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Min, On, Tally = ns.Add, ns.Max, ns.Min, ns.On, ns.Tally
local S, Bad = ns.IsSecret, ns.BadNumber
local contexts, visits, fight = {}, {}, nil
local installed = false

local function Number(v)
    if not S(v) and not Bad(v) then return v end
end
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil, false end
    local ok, v = pcall(fn, ...)
    if not ok or S(v) then return nil, false end
    return v, true
end
local function Flag(fn, ...)
    local v, ok = Read(fn, ...)
    if ok then return v and true or false end
end
local function Both(a, b)
    if a == nil or b == nil then return nil end
    return a and b
end
local function Not(v) if v ~= nil then return not v end end
local function Zone()
    local z = ns.GetZone and ns.GetZone()
    return not S(z) and type(z) == "string" and z ~= "" and z or "Unknown"
end
local function C(v, k) return v.c[k] or 0 end
local function Ratio(a, b) return b > 0 and a / b or 0 end

-- One module, no additional OnUpdate frame. Every sampled counter uses the
-- native movement ticker's same accepted dt/distance and SavedVariables APIs.
local measured = {
    { "moving", "Moving", "travel", false },
    { "stationary", "Stationary", "travel", false },
    { "foot_moving", "Moving on foot", "travel", false },
    { "mount_moving", "Moving while mounted", "travel", false },
    { "swim_moving", "Moving while swimming", "travel", false },
    { "combat_moving", "Moving in combat", "combat", true },
    { "combat_stationary", "Stationary in combat", "combat", false },
    { "peace_moving", "Moving out of combat", "travel", true },
    { "afk_moving", "Moving while AFK", "travel", true },
    { "active_moving", "Moving while not AFK", "travel", true },
    { "rest_moving", "Moving in a rest area", "travel", true },
    { "indoor_moving", "Moving indoors", "travel", true },
    { "outdoor_moving", "Moving outdoors", "travel", true },
    { "group_moving", "Moving in a group", "travel", true },
    { "solo_moving", "Moving solo", "travel", true },
    { "world_moving", "Moving in the open world", "travel", true },
    { "dungeon_moving", "Moving in dungeons", "adventure", true },
    { "raid_moving", "Moving in raids", "adventure", true },
    { "bg_moving", "Moving in battlegrounds", "adventure", true },
    { "arena_moving", "Moving in arenas", "adventure", true },
    { "fall_moving", "Moving while airborne", "travel", true },
    { "low_health", "Below 25% health", "combat", true, "expandedHealth" },
    { "full_health", "At full health", "combat", true, "expandedHealth" },
    { "casting", "Casting", "combat", true, "expandedCasting" },
    { "channeling", "Channeling", "combat", true, "expandedChanneling" },
}
local function Observe(key, active, dt, distance)
    local st = contexts[key]
    if not st then st = { seconds = 0, distance = 0 }; contexts[key] = st end
    if active ~= true then st.seconds, st.distance = 0, 0; return end
    st.seconds = st.seconds + dt
    st.distance = st.distance + (distance or 0)
    Add("ex_time_" .. key, dt)
    if distance and distance > 0 then Add("ex_dist_" .. key, distance) end
    Max("ex_longest_" .. key, st.seconds, Zone())
    if distance then Max("ex_farthest_" .. key, st.distance, Zone()) end
end

-- Confirmed ghost intervals, rather than button clicks or time spent offline.
-- Persistent progress survives /reload. A login already in ghost form is a
-- partial observation, excluded from full-run averages and fastest records.
local function Ghost() return Flag(UnitIsGhost, "player") end
local function Alive() return Not(Flag(UnitIsDeadOrGhost, "player")) end
local function ReleaseWasObserved()
    local stamp = Number(ns.char.meta.expReleasePending)
    local age = stamp and time() - stamp
    return age ~= nil and age >= 0 and age <= 30
end
local function CurrentRecovery()
    local r = ns.char.meta.expRecovery
    if r == nil then return end
    if not S(r) and type(r) == "table" and Number(r.distance) and r.distance >= 0
        and Number(r.seconds) and r.seconds >= 0 and Number(r.moving)
        and r.moving >= 0 and r.moving <= r.seconds and type(r.zone) == "string"
        and type(r.partial) == "boolean" and (r.intent == nil or type(r.intent) == "string") then
        if not Number(r.intentAt) then r.intent, r.intentAt = nil, nil end
        return r
    end
    ns.char.meta.expRecovery = nil
    ns.src.expandedRecoveryInvalid = (ns.src.expandedRecoveryInvalid or 0) + 1
end
local function BeginRecovery(partial)
    if CurrentRecovery() then return end
    local m = ns.char.meta
    m.expRecovery = { partial = partial, distance = 0, seconds = 0, moving = 0, zone = Zone() }
    m.expReleasePending = nil
    Add("ex_recovery_started")
    if partial then Add("ex_recovery_partial") end
end
local function RecoveryIntent(kind)
    if not ns.char then return end
    local r = CurrentRecovery()
    if r and Ghost() == true then r.intent, r.intentAt = kind, time() end
end
local function FinishRecovery()
    if not ns.char or Ghost() ~= false or Alive() ~= true then return end
    local m = ns.char.meta
    local r = CurrentRecovery()
    if not r then return end
    m.expRecovery, m.expReleasePending = nil, nil
    local endZone = Zone()
    Add("ex_recovery_completed")
    Add("ex_recovery_completed_distance", r.distance)
    Add("ex_recovery_completed_time", r.seconds)
    Tally("ex_recovery_ends", endZone)
    local age = r.intentAt and time() - r.intentAt
    local intent = age and age >= 0 and age <= 30 and r.intent or "unknown"
    if intent == "corpse" then
        Add("ex_retrieval_confirmed"); Add("ex_retrieval_distance", r.distance)
        Tally("ex_retrieval_zones", endZone)
    elseif intent == "spirit" then Add("ex_spirit_confirmed")
    elseif intent == "resurrection" then Add("ex_ghost_rez_confirmed")
    else Add("ex_recovery_unknown_end") end
    if not r.partial then
        Add("ex_recovery_full"); Add("ex_recovery_full_distance", r.distance)
        Add("ex_recovery_full_time", r.seconds); Add("ex_recovery_full_moving", r.moving)
        Max("ex_recovery_longest", r.seconds, r.zone)
        Max("ex_recovery_farthest", r.distance, r.zone)
        if intent == "corpse" then Min("ex_retrieval_fastest", r.seconds, r.zone) end
    end
end
On("PLAYER_ALIVE", function()
    if Ghost() == true then BeginRecovery(not ReleaseWasObserved()) end
    FinishRecovery()
end)
On("PLAYER_UNGHOST", FinishRecovery)

-- Interface visit durations are sampled online time, not wall time: a long
-- loading screen, sleep, disconnect or /reload cannot invent hours of activity.
local interfaces = {
    { "merchant", "Vendor", "wealth", "MERCHANT_SHOW", "MERCHANT_CLOSED" },
    { "bank", "Bank", "wealth", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" },
    { "mail", "Mailbox", "wealth", "MAIL_SHOW", "MAIL_CLOSED" },
    { "auction", "Auction house", "wealth", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" },
    { "trade", "Trade window", "wealth", "TRADE_SHOW", "TRADE_CLOSED" },
    { "trainer", "Trainer", "adventure", "TRAINER_SHOW", "TRAINER_CLOSED" },
    { "taximap", "Flight map", "travel", "TAXIMAP_OPENED", "TAXIMAP_CLOSED" },
    { "gossip", "NPC conversation", "social", "GOSSIP_SHOW", "GOSSIP_CLOSED" },
    { "quest", "Quest dialog", "adventure", "QUEST_DETAIL", "QUEST_FINISHED" },
    { "book", "Book / item text", "life", "ITEM_TEXT_BEGIN", "ITEM_TEXT_CLOSED" },
}
local function CloseVisit(id)
    local duration = visits[id]
    if duration == nil then return end
    visits[id] = nil
    Add("ex_visits_" .. id)
    Add("ex_visit_completed_" .. id, duration)
    Max("ex_visit_longest_" .. id, duration, Zone())
end
for _, spec in ipairs(interfaces) do
    local id = spec[1]
    On(spec[4], function() if visits[id] == nil then visits[id] = 0 end end)
    On(spec[5], function() CloseVisit(id) end)
end
local function CloseVisits() for id in pairs(visits) do CloseVisit(id) end end
local function ResetIntervals()
    contexts = {}
    CloseVisits()
    if fight then Add("ex_fights_incomplete"); fight = nil end
end
On("PLAYER_LEAVING_WORLD", ResetIntervals)
On("PLAYER_LOGOUT", ResetIntervals)
On("PLAYER_ENTERING_WORLD", function()
    ResetIntervals()
    if Ghost() == true then BeginRecovery(not ReleaseWasObserved()) end
    FinishRecovery()
end)

On("PLAYER_REGEN_DISABLED", function()
    if fight then return end
    fight = { npc = C(ns.char, "kills_npc"), pvp = C(ns.char, "kills_pvp"),
        casts = C(ns.char, "casts"), distance = 0, moving = 0, stationary = 0 }
end)
On("PLAYER_REGEN_ENABLED", function()
    if not fight then return end
    local f = fight; fight = nil
    Add("ex_fights_observed")
    local alive = Alive()
    if alive == true then Add("ex_fights_survived"); Add("ex_fights_liveness_observed")
    elseif alive == false then Add("ex_fights_ended_dead"); Add("ex_fights_liveness_observed") end
    if C(ns.char, "kills_npc") > f.npc then Add("ex_fights_npc_kill") end
    if C(ns.char, "kills_pvp") > f.pvp then Add("ex_fights_pvp_kill") end
    Max("ex_fight_distance", f.distance, Zone())
    Max("ex_fight_casts", math.max(0, C(ns.char, "casts") - f.casts), Zone())
    Max("ex_fight_moving", f.moving, Zone())
    Max("ex_fight_stationary", f.stationary, Zone())
end)

function ns.InstallExpandedHooks()
    if installed then return end
    installed = true
    local function Hook(name, fn)
        if type(_G[name]) == "function" then pcall(hooksecurefunc, name, ns.Guard("expanded:" .. name, fn)) end
    end
    Hook("RepopMe", function()
        if ns.char and Alive() == false and not CurrentRecovery() and not ReleaseWasObserved() then
            ns.char.meta.expReleasePending = time()
        end
    end)
    Hook("RetrieveCorpse", function() RecoveryIntent("corpse") end)
    Hook("AcceptResurrect", function() RecoveryIntent("resurrection") end)
    Hook("AcceptXPLoss", function() RecoveryIntent("spirit") end)
end
On("PLAYER_LOGIN", ns.InstallExpandedHooks)
On("PLAYER_ENTERING_WORLD", ns.InstallExpandedHooks)

local function InstanceKind()
    local ok, inside, kind = pcall(IsInInstance)
    if not ok or S(inside) or S(kind) then return nil end
    if not inside then return "world" end
    return type(kind) == "string" and kind or nil
end
function ns.TrackExpandedSample(dt, distance, speed)
    if not ns.char or S(dt) or Bad(dt) or dt <= 0 or dt > 2 then return end
    distance, speed = Number(distance), Number(speed)
    if distance and distance < 0 then distance = nil end
    local moving
    if distance and distance > 0 then moving = true
    elseif speed then moving = speed > 0 end
    local ghost, alive = Ghost(), Alive()
    if ghost ~= nil then ns.src.expandedGhost = true end
    if ghost == true then
        BeginRecovery(not ReleaseWasObserved())
        local r = ns.char.meta.expRecovery
        r.seconds = r.seconds + dt
        Add("ex_recovery_time", dt)
        Tally("ex_recovery_zone_time", Zone(), dt)
        if moving == true then
            r.moving = r.moving + dt; Add("ex_recovery_moving_time", dt)
            if distance and distance > 0 then
                r.distance = r.distance + distance
                Add("ex_recovery_distance", distance)
                Tally("ex_recovery_zone_dist", Zone(), distance)
            end
        elseif moving == false then Add("ex_recovery_idle_time", dt) end
    else FinishRecovery() end
    if alive == true then Add("ex_alive_time", dt)
    elseif alive == false and ghost == false then Add("ex_dead_body_time", dt) end
    Add("ex_sample_time", dt)
    if moving ~= nil then Add("ex_motion_observed_time", dt) end
    if moving == true and distance and distance > 0 then Add("ex_moving_distance", distance) end
    local combat = Flag(UnitAffectingCombat, "player")
    local afk, resting = Flag(UnitIsAFK, "player"), Flag(IsResting)
    local indoor, outdoor = Flag(IsIndoors), Flag(IsOutdoors)
    local grouped = Flag(IsInGroup)
    if grouped == nil and type(GetNumGroupMembers) == "function" then
        local n = Number((Read(GetNumGroupMembers))); if n then grouped = n > 0 end
    end
    local kind = InstanceKind()
    local mounted, swim, taxi = Flag(IsMounted), Flag(IsSwimming), Flag(UnitOnTaxi, "player")
    local health, maximum = Number((Read(UnitHealth, "player"))), Number((Read(UnitHealthMax, "player")))
    local low, full
    if health and maximum and maximum > 0 and health >= 0 and health <= maximum and alive == true then
        ns.src.expandedHealth = true
        Add("ex_health_observed_time", dt)
        low, full = health > 0 and health / maximum < 0.25, health == maximum
    end
    local casting, castOK = Read(UnitCastingInfo, "player")
    local channel, channelOK = Read(UnitChannelInfo, "player")
    if castOK then ns.src.expandedCasting = true; casting = casting ~= nil end
    if channelOK then ns.src.expandedChanneling = true; channel = channel ~= nil end
    local active = {
        moving = moving, stationary = Not(moving),
        foot_moving = Both(moving, Both(alive, Both(Not(mounted), Both(Not(swim), Not(taxi))))),
        mount_moving = Both(moving, Both(alive, Both(mounted, Not(taxi)))),
        swim_moving = Both(moving, Both(alive, swim)),
        combat_moving = Both(moving, combat), combat_stationary = Both(Not(moving), combat),
        peace_moving = Both(moving, Not(combat)), afk_moving = Both(moving, afk),
        active_moving = Both(moving, Not(afk)), rest_moving = Both(moving, resting),
        indoor_moving = Both(moving, indoor), outdoor_moving = Both(moving, outdoor),
        group_moving = Both(moving, grouped), solo_moving = Both(moving, Not(grouped)),
        world_moving = kind and Both(moving, kind == "world"),
        dungeon_moving = kind and Both(moving, kind == "party"),
        raid_moving = kind and Both(moving, kind == "raid"),
        bg_moving = kind and Both(moving, kind == "pvp"),
        arena_moving = kind and Both(moving, kind == "arena"),
        fall_moving = Both(moving, Flag(IsFalling)), low_health = low, full_health = full,
        casting = castOK and casting or nil, channeling = channelOK and channel or nil,
    }
    for _, spec in ipairs(measured) do
        Observe(spec[1], active[spec[1]], dt, moving == true and distance or nil)
    end
    for id, duration in pairs(visits) do
        visits[id] = duration + dt
        Add("ex_visit_time_" .. id, dt)
    end
    if fight then
        if distance and distance > 0 then fight.distance = fight.distance + distance end
        if moving == true then fight.moving = fight.moving + dt
        elseif moving == false then fight.stationary = fight.stationary + dt end
    end
end
ns.TrackExpandedSample = ns.Guard("expanded observations", ns.TrackExpandedSample)

-- Append definitions to the existing dashboard: lifetime, session, day, account,
-- search, export and backup views already operate on these standard counters.
local added = 0
local function Stat(cat, label, fmt, key, record, tip, source)
    local row = { label = label, fmt = fmt, tip = tip, expandedSource = source }
    if record then row.rec = key else row.key = key end
    table.insert(ns.STATS[cat], row); added = added + 1
end
local sampleTip = "Observed online samples only. Hidden/missing APIs and loading hitches are skipped. Contexts can overlap; do not add them together."
for _, spec in ipairs(measured) do
    local id, label, cat, dist, source = spec[1], spec[2], spec[3], spec[4], spec[5]
    Stat(cat, label .. ": observed time", "time", "ex_time_" .. id, false, sampleTip, source)
    if dist then Stat(cat, label .. ": distance", "yards", "ex_dist_" .. id, false, sampleTip, source) end
    Stat("records", "Longest observed interval: " .. label:lower(), "time", "ex_longest_" .. id, true, sampleTip, source)
    if dist then Stat("records", "Farthest observed interval: " .. label:lower(), "yards", "ex_farthest_" .. id, true, sampleTip, source) end
end
for _, spec in ipairs(interfaces) do
    local id, label, cat = spec[1], spec[2], spec[3]
    local tip = "Sampled online time while this window is open, not necessarily active interaction. Repeated open/close events are deduplicated. Overlapping windows overlap in time."
    Stat(cat, label .. ": time with window open", "time", "ex_visit_time_" .. id, false, tip)
    Stat(cat, label .. ": visits timed", "int", "ex_visits_" .. id, false, tip)
    Stat("records", label .. ": longest observed visit", "time", "ex_visit_longest_" .. id, true, tip)
    local row = { label = label .. ": average observed visit", fmt = "time", tip = "Completed visit durations only; ongoing visits are excluded.",
        get = function(v) return Ratio(C(v, "ex_visit_completed_" .. id), C(v, "ex_visits_" .. id)) end }
    table.insert(ns.STATS[cat], row); added = added + 1
end
local recoveryRows = {
    { "Distance traveled en route to recover corpse", "yards", "ex_recovery_distance" },
    { "Confirmed corpse-retrieval distance", "yards", "ex_retrieval_distance" },
    { "Observed ghost recovery time", "time", "ex_recovery_time" },
    { "Ghost recovery: moving time", "time", "ex_recovery_moving_time" },
    { "Ghost recovery: stationary time", "time", "ex_recovery_idle_time" },
    { "Recovery segments observed", "int", "ex_recovery_started" },
    { "Recoveries first seen already in progress", "int", "ex_recovery_partial" },
    { "Observed recoveries ended", "int", "ex_recovery_completed" },
    { "Recoveries observed from release to revival", "int", "ex_recovery_full" },
    { "Corpse retrievals confirmed by revival", "int", "ex_retrieval_confirmed" },
    { "Spirit-healer revivals confirmed", "int", "ex_spirit_confirmed" },
    { "Other-player ghost resurrections confirmed", "int", "ex_ghost_rez_confirmed" },
    { "Recovery endings with unknown method", "int", "ex_recovery_unknown_end" },
    { "Observed dead-body waiting time", "time", "ex_dead_body_time" },
    { "Observed time alive", "time", "ex_alive_time" },
}
for _, row in ipairs(recoveryRows) do
    Stat("deaths", row[1], row[2], row[3], false,
        "Requires public ghost/alive state. Distance is measured travel, not straight-line distance. A button click alone never confirms retrieval. Unknown endings stay unknown.", "expandedGhost")
end
Stat("records", "Longest fully observed recovery", "time", "ex_recovery_longest", true, sampleTip, "expandedGhost")
Stat("records", "Farthest fully observed recovery", "yards", "ex_recovery_farthest", true, sampleTip, "expandedGhost")
table.insert(ns.FASTEST, { key = "ex_retrieval_fastest", label = "Confirmed corpse retrieval (fully observed)" }); added = added + 1
for _, row in ipairs({
    { "Observed fight endings", "ex_fights_observed" },
    { "Observed fights survived", "ex_fights_survived" },
    { "Observed fights ended dead", "ex_fights_ended_dead" },
    { "Fight endings with readable alive/dead state", "ex_fights_liveness_observed" },
    { "Observed fights with an NPC kill", "ex_fights_npc_kill" },
    { "Observed fights with a player kill", "ex_fights_pvp_kill" },
    { "Fight observations interrupted by loading/logout", "ex_fights_incomplete" },
}) do Stat("combat", row[1], "int", row[2], false, "Complete observed combat-event pairs only, except the explicit interrupted-observation counter.") end
Stat("records", "Farthest traveled in an observed fight", "yards", "ex_fight_distance", true, sampleTip)
Stat("records", "Most successful casts in an observed fight", "int", "ex_fight_casts", true)
Stat("records", "Most moving time in an observed fight", "time", "ex_fight_moving", true, sampleTip)
Stat("records", "Most stationary time in an observed fight", "time", "ex_fight_stationary", true, sampleTip)

local function Derived(cat, label, fmt, numerator, denominator, scale, naKey, tip, source)
    local function Value(v, key)
        if type(key) == "function" then return key(v) end
        return C(v, key)
    end
    table.insert(ns.STATS[cat], { label = label, fmt = fmt, naKey = naKey, expandedSource = source,
        tip = tip or "Ratio of the recorded counters in the selected scope. No historical data is invented; a zero denominator displays zero.",
        get = function(v) return Ratio(Value(v, numerator), Value(v, denominator)) * (scale or 1) end })
    added = added + 1
end
Derived("deaths", "Average fully observed recovery distance", "yards", "ex_recovery_full_distance", "ex_recovery_full", 1, nil, nil, "expandedGhost")
Derived("deaths", "Average fully observed recovery time", "time", "ex_recovery_full_time", "ex_recovery_full", 1, nil, nil, "expandedGhost")
Derived("deaths", "Fully observed recovery time spent moving", "pct", "ex_recovery_full_moving", "ex_recovery_full_time", 100, nil, nil, "expandedGhost")
Derived("deaths", "Share of observed time spent recovering", "pct", "ex_recovery_time", "ex_sample_time", 100, nil, nil, "expandedGhost")
Derived("deaths", "Share of observed time alive", "pct", "ex_alive_time", "ex_sample_time", 100)
Derived("travel", "Share of readable movement time moving", "pct", "ex_time_moving", "ex_motion_observed_time", 100)
Derived("travel", "Share of readable movement time stationary", "pct", "ex_time_stationary", "ex_motion_observed_time", 100)
Derived("travel", "Movement observation coverage", "pct", "ex_motion_observed_time", "ex_sample_time", 100, nil,
    "Percentage of accepted online samples with readable speed or positional distance; hidden movement is not treated as stationary.")
Derived("travel", "Average moving speed (yd/s)", "num1", "ex_moving_distance", "ex_time_moving", 1, nil,
    "Distance observed since this version / moving time observed since this version; excludes pre-upgrade distance.")
Derived("combat", "Share of observed combat samples moving", "pct", "ex_time_combat_moving",
    function(v) return C(v, "ex_time_combat_moving") + C(v, "ex_time_combat_stationary") end, 100)
Derived("combat", "Low-health share of readable health time", "pct", "ex_time_low_health", "ex_health_observed_time", 100, nil, nil, "expandedHealth")
Derived("combat", "Full-health share of readable health time", "pct", "ex_time_full_health", "ex_health_observed_time", 100, nil, nil, "expandedHealth")
Derived("combat", "Observed fight survival rate (known outcomes)", "pct", "ex_fights_survived",
    "ex_fights_liveness_observed", 100)
local function Kills(v) return C(v, "kills_npc") + C(v, "kills_pvp") end
for _, spec in ipairs({
    { "combat", "Kills per online hour", Kills },
    { "combat", "Fights per online hour", "fights" },
    { "combat", "Successful casts per online hour", "casts" },
    { "combat", "Interrupts per online hour", "interrupts", "interrupts" },
    { "combat", "Dispels per online hour", "dispels", "dispels" },
    { "deaths", "Deaths per online hour", "deaths" },
    { "adventure", "Quests completed per online hour", "quests_done" },
    { "adventure", "Reputation gained per online hour", "rep_gained" },
    { "adventure", "Herbs gathered per online hour", "gather_herb" },
    { "adventure", "Ore mined per online hour", "gather_mine" },
    { "adventure", "Skinning actions per online hour", "gather_skin" },
    { "adventure", "Fish caught per online hour", "fish" },
    { "adventure", "Items crafted per online hour", "items_crafted" },
    { "wealth", "Items looted per online hour", "items_looted" },
    { "social", "Messages sent per online hour", "chat_sent" },
    { "social", "Whispers received per online hour", "whispers_in" },
}) do Derived(spec[1], spec[2], "num1", spec[3], "time_online", 3600, spec[4]) end
for _, spec in ipairs({
    { "adventure", "XP per completed quest (observed)", "xp_quest", "quests_done", "num1" },
    { "adventure", "Quest XP share", "xp_quest", "xp", "pct" },
    { "adventure", "Kill XP share", "xp_kill", "xp", "pct" },
    { "adventure", "Exploration XP share", "xp_explore", "xp", "pct" },
    { "wealth", "Quest gold per completed quest", "money_quest", "quests_done", "money" },
    { "wealth", "Loot gold per loot window", "money_loot", "loot_windows", "money" },
    { "wealth", "Items per loot window", "items_looted", "loot_windows", "num1" },
    { "wealth", "Average recorded repair bill", "money_repair", "repairs", "money" },
    { "wealth", "Average recorded flight fare", "money_taxi", "flights", "money" },
    { "wealth", "Vendor income per visit", "money_vendor_in", "vendor_visits", "money" },
    { "wealth", "Vendor spending per visit", "money_vendor_out", "vendor_visits", "money" },
    { "wealth", "Auction income per visit", "money_ah_in", "ah_visits", "money" },
    { "wealth", "Auction spending per visit", "money_ah_out", "ah_visits", "money" },
    { "wealth", "Quest share of recorded income", "money_quest", "money_in", "pct" },
    { "wealth", "Loot share of recorded income", "money_loot", "money_in", "pct" },
    { "wealth", "Vendor share of recorded income", "money_vendor_in", "money_in", "pct" },
    { "wealth", "Auction share of recorded income", "money_ah_in", "money_in", "pct" },
    { "wealth", "Mail share of recorded income", "money_mail_in", "money_in", "pct" },
    { "wealth", "Repair share of recorded spending", "money_repair", "money_out", "pct" },
    { "wealth", "Flight share of recorded spending", "money_taxi", "money_out", "pct" },
    { "wealth", "Training share of recorded spending", "money_train", "money_out", "pct" },
    { "wealth", "Auction share of recorded spending", "money_ah_out", "money_out", "pct" },
    { "wealth", "Mail share of recorded spending", "money_mail_out", "money_out", "pct" },
    { "social", "Average typed bytes per public/channel message", "chars_typed",
        function(v) return math.max(0, C(v, "chat_sent") - C(v, "whispers_sent")) end, "num1" },
}) do Derived(spec[1], spec[2], spec[5], spec[3], spec[4], spec[5] == "pct" and 100 or 1) end
for _, spec in ipairs({
    { "Effective healing per recorded heal", "heal_done", "heals", "num1", "heals" },
    { "Overhealing share of total healing", "overheal",
        function(v) return C(v, "heal_done") + C(v, "overheal") end, "pct", "overheal" },
    { "Healing directed to others", "heal_others", "heal_done", "pct", "heal_others" },
    { "Healing directed to yourself", "heal_self", "heal_done", "pct", "heal_self" },
    { "Pet share of recorded damage", "dmg_pet", "dmg_done", "pct", "dmg_pet" },
    { "Player share of recorded damage taken", "dmg_taken_pvp", "dmg_taken", "pct", "dmg_taken_pvp" },
    { "Fights won per fight entered", "fights_won", "fights", "pct" },
    { "Fights without a kill per fight entered", "fights_no_kill", "fights", "pct" },
}) do Derived("combat", spec[1], spec[4], spec[2], spec[3], spec[4] == "pct" and 100 or 1, spec[5]) end
for _, row in ipairs({
    { "ex_recovery_zone_dist", "Ghost recovery distance by zone", "yards" },
    { "ex_recovery_zone_time", "Ghost recovery time by zone", "time" },
    { "ex_retrieval_zones", "Confirmed corpse retrievals by zone", "int" },
    { "ex_recovery_ends", "Observed recovery endings by zone", "int" },
}) do table.insert(ns.LISTS, { id = row[1], name = row[2], fmt = row[3] }); added = added + 1 end

-- Keep a small, local timeline of meaningful lifetime/session bests. Formats
-- are borrowed from the existing record definitions so values remain legible.
local recordInfo = {}
for _, rows in pairs(ns.STATS) do
    for _, stat in ipairs(rows) do
        if type(stat.rec) == "string" then recordInfo[stat.rec] = { label = stat.label, fmt = stat.fmt } end
    end
end
for _, fastest in ipairs(ns.FASTEST) do
    recordInfo[fastest.key] = { label = "Fastest: " .. fastest.label, fmt = "time" }
end
local function RecordTitle(entry)
    local info = recordInfo[entry.k]
    return info and info.label or entry.k:gsub("_", " ")
end
local function RecordValue(entry)
    local info = recordInfo[entry.k]
    return ns.FormatStat({ fmt = info and info.fmt or "int" }, entry.v)
end
function ns.SessionRecordHighlights(history, limit)
    if type(history) ~= "table" then return {} end
    local entries = {}
    for i, entry in ipairs(history) do
        if type(entry) == "table" and type(entry.k) == "string" and type(entry.v) == "number"
            and type(entry.at) == "number" and (entry.d == "max" or entry.d == "min") then
            entries[#entries + 1] = { entry = entry, order = i }
        end
    end
    table.sort(entries, function(a, b)
        if a.entry.at == b.entry.at then return a.order > b.order end
        return a.entry.at > b.entry.at
    end)
    local out = {}
    for i = 1, math.min(limit or 3, #entries) do
        local entry = entries[i].entry
        local text = RecordTitle(entry) .. ": " .. RecordValue(entry)
        if type(entry.w) == "string" and entry.w ~= "" then text = text .. " (" .. entry.w .. ")" end
        out[#out + 1] = text
    end
    return out
end
local function RecordRows(view, session)
    local entries = {}
    local function append(history, scope)
        for i, entry in ipairs(history or {}) do
            if type(entry) == "table" and type(entry.k) == "string" and type(entry.v) == "number"
                and type(entry.at) == "number" and (entry.d == "max" or entry.d == "min") then
                entries[#entries + 1] = { entry = entry, scope = scope, order = i }
            end
        end
    end
    append(view.rh, ns.settings.scope == "account" and "Account" or "Lifetime")
    if session and session ~= view then append(session.rh, "Session") end
    table.sort(entries, function(a, b)
        if a.entry.at == b.entry.at then return a.order > b.order end
        return a.entry.at > b.entry.at
    end)
    local rows = {}
    for i = 1, math.min(100, #entries) do
        local item, entry = entries[i], entries[i].entry
        local name = date("%b %d  %H:%M", entry.at) .. "  ·  " .. RecordTitle(entry)
        if type(entry.w) == "string" and entry.w ~= "" then name = name .. "  ·  " .. entry.w end
        local scope = item.scope
        if type(entry.character) == "string" and entry.character ~= "" then scope = scope .. "  ·  " .. entry.character end
        rows[#rows + 1] = { tostring(i), name, 0, RecordValue(entry), scope }
    end
    return rows
end
table.insert(ns.LISTS, {
    id = "recordhistory", name = "Personal best history",
    count = function(view) return math.min(200, #(view.rh or {})) end,
    rows = RecordRows,
})
local recordsReadyAt = nil
On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin then recordsReadyAt = GetTime() + 5 end
end)
function ns.RecordMoment(entry)
    if not recordsReadyAt or GetTime() < recordsReadyAt
        or not ns.settings or not ns.settings.recordMoments or not ns.loggedIn or not ns.Journal then return end
    ns.Journal("New personal record: " .. RecordTitle(entry) .. " — " .. RecordValue(entry)
        .. (type(entry.w) == "string" and entry.w ~= "" and (" in " .. entry.w) or ""))
end
ns.EXPANDED_STAT_COUNT = added
local previousIsNA = ns.IsNA
function ns.IsNA(stat, value)
    if stat.expandedSource and (value or 0) == 0 and not ns.src[stat.expandedSource] then
        return true, "The required API has not supplied readable state this session. Hidden or missing data is skipped, not guessed."
    end
    return previousIsNA(stat, value)
end

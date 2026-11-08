-- LifeTimeStats - extra trackers: uniques, firsts, timings, falls, corpse runs, silly counters
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local B = ns.Bool -- hidden booleans read as false

local Add, Max, Min, Tally, Unique, First, On = ns.Add, ns.Max, ns.Min, ns.Tally, ns.Unique, ns.First, ns.On
local GetTime = GetTime

local function Zone() local z = ns.GetZone and ns.GetZone() return (z and z ~= "") and z or "?" end
local function Band() local l = UnitLevel("player") or 1 local b = math.floor(l / 10) * 10 return (b == 0 and 1 or b) .. "-" .. (b + 9) end
ns.LevelBand = Band

local function NpcID(guid)
    return guid and guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
end

local function SafeHook(name, fn, tbl)
    if tbl then
        if type(tbl) == "table" and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) end
    elseif type(_G[name]) == "function" then
        hooksecurefunc(name, fn)
    end
end

-- ------------------------------------------------------------ NPCs
local function MetNPC(kind)
    local guid = UnitGUID("npc")
    local id = NpcID(guid)
    if not id then return end
    local name = UnitName("npc") or id
    if Unique("npcs", id) then First("npc", name) end
    Tally("npcnames", name)
    if kind then Unique(kind, id) end
end
On("GOSSIP_SHOW", function() Add("gossip_opens"); MetNPC() end)
On("QUEST_DETAIL", function() MetNPC() end)
On("QUEST_GREETING", function() MetNPC() end)
On("QUEST_PROGRESS", function() MetNPC() end)
On("MERCHANT_SHOW", function() Add("vendor_visits"); MetNPC("vendors") end)
On("TRAINER_SHOW", function() MetNPC("trainers") end)
On("TAXIMAP_OPENED", function() MetNPC("flightmasters") end)
On("BANKFRAME_OPENED", function() Add("bank_visits"); MetNPC("bankers") end)
On("AUCTION_HOUSE_SHOW", function() Add("ah_visits"); MetNPC("auctioneers") end)
On("MAIL_SHOW", function() Add("mailbox_opens") end)

-- ------------------------------------------------------------ places
local function Places()
    local z = GetRealZoneText and GetRealZoneText() or ""
    local sub = GetSubZoneText and GetSubZoneText() or ""
    if z ~= "" then Unique("zones", z) end
    if sub ~= "" then Unique("subzones", z .. ": " .. sub) end
end
On("ZONE_CHANGED", function() Add("subzone_changes"); Places() end)
On("ZONE_CHANGED_INDOORS", function() Add("indoor_changes"); Places() end)
On("ZONE_CHANGED_NEW_AREA", function() Add("zone_changes"); Places() end)
On("PLAYER_UPDATE_RESTING", function() if B(IsResting()) then Add("rest_entered") end end)

-- ------------------------------------------------------------ loot uniques & firsts
On("CHAT_MSG_LOOT", function(_, msg)
    local P = ns.P
    if not P then return end
    local c = ns.Match(P.lootMulti, msg) or ns.Match(P.pushMulti, msg) or ns.Match(P.loot, msg) or ns.Match(P.push, msg)
    if not c then return end
    local link = c[1]
    local id = link and link:match("|Hitem:(%d+)")
    if id then Unique("items", id) end
    local q = ns.LinkQuality(link)
    local name = link and link:match("%[(.-)%]") or "?"
    if q == 2 then First("green", name) elseif q == 3 then First("blue", name) elseif q and q >= 4 then First("epic", name) end
end)
On("LOOT_OPENED", function()
    Add("loot_windows")
    if IsFishingLoot and B(IsFishingLoot()) then First("fish", Zone()) end
end)

-- ------------------------------------------------------------ spells, emotes, people
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit == "player" and spellID then Unique("spells", spellID) end
end)
On("UNIT_SPELLCAST_FAILED", function(_, unit) if unit == "player" then Add("casts_failed") end end)
On("UNIT_SPELLCAST_INTERRUPTED", function(_, unit) if unit == "player" then Add("casts_interrupted") end end)

On("GROUP_ROSTER_UPDATE", function()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n == 0 then return end
    local prefix = (IsInRaid and B(IsInRaid())) and "raid" or "party"
    local me = UnitName("player")
    for i = 1, (prefix == "raid" and n or n - 1) do
        local name, realm = UnitName(prefix .. i)
        if name and name ~= me and name ~= UNKNOWNOBJECT then
            Unique("groupmates", realm and realm ~= "" and (name .. "-" .. realm) or name)
        end
    end
end)
On("DUEL_REQUESTED", function(_, who) if who then Unique("duelers", who) end end)
On("PARTY_INVITE_REQUEST", function() Add("invites_in") end)
-- Money backup: "You loot 3 Copper" lines, used only when your gold is hidden from addons.
On("CHAT_MSG_MONEY", function(_, msg)
    ns.src.moneyChat = (ns.src.moneyChat or 0) + 1
    if not ns.src.moneySecret or ns.IsSecret(msg) or type(msg) ~= "string" then return end
    local g = tonumber(msg:match("(%d+) " .. (GOLD_AMOUNT and GOLD_AMOUNT:match("%%d (.+)") or "Gold"))) or 0
    local s = tonumber(msg:match("(%d+) " .. (SILVER_AMOUNT and SILVER_AMOUNT:match("%%d (.+)") or "Silver"))) or 0
    local cp = tonumber(msg:match("(%d+) " .. (COPPER_AMOUNT and COPPER_AMOUNT:match("%%d (.+)") or "Copper"))) or 0
    local total = g * 10000 + s * 100 + cp
    if total > 0 then Add("money_in", total); Add("money_loot", total); Max("max_loot_money", total) end
end)
On("PLAYER_DEAD", function() ns.src.deathEvents = (ns.src.deathEvents or 0) + 1 end)
-- Backup for emotes: your own "You love Hare." line. English verbs map to emote tokens.
On("CHAT_MSG_TEXT_EMOTE", function(_, msg, sender)
    if ns.IsSecret(msg) or ns.IsSecret(sender) or type(msg) ~= "string" then return end
    local me = UnitName("player")
    if sender and me and sender ~= me and not sender:find("^" .. me .. "%-") then return end
    local verb = msg:match("^You (%a+)")
    if verb and ns.HandleTextEmote then ns.HandleTextEmote(verb) end
end)
On("CHAT_MSG_WHISPER", function() if B(UnitIsAFK("player")) then Add("whispers_afk") end end)
On("PLAYER_TARGET_CHANGED", function() if B(UnitExists("target")) then Add("targets") end end)
On("PLAYER_EQUIPMENT_CHANGED", function() Add("gear_changes") end)
On("LEARNED_SPELL_IN_TAB", function() Add("spells_learned") end)
On("CHARACTER_POINTS_CHANGED", function(_, change) if type(change) == "number" and change < 0 then Add("talents_spent", -change) end end)
On("CHAT_MSG_COMBAT_HONOR_GAIN", function() Add("honor_events") end)

-- ------------------------------------------------------------ system text: rolls, rep, skills, errors
local PX = {}
local function BuildPatterns()
    PX.roll    = ns.MakePattern(RANDOM_ROLL_RESULT)
    PX.repUp   = ns.MakePattern(FACTION_STANDING_INCREASED)
    PX.repDown = ns.MakePattern(FACTION_STANDING_DECREASED)
    PX.skill   = ns.MakePattern(SKILL_RANK_UP)
    PX.transmog = ns.MakePattern(ERR_LEARN_TRANSMOG_S or "%s has been added to your appearance collection.")
    PX.qAccept = ns.MakePattern(ERR_QUEST_ACCEPTED_S or "Quest accepted: %s")
    PX.qDone   = ns.MakePattern(ERR_QUEST_COMPLETE_S or "%s completed.")
end

-- Quest events can be missed; the system lines are a backup (counted only if the event did not fire).
local lastQA, lastQT = -10, -10
On("QUEST_ACCEPTED", function() lastQA = GetTime(); ns.src.questEvents = (ns.src.questEvents or 0) + 1 end)
On("QUEST_TURNED_IN", function() lastQT = GetTime(); ns.src.questEvents = (ns.src.questEvents or 0) + 1 end)

On("CHAT_MSG_SYSTEM", function(_, msg)
    if ns.IsSecret(msg) or type(msg) ~= "string" then return end
    local t = ns.Match(PX.transmog, msg)
    if t then
        local name = t[1] and t[1]:match("%[(.-)%]") or t[1]
        Add("appearances"); Unique("appearances", name); First("appearance", name)
        ns.src.appearances = (ns.src.appearances or 0) + 1
        return
    end
    if ns.Match(PX.qAccept, msg) then
        C_Timer.After(1, function() if GetTime() - lastQA > 2 then Add("quests_accepted"); ns.src.questChat = (ns.src.questChat or 0) + 1 end end)
        return
    end
    local qd = ns.Match(PX.qDone, msg)
    if qd and qd[1] then
        C_Timer.After(1, function()
            if GetTime() - lastQT > 2 then
                Add("quests_done"); ns.First("quest", qd[1]); ns.src.questChat = (ns.src.questChat or 0) + 1
            end
        end)
        return
    end
    local c = ns.Match(PX.roll, msg)
    if c and c[1] == UnitName("player") then
        local v, lo, hi = tonumber(c[2]), tonumber(c[3]), tonumber(c[4])
        if v then
            Add("rolls"); Add("roll_sum", v); Max("max_roll", v)
            if v == hi then Add("rolls_max") end
            if v == lo then Add("rolls_min") end
        end
    end
end)
On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(_, msg)
    if ns.IsSecret(msg) or type(msg) ~= "string" then return end
    local alt = { msg:match("^Reputation with (.+) increased by (%d+)") }
    if alt[1] then Add("rep_gained", tonumber(alt[2]) or 0); Tally("reps", alt[1], tonumber(alt[2]) or 0) return end
    alt = { msg:match("^Reputation with (.+) decreased by (%d+)") }
    if alt[1] then Add("rep_lost", tonumber(alt[2]) or 0) return end
    local c = ns.Match(PX.repUp, msg)
    if c then Add("rep_gained", tonumber(c[2]) or 0); Tally("reps", c[1], tonumber(c[2]) or 0) return end
    c = ns.Match(PX.repDown, msg)
    if c then Add("rep_lost", tonumber(c[2]) or 0) end
end)
On("CHAT_MSG_SKILL", function(_, msg)
    local c = ns.Match(PX.skill, msg)
    if c then Add("skillups"); Tally("skills", c[1]); Max("max_skill", tonumber(c[2]) or 0, c[1]) end
end)
On("UI_ERROR_MESSAGE", function(_, a, b)
    local msg = type(b) == "string" and b or a
    if type(msg) ~= "string" then return end
    Add("ui_errors")
    Tally("uierrors", msg)
    if ERR_INV_FULL and msg == ERR_INV_FULL then Add("bags_full") end
end)

-- ------------------------------------------------------------ combat log extras
local me
On("PLAYER_ENTERING_WORLD", function() me = UnitGUID("player") end)
On("COMBAT_LOG_EVENT_UNFILTERED", function()
    local _, sub, _, sGUID, _, _, _, dGUID, _, _, _, _, a13, _, a15 = CombatLogGetCurrentEventInfo()
    if sub == "SPELL_AURA_APPLIED" and dGUID == me then
        if a15 == "DEBUFF" then Add("debuffs_taken")
        elseif sGUID ~= me then Add("buffs_from_others") end
    elseif sGUID == me then
        if sub == "SPELL_DISPEL" then Add("dispels")
        elseif sub == "SPELL_RESURRECT" then Add("rezzes_cast")
        elseif sub == "SPELL_AURA_APPLIED" and dGUID ~= me and a15 == "BUFF" then Add("buffs_given") end
    end
end)

-- ------------------------------------------------------------ fights
local fightStart, killsAtStart
On("PLAYER_REGEN_DISABLED", function()
    fightStart = GetTime()
    local c = ns.char.c
    killsAtStart = (c.kills_npc or 0) + (c.kills_pvp or 0)
    Add("fights")
end)
On("PLAYER_REGEN_ENABLED", function()
    if not fightStart then return end
    local dur = GetTime() - fightStart
    fightStart = nil
    local c = ns.char.c
    local kills = (c.kills_npc or 0) + (c.kills_pvp or 0) - (killsAtStart or 0)
    Max("max_fight", dur, Zone())
    if kills > 0 and not B(UnitIsDeadOrGhost("player")) then
        Add("fights_won")
        Min("fight_fast", dur, Zone())
        Max("max_fight_kills", kills, Zone())
    end
end)

-- ------------------------------------------------------------ corpse runs
On("PLAYER_DEAD", function() ns.char.meta.deathAt = time() end)
local function OnRelease()
    local m = ns.char.meta
    m.releaseAt = time()
    m.releaseGhostDist = ns.char.c.dist_ghost or 0
    m.releaseZone = Zone()
end
On("PLAYER_UNGHOST", function()
    local m = ns.char.meta
    if not m.releaseAt then return end
    local dur = time() - m.releaseAt
    local dist = (ns.char.c.dist_ghost or 0) - (m.releaseGhostDist or 0)
    m.releaseAt = nil
    if dur <= 0 or dur > 3600 then return end
    Add("corpse_runs")
    Max("max_corpse_time", dur, m.releaseZone)
    Min("corpse_fast", dur, m.releaseZone)
    if dist > 0 then Max("max_corpse_dist", dist, m.releaseZone) end
end)
On("PLAYER_ALIVE", function()
    -- Resurrected at the corpse by another player without releasing
    local m = ns.char.meta
    if m.deathAt and not m.releaseAt and not B(UnitIsDeadOrGhost("player")) then
        Add("rezzed_in_place")
        Max("max_dead_wait", time() - m.deathAt)
        m.deathAt = nil
    end
end)

-- ------------------------------------------------------------ deaths (called from Trackers)
local aliveSince
function ns.OnPlayerDeath(cause)
    if ns.OnStoryDeath then ns.OnStoryDeath(cause) end
    Tally("zonedeaths", Zone())
    Tally("banddeaths", Band())
    local s = ns.session
    if (s.c.deaths or 0) == 1 then Min("first_death_session", GetTime() - s.start, cause) end
    local online = ns.char.c.time_online or 0
    if aliveSince then Max("max_alive", online - aliveSince, cause) end
    aliveSince = online
    if B(IsMounted()) then Add("deaths_mounted") end
    if B(IsSwimming()) then Add("deaths_swimming") end
    if B(UnitIsAFK("player")) then Add("deaths_afk") end
end

-- ------------------------------------------------------------ location
-- Capital city uiMapIDs (Classic): Stormwind, Orgrimmar, Ironforge, Thunder Bluff, Darnassus, Undercity.
local CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
local whereCache, whereZone = {}, nil
function ns.Where()
    local z = GetRealZoneText and GetRealZoneText() or ""
    if z == whereZone then return whereCache end
    whereZone = z
    local w = {}
    local inInst, itype = IsInInstance()
    if inInst and itype ~= "none" then w.instance = z end
    if C_Map and C_Map.GetBestMapForUnit then
        local id = C_Map.GetBestMapForUnit("player")
        local guard = 0
        while id and guard < 8 do
            guard = guard + 1
            local info = C_Map.GetMapInfo(id)
            if not info then break end
            if CAPITALS[id] then w.city = info.name end
            if info.mapType == 2 then w.continent = info.name; break end -- Enum.UIMapType.Continent
            id = info.parentMapID
            if id == 0 then break end
        end
    end
    whereCache = w
    return w
end
On("ZONE_CHANGED_NEW_AREA", function() whereZone = nil end)
On("ZONE_CHANGED", function() whereZone = nil end)
On("PLAYER_ENTERING_WORLD", function() whereZone = nil end)

-- ------------------------------------------------------------ per-frame watcher
-- Watches counters that other trackers bump and derives zone/hour/band tallies,
-- firsts and rolling records from them. Also measures airtime of falls.
local watch = CreateFrame("Frame")
local last = {}
local killTimes = {}
local falling, fallStart, lastAir, landedAt = false, 0, 0, 0
local taxiStart
local formAcc = 0

function ns.LastAirtime()
    if falling then return GetTime() - fallStart end
    if GetTime() - landedAt < 2 then return lastAir end
    return 0
end

local function Delta(key)
    local v = ns.char.c[key] or 0
    local d = v - (last[key] or v)
    last[key] = v
    return d
end

watch:SetScript("OnUpdate", ns.Guard("watcher", function(_, elapsed)
    if not ns.char or not ns.char.c then return end
    local now = GetTime()

    -- airtime
    local f = B(IsFalling()) and not B(UnitOnTaxi("player"))
    if f and not falling then
        falling, fallStart = true, now
    elseif not f and falling then
        falling = false
        lastAir, landedAt = now - fallStart, now
        if lastAir > 0.25 and not B(IsSwimming()) then
            Max("max_airtime", lastAir, Zone())
            Add("airtime", lastAir)
            if lastAir > 3 then Add("big_falls") end
        end
    end

    -- flights
    local taxi = B(UnitOnTaxi("player"))
    if taxi and not taxiStart then taxiStart = now
    elseif not taxi and taxiStart then
        local dur = now - taxiStart
        taxiStart = nil
        if dur > 5 then Min("flight_fast", dur, Zone()); Max("flight_long", dur, Zone()) end
    end

    -- everything below runs at 4 Hz
    formAcc = formAcc + elapsed
    if formAcc < 0.25 then return end
    local dt = formAcc
    formAcc = 0
    do
        if dt < 2 and GetShapeshiftForm then
            local i = GetShapeshiftForm()
            if i and i > 0 and GetShapeshiftFormInfo then
                local _, _, _, spellID = GetShapeshiftFormInfo(i)
                local name = spellID and (GetSpellInfo and GetSpellInfo(spellID)) or ("Form " .. i)
                Tally("formtime", name, dt)
            end
        end
    end

    -- where you are: capital cities, continents, indoors/outdoors, instances
    if dt < 2 then
        local where = ns.Where()
        if where.city then Tally("citytime", where.city, dt) end
        if where.continent then Tally("continenttime", where.continent, dt) end
        if where.instance then Tally("instancetime", where.instance, dt) end
        if IsIndoors and B(IsIndoors()) then Add("time_indoors", dt) else Add("time_outdoors", dt) end
        if IsFlying and B(IsFlying()) then Add("time_flying", dt) end
        if B(UnitAffectingCombat("player")) and where.instance then Add("time_combat_instances", dt) end
    end

    -- derived tallies from counter changes
    local hour = tostring(tonumber(date("%H")))
    local dj = Delta("jumps")
    if dj > 0 then Tally("jumphour", hour, dj); First("jump", Zone()) end
    local dk = Delta("kills_npc") + Delta("kills_pvp")
    if dk > 0 then
        Tally("zonekills", Zone(), dk)
        Tally("bandkills", Band(), dk)
        Tally("killhour", hour, dk)
        for _ = 1, dk do
            killTimes[#killTimes + 1] = now
            if #killTimes > 10 then table.remove(killTimes, 1) end
        end
        if #killTimes == 10 then Min("ten_kills", killTimes[10] - killTimes[1], Zone()) end
    end
    local dq = Delta("quests_done")
    if dq > 0 then Tally("bandquests", Band(), dq) end
    local dm = Delta("mount_ups")
    if dm > 0 then First("mount", Zone()) end
    local dd = Delta("duels_won")
    if dd > 0 then First("duel_won", Zone()) end
    local dx = Delta("deaths")
    if dx > 0 then Tally("deathhour", hour, dx) end
end))

-- ------------------------------------------------------------ hooks
function ns.InstallExtraHooks()
    BuildPatterns()
    SafeHook("RepopMe", OnRelease)
    SafeHook("ToggleBackpack", function() Add("bags_opened") end)
    SafeHook("OpenAllBags", function() Add("bags_opened") end)
    SafeHook("ToggleBag", function() Add("bags_opened") end)
    SafeHook("ToggleCharacter", function() Add("char_opens") end)
    SafeHook("ToggleSpellBook", function() Add("spellbook_opens") end)
    SafeHook("ToggleTalentFrame", function() Add("talent_opens") end)
    SafeHook("ToggleQuestLog", function() Add("questlog_opens") end)
    SafeHook("ToggleFriendsFrame", function() Add("friends_opens") end)
    SafeHook("SitStandOrDescendStart", function() Add("sits") end)
    SafeHook("ToggleAutoRun", function() Add("autoruns") end)
    SafeHook("NotifyInspect", function() Add("inspects") end)
    SafeHook("FollowUnit", function() Add("follows") end)
    SafeHook("AssistUnit", function() Add("assists") end)
    SafeHook("ConfirmBinder", function() Add("hearth_binds"); C_Timer.After(2, function() if ns.char then ns.char.meta._bindCheck = true end end) end)
    SafeHook("StartDuel", function(unit) Add("duels_started"); local n = unit and UnitName(unit); if n then Unique("duelers", n) end end)
    SafeHook("AcceptResurrect", function() Add("rez_accepted") end)
    SafeHook("RetrieveCorpse", function() Add("corpses_retrieved") end)
    -- Typed emotes may go through DoEmote or C_ChatInfo.PerformEmote depending on the
    -- client; both are hooked and the chat line "You love X." is a backup. One emote
    -- is only ever counted once.
    local lastEmoteT = -10
    local function OnEmote(token, target, source)
        if type(token) ~= "string" or ns.IsSecret(token) then return end
        local now = GetTime()
        if source ~= "text" then
            if now - lastEmoteT < 0.05 then return end -- same emote seen by both hooks
            lastEmoteT = now
            ns.src.emoteHook = (ns.src.emoteHook or 0) + 1
        else
            if now - lastEmoteT < 1.5 then return end -- a hook already counted it
            ns.src.emoteText = (ns.src.emoteText or 0) + 1
        end
        token = token:upper()
        Add("emotes")
        Add("emote_" .. token)
        Tally("emotes", token:lower())
        Unique("emotes", token)
        if token == "LOVE" then
            local unit = (type(target) == "string" and target ~= "" and B(UnitExists(target))) and target or "target"
            if ns.IsCritter and ns.IsCritter(unit) then
                local name = UnitName(unit)
                if ns.IsSecret(name) then name = nil end
                Add("critters_loved")
                local g = UnitGUID(unit)
                if g and not ns.IsSecret(g) then ns.lovedGuids = ns.lovedGuids or {}; ns.lovedGuids[g] = true end
                Tally("critters_loved", name or "Critter")
                Unique("critters_loved", name)
                First("critter_loved", name)
            end
        end
    end
    SafeHook("DoEmote", function(t, u) OnEmote(t, u, "hook") end)
    if C_ChatInfo then SafeHook("PerformEmote", function(t, u) OnEmote(t, u, "hook") end, C_ChatInfo) end
    ns.HandleTextEmote = function(token) OnEmote(token, nil, "text") end
    aliveSince = ns.char and ns.char.c.time_online or 0
end

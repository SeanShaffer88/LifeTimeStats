-- LifeTimeStats - event trackers
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local B = ns.Bool -- hidden booleans read as false

local Add, Max, Tally, On = ns.Add, ns.Max, ns.Tally, ns.On
local GetTime, UnitGUID = GetTime, UnitGUID
local band = bit.band

-- Combat log flag constants (with fallbacks if the globals are missing).
local MINE    = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x00000040
local T_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
local T_PET   = COMBATLOG_OBJECT_TYPE_PET or 0x00001000
local T_GUARD = COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000

local me                  -- player GUID
local curType             -- "party" | "raid" | "pvp" | "arena" | nil
local zone = ""
local lastMoney
local lastXP, lastXPMax, lastLevel
local wasMounted, wasAFK, lastForm
local isDead = false
local streak = 0
local critRun = 0
local lastHit            -- { t, name, player, env }
local damaged = {}       -- guid -> time we last damaged it
local bossGUIDs = {}     -- guid -> true (fallback boss detection)
local lastEncounterEnd = 0
local ctx = {}           -- open UI contexts: merchant, mail, taxi, ah, trainer, loot, trade
ns.ctx = ctx
local repairBase

-- ------------------------------------------------------------ helpers
local function SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if type(info) == "table" then return info.name end
    end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

-- Converts a Blizzard format string (e.g. "You receive loot: %sx%d.") into a
-- Lua pattern plus the argument order (supports %1$s style positions).
local function MakePattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local order, n = {}, 0
    local s = fmt:gsub("%%(%d?)%$?([sd])", function(idx, kind)
        n = n + 1
        order[n] = tonumber(idx) or n
        return kind == "d" and "\001" or "\002"
    end)
    s = s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    s = s:gsub("\001", "(%%d+)")
    s = s:gsub("\002", "(.-)")
    return { pat = "^" .. s .. "$", order = order }
end
ns.MakePattern = MakePattern

local function Match(p, msg)
    if not p or type(msg) ~= "string" then return nil end
    local caps = { msg:match(p.pat) }
    if #caps == 0 then return nil end
    local out = {}
    for i = 1, #caps do out[p.order[i] or i] = caps[i] end
    return out
end
ns.Match = Match

local QUALITY_BY_COLOR = {
    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2, ["0070dd"] = 3,
    ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6,
}
local function LinkQuality(link)
    if type(link) ~= "string" then return nil end
    local iq = link:match("|cnIQ(%d):")
    if iq then return tonumber(iq) end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
    if hex then return QUALITY_BY_COLOR[hex:lower()] end
    local id = link:match("|Hitem:(%d+)")
    if id and C_Item and C_Item.GetItemQualityByID then
        local ok, q = pcall(C_Item.GetItemQualityByID, tonumber(id))
        if ok and type(q) == "number" then return q end
    end
    if id and GetItemInfo then
        local ok, _, _, q = pcall(GetItemInfo, tonumber(id))
        if ok and type(q) == "number" then return q end
    end
end
ns.LinkQuality = LinkQuality

local function IsMine(guid, flags)
    if guid == me then return true end
    if not ns.settings.countPet or not flags then return false end
    return band(flags, MINE) ~= 0 and band(flags, T_PET + T_GUARD) ~= 0
end

-- ------------------------------------------------------------ patterns
local P = {}
local function BuildPatterns()
    P.lootMulti    = MakePattern(LOOT_ITEM_SELF_MULTIPLE)
    P.loot         = MakePattern(LOOT_ITEM_SELF)
    P.pushMulti    = MakePattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE)
    P.push         = MakePattern(LOOT_ITEM_PUSHED_SELF)
    P.createMulti  = MakePattern(LOOT_ITEM_CREATED_SELF_MULTIPLE)
    P.create       = MakePattern(LOOT_ITEM_CREATED_SELF)
    P.duelKO       = MakePattern(DUEL_WINNER_KNOCKOUT)
    P.duelFled     = MakePattern(DUEL_WINNER_RETREAT)
    P.tradeDone    = MakePattern(ERR_TRADE_COMPLETE)
    P.instReset    = MakePattern(INSTANCE_RESET_SUCCESS)
    P.exploredXP   = MakePattern(ERR_ZONE_EXPLORED_XP)
    P.explored     = MakePattern(ERR_ZONE_EXPLORED)
end

-- Spell names that identify special casts (localised by the client).
local S = {}
local function BuildSpellNames()
    S.hearth = SpellName(8690)   -- Hearthstone
    S.herb   = SpellName(2366)   -- Herb Gathering
    S.mine   = SpellName(2575)   -- Mining
    S.skin   = SpellName(8613)   -- Skinning
    S.food   = SpellName(433)    -- Food
    S.drink  = SpellName(430)    -- Drink
    S.aid    = SpellName(746)    -- First Aid (bandage channel)
end

-- ------------------------------------------------------------ instances
local function UpdateInstance()
    local ch = ns.char
    local inInst, itype = IsInInstance()
    if not inInst or itype == "none" then
        curType = nil
        if ch.run and not ch.run.left then ch.run.left = time() end
        return
    end
    if itype == "arena" then itype = "pvp" end
    curType = itype
    local name, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local run, now = ch.run, time()
    local same = run and run.name == name and run.mapID == mapID
        and (not run.left or (itype ~= "pvp" and now - run.left < 1800))
    if same then
        run.left = nil
        return
    end
    ns.FinalizeRun(run)
    ch.run = { name = name, mapID = mapID, type = itype, start = now, bosses = 0 }
    if ns.DungeonRunStart then pcall(ns.DungeonRunStart, ch.run) end
    if itype == "party" then ns.First("dungeon", name) elseif itype == "raid" then ns.First("raid", name) end
    ns.Unique("instances", name)
    if itype == "party" or itype == "raid" or itype == "pvp" then
        Add("runs_" .. itype)
    end
    Tally("instances", name)
end

-- Fastest clear per instance: time from entering to the last boss of the run.
-- Only runs that killed at least as many bosses as your best run there qualify.
function ns.FinalizeRun(run)
    local ch = ns.char
    if not run or run.finalized or not run.lastBoss then return end
    if run.type ~= "party" and run.type ~= "raid" then return end
    run.finalized = true
    local best = ch.t.instbosses and ch.t.instbosses[run.name] or 0
    if run.bosses < best then return end
    ch.t.instbosses = ch.t.instbosses or {}
    ch.t.instbosses[run.name] = run.bosses
    local key = "run:" .. run.name
    if run.bosses > best then ch.f[key] = nil end
    ns.Min(key, run.lastBoss - run.start, run.bosses .. (run.bosses == 1 and " boss" or " bosses"))
end

local function BossKilled(name)
    name = name or "?"
    local run = ns.char.run
    local kind = run and not run.left and run.type or "world"
    if kind ~= "party" and kind ~= "raid" then kind = "world" end
    Add("boss_kills")
    Add("boss_kills_" .. kind)
    Tally("bosses", name)
    Tally("bosses_" .. kind, name)
    ns.Unique("bosses_" .. kind, name)
    ns.First("boss", name)
    ns.lastBossKill = { name = name, t = GetTime(), kind = kind }
    if ns.OnBossKill then ns.OnBossKill(name, kind) end
    if ns.DungeonBossKill then pcall(ns.DungeonBossKill, name, kind) end
    if run and kind ~= "world" then
        run.bosses = (run.bosses or 0) + 1
        run.lastBoss = time()
        if run.bosses == 1 and run.type == "party" then Add("runs_party_boss") end
        if run.bosses == 1 and run.type == "raid" then Add("runs_raid_boss") end
        if run.type == "raid" and RequestRaidInfo then
            C_Timer.After(3, RequestRaidInfo)
        end
    end
end

On("ENCOUNTER_END", function(_, _, name, _, _, success)
    if success ~= 1 and success ~= true then return end
    lastEncounterEnd = GetTime()
    BossKilled(name)
end)

On("INSTANCE_ENCOUNTER_ENGAGE_UNIT", function()
    for i = 1, 5 do
        local g = UnitGUID("boss" .. i)
        if g then bossGUIDs[g] = true end
    end
end)

On("PLAYER_TARGET_CHANGED", function()
    if B(UnitExists("target")) and UnitClassification("target") == "worldboss" then
        local g = UnitGUID("target")
        if g then bossGUIDs[g] = true end
    end
end)

On("UPDATE_INSTANCE_INFO", function()
    local run = ns.char and ns.char.run
    if not run or run.type ~= "raid" or run.cleared or not GetNumSavedInstances then return end
    for i = 1, GetNumSavedInstances() do
        local n, _, _, _, _, _, _, isRaid, _, _, numEnc, prog = GetSavedInstanceInfo(i)
        if isRaid and n == run.name and numEnc and numEnc > 0 and prog == numEnc then
            run.cleared = true
            Add("raid_clears")
            ns.Min("raidclear:" .. run.name, (run.lastBoss or time()) - run.start, "full clear")
            return
        end
    end
end)

local function CheckBattleground()
    local run = ns.char and ns.char.run
    if not run or run.type ~= "pvp" or run.decided or not GetBattlefieldWinner then return end
    local w = GetBattlefieldWinner()
    if w == nil then return end
    run.decided = true
    local fac = UnitFactionGroup("player")
    if (w == 0 and fac == "Horde") or (w == 1 and fac == "Alliance") then
        Add("bg_won")
        ns.Min("bg_win", time() - run.start, run.name)
        ns.First("bg_win", run.name)
        if ns.OnBattlegroundEnd then pcall(ns.OnBattlegroundEnd, run, true) end
    else
        Add("bg_lost")
        if ns.OnBattlegroundEnd then pcall(ns.OnBattlegroundEnd, run, false) end
    end
end
On("UPDATE_BATTLEFIELD_STATUS", CheckBattleground)
On("UPDATE_BATTLEFIELD_SCORE", CheckBattleground)

-- ------------------------------------------------------------ combat log
local function OnKill(guid, name, flags)
    if ns.IsSecret(name) then name = nil end
    if ns.IsSecret(guid) or type(guid) ~= "string" then guid = "Creature-unknown" end
    if guid:find("^Player") then
        if flags and band(flags, HOSTILE) == 0 then return end
        Add("kills_pvp")
        local cls = GetPlayerInfoByGUID and GetPlayerInfoByGUID(guid)
        Tally("players", cls or "Unknown")
        ns.Unique("pvp_victims", guid)
        ns.First("pvp_kill", name)
    else
        Add("kills_npc")
        Tally("creatures", name or "?")
        local npcID = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)")
        ns.Unique("creatures", npcID or name)
        ns.First("kill", name)
    end
    streak = streak + 1
    Max("max_streak", streak)
    local s = ns.session.c
    Max("max_session_kills", (s.kills_npc or 0) + (s.kills_pvp or 0))
end

ns.RecordKill = function(guid, name, flags) OnKill(guid, name, flags) end

local function HandleCLEU()
    if type(CombatLogGetCurrentEventInfo) ~= "function" then return end
    local ok0, ts0 = pcall(CombatLogGetCurrentEventInfo)
    if not ok0 or ts0 == nil then return end
    ns.cleuSeen = GetTime()
    ns.src.cleu = (ns.src.cleu or 0) + 1
    local _, sub, _, sGUID, sName, sFlags, _, dGUID, dName, dFlags, _, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21 = CombatLogGetCurrentEventInfo()
    local fromMe = IsMine(sGUID, sFlags)
    local toMe = dGUID == me

    if sub == "UNIT_DIED" then
        if toMe or not dGUID then return end
        if bossGUIDs[dGUID] then
            bossGUIDs[dGUID] = nil
            local n = dName
            C_Timer.After(5, function()
                if GetTime() - lastEncounterEnd > 10 then BossKilled(n) end
            end)
        end
        if damaged[dGUID] and GetTime() - damaged[dGUID] < 180 then
            damaged[dGUID] = nil
            OnKill(dGUID, dName, dFlags)
        end
        return
    end

    if not fromMe and not toMe then return end

    local amount, crit, overheal, spellName
    if sub == "SWING_DAMAGE" then
        amount, crit, spellName = a12, a18, "Melee"
    elseif sub == "SPELL_DAMAGE" or sub == "RANGE_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "DAMAGE_SHIELD" then
        amount, crit, spellName = a15, a21, a13
    elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        local eff = (a15 or 0) - (a16 or 0)
        if fromMe then
            Add("heal_done", eff)
            Add("overheal", a16 or 0)
            Add("heals")
            if a18 then Add("heal_crits"); Max("max_heal_crit", eff, a13) end
            Max("max_heal", eff, a13)
            if toMe then Add("heal_self", eff) elseif eff > 0 then Add("heal_others", eff) end
        end
        if toMe then Add("heal_taken", eff); Max("max_heal_taken", eff, sName) end
        return
    elseif sub == "ENVIRONMENTAL_DAMAGE" then
        if toMe then
            local env, amt = a12, a13 or 0
            Add("dmg_taken", amt)
            local E = tostring(env):upper()
            Add("env_hits")
            Add("dmg_env_" .. E:lower(), amt)
            if E == "FALLING" then
                Add("falls")
                Add("dmg_fall", amt)
                Max("max_fall", amt)
                local mx = UnitHealthMax("player")
                local hpPct = (mx and not ns.IsSecret(mx) and mx > 0) and amt / mx * 100 or 0
                C_Timer.After(1.5, function()
                    if not B(UnitIsDeadOrGhost("player")) then
                        Max("max_fall_survived", amt)
                        Max("max_fall_survived_pct", hpPct)
                        Add("falls_survived")
                    end
                end)
            end
            lastHit = { t = GetTime(), env = E, amt = amt }
        end
        return
    elseif sub == "SWING_MISSED" or sub == "RANGE_MISSED" or sub == "SPELL_MISSED" then
        local missType = tostring((sub == "SWING_MISSED") and a12 or a15):lower()
        local real = missType ~= "absorb" and missType ~= "immune"
        if fromMe and not toMe then
            Add("out_" .. missType)
            if real then Add("misses_out") end
            critRun = 0
        end
        if toMe and not fromMe then
            Add("in_" .. missType)
            if real then Add("avoided_in") end
        end
        return
    elseif sub == "SPELL_INTERRUPT" then
        if fromMe then Add("interrupts") end
        return
    elseif sub == "PARTY_KILL" then
        if fromMe then Add("killing_blows") end
        return
    else
        return
    end

    amount = amount or 0
    if fromMe and not toMe then
        Add("dmg_done", amount)
        Add("hits")
        if crit then
            Add("crits")
            Max("max_crit", amount, spellName)
            critRun = critRun + 1
            Max("max_crit_streak", critRun)
        else
            critRun = 0
        end
        if sub == "SWING_DAMAGE" then
            Add("melee_hits")
            if a19 then Add("glancing_out") end
        elseif sub == "RANGE_DAMAGE" then Add("ranged_hits")
        elseif sub == "SPELL_PERIODIC_DAMAGE" then Add("dot_ticks")
        else Add("spell_hits") end
        Max("max_hit", amount, spellName)
        if dGUID then damaged[dGUID] = GetTime() end
    elseif toMe then
        Add("dmg_taken", amount)
        Add("hits_taken")
        if sub == "SWING_DAMAGE" then
            if a18 then Add("crits_taken"); Max("max_crit_taken", amount, sName) end
            if a20 then Add("crushing_in") end
            if (a16 or 0) > 0 then Add("blocks_partial_in") end
        elseif a21 then
            Add("crits_taken"); Max("max_crit_taken", amount, sName)
        end
        if sFlags and band(sFlags, T_PLAYER) ~= 0 then Add("dmg_taken_pvp", amount) end
        Max("max_hit_taken", amount, sName)
        lastHit = { t = GetTime(), name = sName, player = sFlags and band(sFlags, T_PLAYER) ~= 0 }
    end
end
On("COMBAT_LOG_EVENT_UNFILTERED", HandleCLEU)

-- ------------------------------------------------------------ deaths
On("PLAYER_DEAD", function()
    if isDead then return end
    isDead = true
    Add("deaths")
    streak = 0
    if curType == "party" then Add("deaths_party") elseif curType == "raid" then Add("deaths_raid")
    elseif curType == "pvp" or curType == "arena" then Add("deaths_bg") else Add("deaths_world") end
    Max("max_session_deaths", ns.session.c.deaths or 0)
    local h0 = lastHit
    if (not h0 or GetTime() - h0.t >= 5) and ns.GuessDeathCause then h0 = ns.GuessDeathCause() end
    if h0 and h0.env == "FALLING" then ns.src.fatalFall = true end
    -- Give the game a moment to write its death recap, which names the killing blow.
    C_Timer.After(0.7, function()
        local h = h0
        local r = ns.RecapCause and ns.RecapCause()
        if r then h = r end
        if h then h.t = GetTime() end
        ns.ClassifyDeath(h)
    end)
end)

function ns.ClassifyDeath(h)
    local cause = "Unknown"
    if h then cause = h.env and (h.env:sub(1, 1) .. h.env:sub(2):lower()) or h.name or cause end
    ns.First("death", cause)
    if ns.OnPlayerDeath then ns.OnPlayerDeath(cause) end
    if h then
        if h.env then
            if h.env == "FALLING" then
                Add("deaths_fall"); Tally("killers", "Falling")
                ns.src.fatalFall = true
                Max("max_fall_fatal", h.amt or 0)
                if ns.LastAirtime then Max("max_airtime_fatal", ns.LastAirtime()) end
            elseif h.env == "DROWNING" then Add("deaths_drown"); Tally("killers", "Drowning")
            elseif h.env == "FATIGUE" then Add("deaths_fatigue"); Tally("killers", "Fatigue")
            elseif h.env == "LAVA" or h.env == "FIRE" then Add("deaths_lava"); Tally("killers", h.env == "LAVA" and "Lava" or "Fire")
            elseif h.env == "SLIME" then Add("deaths_slime"); Tally("killers", "Slime")
            else Tally("killers", h.env:sub(1, 1) .. h.env:sub(2):lower()) end
        elseif h.player then
            Add("deaths_pvp"); Tally("killers", h.name or "A player")
        else
            Add("deaths_npc"); Tally("killers", h.name or "Unknown")
        end
        if h.spell then Tally("killedwith", h.spell) end
    else
        Add("deaths_npc"); Tally("killers", "Unknown")
    end
end
local function Alive() if not B(UnitIsDeadOrGhost("player")) then isDead = false end end
On("PLAYER_ALIVE", Alive)
On("PLAYER_UNGHOST", Alive)
On("RESURRECT_REQUEST", function() Add("rez_offered") end)

-- ------------------------------------------------------------ quests & xp
local function QuestTitle(id)
    local t
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then t = C_QuestLog.GetTitleForQuestID(id) end
    if not t and C_QuestLog and C_QuestLog.GetQuestInfo then t = C_QuestLog.GetQuestInfo(id) end
    return t or ("Quest #" .. tostring(id))
end
On("QUEST_ACCEPTED", function(_, a, b)
    Add("quests_accepted")
    local qid = (type(b) == "number" and b > 0) and b or a
    if type(qid) == "number" then
        ns.char.qa[qid] = time()
        ns.char.qaTitle = ns.char.qaTitle or {}
    end
end)
On("QUEST_TURNED_IN", function(_, qid, xp, money)
    Add("quests_done")
    if type(qid) == "number" then
        local title = QuestTitle(qid)
        ns.Unique("quests", qid)
        ns.First("quest", title)
        local t0 = ns.char.qa[qid]
        if t0 then
            local dur = time() - t0
            ns.Min("quest_fast", math.max(dur, 1), title)
            Max("quest_slow", dur, title)
            ns.char.qa[qid] = nil
        end
    end
    if type(xp) == "number" then Add("xp_quest", xp) end
    if type(money) == "number" then Add("money_quest", money) end
end)

local function XPUpdate()
    local xp, mx, lvl = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if lastXP and lastLevel then
        local gained
        if lvl > lastLevel then
            gained = (lastXPMax - lastXP) + xp
            if ns.LevelUp then ns.LevelUp(lvl) end
        elseif lvl == lastLevel then gained = xp - lastXP end
        if gained and gained > 0 then Add("xp", gained) end
    end
    lastXP, lastXPMax, lastLevel = xp, mx, lvl
end
On("PLAYER_XP_UPDATE", XPUpdate)
local function LevelUp(level)
    level = tonumber(level)
    local m = ns.char and ns.char.meta
    if not level or not m then return end
    if (m.lastLevelCounted or 0) >= level then return end
    m.lastLevelCounted = level
    Add("levels")
    Max("max_level", level)
    ns.First("levelup", "Level " .. tostring(level))
    local m, online = ns.char.meta, ns.char.c.time_online or 0
    local dur
    if m.levelMark and m.levelMarkLevel == (level - 1) then
        dur = online - m.levelMark
        local label = (level - 1) .. " > " .. level
        ns.Min("level_fast", dur, label)
        Max("level_slow", dur, label)
        ns.char.t.leveltime = ns.char.t.leveltime or {}
        ns.char.t.leveltime["Level " .. label] = dur
    end
    m.levelMark, m.levelMarkLevel = online, level
    if ns.LevelSnapshot then ns.LevelSnapshot(level) end
    if ns.OnLevelUp then ns.OnLevelUp(level, dur, online) end
end
On("PLAYER_LEVEL_UP", function(_, level) LevelUp(level) end)
On("PLAYER_LEVEL_CHANGED", function(_, _, newLevel) LevelUp(newLevel) end)
ns.LevelUp = function(l) LevelUp(l) end

-- ------------------------------------------------------------ money & loot
local function SetCtx(key, val) return function() ctx[key] = val end end
On("MERCHANT_SHOW", function()
    ctx.merchant = true
    repairBase = GetRepairAllCost and GetRepairAllCost() or 0
end)
On("MERCHANT_CLOSED", SetCtx("merchant", false))
On("MAIL_SHOW", SetCtx("mail", true))
On("MAIL_CLOSED", SetCtx("mail", false))
On("TAXIMAP_OPENED", SetCtx("taxi", true))
On("TAXIMAP_CLOSED", SetCtx("taxi", false))
On("AUCTION_HOUSE_SHOW", SetCtx("ah", true))
On("AUCTION_HOUSE_CLOSED", SetCtx("ah", false))
On("TRAINER_SHOW", function() ctx.trainer = true; Add("trainer_visits") end)
On("TRAINER_CLOSED", SetCtx("trainer", false))
On("LOOT_OPENED", function()
    ctx.loot = true
    if IsFishingLoot and B(IsFishingLoot()) then Add("fish") end
end)
On("LOOT_CLOSED", SetCtx("loot", false))

On("UPDATE_INVENTORY_DURABILITY", function()
    if not ctx.merchant or not GetRepairAllCost then return end
    local cost = GetRepairAllCost() or 0
    if repairBase and cost < repairBase then
        Add("money_repair", repairBase - cost)
        Add("repairs")
    end
    repairBase = cost
end)

On("PLAYER_MONEY", function()
    local m = GetMoney()
    ns.src.moneyEvents = (ns.src.moneyEvents or 0) + 1
    if ns.IsSecret(m) or type(m) ~= "number" then ns.src.moneySecret = true; return end
    if lastMoney then
        local d = m - lastMoney
        if d > 0 then
            Add("money_in", d)
            if ctx.loot then Add("money_loot", d); Max("max_loot_money", d)
            elseif ctx.merchant then Add("money_vendor_in", d)
            elseif ctx.ah then Add("money_ah_in", d)
            elseif ctx.mail then Add("money_mail_in", d) end
        elseif d < 0 then
            d = -d
            Add("money_out", d)
            if ctx.taxi then Add("money_taxi", d)
            elseif ctx.trainer then Add("money_train", d)
            elseif ctx.merchant then Add("money_vendor_out", d)
            elseif ctx.ah then Add("money_ah_out", d)
            elseif ctx.mail then Add("money_mail_out", d) end
        end
    end
    lastMoney = m
    Max("max_money", m)
end)

On("CHAT_MSG_LOOT", function(_, msg)
    local c = Match(P.lootMulti, msg) or Match(P.pushMulti, msg)
    local qty
    if c then qty = tonumber(c[2]) or 1
    else
        c = Match(P.loot, msg) or Match(P.push, msg)
        qty = 1
    end
    if c then
        local link = c[1]
        Add("items_looted", qty)
        ns.src.loot = (ns.src.loot or 0) + 1
        local q = LinkQuality(link)
        if q then ns.src.quality = true end
        local g = ns.lastGather
        if g and GetTime() - g[2] < 8 then Tally(g[1], (link:match("%[(.-)%]")) or link, qty) end
        if q then
            Add("loot_q" .. q, qty)
            if q >= 4 then Tally("epics", link:match("%[(.-)%]") or link, qty) end
        end
        return
    end
    c = Match(P.createMulti, msg)
    local qty2 = c and (tonumber(c[2]) or 1) or 1
    if not c then c = Match(P.create, msg) end
    if c then
        local name = (c[1] and c[1]:match("%[(.-)%]")) or c[1] or "?"
        Add("items_crafted", qty2)
        Tally("created", name, qty2)
        if name:find("^Conjured") then Add("conjured", qty2) end
    end
end)

On("TRADE_SHOW", SetCtx("trade", true))
On("TRADE_CLOSED", SetCtx("trade", false))
On("MAIL_SEND_SUCCESS", function() Add("mails_sent") end)

-- ------------------------------------------------------------ system messages
On("CHAT_MSG_SYSTEM", function(_, msg)
    local myName = UnitName("player")
    local c = Match(P.duelKO, msg) or Match(P.duelFled, msg)
    if c then
        if c[1] == myName then Add("duels_won") elseif c[2] == myName then Add("duels_lost") end
        return
    end
    if Match(P.tradeDone, msg) then Add("trades") return end
    c = Match(P.instReset, msg)
    if c then
        local run = ns.char.run
        if run and run.left and run.name == c[1] then ns.FinalizeRun(run); ns.char.run = nil end
        return
    end
    if Match(P.exploredXP, msg) or Match(P.explored, msg) then Add("zones_discovered") end
end)

On("DUEL_REQUESTED", function() Add("duels_asked") end)

-- ------------------------------------------------------------ spells
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" then return end
    local name = SpellName(spellID)
    if not name or ns.IsSecret(name) or name:match("^%u+$") then return end
    Add("casts")
    Tally("spells", name)
    if name == S.hearth then Add("hearths")
    elseif name == S.herb then Add("gather_herb"); ns.lastGather = { "herbs", GetTime() }
    elseif name == S.mine then Add("gather_mine"); ns.lastGather = { "ores", GetTime() }
    elseif name == S.skin then Add("gather_skin")
    elseif name == S.food then Add("food")
    elseif name == S.drink then Add("drink")
    elseif name == S.aid then Add("bandages") end
end)

On("UPDATE_SHAPESHIFT_FORM", function()
    if not GetShapeshiftForm then return end
    local f = GetShapeshiftForm()
    if lastForm ~= nil and f ~= lastForm then Add("shapeshifts") end
    lastForm = f
end)

-- ------------------------------------------------------------ social
-- incoming whispers: Social.lua
On("GROUP_JOINED", function() Add("groups_joined") end)
On("SCREENSHOT_SUCCEEDED", function() Add("screenshots") end)
On("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit ~= "player" then return end
    local afk = B(UnitIsAFK("player")) and true or false
    if afk and not wasAFK then Add("afk_count") end
    wasAFK = afk
end)

local function SafeHook(tbl, name, fn)
    if type(tbl) == "string" then
        name, fn = tbl, name
        if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
    elseif type(tbl) == "table" and type(tbl[name]) == "function" then
        hooksecurefunc(tbl, name, fn)
    end
end

local function InstallHooks()
    -- Chat you send is counted from chat events in Social.lua (hooks miss typed chat).
    SafeHook("RepopMe", function() Add("releases") end)
    SafeHook("DeleteCursorItem", function() Add("items_destroyed") end)
    SafeHook("TakeTaxiNode", function() Add("flights") end)
    SafeHook("AbandonQuest", function() Add("quests_abandoned") end)
    if C_QuestLog and type(C_QuestLog.AbandonQuest) == "function" then
        SafeHook(C_QuestLog, "AbandonQuest", function() Add("quests_abandoned") end)
    end
    if WorldMapFrame and WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function() Add("map_opens") end)
    end

    -- Jumps: count only presses that actually lift you off the ground.
    local lastJump, pending = 0, false
    SafeHook("JumpOrAscendStart", function()
        local now = GetTime()
        if pending or now - lastJump < 0.35 then return end
        if B(IsFalling()) or B(IsSwimming()) or B(UnitOnTaxi("player")) then return end
        if IsFlying and B(IsFlying()) then return end
        pending = true
        C_Timer.After(0.15, function()
            pending = false
            if B(IsFalling()) then
                lastJump = GetTime()
                Add("jumps")
            end
        end)
    end)
end

-- ------------------------------------------------------------ played time
local suppressPlayed = false
-- Hides the automatic /played chat lines that our login request would print.
-- A /played typed by the player is shown as normal (the flag clears after 1 s).
local function Wrap(orig)
    return function(...)
        if suppressPlayed then return end
        return orig(...)
    end
end
local function HookPlayedDisplay()
    if type(ChatFrame_DisplayTimePlayed) == "function" then
        ChatFrame_DisplayTimePlayed = Wrap(ChatFrame_DisplayTimePlayed)
    end
    if ChatFrameUtil and type(ChatFrameUtil.DisplayTimePlayed) == "function" then
        ChatFrameUtil.DisplayTimePlayed = Wrap(ChatFrameUtil.DisplayTimePlayed)
    end
end
On("TIME_PLAYED_MSG", function(_, total)
    if type(total) == "number" and ns.char then
        ns.char.c.played_server = total
    end
    C_Timer.After(1, function() suppressPlayed = false end)
end)

-- ------------------------------------------------------------ movement
-- Speed can be a secret value on Forever (often in combat). Then distance comes from
-- the change in your world position, if that is readable; otherwise the tick is skipped.
local lastX, lastY, lastInst
local function MoveTick(dt)
    local S = ns.IsSecret
    local x, y, inst
    if UnitPosition then
        local ok, py, px, _, pinst = pcall(UnitPosition, "player")
        if ok and py and not S(py) and not S(px) and not S(pinst) then x, y, inst = px, py, pinst end
    end
    local d, speed
    local sp = GetUnitSpeed("player")
    if sp ~= nil and not S(sp) then
        speed = sp
        if sp > 0 then d = sp * dt end
        ns.src.speedReadable = true
    elseif x and lastX and inst == lastInst then
        local dx, dy = x - lastX, y - lastY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0.05 and dist / dt < 60 then -- ignore teleports, hearths, loading jumps
            d, speed = dist, dist / dt
            ns.src.posDistance = (ns.src.posDistance or 0) + 1
        end
    else
        ns.src.moveSkipped = (ns.src.moveSkipped or 0) + 1
    end
    lastX, lastY, lastInst = x, y, inst
    return d, speed
end

-- ------------------------------------------------------------ ticker
local ticker = CreateFrame("Frame")
local acc, slow = 0, 0
ticker:SetScript("OnUpdate", ns.Guard("ticker", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    local dt = acc
    acc = 0
    if dt > 2 or not ns.char then return end -- loading hitch or not ready

    if isDead and not B(UnitIsDeadOrGhost("player")) then isDead = false end
    local c = ns.char.c
    c.played_server = (c.played_server or 0) + dt -- server value, refreshed at login
    Add("time_online", dt)
    if B(UnitAffectingCombat("player")) then Add("time_combat", dt) end
    if B(UnitIsAFK("player")) then Add("time_afk", dt) end
    if B(UnitIsDeadOrGhost("player")) then Add("time_dead", dt) end
    if B(IsResting()) then Add("time_rest", dt) end
    if curType then Add("time_" .. curType, dt) end
    if zone ~= "" then Tally("zonetime", zone, dt) end

    local taxi = B(UnitOnTaxi("player"))
    local mounted = B(IsMounted())
    local swimming = B(IsSwimming())
    if mounted and not wasMounted then Add("mount_ups") end
    wasMounted = mounted
    if taxi then Add("time_taxi", dt)
    elseif mounted then Add("time_mounted", dt) end
    if swimming then Add("time_swim", dt) end

    local d, speed = MoveTick(dt)
    if d and d > 0 then
        Add("dist_total", d)
        if taxi then Add("dist_taxi", d)
        elseif B(UnitIsDeadOrGhost("player")) then Add("dist_ghost", d)
        elseif swimming then Add("dist_swim", d)
        elseif mounted then Add("dist_mount", d)
        else Add("dist_foot", d) end
        if not taxi and speed then Max("max_speed", speed) end
        if zone ~= "" then Tally("zonedist", zone, d) end
        local w = ns.Where and ns.Where()
        if w and w.continent then Tally("continentdist", w.continent, d) end
    end

    slow = slow + dt
    if slow >= 30 then
        slow = 0
        Max("max_session", GetTime() - ns.session.start)
        local now = GetTime()
        for g, t in pairs(damaged) do
            if now - t > 180 then damaged[g] = nil end
        end
    end
end))

-- ------------------------------------------------------------ login
On("ZONE_CHANGED_NEW_AREA", function()
    zone = GetRealZoneText() or ""
    UpdateInstance()
end)

On("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    me = UnitGUID("player")
    ns.playerGUID = me
    if not S.hearth then BuildSpellNames() end
    zone = GetRealZoneText() or ""
    if isLogin then
        Add("logins")
        isDead = B(UnitIsDeadOrGhost("player")) and true or false
        wasMounted = B(IsMounted())
        wasAFK = B(UnitIsAFK("player")) and true or false
        if RequestTimePlayed then
            suppressPlayed = true
            RequestTimePlayed()
        end
    elseif isReload then
        Add("reloads")
        isDead = B(UnitIsDeadOrGhost("player")) and true or false
    else
        Add("loading_screens")
    end
    UpdateInstance()
    local m = ns.char.meta
    if m.levelMarkLevel ~= UnitLevel("player") then
        m.levelMark, m.levelMarkLevel = nil, nil -- unknown start of this level
    end
    lastMoney = GetMoney()
    Max("max_money", lastMoney)
    lastXP, lastXPMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    Max("max_level", lastLevel)
    if not ns.char.meta.lastLevelCounted or ns.char.meta.lastLevelCounted > lastLevel then ns.char.meta.lastLevelCounted = lastLevel end
    if GetShapeshiftForm then lastForm = GetShapeshiftForm() end
    if GetPVPLifetimeStats then
        local hk = GetPVPLifetimeStats()
        if type(hk) == "number" then ns.char.c.hk_server = hk end
    end
end)

On("PLAYER_PVP_KILLS_CHANGED", function()
    if GetPVPLifetimeStats then
        local hk = GetPVPLifetimeStats()
        if type(hk) == "number" then ns.char.c.hk_server = hk end
    end
end)

function ns.GetZone() return zone, curType end
ns.P = P

function ns.OnInit()
    -- Each step isolated: one failing API on a new client build must not stop the rest.
    for _, step in ipairs({ BuildPatterns, BuildSpellNames, InstallHooks, HookPlayedDisplay, ns.InstallExtraHooks, ns.InstallFallback, ns.InstallSocialHooks, ns.InstallTooltip, ns.CreateUI, ns.CreateOptions }) do
        if step then
            local ok, err = pcall(step)
            if not ok then ns.LogError("init", err) end
        end
    end
    if ns.restoredFromBackup then
        ns.Print("Restored this character's lifetime stats from the per-character backup.")
    end
end

function ns.OnLogout()
    if ns.OnCampLogout then ns.OnCampLogout() end
    Max("max_session", GetTime() - ns.session.start)
end

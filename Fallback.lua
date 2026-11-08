-- LifeTimeStats - combat data from sources Forever still gives addons
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
--
-- Forever follows Midnight's addon rules: the combat log (COMBAT_LOG_EVENT_UNFILTERED /
-- CombatLogGetCurrentEventInfo) is secure-only, so addons never see it. Everything here
-- rebuilds the same statistics from readable signals. If the combat log ever does reach
-- the addon (ns.cleuSeen), these sources step aside so nothing is counted twice.
local _, ns = ...
local B = ns.Bool -- hidden booleans read as false

local Add, Max, Tally, On = ns.Add, ns.Max, ns.Tally, ns.On
local GetTime = GetTime
local S = ns.IsSecret

local function CleuActive() return ns.cleuSeen and (GetTime() - ns.cleuSeen) < 120 end
local function Src(k) ns.src[k] = (ns.src[k] or 0) + 1 end
local function Safe(v) if S(v) then Src("secret") return nil end return v end

-- ------------------------------------------------------------ kill de-duplication
-- A kill can be seen twice: as an XP chat line and as a watched unit dying.
-- Each source leaves a short-lived marker per name; the other source consumes it.
local marks = { xp = {}, unit = {} }
local WINDOW = 5
local function Consume(kind, name)
    local list = marks[kind][name]
    if not list then return nil end
    local now = GetTime()
    while list[1] and now - list[1].t > WINDOW do table.remove(list, 1) end
    if list[1] then return table.remove(list, 1) end
    return nil
end
local function Mark(kind, name, detailed)
    local list = marks[kind][name] or {}
    marks[kind][name] = list
    list[#list + 1] = { t = GetTime(), detailed = detailed }
end

-- Level colour of a kill, Classic rules (grey/green/yellow/orange/red).
local function GreyLevel(my)
    if my <= 5 then return 0 end
    if my <= 39 then return my - math.floor(my / 10) - 5 end
    if my <= 59 then return my - math.floor(my / 5) - 1 end
    return my - 9
end
function ns.KillColor(lvl, my)
    if type(lvl) ~= "number" or type(my) ~= "number" then return nil end
    if lvl < 0 then return "red" end -- ?? skull
    local d = lvl - my
    if d >= 5 then return "red" elseif d >= 3 then return "orange" elseif d >= -2 then return "yellow"
    elseif lvl > GreyLevel(my) then return "green" end
    return "grey"
end

-- Extra detail for a creature kill: level colour, elite / rare / boss.
local function KillDetail(info, name)
    if not info or info.isPlayer then return end
    local col = ns.KillColor(info.level, info.myLevel)
    if col then Add("kills_" .. col); Tally("killcolor", col) end
    local cls = info.class
    if cls == "elite" or cls == "rareelite" or cls == "worldboss" then Add("kills_elite"); ns.First("elite", name) end
    if cls == "rare" or cls == "rareelite" then
        Add("kills_rare"); Tally("rares", name or "?"); ns.Unique("rares", name); ns.First("rare", name)
    end
end

-- Most recent info about a creature by name (watched units, then your target).
local recentInfo = {}
local function InfoFor(name, guid)
    local now = GetTime()
    local r = name and recentInfo[name]
    if r and now - r.t < 10 then return r end
    if B(UnitExists("target")) and Safe(UnitName("target")) == name then
        local lvl = Safe(UnitLevel("target"))
        local ok, cls = pcall(UnitClassification, "target")
        return { level = lvl, class = (ok and not S(cls)) and cls or nil, myLevel = Safe(UnitLevel("player")), isPlayer = B(UnitIsPlayer("target")) }
    end
end

local function Kill(source, guid, name, isPlayer, info)
    if CleuActive() then return end
    name = name or "Unknown"
    info = info or InfoFor(name, guid)
    local other = (source == "xp") and "unit" or "xp"
    if source ~= "honor" then
        local entry = Consume(other, name)
        if entry then
            if not entry.detailed and info then entry.detailed = true; KillDetail(info, name) end
            return
        end
        Mark(source, name, info ~= nil)
    end
    if source == "xp" then Src("xpKills") elseif source == "unit" then Src("unitKills") else Src("honorKills") end
    if not guid then guid = (isPlayer and "Player-" or "Creature-x-") .. name end
    ns.RecordKill(guid, name, nil)
    KillDetail(info, name)
end

-- ------------------------------------------------------------ XP and honor chat lines
local xpPat, honorPat
local function Prefix(fmt)
    local p = ns.MakePattern(fmt)
    if not p then return nil end
    p.pat = p.pat:gsub("%%%.%$$", ""):gsub("%$$", "")
    return p
end
local function BuildPatterns()
    xpPat = Prefix(COMBATLOG_XPGAIN_FIRSTPERSON)        -- "%s dies, you gain %d experience."
    honorPat = Prefix(COMBATLOG_HONORGAIN)              -- "%s dies, honorable kill Rank: %s ..."
end

local lastQuestTurnIn = 0
On("QUEST_TURNED_IN", function() lastQuestTurnIn = GetTime() end)

On("CHAT_MSG_COMBAT_XP_GAIN", function(_, msg)
    if S(msg) then
        -- Inside instances the line is secret. Still a kill unless it was quest XP.
        Src("secret")
        if GetTime() - lastQuestTurnIn > 1 then Kill("xp", nil, "Unknown (instance)") end
        return
    end
    local c = ns.Match(xpPat, msg)
    if c and c[1] then Kill("xp", nil, c[1]) end
end)

On("CHAT_MSG_COMBAT_HONOR_GAIN", function(_, msg)
    if S(msg) then return end
    local c = ns.Match(honorPat, msg)
    if c and c[1] then Kill("honor", nil, c[1], true) end
end)

-- ------------------------------------------------------------ watched units
-- Hostile units you engaged (target, mouseover, nameplates, boss frames) are counted
-- when they die and were not tapped by someone else.
local engaged = {}   -- guid -> { name, isPlayer, t }
local counted = {}   -- guid -> time
local plates = {}    -- unit token -> true

local function Hostile(unit)
    return B(UnitExists(unit)) and B(UnitCanAttack("player", unit)) and not (UnitIsTapDenied and B(UnitIsTapDenied(unit)))
end

-- Critters: creature type ID 8, or the localised type name as a fallback.
local CRITTER_NAMES = { Critter = true, Kleintier = true, Bestiole = true, ["Alimaña"] = true, Bicho = true,
    Animale = true, ["Существо"] = true, ["Животное"] = true, ["동물"] = true, ["小动物"] = true, ["小動物"] = true }
function ns.IsCritter(unit)
    if not B(UnitExists(unit)) or B(UnitIsPlayer(unit)) then return false end
    if UnitCreatureType then
        local ok, name, id = pcall(UnitCreatureType, unit)
        if ok and name ~= nil and not S(name) and not S(id) then
            ns.src.critterTypeRead = (ns.src.critterTypeRead or 0) + 1
            if id == 8 then return true end
            return CRITTER_NAMES[name] or false
        end
        ns.src.critterTypeHidden = (ns.src.critterTypeHidden or 0) + 1
    end
    -- Type hidden: critters are the level-1 creatures you can attack once you are past level 3.
    if UnitClassification then
        local ok, cls = pcall(UnitClassification, unit)
        if ok and not S(cls) and cls == "minus" then return true end
    end
    local lvl, mine = UnitLevel(unit), UnitLevel("player")
    if S(lvl) or S(mine) or type(lvl) ~= "number" or type(mine) ~= "number" then return false end
    return lvl == 1 and mine >= 3
end

local function Engage(unit)
    if not Hostile(unit) then return end
    local guid = Safe(UnitGUID(unit))
    if not guid then return end
    local name = Safe(UnitName(unit))
    local e = engaged[guid]
    if not e then e = {}; engaged[guid] = e end
    e.name, e.isPlayer, e.t = name, B(UnitIsPlayer(unit)) and true or false, GetTime()
    e.critter = ns.IsCritter(unit)
    if e.critter then Src("critterEngaged") end
    e.level, e.myLevel = Safe(UnitLevel(unit)), Safe(UnitLevel("player"))
    if UnitClassification then
        local ok, cls = pcall(UnitClassification, unit)
        if ok and not S(cls) then e.class = cls end
    end
    if name then recentInfo[name] = { level = e.level, myLevel = e.myLevel, class = e.class, isPlayer = e.isPlayer, t = GetTime() } end
end

local function CheckDead(unit)
    if not B(UnitExists(unit)) then return end
    local guid = Safe(UnitGUID(unit))
    if not guid or counted[guid] or not engaged[guid] then return end
    local dead = B(UnitIsDead(unit))
    if S(dead) or not dead then return end
    if UnitIsTapDenied and B(UnitIsTapDenied(unit)) then return end
    counted[guid] = GetTime()
    local e = engaged[guid]
    engaged[guid] = nil
    local name = e.name or Safe(UnitName(unit))
    if e.critter then
        -- Critters are counted on their own, never as enemies killed.
        Src("critterKills")
        Add("critter_kills")
        if ns.lovedGuids and ns.lovedGuids[guid] then
            ns.lovedGuids[guid] = nil
            Add("critters_love_kill")
        end
        Tally("critters", name or "Critter")
        ns.Unique("critter_kinds", name)
        ns.First("critter_kill", name)
        return
    end
    Kill("unit", guid, name, e.isPlayer, { level = e.level, myLevel = e.myLevel, class = e.class, isPlayer = e.isPlayer })
end

-- NAME_PLATE_UNIT_ADDED can fire before the unit is filled in, so nameplates are also
-- swept directly (nameplate1-40) every check.
local function Units()
    local list = { "target", "mouseover", "focus", "pettarget" }
    for i = 1, 5 do list[#list + 1] = "boss" .. i end
    for i = 1, 40 do
        local u = "nameplate" .. i
        if plates[u] or B(UnitExists(u)) then list[#list + 1] = u end
    end
    return list
end

On("NAME_PLATE_UNIT_ADDED", function(_, unit) plates[unit] = true end)
On("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    CheckDead(unit)
    plates[unit] = nil
end)
On("PLAYER_TARGET_CHANGED", function() CheckDead("target") end)
On("UNIT_HEALTH", function(_, unit)
    if unit == "player" then return end
    if B(UnitAffectingCombat("player")) and B(UnitAffectingCombat(unit)) then Engage(unit) end
    CheckDead(unit)
end)
On("UNIT_THREAT_LIST_UPDATE", function(_, unit) if unit then Engage(unit) end end)
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit)
    if unit ~= "player" or not B(UnitExists("target")) then return end
    -- Critters rarely put you in combat, so any cast at one counts as attacking it.
    if B(UnitAffectingCombat("player")) or ns.IsCritter("target") then Engage("target") end
end)
On("PLAYER_ENTER_COMBAT", function() if ns.IsCritter("target") then Engage("target") end end) -- auto-attack
On("PLAYER_REGEN_DISABLED", function()
    for _, u in ipairs(Units()) do if B(UnitAffectingCombat(u)) then Engage(u) end end
end)

-- ------------------------------------------------------------ UNIT_COMBAT (combat text feed)
local AVOID = { DODGE = "dodge", PARRY = "parry", BLOCK = "block", MISS = "miss", RESIST = "resist",
                IMMUNE = "immune", ABSORB = "absorb", EVADE = "evade", DEFLECT = "deflect", REFLECT = "reflect" }
local lastSpell, lastSpellT = nil, 0
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or not spellID then return end
    local n = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    n = type(n) == "table" and n.name or (GetSpellInfo and GetSpellInfo(spellID))
    if n and not S(n) then lastSpell, lastSpellT = n, GetTime() end
end)
local critRun = 0
local incomingHits = {}  -- recent damage on you, for fall detection

On("UNIT_COMBAT", function(_, unit, action, flag, amount, school)
    if CleuActive() then return end
    if S(action) or S(flag) then Src("secret") return end
    if S(amount) then
        Src("secret"); amount = nil
        if not ns.settings.amountsSecret then ns.settings.amountsSecret = true end
    elseif type(amount) == "number" and amount > 0 then
        ns.src.amountReadable = true
    end
    if S(school) then school = nil end
    if unit == "player" then
        Src("ucPlayer")
        if action == "WOUND" then
            if amount and amount > 0 then
                Add("dmg_taken", amount)
                incomingHits[#incomingHits + 1] = { GetTime(), amount }
                if #incomingHits > 8 then table.remove(incomingHits, 1) end
            end
            Add("hits_taken")
            local src = Hostile("target") and Safe(UnitName("target")) or nil
            if flag == "CRITICAL" then Add("crits_taken"); if amount then Max("max_crit_taken", amount, src) end end
            if flag == "CRUSHING" then Add("crushing_in") end
            if flag == "BLOCK" then Add("blocks_partial_in") end
            if amount then Max("max_hit_taken", amount, src) end
        elseif action == "HEAL" then
            if amount and amount > 0 then Add("heal_taken", amount); Max("max_heal_taken", amount) end
        elseif AVOID[action] then
            Add("in_" .. AVOID[action])
            if action ~= "ABSORB" and action ~= "IMMUNE" then Add("avoided_in") end
        end
    elseif unit == "target" then
        if ns.IsCritter("target") and action == "WOUND" then Engage("target") end
        -- Damage on your target is only yours when nobody else is fighting with you.
        if (GetNumGroupMembers and GetNumGroupMembers() > 0) or not B(UnitAffectingCombat("player")) then return end
        if not Hostile("target") then return end
        Src("ucTarget")
        Engage("target")
        local what = (GetTime() - lastSpellT < 3) and lastSpell or "Melee"
        if action == "WOUND" then
            if amount and amount > 0 then Add("dmg_done", amount); Max("max_hit", amount, what) end
            Add("hits")
            if school == 1 then Add("melee_hits") elseif school then Add("spell_hits") end
            if flag == "CRITICAL" then
                Add("crits"); critRun = critRun + 1; Max("max_crit_streak", critRun)
                if amount then Max("max_crit", amount, what) end
            else
                critRun = 0
            end
            if flag == "GLANCING" then Add("glancing_out") end
        elseif AVOID[action] then
            Add("out_" .. AVOID[action])
            if action ~= "ABSORB" and action ~= "IMMUNE" then Add("misses_out") end
            critRun = 0
        end
    end
end)

-- ------------------------------------------------------------ your health
-- When UNIT_COMBAT amounts are hidden, damage taken and healing received come from
-- your own health changing (healing only counts in combat, so regeneration is ignored).
local lastHp
local function HealthDelta()
    local hp = UnitHealth("player")
    if S(hp) or type(hp) ~= "number" then
        if not ns.settings.healthSecret then ns.settings.healthSecret = true end
        return
    end
    ns.src.hpReadable = true
    if ns.settings.healthSecret then ns.settings.healthSecret = nil end
    if lastHp and ns.settings.amountsSecret and not ns.src.amountReadable and not CleuActive() then
        local d = hp - lastHp
        if d < 0 then
            local dmg = -d
            Add("dmg_taken", dmg)
            local src = Hostile("target") and Safe(UnitName("target")) or nil
            Max("max_hit_taken", dmg, src)
        elseif d > 0 and B(UnitAffectingCombat("player")) and not B(UnitIsDeadOrGhost("player")) then
            Add("heal_taken", d)
            Max("max_heal_taken", d)
        end
    end
    lastHp = hp
end
On("UNIT_HEALTH", function(_, unit) if unit == "player" then HealthDelta() end end)
On("UNIT_MAXHEALTH", function(_, unit) if unit == "player" then lastHp = nil; HealthDelta() end end)
On("PLAYER_ENTERING_WORLD", function() lastHp = nil; HealthDelta() end)
On("PLAYER_ALIVE", function() lastHp = nil end)
On("PLAYER_UNGHOST", function() lastHp = nil end)

-- ------------------------------------------------------------ falls from health
local wasFalling, hpAtFall, airStart = false, nil, 0
local lastFall -- { t, amt }
local fallFrame = CreateFrame("Frame")
fallFrame:SetScript("OnUpdate", ns.Guard("falls", function()
    if not ns.char or CleuActive() then return end
    local falling = B(IsFalling()) and not B(UnitOnTaxi("player"))
    if falling and not wasFalling then
        wasFalling, airStart = true, GetTime()
        local hp = UnitHealth("player")
        hpAtFall = (not S(hp)) and hp or nil
    elseif not falling and wasFalling then
        wasFalling = false
        local air = GetTime() - airStart
        local before = hpAtFall
        if air < 0.6 or not before or B(IsSwimming()) then return end
        C_Timer.After(0.35, function()
            local hp = UnitHealth("player")
            if S(hp) or not hp then return end
            local drop = before - hp
            if B(UnitIsDeadOrGhost("player")) then drop = before end
            if drop <= 0 then return end
            Src("falls")
            lastFall = { t = GetTime(), amt = drop }
            Add("falls"); Add("dmg_fall", drop); Max("max_fall", drop)
            local maxHp = UnitHealthMax("player")
            local pct = (maxHp and not S(maxHp) and maxHp > 0) and (drop / maxHp * 100) or 0
            C_Timer.After(1.2, function()
                if not B(UnitIsDeadOrGhost("player")) then
                    Max("max_fall_survived", drop); Max("max_fall_survived_pct", pct); Add("falls_survived")
                end
            end)
        end)
    end
end))

-- ------------------------------------------------------------ death cause
-- Breath / fatigue bars: only count when the bar is actually running (events, not
-- GetMirrorTimerProgress, which reads 0 when no bar is shown).
local mirror = {}
On("MIRROR_TIMER_START", function(_, timer)
    if S(timer) or type(timer) ~= "string" then return end
    mirror[timer] = GetTime()
    if timer == "BREATH" then Add("breath_held") elseif timer == "EXHAUSTION" then Add("fatigue_entered") end
end)
On("MIRROR_TIMER_STOP", function(_, timer) if not S(timer) and type(timer) == "string" then mirror[timer] = nil end end)
On("PLAYER_ENTERING_WORLD", function() mirror = {} end)
local function MirrorZero(name)
    local started = mirror[name]
    if not started then return false end
    if GetMirrorTimerProgress then
        local ok, v = pcall(GetMirrorTimerProgress, name)
        if ok and type(v) == "number" and not S(v) then return v <= 0 end
    end
    return true -- bar running and we just died: it ran out
end

-- Called by the death tracker when no combat-log hit is known.
-- The game's death recap: events[1] is the killing blow (environmentalType, spellName,
-- sourceName). The recap ID comes from the meter's deaths list, else the newest ID found.
local function RecapID()
    local DR = C_DeathRecap
    if type(DR) ~= "table" or type(DR.GetRecapEvents) ~= "function" then return nil end
    local id = ns.DMMyRecapID and ns.DMMyRecapID()
    if id and id > 0 and id ~= ns.char.meta.lastRecap then return id end
    local has = DR.HasRecapEvents
    local start = (ns.char.meta.lastRecap or 0) + 1
    local best
    for i = start, start + 30 do
        local ok, r = pcall(has or DR.GetRecapEvents, i)
        if ok and r and (has or (type(r) == "table" and #r > 0)) then best = i end
    end
    return best
end
function ns.RecapCause()
    if not ns.char then return nil end
    local id = RecapID()
    if not id then return nil end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents, id)
    if not ok or type(events) ~= "table" then return nil end
    local e = events[1]
    if type(e) ~= "table" then return nil end
    ns.char.meta.lastRecap = id
    ns.src.recapDeaths = (ns.src.recapDeaths or 0) + 1
    local function Str(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end
    local env = Str(e.environmentalType)
    local spell = Str(e.spellName)
    if not spell and Str(e.event) == "SWING_DAMAGE" then spell = "Melee" end
    local name = Str(e.sourceName)
    -- what hurt you in the last seconds of your life
    -- Recap amounts are readable on Forever (unlike UNIT_COMBAT and health).
    local function N(v) if type(v) == "number" and not S(v) and v == v then return v end end
    local function What(ev)
        local et = Str(ev.environmentalType)
        if et then return et:sub(1, 1):upper() .. et:sub(2):lower(), et end
        local sp = Str(ev.spellName) or (Str(ev.event) == "SWING_DAMAGE" and "Melee") or "?"
        return (Str(ev.sourceName) or "?") .. " · " .. sp
    end
    for _, ev in ipairs(events) do
        if type(ev) == "table" then
            local label, et = What(ev)
            local amt = N(ev.amount)
            if et then
                Add("env_hits")
                if amt then Add("dmg_env_" .. et:lower(), amt) end
            end
            if amt and amt > 0 then
                Add("recap_damage", amt)
                Tally("envdamage", label, amt)
                Max("max_hit_taken", amt, label)
                if ev.critical == true then Max("max_crit_taken", amt, label) end
            end
        end
    end
    local kb = N(e.amount)
    if kb and kb > 0 then Max("max_killing_blow", kb, (What(e))) end
    local ok2 = N(e.overkill); if ok2 and ok2 > 0 then Add("death_overkill", ok2); Max("max_death_overkill", ok2, (What(e))) end
    local hp = N(e.currentHP); if hp and hp > 0 then Max("max_hp_before_killing_blow", hp, (What(e))) end
    if env then return { env = env:upper(), spell = env:sub(1, 1):upper() .. env:sub(2):lower(), t = GetTime() } end
    if not name and not spell then return nil end
    local player = false
    if name and B(UnitExists("target")) and Safe(UnitName("target")) == name then player = B(UnitIsPlayer("target")) and true or false end
    return { name = name, spell = spell, player = player, t = GetTime() }
end

function ns.GuessDeathCause()
    local now = GetTime()
    if lastFall and now - lastFall.t < 3 then return { t = now, env = "FALLING", amt = lastFall.amt } end
    if B(IsFalling()) then return { t = now, env = "FALLING", amt = 0 } end
    if B(IsSwimming()) and MirrorZero("BREATH") then return { t = now, env = "DROWNING" } end
    if MirrorZero("EXHAUSTION") then return { t = now, env = "FATIGUE" } end
    -- Forever's damage meter knows the killing blow of the current fight (only if you were
    -- actually fighting: out of combat its "current" fight is an old one).
    if ns.DMKiller and ns.FightingRecently and ns.FightingRecently() then
        local ok, k = pcall(ns.DMKiller)
        if ok and k and k.name then
            local player = false
            if B(UnitExists("target")) and Safe(UnitName("target")) == k.name then player = B(UnitIsPlayer("target")) and true or false end
            ns.src.dmKiller = (ns.src.dmKiller or 0) + 1
            return { t = now, name = k.name, spell = k.spell, player = player }
        end
    end
    if B(UnitExists("target")) and B(UnitCanAttack("player", "target")) then
        local n = Safe(UnitName("target"))
        return { t = now, name = n, player = B(UnitIsPlayer("target")) and true or false }
    end
    return nil
end

-- ------------------------------------------------------------ housekeeping
local acc = 0
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", ns.Guard("unitwatch", function(_, el)
    acc = acc + el
    if acc < 0.25 then return end
    acc = 0
    if not ns.char or CleuActive() then return end
    local fighting = B(UnitAffectingCombat("player"))
    for _, u in ipairs(Units()) do
        if fighting and B(UnitAffectingCombat(u)) then Engage(u) end
        CheckDead(u)
    end
    local now = GetTime()
    for g, e in pairs(engaged) do if now - e.t > 300 then engaged[g] = nil end end
    for g, t in pairs(counted) do if now - t > 600 then counted[g] = nil end end
end))

function ns.InstallFallback()
    BuildPatterns()
end

-- Stats that need UNIT_COMBAT amounts (n/a when Forever hides them).
ns.AMOUNT_KEYS = { dmg_done = true, max_hit = true, max_crit = true }
-- Stats rebuilt from your health when amounts are hidden (n/a only if health is hidden too).
ns.HEALTH_KEYS = { dmg_taken = true, max_hit_taken = true, max_crit_taken = true, heal_taken = true, max_heal_taken = true, dmg_fall = true, max_fall = true, max_fall_survived = true, max_fall_survived_pct = true, falls = true, falls_survived = true }

-- Stats that only the combat log can provide (shown as "n/a" while it is unavailable).
ns.CLEU_ONLY = {
    heal_done = true, heal_others = true, heal_self = true, overheal = true, heals = true, heal_crits = true,
    killing_blows = true, interrupts = true, dispels = true, buffs_given = true, buffs_from_others = true,
    debuffs_taken = true, dot_ticks = true, ranged_hits = true, dmg_taken_pvp = true, rezzes_cast = true,
    max_heal = true, max_heal_crit = true, env_hits = true, dmg_env_drowning = true, dmg_env_lava = true, dmg_env_fatigue = true,
}

-- LifeTimeStats - Forever's built-in damage meter (C_DamageMeter).
-- Forever does not give addons the combat log, but its own meter keeps a list of fights
-- (GetAvailableCombatSessions: sessionID, name, durationSeconds) with readable totals and
-- per-spell rows. After combat every fight not counted yet is read once, oldest first.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Tally, On = ns.Add, ns.Max, ns.Tally, ns.On
local S = ns.IsSecret
local GetTime = GetTime

-- Enum.DamageMeterType on Forever 1.60.1 (from /lts dm).
local DT = { damage = 0, heal = 2, interrupts = 5, dispels = 6, taken = 7, avoidable = 8, deaths = 9, enemy = 10 }
ns.DM_TYPES = DT
local MAX_PER_PASS = 20

local function Zone() local z = ns.GetZone and ns.GetZone() return (z and z ~= "") and z or "?" end
local function Num(v)
    if S(v) then ns.src.dmSecret = true return nil end
    if type(v) == "number" and v == v then return v end
end
local function Name(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end
local function Persist() ns.src.dmReadable = true; if ns.settings then ns.settings.dmReadable = true end end
local function Me() local g = UnitGUID("player") if S(g) then return nil end return g end
local function Band() local l = UnitLevel("player") or 1 local b = math.floor(l / 10) * 10 return (b == 0 and 1 or b) .. "-" .. (b + 9) end
local function LevelKey() return string.format("%02d", UnitLevel("player") or 1) end
local function Round1(x) return math.floor(x * 10 + 0.5) / 10 end

local function SpellName(id)
    if not Num(id) then return nil end
    local n
    if C_Spell and C_Spell.GetSpellName then local ok, r = pcall(C_Spell.GetSpellName, id); if ok then n = r end end
    if not n and GetSpellInfo then local ok, r = pcall(GetSpellInfo, id); if ok then n = r end end
    if id == 6603 or id == 1 or n == "Attack" or n == "Auto Attack" then return "Melee" end
    if id == 75 or n == "Auto Shot" then return "Auto Shot" end
    if type(n) == "string" and not S(n) and n ~= "" then return n end
    return "Spell " .. id
end
ns.DMSpellName = SpellName

-- Iterate combatSpells rows with a readable amount above zero.
local function Spells(src)
    local list = type(src) == "table" and src.combatSpells
    if type(list) ~= "table" then return function() end end
    local i = 0
    return function()
        while true do
            i = i + 1
            local sp = list[i]
            if sp == nil then return nil end
            if type(sp) == "table" then
                local amt = Num(sp.totalAmount)
                if amt and amt > 0 then return sp, amt end
            end
        end
    end
end

local function Total(t)
    if type(t) ~= "table" then return nil end
    return Num(t.totalAmount) or Num(t.amount) or Num(t.total) or Num(t.value)
end
local function Sources(sess)
    local list = type(sess) == "table" and (sess.combatSources or sess.sources)
    return type(list) == "table" and list or nil
end
local function IsMe(src, me, myAmt)
    local isMe = src.isLocalPlayer
    if not S(isMe) and isMe == true then return true end
    local g = src.sourceGUID
    if me and not S(g) and g == me then return true end
    if myAmt and Total(src) == myAmt then
        local cls = src.classFilename
        local _, mine = UnitClass("player")
        if not S(cls) and cls == mine then return true end
    end
    return false
end

local function Call(fname, a, b, c)
    local DM = C_DamageMeter
    local fn = type(DM) == "table" and DM[fname]
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn, a, b, c)
    if ok and type(res) == "table" then return res end
end

-- My source for one fight and one meter type: totals and per-spell rows.
local function MySource(id, kind)
    local t, me = DT[kind], Me()
    if me then
        for _, args in ipairs({ { id, t }, { t, id } }) do
            local res = Call("GetCombatSessionSourceFromID", args[1], args[2], me)
            local v = Total(res)
            if v then ns.src.dmCall = "GetCombatSessionSourceFromID" return v, res end
        end
    end
    for _, args in ipairs({ { id, t }, { t, id } }) do
        local sess = Call("GetCombatSessionFromID", args[1], args[2])
        local list = Sources(sess)
        if list then
            for _, src in pairs(list) do
                if type(src) == "table" and IsMe(src, me) then
                    local v = Total(src)
                    if v then ns.src.dmCall = "GetCombatSessionFromID" return v, src end
                end
            end
        end
    end
end

-- Current fight, by type (used when the client has no fight list, and for death causes).
local function Local(kind)
    local t, me = DT[kind], Me()
    if me then
        for _, args in ipairs({ { 1, t }, { t, 1 } }) do
            local res = Call("GetCombatSessionSourceFromType", args[1], args[2], me)
            local v = Total(res)
            if v then return v, res end
        end
    end
    for _, args in ipairs({ { 1, t }, { t, 1 } }) do
        local list = Sources(Call("GetCombatSessionFromType", args[1], args[2]))
        if list then
            for _, src in pairs(list) do
                if type(src) == "table" and IsMe(src, me) then
                    local v = Total(src)
                    if v then return v, src end
                end
            end
        end
    end
end
ns.DMLocal = Local

local function SessionList()
    if type(C_DamageMeter) ~= "table" or type(C_DamageMeter.GetAvailableCombatSessions) ~= "function" then return nil end
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" then return nil end
    local out = {}
    for _, s in pairs(list) do
        if type(s) == "table" and Num(s.sessionID) then out[#out + 1] = s end
    end
    table.sort(out, function(a, b) return a.sessionID < b.sessionID end)
    return out
end
ns.DMSessionList = SessionList

-- Biggest single hit: combatSpellDetails holds per-spell detail. Its field names are not
-- documented, so any readable number whose key says max / largest / biggest / highest is
-- taken as the biggest hit (only if it is not more than the spell's total).
local function ProbeDetails(sp, nm, amt)
    local det = sp.combatSpellDetails
    if type(det) ~= "table" then return end
    local best, bestCrit
    local function Walk(t, depth)
        for k, v in pairs(t) do
            if type(v) == "table" and depth < 2 then Walk(v, depth + 1)
            elseif type(k) == "string" and not S(v) and type(v) == "number" then
                local lk = k:lower()
                ns.src.dmDetailKeys = ns.src.dmDetailKeys or {}
                ns.src.dmDetailKeys[k] = true
                if (lk:find("max") or lk:find("largest") or lk:find("biggest") or lk:find("highest")) and v > 0 and v <= amt then
                    if lk:find("crit") then
                        if not bestCrit or v > bestCrit then bestCrit = v end
                    elseif not best or v > best then best = v; ns.src.dmHitKey = k end
                end
            end
        end
    end
    Walk(det, 0)
    if best then
        Max("max_hit", best, nm)
        if ns.settings then ns.settings.dmHitReadable = true end
    end
    if bestCrit then Max("max_crit", bestCrit, nm) end
end

local function B_InGroup()
    local g = IsInGroup and IsInGroup()
    if S(g) then return false end
    return g and true or false
end

-- ------------------------------------------------------------ one fight
local function ReadFight(sess)
    local id = sess and sess.sessionID
    local name = Name(sess and sess.name)
    local dur = sess and Num(sess.durationSeconds)
    local solo = not B_InGroup()
    ns.src.dmSessions = (ns.src.dmSessions or 0) + 1
    if name then Tally("foughtenemies", name) end
    if dur then Add("dm_fight_time", dur); Max("max_dm_fight", dur, name) end
    local countTotals = not ns.src.amountReadable  -- UNIT_COMBAT already counts if amounts are open
    local function Read(kind)
        if id then
            local v, src = MySource(id, kind)
            if v then return v, src end
        end
        if not id then return Local(kind) end
    end

    -- damage done
    local d, dsrc = Read("damage")
    if d and d > 0 then
        Persist()
        ns.src.dmCounted = (ns.src.dmCounted or 0) + d
        if countTotals then Add("dmg_done", d) end
        Max("max_fight_damage", d, name or Zone())
        Add("dm_fights_dmg", 1)
        Tally("dmglevel", LevelKey(), d)
        if dur and dur > 0 then Tally("timelevel", LevelKey(), dur) end
        local dps = (dur and dur >= 3) and Round1(d / dur) or nil
        if dps then Max("max_fight_dps", dps, name) end
        local top, topAmt = nil, 0
        for sp, amt in Spells(dsrc) do
            local nm = SpellName(sp.spellID)
            local det = type(sp.combatSpellDetails) == "table" and sp.combatSpellDetails or {}
            local pet = (det.isPet == true and (Name(det.unitName) or "Pet")) or Name(sp.creatureName)
            if pet then
                Add("dmg_pet", amt); Tally("petdamage", pet, amt)
            elseif nm then
                Tally("spelldamage", nm, amt)
                Tally("bandspells", Band() .. " · " .. nm, amt)
                if amt > topAmt then top, topAmt = nm, amt end
            end
            local ok = Num(sp.overkillAmount); if ok and ok > 0 then Add("overkill", ok) end
            ProbeDetails(sp, pet and (pet .. " (pet)") or nm, amt)
        end
        if top then Max("max_spell_fight", topAmt, top) end
        -- boss fights: a boss died within the last 20 seconds
        local boss = ns.lastBossKill
        if boss and GetTime() - boss.t < 20 and not boss.read then
            boss.read = true
            Tally("bossdamage", boss.name, d)
            Max("max_boss_damage", d, boss.name)
            if dps then Max("best_boss_dps", dps, boss.name) end
        end
        -- group share: your part of everyone's damage in this fight
        if id and not solo then
            local list = Sources(Call("GetCombatSessionFromID", id, DT.damage))
            if list then
                local total, players, top2, me = 0, 0, 0, Me()
                for _, src in pairs(list) do
                    local v = type(src) == "table" and Total(src)
                    if v and v > 0 then
                        total = total + v; players = players + 1
                        if not IsMe(src, me, d) and v > top2 then top2 = v end
                    end
                end
                if players >= 2 and total > 0 then
                    Add("group_fights")
                    Add("group_dmg_all", total); Add("group_dmg_mine", d)
                    Max("max_group_share", math.floor(d * 100 / total + 0.5), name)
                    if d >= top2 then Add("meter_topped") end
                end
            end
        end
    end

    -- healing done
    local h, hsrc = Read("heal")
    if h and h > 0 then
        Persist(); Add("heal_done", h); Max("max_fight_heal", h, name or Zone())
        for sp, amt in Spells(hsrc) do local nm = SpellName(sp.spellID); if nm then Tally("spellheal", nm, amt) end end
    end

    -- damage taken
    local tk, tsrc = Read("taken")
    if tk and tk > 0 then
        Persist()
        if ns.settings.amountsSecret then Add("dmg_taken", tk) end
        Max("max_fight_taken", tk, name or Zone())
        for sp, amt in Spells(tsrc) do
            local det = type(sp.combatSpellDetails) == "table" and sp.combatSpellDetails or {}
            local who = Name(det.unitName) or Name(sp.creatureName) or name
            if who then Tally("hurtby", who, amt) end
            local nm = SpellName(sp.spellID); if nm then Tally("hurtbyspell", nm, amt) end
            if sp.isDeadly == true then Add("deadly_hits", 1) end
        end
    end

    -- avoidable damage taken ("standing in the fire")
    local av, asrc = Read("avoidable")
    if av and av > 0 then
        Persist(); Add("dmg_avoidable", av); Add("fights_in_fire")
        Max("max_fight_avoidable", av, name or Zone())
        for sp, amt in Spells(asrc) do local nm = SpellName(sp.spellID); if nm then Tally("standinfire", nm, amt) end end
    end

    -- damage each enemy took (only yours while solo)
    if id and solo then
        local list = Sources(Call("GetCombatSessionFromID", id, DT.enemy))
        if list then
            for _, src in pairs(list) do
                local v = type(src) == "table" and Total(src)
                local who = type(src) == "table" and Name(src.name)
                if v and v > 0 and who then Tally("damagetoenemy", who, v) end
            end
        end
    end

    -- deaths in your group during the fight (not yours: those are counted on PLAYER_DEAD)
    if id and not solo then
        local list = Sources(Call("GetCombatSessionFromID", id, DT.deaths))
        if list then
            local me = Me()
            for _, src in pairs(list) do
                if type(src) == "table" and not IsMe(src, me) then
                    local t = Num(src.deathTimeSeconds)
                    if t and t > 0 then Add("allies_died") end
                end
            end
        end
    end

    local it = Read("interrupts"); if it and it > 0 then Persist(); Add("interrupts", it) end
    local dp = Read("dispels"); if dp and dp > 0 then Persist(); Add("dispels", dp) end
end

-- ------------------------------------------------------------ after combat: all unread fights
function ns.DMCatchUp()
    if not ns.char or ns.cleuSeen then return end
    local m = ns.char.meta
    local list = SessionList()
    if not list then
        -- no fight list on this client: read the current fight once
        ReadFight(nil)
        return
    end
    if #list == 0 then return end
    local newest = list[#list].sessionID
    if not m.dmLastID or newest < m.dmLastID then
        -- first read ever, or the meter restarted its numbering: only the newest fight
        m.dmLastID = newest - 1
    end
    local done = 0
    for _, sess in ipairs(list) do
        if sess.sessionID > m.dmLastID then
            m.dmLastID = sess.sessionID
            ReadFight(sess)
            done = done + 1
            if done >= MAX_PER_PASS then break end
        end
    end
end

On("PLAYER_REGEN_ENABLED", function()
    C_Timer.After(0.8, function() ns.DMCatchUp() end)
end)

-- Login / reload: fights from before are not counted again. Also note the meter's own
-- overall total so /lts debug can compare it with what was counted this session.
local function OverallMine()
    local v = Total(Call("GetCombatSessionSourceFromType", 0, DT.damage, Me()))
    return v
end
On("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    if not (isLogin or isReload) or not ns.char then return end
    local list = SessionList()
    if list and #list > 0 then
        local newest = list[#list].sessionID
        local m = ns.char.meta
        if not m.dmLastID or newest < m.dmLastID then m.dmLastID = newest end
    end
    ns.src.dmOverall0 = OverallMine() or 0
    ns.src.dmCounted = 0
end)

-- "Missed fights" check for /lts debug: meter overall since login vs what was counted.
function ns.DMGap()
    local now = OverallMine()
    if not now then return nil end
    local meter = now - (ns.src.dmOverall0 or 0)
    return meter, ns.src.dmCounted or 0
end

-- Killing blow from the current fight: the hit marked deadly, else the biggest hitter.
function ns.DMKiller()
    local _, src = Local("taken")
    if type(src) ~= "table" then return nil end
    local deadly, biggest, bigAmt
    for sp, amt in Spells(src) do
        if sp.isDeadly == true then deadly = sp end
        if not bigAmt or amt > bigAmt then biggest, bigAmt = sp, amt end
    end
    local sp = deadly or biggest
    if not sp then return nil end
    local det = type(sp.combatSpellDetails) == "table" and sp.combatSpellDetails or {}
    return { name = Name(det.unitName) or Name(sp.creatureName), spell = SpellName(sp.spellID), deadly = deadly and true or false }
end

-- In a fight now, or one ended in the last 3 seconds.
local inFight, fightEnd = false, -100
On("PLAYER_REGEN_DISABLED", function() inFight = true end)
On("PLAYER_REGEN_ENABLED", function() inFight = false; fightEnd = GetTime() end)
function ns.FightingRecently() return inFight or GetTime() - fightEnd < 3 end

-- Your death-recap ID from the meter's deaths list for the current fight.
function ns.DMMyRecapID()
    local list = Sources(Call("GetCombatSessionFromType", 1, DT.deaths))
    if not list then return nil end
    local me, best = Me(), nil
    for _, src in pairs(list) do
        if type(src) == "table" and IsMe(src, me) then
            local id = Num(src.deathRecapID)
            if id and id > 0 and (not best or id > best) then best = id end
        end
    end
    return best
end

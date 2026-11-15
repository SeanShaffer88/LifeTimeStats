-- LifeTimeStats - Characters: a snapshot of every character (gold, /played, professions,
-- lockouts, rested XP, bags, guild, hearth...), a local log of the players you grouped with,
-- and farming rates per play session (gold, XP, kills and vendor value of loot per hour).
-- Ideas from Exlist, Warbandeer: Characters, PlayerTracker and Haul (public descriptions only,
-- no code). Nothing here is sent anywhere.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Tally, On = ns.Add, ns.Max, ns.Tally, ns.On
local S = ns.IsSecret

local PEOPLE_CAP = 2000
ns.PEOPLE_CAP = PEOPLE_CAP

local function N(v) if type(v) == "number" and not S(v) and v == v and v ~= math.huge and v ~= -math.huge then return v end end
local function Str(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end
local function B(v) return ns.Bool(v) end

-- ------------------------------------------------------------ snapshot
local function Professions()
    local out = {}
    if not GetProfessions or not GetProfessionInfo then return out end
    -- Slots can be nil in the middle (no second profession, no fishing), so no ipairs here.
    local ok, a, b, c, d, e = pcall(GetProfessions)
    if not ok then return out end
    local slots = { a, b, c, d, e }
    for i = 1, 5 do
        local idx = slots[i]
        if N(idx) then
            local okI, name, _, rank, max = pcall(GetProfessionInfo, idx)
            if okI and Str(name) then out[#out + 1] = { n = name, r = N(rank) or 0, m = N(max) or 0 } end
        end
    end
    return out
end

local function Lockouts()
    local out = {}
    if not GetNumSavedInstances or not GetSavedInstanceInfo then return out end
    local ok, n = pcall(GetNumSavedInstances)
    if not ok or not N(n) then return out end
    for i = 1, n do
        local okI, name, _, reset, _, locked, extended, _, isRaid, _, diffName, numEnc, prog = pcall(GetSavedInstanceInfo, i)
        if okI and Str(name) and (B(locked) or B(extended)) and N(reset) then
            out[#out + 1] = { n = name, e = time() + reset, raid = B(isRaid) or nil, p = N(prog), t = N(numEnc), d = Str(diffName) }
        end
    end
    return out
end

local function BagSpace()
    local free, total = 0, 0
    local cont = C_Container
    local numFree = cont and cont.GetContainerNumFreeSlots
    local numSlots = cont and cont.GetContainerNumSlots
    if not numFree or not numSlots then return nil, nil end
    for bag = 0, 4 do
        local ok1, slots = pcall(numSlots, bag)
        local ok2, f = pcall(numFree, bag)
        if ok1 and N(slots) then total = total + slots end
        if ok2 and N(f) then free = free + f end
    end
    return free, total
end

local function BestReputation()
    if not C_Reputation or not C_Reputation.GetNumFactions or not C_Reputation.GetFactionDataByIndex then return nil end
    local ok, n = pcall(C_Reputation.GetNumFactions)
    if not ok or not N(n) then return nil end
    local best
    for i = 1, n do
        local okI, data = pcall(C_Reputation.GetFactionDataByIndex, i)
        if okI and type(data) == "table" and not S(data) and not (data.isHeader and not data.isHeaderWithRep) then
            local r = N(data.reaction)
            if r and Str(data.name) and (not best or r > best.r) then best = { n = data.name, r = r } end
        end
    end
    return best
end

-- Everything about this character right now; kept on the character record as rec.snap.
function ns.TakeSnapshot()
    local ch = ns.char
    if not ch then return end
    local snap = ch.snap or {}
    snap.t = time()
    snap.level = N(UnitLevel("player")) or snap.level
    local race = UnitRace and UnitRace("player")
    snap.race = Str(race) or snap.race
    local className, classFile = UnitClass("player")
    snap.className, snap.class = Str(className) or snap.className, Str(classFile) or snap.class
    local guild, rank = nil, nil
    if GetGuildInfo then guild, rank = GetGuildInfo("player") end
    snap.guild, snap.guildRank = Str(guild), Str(rank)
    snap.gold = N(GetMoney and GetMoney()) or snap.gold
    snap.played = N(ch.c.played_server) or snap.played
    if GetXPExhaustion then snap.rested = N(GetXPExhaustion()) or 0 end
    snap.xp, snap.xpMax = N(UnitXP and UnitXP("player")), N(UnitXPMax and UnitXPMax("player"))
    snap.zone = Str(GetRealZoneText and GetRealZoneText()) or snap.zone
    snap.subzone = Str(GetSubZoneText and GetSubZoneText())
    snap.hearth = Str(GetBindLocation and GetBindLocation()) or snap.hearth
    local il = ns.AvgItemLevel and ns.AvgItemLevel()
    snap.ilvl = N(il) or snap.ilvl
    snap.bagFree, snap.bagTotal = BagSpace()
    if GetCurrentTitle and GetTitleName then
        local okT, id = pcall(GetCurrentTitle)
        if okT and N(id) and id > 0 then
            local okN, name = pcall(GetTitleName, id)
            snap.title = okN and Str(name) and (name:gsub("^%s+", ""):gsub("%s+$", "")) or nil
        else
            snap.title = nil
        end
    end
    snap.titleLTS = ns.TitledName and Str(ns.TitledName()) or nil
    snap.profs = Professions()
    snap.locks = Lockouts()
    snap.rep = BestReputation() or snap.rep
    ch.snap = snap
    Max("max_bag_slots", snap.bagTotal or 0)
    return snap
end

On("PLAYER_ENTERING_WORLD", function()
    if C_Timer then C_Timer.After(5, function() pcall(ns.TakeSnapshot) end) end
end)
On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(60, function() pcall(ns.TakeSnapshot) end) end
end)
On("PLAYER_LOGOUT", function() pcall(ns.TakeSnapshot) end)
On("PLAYER_MONEY", function() if ns.char and ns.char.snap then ns.char.snap.gold = N(GetMoney()) or ns.char.snap.gold end end)
On("UPDATE_INSTANCE_INFO", function() if ns.char and ns.char.snap then ns.char.snap.locks = Lockouts() end end)

-- Every character, newest login first: { key, rec, snap, name, realm }.
function ns.RosterCharacters()
    local out = {}
    for key, rec in pairs((ns.db and ns.db.chars) or {}) do
        if ns.ValidRecord(rec) then
            out[#out + 1] = { key = key, rec = rec, snap = rec.snap or {}, name = rec.meta.name or key, realm = rec.meta.realm }
        end
    end
    table.sort(out, function(a, b)
        local ta, tb = a.snap.t or 0, b.snap.t or 0
        if ta ~= tb then return ta > tb end
        return a.key < b.key
    end)
    return out
end

-- Account totals over every character's snapshot.
function ns.RosterTotals()
    local t = { chars = 0, gold = 0, played = 0, levels = 0, rested = 0, maxLevel = 0, unseen = 0 }
    for _, c in ipairs(ns.RosterCharacters()) do
        t.chars = t.chars + 1
        t.gold = t.gold + (c.snap.gold or 0)
        if not c.snap.t then t.unseen = t.unseen + 1 end
        t.played = t.played + (c.snap.played or c.rec.c.played_server or 0)
        local lvl = c.snap.level or c.rec.meta.level or 0
        t.levels = t.levels + lvl
        if lvl > t.maxLevel then t.maxLevel = lvl end
    end
    return t
end

-- ------------------------------------------------------------ people you grouped with
-- rec.people[name] = { f first grouped, l last seen in your group, n groups joined,
-- t seconds grouped, cls class file, lvl last level, z zone first met }.
local inGroup = {} -- names in the group right now (to count each joining once)

local function GroupUnits()
    local units = {}
    local raid = IsInRaid and B(IsInRaid())
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if S(n) or type(n) ~= "number" then n = 0 end
    for i = 1, raid and n or math.max(0, n - 1) do units[#units + 1] = (raid and "raid" or "party") .. i end
    return units
end

local function Prune(people)
    local list = {}
    for name, p in pairs(people) do list[#list + 1] = { name, p.l or 0 } end
    if #list <= PEOPLE_CAP then return end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i = PEOPLE_CAP + 1, #list do people[list[i][1]] = nil end
end

function ns.UpdatePeople()
    local ch = ns.char
    if not ch then return end
    ch.people = ch.people or {}
    local now, seen, me = time(), {}, UnitName("player")
    for _, u in ipairs(GroupUnits()) do
        local name, realm = UnitName(u)
        name, realm = Str(name), Str(realm)
        if name and name ~= me and name ~= UNKNOWNOBJECT then
            local key = realm and (name .. "-" .. realm) or name
            seen[key] = true
            local p = ch.people[key]
            if not p then
                p = { f = now, n = 0, t = 0, z = Str(GetRealZoneText and GetRealZoneText()) }
                ch.people[key] = p
                Add("people_met")
            end
            if not inGroup[key] then
                p.n = (p.n or 0) + 1
                Add("people_groupings")
            end
            p.l = now
            local _, cls = UnitClass(u)
            p.cls = Str(cls) or p.cls
            local lvl = N(UnitLevel(u))
            if lvl and lvl > 0 then p.lvl = lvl end
        end
    end
    inGroup = seen
    Prune(ch.people)
end
On("GROUP_ROSTER_UPDATE", function() pcall(ns.UpdatePeople) end)
On("PLAYER_ENTERING_WORLD", function() pcall(ns.UpdatePeople) end)

-- Grouped seconds per person, every 5 seconds while in a group.
local acc = 0
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", ns.Guard("people", function(_, el)
    acc = acc + el
    if acc < 5 then return end
    local dt = acc
    acc = 0
    local people = ns.char and ns.char.people
    if not people or not next(inGroup) then return end
    if dt > 120 then dt = 120 end
    local now = time()
    for key in pairs(inGroup) do
        local p = people[key]
        if p then p.t = (p.t or 0) + dt; p.l = now end
    end
end))

-- Everyone across the shown characters (account scope merges them).
function ns.RosterPeople()
    local merged = {}
    local recs = ns.GuideRecords and ns.GuideRecords() or { { rec = ns.char, name = "" } }
    for _, r in ipairs(recs) do
        for name, p in pairs((r.rec and r.rec.people) or {}) do
            if type(p) == "table" then
                local m = merged[name]
                if not m then
                    m = { name = name, f = p.f, l = p.l, n = 0, t = 0, cls = p.cls, lvl = p.lvl, z = p.z, with = {} }
                    merged[name] = m
                end
                m.n, m.t = m.n + (p.n or 0), m.t + (p.t or 0)
                if (p.f or math.huge) < (m.f or math.huge) then m.f, m.z = p.f, p.z or m.z end
                if (p.l or 0) > (m.l or 0) then m.l, m.lvl, m.cls = p.l, p.lvl or m.lvl, p.cls or m.cls end
                m.with[#m.with + 1] = r.name
            end
        end
    end
    local list = {}
    for _, m in pairs(merged) do list[#list + 1] = m end
    table.sort(list, function(a, b) if a.t ~= b.t then return a.t > b.t end return a.name < b.name end)
    return list
end

-- ------------------------------------------------------------ farming value of loot
-- Vendor value of what you loot, from the item's sell price when the client has it cached.
local function SellPrice(link)
    local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not info then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, price = pcall(info, link)
    if ok then return N(price) end
end
local lootHook = ns.OnLootItem
function ns.OnLootItem(link, qty, quality)
    if lootHook then lootHook(link, qty, quality) end
    if not ns.char or type(link) ~= "string" or S(link) then return end
    local price = SellPrice(link)
    if price and price > 0 then
        local value = price * (tonumber(qty) or 1)
        Add("loot_value", value)
        ns.Max("max_loot_value", value, link:match("%[(.-)%]"))
        if type(quality) == "number" then Add("loot_value_q" .. quality, value) end
    else
        Add("loot_unpriced", tonumber(qty) or 1)
    end
end

-- Rates for a session-log row: per hour of active (non-AFK) time.
function ns.SessionRates(e)
    local active = math.max(0, (e.d or 0) - (e.afk or 0))
    local h = active / 3600
    if h <= 0 then return { active = active } end
    return {
        active = active, gold = (e.g or 0) / h, xp = (e.xp or 0) / h, kills = (e.k or 0) / h,
        value = (e.lv or 0) / h, items = (e.it or 0) / h,
    }
end

-- Called by LogSession after it fills the row: adds money and loot, and best rates.
function ns.LogSessionFarming(e, c)
    e.g = math.floor((c.money_in or 0) - (c.money_out or 0))
    e.mi = math.floor(c.money_in or 0)
    e.lv = math.floor(c.loot_value or 0)
    e.it = math.floor(c.items_looted or 0)
    local r = ns.SessionRates(e)
    if (r.active or 0) >= 600 then -- only sessions with 10+ active minutes set rate records
        local when = date("%b %d", e.s or time())
        if (r.gold or 0) > 0 then Max("max_gold_per_hour", r.gold, when) end
        if (r.xp or 0) > 0 then Max("max_xp_per_hour", r.xp, when) end
        if (r.kills or 0) > 0 then Max("max_kills_per_hour", r.kills, when) end
        if (r.value or 0) > 0 then Max("max_value_per_hour", r.value, when) end
    end
end

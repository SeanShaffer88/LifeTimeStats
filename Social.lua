-- LifeTimeStats - extensive logging: chat, whispers, friends, barber, mounts/pets owned,
-- flight paths known, loot rolls, merchants, summons, spirit healer, professions, broken gear.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local B = ns.Bool
local Add, Max, Tally, Unique, First, On = ns.Add, ns.Max, ns.Tally, ns.Unique, ns.First, ns.On
local S = ns.IsSecret

local function Str(v) if S(v) or type(v) ~= "string" or v == "" then return nil end return v end
local function Me(sender)
    sender = Str(sender)
    local me = UnitName("player")
    if not sender or not me then return false end
    return sender == me or sender:find("^" .. me .. "%-") ~= nil
end
local function Short(name) name = Str(name) return name and (name:match("^([^%-]+)") or name) end

-- ------------------------------------------------------------ chat you send, by channel
local CHAN = {
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell", CHAT_MSG_EMOTE = "emote_text",
    CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_RAID_WARNING = "raid", CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
    CHAT_MSG_INSTANCE_CHAT = "instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "instance", CHAT_MSG_CHANNEL = "channel",
}
for ev, kind in pairs(CHAN) do
    On(ev, function(_, msg, sender)
        if not Me(sender) then
            if ev == "CHAT_MSG_SAY" or ev == "CHAT_MSG_YELL" then Add("heard_" .. kind) end
            return
        end
        Add("chat_sent"); Add("chat_" .. kind)
        if type(msg) == "string" and not S(msg) then
            Add("chars_typed", #msg)
            if msg:find("%?$") then Add("questions_asked") end
            if msg:find("!$") then Add("exclamations") end
            local lower = msg:lower()
            if lower:find("lol") or lower:find("haha") or lower:find("lmao") then Add("lols") end
            if lower:find("thank") or lower:find("^ty") or lower:find(" ty") then Add("thanks_said") end
            if lower:find("^hi") or lower:find("^hello") or lower:find("^hey") then Add("greetings") end
        end
    end)
end

-- ------------------------------------------------------------ whispers
On("CHAT_MSG_WHISPER", function(_, msg, sender)
    Add("whispers_in")
    local who = Short(sender)
    if who then Tally("whisperers", who); Unique("whisperers", who); First("whisper_in", who) end
end)
On("CHAT_MSG_WHISPER_INFORM", function(_, msg, target)
    Add("whispers_sent"); Add("chat_sent"); Add("chat_whisper")
    local who = Short(target)
    if who then Tally("whispered", who); Unique("whispered", who); First("whisper_out", who) end
end)
On("CHAT_MSG_BN_WHISPER", function() Add("bn_whispers_in") end)
On("CHAT_MSG_BN_WHISPER_INFORM", function() Add("bn_whispers_sent") end)

-- ------------------------------------------------------------ friends, ignore, invites, guild
local function Hook(tbl, name, fn)
    if type(tbl) == "string" then if type(_G[tbl]) == "function" then hooksecurefunc(tbl, name) end
    elseif type(tbl) == "table" and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) end
end
local function InstallHooks()
    Hook("AddFriend", function() Add("friends_added") end)
    Hook(C_FriendList, "AddFriend", function() Add("friends_added") end)
    Hook("RemoveFriend", function() Add("friends_removed") end)
    Hook(C_FriendList, "RemoveFriend", function() Add("friends_removed") end)
    Hook("AddIgnore", function() Add("players_ignored") end)
    Hook(C_FriendList, "AddIgnore", function() Add("players_ignored") end)
    Hook("InviteUnit", function() Add("invites_sent") end)
    Hook(C_PartyInfo, "InviteUnit", function() Add("invites_sent") end)
    Hook("AcceptGroup", function() Add("invites_accepted") end)
    Hook("DeclineGroup", function() Add("invites_declined") end)
    Hook("LeaveParty", function() Add("groups_left") end)
    Hook(C_PartyInfo, "LeaveParty", function() Add("groups_left") end)
    Hook("RollOnLoot", function(_, rollType)
        if rollType == 1 then Add("rolls_need") elseif rollType == 2 then Add("rolls_greed") elseif rollType == 0 then Add("rolls_pass") end
    end)
    Hook("BuyMerchantItem", function(_, qty) Add("items_bought", tonumber(qty) or 1) end)
    Hook("BuybackItem", function() Add("buybacks") end)
    local function Sold()
        if MerchantFrame and MerchantFrame:IsShown() then Add("items_sold") end
    end
    Hook(C_Container, "UseContainerItem", Sold)
    Hook("UseContainerItem", Sold)
    Hook("AcceptXPLoss", function() Add("spirit_healer") end)
    Hook(C_SummonInfo, "ConfirmSummon", function() Add("summons_accepted") end)
    Hook("ConfirmSummon", function() Add("summons_accepted") end)
    Hook("AcceptTrade", function() Add("trades_accepted") end)
    Hook("StartAuction", function() Add("auctions_posted") end)
    Hook(C_AuctionHouse, "PostItem", function() Add("auctions_posted") end)
    Hook("PlaceAuctionBid", function() Add("auction_bids") end)
    Hook("TakeInboxItem", function() Add("mail_items_taken") end)
    Hook("TakeInboxMoney", function() Add("mail_money_taken") end)
    Hook("ReturnInboxItem", function() Add("mail_returned") end)
    Hook("PickupMerchantItem", function() end)
    Hook("Dismount", function() Add("dismounts") end)
    Hook("SetRaidTarget", function() Add("raid_marks") end)
    Hook("DoReadyCheck", function() Add("ready_checks") end)
    Hook("ToggleWorldMap", function() end)
    Hook("TakeScreenshot", function() end)
end
On("PLAYER_GUILD_UPDATE", function()
    local g = IsInGuild and B(IsInGuild()) and GetGuildInfo and Str((GetGuildInfo("player")))
    if g and Unique("guilds", g) then First("guild", g); if ns.Journal then ns.Journal("Joined guild <" .. g .. ">") end end
end)
On("GUILD_INVITE_REQUEST", function() Add("guild_invites") end)
On("DUEL_FINISHED", function() Add("duels_finished") end)
On("READY_CHECK", function() Add("ready_checks_seen") end)

-- ------------------------------------------------------------ barber
local barberMoney
On("BARBER_SHOP_OPEN", function() Add("barber_visits"); barberMoney = GetMoney() end)
On("BARBER_SHOP_APPEARANCE_APPLIED", function()
    Add("haircuts"); First("haircut", "barber")
    if ns.Journal then ns.Journal("Got a new look at the barber") end
end)
On("BARBER_SHOP_CLOSE", function()
    local m = GetMoney()
    if barberMoney and type(m) == "number" and not S(m) and m < barberMoney then Add("money_barber", barberMoney - m) end
    barberMoney = nil
end)

-- ------------------------------------------------------------ mounts and pets owned, flight paths known
local function CountOwned()
    if C_MountJournal and C_MountJournal.GetNumDisplayedMounts and C_MountJournal.GetMountIDs then
        local ok, ids = pcall(C_MountJournal.GetMountIDs)
        if ok and type(ids) == "table" then
            local n = 0
            for _, id in ipairs(ids) do
                local ok2, _, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, id)
                if ok2 and collected and not S(collected) then n = n + 1 end
            end
            if n > 0 then Max("mounts_owned", n) end
        end
    elseif GetNumCompanions then
        local ok, n = pcall(GetNumCompanions, "MOUNT")
        if ok and type(n) == "number" and not S(n) and n > 0 then Max("mounts_owned", n) end
    end
    if GetNumCompanions then
        local ok, n = pcall(GetNumCompanions, "CRITTER")
        if ok and type(n) == "number" and not S(n) and n > 0 then Max("pets_owned", n) end
    end
    if C_PetJournal and C_PetJournal.GetNumPets then
        local ok, _, owned = pcall(C_PetJournal.GetNumPets)
        if ok and type(owned) == "number" and not S(owned) and owned > 0 then Max("pets_owned", owned) end
    end
end
On("COMPANION_LEARNED", function() C_Timer.After(1, CountOwned) end)
On("NEW_MOUNT_ADDED", function() Add("mounts_learned"); C_Timer.After(1, CountOwned) end)
On("NEW_PET_ADDED", function() Add("pets_learned"); C_Timer.After(1, CountOwned) end)

On("TAXIMAP_OPENED", function()
    if not NumTaxiNodes then return end
    local ok, n = pcall(NumTaxiNodes)
    if not ok or type(n) ~= "number" or S(n) then return end
    local known = 0
    for i = 1, n do
        local okT, t = pcall(TaxiNodeGetType, i)
        if okT and (t == "REACHABLE" or t == "CURRENT") then
            known = known + 1
            local okN, name = pcall(TaxiNodeName, i)
            if okN and Str(name) then Unique("flightpoints", name) end
        end
    end
    Max("flightpaths_known", known)
end)

-- ------------------------------------------------------------ system lines: spells, professions, loot rolls, repairs
local lastRepair = -10
On("UPDATE_INVENTORY_DURABILITY", function() lastRepair = GetTime() end)
On("UPDATE_INVENTORY_ALERTS", function()
    if GetInventoryAlertStatus then
        for slot = 1, 19 do
            local ok, st = pcall(GetInventoryAlertStatus, slot)
            if ok and st == 2 then Add("gear_broken_seen"); return end
        end
    end
end)
On("CHAT_MSG_SYSTEM", function(_, msg)
    if S(msg) or type(msg) ~= "string" then return end
    local skill = msg:match("^You have gained the (.+) skill%.")
    if skill then Add("skills_learned"); Unique("professions", skill); First("profession", skill)
        if ns.Journal then ns.Journal("Learned " .. skill) end return end
    if msg:find("^You have learned a new spell") or msg:find("^You have learned a new ability") then Add("abilities_learned") return end
    if msg:find("^You have learned how to create") then Add("recipes_learned") return end
    local rep = msg:match("^Repaired for (.+)%.")
    if rep then Add("repair_lines") return end
end)
On("CHAT_MSG_LOOT", function(_, msg)
    if S(msg) or type(msg) ~= "string" then return end
    if msg:find("^You won") then Add("rolls_won") end
end)
On("CHAT_MSG_OPENING", function() Add("objects_opened_lines") end)

-- ------------------------------------------------------------ logins by hour
On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin then
        Tally("loginhour", date("%H") .. ":00")
        C_Timer.After(5, CountOwned)
    end
end)

function ns.InstallSocialHooks() InstallHooks() end

-- ------------------------------------------------------------ damage meter dump (/lts dm)
local function Dump(v, depth, prefix, out, maxDepth)
    maxDepth = maxDepth or 2
    if #out > 600 then return end
    if S(v) then out[#out + 1] = prefix .. " = <secret>" return end
    if type(v) ~= "table" then out[#out + 1] = prefix .. " = " .. tostring(v) .. " (" .. type(v) .. ")" return end
    if depth > maxDepth then out[#out + 1] = prefix .. " = {...}" return end
    local n = 0
    for k, x in pairs(v) do
        n = n + 1
        if n > 30 then out[#out + 1] = prefix .. ".… more" break end
        Dump(x, depth + 1, prefix .. "." .. tostring(k), out, maxDepth)
    end
    if n == 0 then out[#out + 1] = prefix .. " = {}" end
end
function ns.DumpDamageMeter()
    local DM = C_DamageMeter
    if type(DM) ~= "table" then ns.Print("No C_DamageMeter on this client.") return end
    local out = {}
    local okS, sessions = pcall(DM.GetAvailableCombatSessions)
    local newest
    if okS and type(sessions) == "table" then
        for _, x in pairs(sessions) do
            if type(x) == "table" and type(x.sessionID) == "number" and (not newest or x.sessionID > newest.sessionID) then newest = x end
        end
        out[#out + 1] = "sessions: " .. #sessions .. (newest and (", newest id " .. newest.sessionID .. " (" .. tostring(newest.name) .. ")") or "")
    end
    local id = newest and newest.sessionID or 0
    local me = UnitGUID("player")
    -- 1.10: the per-spell detail table (biggest hit?), damage taken, avoidable, deaths, enemy damage.
    local function Add(label, res, depth, cap)
        local sub = {}
        Dump(res, 0, label, sub, depth)
        for k = 1, math.min(#sub, (cap or 10) * 4) do out[#out + 1] = sub[k] end
    end
    local function Try(fname, a, b, c)
        local fn = DM[fname]
        if type(fn) ~= "function" then return "missing" end
        local ok, res = pcall(fn, a, b, c)
        return ok and res or ("error: " .. tostring(res))
    end
    local dmg = Try("GetCombatSessionSourceFromID", id, 0, me)
    local sp = type(dmg) == "table" and type(dmg.combatSpells) == "table" and dmg.combatSpells[1]
    Add("damage spell 1 details", type(sp) == "table" and sp.combatSpellDetails or "none", 4, 24)
    local src = Try("GetCombatSessionFromID", id, 0)
    local s1 = type(src) == "table" and type(src.combatSources) == "table" and src.combatSources[1]
    Add("damage source 1", s1 or "none", 1, 16)
    Add("taken(7) by you", Try("GetCombatSessionSourceFromID", id, 7, me), 3, 12)
    Add("avoidable(8)", Try("GetCombatSessionSourceFromID", id, 8, me), 2, 6)
    Add("deaths(9) session", Try("GetCombatSessionFromID", id, 9), 2, 6)
    Add("enemy damage taken(10)", Try("GetCombatSessionFromID", id, 10), 2, 8)
    Add("interrupts(5)", Try("GetCombatSessionSourceFromID", id, 5, me), 1, 3)
    Add("C_DeathRecap", type(C_DeathRecap) == "table" and "present" or "missing", 0, 1)
    -- last few fights
    if okS and type(sessions) == "table" then
        local list = {}
        for _, x in pairs(sessions) do if type(x) == "table" and type(x.sessionID) == "number" then list[#list + 1] = x end end
        table.sort(list, function(a, b) return a.sessionID > b.sessionID end)
        for i = 1, math.min(5, #list) do
            out[#out + 1] = string.format("fight %d: %s, %s s", list[i].sessionID, tostring(list[i].name), tostring(list[i].durationSeconds))
        end
    end
    -- your last death recap (the killing blow is event 1)
    if type(C_DeathRecap) == "table" and type(C_DeathRecap.GetRecapEvents) == "function" then
        local rid = (ns.char and ns.char.meta.lastRecap) or (ns.DMMyRecapID and ns.DMMyRecapID())
        if rid then
            local ok, ev = pcall(C_DeathRecap.GetRecapEvents, rid)
            Add("death recap " .. rid, ok and ev or "error", 2, 12)
        else
            out[#out + 1] = "death recap: none seen yet"
        end
    end
    for _, line in ipairs(out) do ns.Print(line) end
end

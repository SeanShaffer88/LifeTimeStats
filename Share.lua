-- LifeTimeStats - share a stat line to chat (only ever on an explicit click or command)
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local MAX = 250
local function c(v, k) return (v.c and v.c[k]) or 0 end
local function Int(n) return ns.FormatInt(n) end
local function T(n) return ns.FormatTime(n) end
-- Plain-text money (chat rejects colour codes)
local function Gold(cp)
    cp = math.floor(cp or 0)
    local neg = cp < 0
    if neg then cp = -cp end
    local g, s = math.floor(cp / 10000), math.floor((cp % 10000) / 100)
    local out = (g > 0) and (Int(g) .. "g " .. s .. "s") or (s .. "s " .. (cp % 100) .. "c")
    return neg and ("-" .. out) or out
end
local function Yd(y) return y >= 1760 and string.format("%.1f mi", y / 1760) or (Int(y) .. " yd") end
local function Strip(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "")
        :gsub("[%z\1-\31\127]+", " "):match("^%s*(.-)%s*$"))
end

local function CutUTF8(text, limit)
    if #text <= limit then return text end
    local boundary = limit + 1
    while boundary > 1 do
        local byte = text:byte(boundary)
        if byte < 128 or byte >= 192 then break end
        boundary = boundary - 1
    end
    return text:sub(1, boundary - 1)
end

local TOPICS = {}
TOPICS.dashboard = function(v)
    return string.format("%s steps, %s jumps, %s kills (%s players), %s deaths, %s quests, %s dungeon bosses",
        Int(ns.Steps(v)), Int(c(v, "jumps")), Int(ns.Kills(v)), Int(c(v, "kills_pvp")), Int(c(v, "deaths")), Int(c(v, "quests_done")), Int(c(v, "boss_kills_party")))
end
TOPICS.travel = function(v)
    return string.format("Travelled %s: %s on foot (%s steps), %s mounted, %s by flight path, %s swimming; jumped %s times",
        Yd(c(v, "dist_total")), Yd(c(v, "dist_foot")), Int(ns.Steps(v)), Yd(c(v, "dist_mount")), Yd(c(v, "dist_taxi")), Yd(c(v, "dist_swim")), Int(c(v, "jumps")))
end
TOPICS.combat = function(v)
    return string.format("%s damage (%.1f DPS), %s crits (%.1f%%), dodged %s and parried %s attacks, %s kills, %s killing blows",
        Int(c(v, "dmg_done")), ns.Div(c(v, "dmg_done"), c(v, "time_combat")), Int(c(v, "crits")), ns.Div(c(v, "crits") * 100, c(v, "hits")),
        Int(c(v, "in_dodge")), Int(c(v, "in_parry")), Int(ns.Kills(v)), Int(c(v, "killing_blows")))
end
TOPICS.deaths = function(v)
    local top = ns.TopList(v, "killers", 1)[1]
    return string.format("Died %s times (%s from falling, %s drowned), %s corpse runs, longest %s; killed most by %s",
        Int(c(v, "deaths")), Int(c(v, "deaths_fall")), Int(c(v, "deaths_drown")), Int(c(v, "corpse_runs")),
        T((v.r and v.r.max_corpse_time) or 0), top and tostring(top[1]) or "nobody yet")
end
TOPICS.adventure = function(v)
    return string.format("%s quests done, %s levels, %s dungeon runs, %s dungeon bosses, %s raid bosses, %s raid clears, %s fish",
        Int(c(v, "quests_done")), Int(c(v, "levels")), Int(c(v, "runs_party")), Int(c(v, "boss_kills_party")), Int(c(v, "boss_kills_raid")), Int(c(v, "raid_clears")), Int(c(v, "fish")))
end
TOPICS.wealth = function(v)
    return string.format("Earned %s, spent %s (%s on repairs), looted %s items incl. %s epics",
        Gold(c(v, "money_in")), Gold(c(v, "money_out")), Gold(c(v, "money_repair")), Int(c(v, "items_looted")), Int(c(v, "loot_q4")))
end
TOPICS.social = function(v)
    return string.format("%s dances, %s hugs, %s chickens, %s /rolls (%s perfect), %s red errors seen, AFK for %s",
        Int(c(v, "emote_DANCE")), Int(c(v, "emote_HUG")), Int(c(v, "emote_CHICKEN")), Int(c(v, "rolls")), Int(c(v, "rolls_max")), Int(c(v, "ui_errors")), T(c(v, "time_afk")))
end
TOPICS.records = function(v)
    local r = v.r or {}
    return string.format("Biggest hit %s (%s), biggest crit %s, biggest fall survived %s, longest corpse run %s, kill streak %s",
        Int(r.max_hit or 0), r.max_hit_what or "?", Int(r.max_crit or 0), Int(r.max_fall_survived or 0), T(r.max_corpse_time or 0), Int(r.max_streak or 0))
end
TOPICS.fastest = function(v)
    local f, un = v.f or {}, v.un or {}
    return string.format("Fastest level %s, quest %s, 10 kills %s, corpse run %s; met %s NPCs, killed %s creature types",
        f.level_fast and T(f.level_fast) or "-", f.quest_fast and T(f.quest_fast) or "-", f.ten_kills and T(f.ten_kills) or "-",
        f.corpse_fast and T(f.corpse_fast) or "-", Int(un.npcs or 0), Int(un.creatures or 0))
end
TOPICS.achievements = function(v)
    local e, t, pts = ns.AchTotals(v)
    return string.format("%d of %d achievements, %s points", e, t, Int(pts))
end
TOPICS.timeline = function()
    local d = ns.char.days[ns.Today()] or {}
    return string.format("Today: %s steps, %s kills, %s deaths, %s quests, %s XP, %s online",
        Int((d.dist_foot or 0) * ns.YARDS_TO_STEPS), Int((d.kills_npc or 0) + (d.kills_pvp or 0)), Int(d.deaths or 0),
        Int(d.quests_done or 0), Int(d.xp or 0), T(d.time_online or 0))
end
TOPICS.lists = TOPICS.dashboard
TOPICS.help = TOPICS.dashboard
TOPICS.search = TOPICS.dashboard
TOPICS.summary = TOPICS.dashboard
ns.SHARE_TOPICS = TOPICS

function ns.ShareText(topic, view)
    view = view or ns.char
    local fn = TOPICS[topic] or TOPICS.dashboard
    local who = (UnitName("player") or "")
    if ns.settings.scope == "account" and view ~= ns.char then who = who .. " (all characters)" end
    local ok, body = pcall(fn, view)
    if not ok then body = TOPICS.dashboard(ns.char) end
    local s = Strip("[LifeTimeStats] " .. who .. ": " .. body)
    if #s > MAX then s = CutUTF8(s, MAX - 3) .. "..." end
    return s
end

-- Channels the player can actually use right now.
function ns.ShareChannels()
    local list = { { "SAY", "Say" } }
    if IsInGroup and ns.Bool(IsInGroup()) then list[#list + 1] = { "PARTY", "Party" } end
    if IsInRaid and ns.Bool(IsInRaid()) then list[#list + 1] = { "RAID", "Raid" } end
    if IsInGuild and ns.Bool(IsInGuild()) then list[#list + 1] = { "GUILD", "Guild" } end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and ns.Bool(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then list[#list + 1] = { "INSTANCE_CHAT", "Instance" } end
    return list
end

local ALIASES = { s = "SAY", say = "SAY", p = "PARTY", party = "PARTY", r = "RAID", raid = "RAID", g = "GUILD", guild = "GUILD", i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT" }

local function Send(text, channel)
    if type(text) ~= "string" or ns.IsSecret(text) then return false end
    text = CutUTF8(Strip(text), 255)
    if text == "" then return false end
    local available = false
    for _, entry in ipairs(ns.ShareChannels()) do
        if entry[1] == channel then available = true; break end
    end
    if not available then ns.Print("That chat channel is no longer available."); return false end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false end
    local ok, result = pcall(send, text, channel)
    if not ok or result == false then
        ns.Print("Could not post to " .. channel:lower() .. (not ok and (": " .. tostring(result)) or "."))
        return false
    end
    ns.Add("shares")
    return true
end
ns.ShareSend = Send

-- /lts share [channel] [topic]   e.g. /lts share p deaths
function ns.ShareCommand(args)
    local a, b = (args or ""):match("^%s*(%S*)%s*(%S*)%s*$")
    if not a or (b ~= "" and not ALIASES[a:lower()]) then
        ns.Print("Usage: /lts share [channel] [topic]")
        return
    end
    local channel = ALIASES[(a or ""):lower()]
    local topic = channel and b or a
    topic = (topic and topic ~= "") and topic:lower() or "summary"
    if not TOPICS[topic] then
        ns.Print("Share topics: summary, travel, combat, deaths, adventure, wealth, social, records, fastest, achievements, timeline")
        return
    end
    if channel then
        Send(ns.ShareText(topic), channel)
    else
        ns.ShowShare(topic)
    end
end

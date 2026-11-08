-- LifeTimeStats - stat definitions and formatting
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

-- Average stride used to turn distance on foot into steps (0.75 m per step).
ns.YARDS_TO_STEPS = 0.9144 / 0.75

local floor = math.floor

local function Int(n)
    n = floor((n or 0) + 0.5)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end
ns.FormatInt = Int

local function Time(s)
    s = s or 0
    if s <= 0 then return "0s" end
    if s < 10 then return string.format("%.1fs", s) end
    s = floor(s)
    local d = floor(s / 86400); s = s - d * 86400
    local h = floor(s / 3600);  s = s - h * 3600
    local m = floor(s / 60);    s = s - m * 60
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %02dm", h, m) end
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return string.format("%ds", s)
end
ns.FormatTime = Time

local function Money(c)
    c = floor(c or 0)
    local neg = c < 0
    if neg then c = -c end
    local g = floor(c / 10000)
    local s = floor((c % 10000) / 100)
    local cp = c % 100
    local out
    if g > 0 then
        out = string.format("%s|cffffd100g|r %d|cffc7c7cfs|r %d|cffeda55fc|r", Int(g), s, cp)
    elseif s > 0 then
        out = string.format("%d|cffc7c7cfs|r %d|cffeda55fc|r", s, cp)
    else
        out = string.format("%d|cffeda55fc|r", cp)
    end
    return neg and ("-" .. out) or out
end
ns.FormatMoney = Money

local function Yards(y)
    y = y or 0
    if y >= 1760 then return string.format("%s yd (%.1f mi)", Int(y), y / 1760) end
    return Int(y) .. " yd"
end

local FMT = {
    int   = Int,
    time  = Time,
    money = Money,
    yards = Yards,
    speed = function(v) return string.format("%d%%", floor((v or 0) / 7 * 100 + 0.5)) end,
    ratio = function(v) return string.format("%.2f", v or 0) end,
    num1  = function(v) return string.format("%.1f", v or 0) end,
    pct   = function(v) return string.format("%.1f%%", v or 0) end,
    level = function(v) return tostring(floor(v or 0)) end,
    sec   = function(v) return string.format("%.2fs", v or 0) end,
}
ns.FMT = FMT

local function C(v, k) return v.c[k] or 0 end
local function Div(a, b) if not b or b <= 0 then return 0 end return a / b end
ns.Div = Div

ns.CATEGORIES = {
    { id = "dashboard", name = "Dashboard",         icon = "dashboard", key = "1" },
    { id = "travel",    name = "Travel",            icon = "travel",    key = "2" },
    { id = "combat",    name = "Combat",            icon = "combat",    key = "3" },
    { id = "deaths",    name = "Deaths",            icon = "deaths",    key = "4" },
    { id = "adventure", name = "Adventure",         icon = "adventure", key = "5" },
    { id = "wealth",    name = "Wealth & Loot",     icon = "wealth",    key = "6" },
    { id = "social",    name = "Social & Silly",    icon = "social",    key = "7" },
    { id = "life",      name = "Adventurer's Life", short = "Adventurer's Life", icon = "scroll", key = "J" },
    { id = "records",   name = "Records",           icon = "records",   key = "8" },
    { id = "fastest",   name = "Fastest & Uniques", short = "Fastest/Uniques", icon = "fastest",   key = "F" },
    { id = "lists",     name = "Top Lists",         icon = "lists",     key = "9" },
    { id = "timeline",  name = "Timeline",          icon = "timeline",  key = "0" },
    { id = "journal",   name = "Journal",           icon = "scroll",    key = "L" },
    { id = "achievements", name = "Achievements",   icon = "trophy",    key = "A" },
    { id = "compare",   name = "Compare",           icon = "person",    key = "C" },
    { id = "help",      name = "How it works",      icon = "scroll",    key = "H" },
}

local function Steps(v) return C(v, "dist_foot") * ns.YARDS_TO_STEPS end
local function Kills(v) return C(v, "kills_npc") + C(v, "kills_pvp") end
ns.Steps, ns.Kills = Steps, Kills

-- Each stat: label, fmt, tip, and one of: key (counter), rec (max record), get(view).
ns.STATS = {
    travel = {
        { label = "Total distance", fmt = "yards", key = "dist_total", tip = "Everything: feet, mounts, swimming, flights and ghost runs." },
        { label = "On foot", fmt = "yards", key = "dist_foot", tip = "Walking or running, including travel and cat forms." },
        { label = "Steps taken", fmt = "int", get = Steps, tip = "On-foot distance / 0.75 m stride." },
        { label = "Mounted", fmt = "yards", key = "dist_mount" },
        { label = "Swimming", fmt = "yards", key = "dist_swim" },
        { label = "Flight paths", fmt = "yards", key = "dist_taxi" },
        { label = "As a ghost", fmt = "yards", key = "dist_ghost", tip = "Corpse runs." },
        { label = "Times jumped", fmt = "int", key = "jumps", tip = "Jumps that actually left the ground." },
        { label = "Time in the air", fmt = "time", key = "airtime", tip = "Total time spent falling or jumping." },
        { label = "Big falls (3 s+ in the air)", fmt = "int", key = "big_falls" },
        { label = "Flights taken", fmt = "int", key = "flights" },
        { label = "Hearthstone uses", fmt = "int", key = "hearths" },
        { label = "Hearthstone set", fmt = "int", key = "hearth_binds" },
        { label = "Times mounted up", fmt = "int", key = "mount_ups" },
        { label = "Shapeshifts", fmt = "int", key = "shapeshifts", tip = "Form changes (Druid forms, Ghost Wolf, stances...)." },
        { label = "Times you sat down", fmt = "int", key = "sits" },
        { label = "Auto-run toggles", fmt = "int", key = "autoruns" },
        { label = "Times followed someone", fmt = "int", key = "follows" },
        { label = "Time mounted", fmt = "time", key = "time_mounted" },
        { label = "Time swimming", fmt = "time", key = "time_swim" },
        { label = "Time on flight paths", fmt = "time", key = "time_taxi" },
        { label = "Time resting", fmt = "time", key = "time_rest" },
        { label = "Time indoors", fmt = "time", key = "time_indoors" },
        { label = "Time outdoors", fmt = "time", key = "time_outdoors" },
        { label = "Most visited capital", fmt = "time", get = function(v) local t = ns.TopList(v, "citytime", 1)[1] return t and t[2] or 0 end, label2 = "citytime", tip = "The capital city you have spent the most time in." },
        { label = "Most visited continent", fmt = "time", get = function(v) local t = ns.TopList(v, "continenttime", 1)[1] return t and t[2] or 0 end, label2 = "continenttime" },
        { label = "Most visited zone", fmt = "time", get = function(v) local t = ns.TopList(v, "zonetime", 1)[1] return t and t[2] or 0 end, label2 = "zonetime" },
        { label = "Inns / cities entered", fmt = "int", key = "rest_entered" },
        { label = "Zone changes", fmt = "int", key = "zone_changes" },
        { label = "Subzone changes", fmt = "int", key = "subzone_changes" },
        { label = "Zones discovered", fmt = "int", key = "zones_discovered", tip = "Exploration discovery messages." },
        { label = "Loading screens", fmt = "int", key = "loading_screens" },
    },
    combat = {
        { label = "Damage done", fmt = "int", key = "dmg_done", tip = "Damage from you (and your pet, if enabled in settings)." },
        { label = "Damage taken", fmt = "int", key = "dmg_taken" },
        { label = "Damage taken from players", fmt = "int", key = "dmg_taken_pvp" },
        { label = "Average damage per second", fmt = "num1", naKey = "dmg_done", get = function(v) return Div(C(v, "dmg_done"), C(v, "time_combat")) end, tip = "Damage done / time in combat." },
        { label = "Time in combat", fmt = "time", key = "time_combat" },
        { label = "Fights", fmt = "int", key = "fights", tip = "Times you entered combat." },
        { label = "Fight time (game damage meter)", fmt = "time", key = "dm_fight_time", tip = "Sum of fight lengths from Forever's built-in damage meter." },
        { label = "Fights won", fmt = "int", key = "fights_won", tip = "Combat ended alive with at least one kill." },
        { label = "Hits landed", fmt = "int", key = "hits" },
        { label = "Melee hits", fmt = "int", key = "melee_hits" },
        { label = "Spell hits", fmt = "int", key = "spell_hits" },
        { label = "Ranged hits", fmt = "int", key = "ranged_hits" },
        { label = "Damage-over-time ticks", fmt = "int", key = "dot_ticks" },
        { label = "Critical hits", fmt = "int", key = "crits" },
        { label = "Crit rate", fmt = "pct", get = function(v) return Div(C(v, "crits") * 100, C(v, "hits")) end },
        { label = "Glancing blows dealt", fmt = "int", key = "glancing_out" },
        { label = "Your attacks that missed", fmt = "int", key = "out_miss" },
        { label = "Your attacks dodged", fmt = "int", key = "out_dodge" },
        { label = "Your attacks parried", fmt = "int", key = "out_parry" },
        { label = "Your attacks blocked", fmt = "int", key = "out_block" },
        { label = "Your spells resisted", fmt = "int", key = "out_resist" },
        { label = "Your attacks absorbed", fmt = "int", key = "out_absorb" },
        { label = "Targets immune to you", fmt = "int", key = "out_immune" },
        { label = "Your attacks evaded", fmt = "int", key = "out_evade" },
        { label = "Hits taken", fmt = "int", key = "hits_taken" },
        { label = "Critical hits taken", fmt = "int", key = "crits_taken" },
        { label = "Crushing blows taken", fmt = "int", key = "crushing_in" },
        { label = "Attacks you dodged", fmt = "int", key = "in_dodge" },
        { label = "Attacks you parried", fmt = "int", key = "in_parry" },
        { label = "Attacks you blocked", fmt = "int", key = "in_block" },
        { label = "Partial blocks", fmt = "int", key = "blocks_partial_in" },
        { label = "Attacks that missed you", fmt = "int", key = "in_miss" },
        { label = "Spells you resisted", fmt = "int", key = "in_resist" },
        { label = "Damage absorbed on you", fmt = "int", key = "in_absorb" },
        { label = "Times you were immune", fmt = "int", key = "in_immune" },
        { label = "Spells you reflected", fmt = "int", key = "in_reflect" },
        { label = "Dodge rate", fmt = "pct", get = function(v) local a = C(v, "in_dodge") return Div(a * 100, a + C(v, "hits_taken") + C(v, "in_parry") + C(v, "in_block") + C(v, "in_miss")) end },
        { label = "Healing done", fmt = "int", key = "heal_done", tip = "Effective healing, overhealing excluded." },
        { label = "Healing on others", fmt = "int", key = "heal_others" },
        { label = "Healing on yourself", fmt = "int", key = "heal_self" },
        { label = "Overhealing", fmt = "int", key = "overheal" },
        { label = "Heals cast", fmt = "int", key = "heals" },
        { label = "Critical heals", fmt = "int", key = "heal_crits" },
        { label = "Healing received", fmt = "int", key = "heal_taken" },
        { label = "Killing blows", fmt = "int", key = "killing_blows" },
        { label = "Enemies killed", fmt = "int", key = "kills_npc", tip = "Creatures that died after you or your pet damaged them." },
        { label = "Enemy players killed", fmt = "int", key = "kills_pvp" },
        { label = "Grey kills (no XP level)", fmt = "int", key = "kills_grey" },
        { label = "Green kills", fmt = "int", key = "kills_green" },
        { label = "Yellow kills", fmt = "int", key = "kills_yellow" },
        { label = "Orange kills", fmt = "int", key = "kills_orange" },
        { label = "Red kills (5+ levels above you)", fmt = "int", key = "kills_red" },
        { label = "Elites killed", fmt = "int", key = "kills_elite" },
        { label = "Rares killed", fmt = "int", key = "kills_rare" },
        { label = "Critters loved, then killed", fmt = "int", key = "critters_love_kill", tip = "You used /love on it, then killed it." },
        { label = "Critters killed", fmt = "int", key = "critter_kills", tip = "Critters (rabbits, squirrels, roaches...) that died after you hit or cast at them. Not counted as enemies." },
        { label = "Honorable kills (server)", fmt = "int", key = "hk_server" },
        { label = "Honor gains", fmt = "int", key = "honor_events" },
        { label = "Spells cast", fmt = "int", key = "casts" },
        { label = "Casts failed", fmt = "int", key = "casts_failed" },
        { label = "Casts interrupted", fmt = "int", key = "casts_interrupted" },
        { label = "Interrupts", fmt = "int", key = "interrupts" },
        { label = "Dispels", fmt = "int", key = "dispels" },
        { label = "Overkill damage", fmt = "int", key = "overkill", tip = "Damage past the killing blow, from the game damage meter." },
        { label = "Deadly hits taken", fmt = "int", key = "deadly_hits", tip = "Hits the game damage meter marks as deadly." },
        { label = "Fights read from the damage meter", fmt = "int", key = "dm_fights_dmg" },
        { label = "Damage by your pet", fmt = "int", key = "dmg_pet", tip = "Pet and guardian spells in the game damage meter." },
        { label = "Avoidable damage taken", fmt = "int", key = "dmg_avoidable", tip = "Damage the game marks as avoidable: standing in the fire." },
        { label = "Fights where you stood in the fire", fmt = "int", key = "fights_in_fire" },
        { label = "Group fights", fmt = "int", key = "group_fights", tip = "Fights with two or more players dealing damage." },
        { label = "Times you topped the damage meter", fmt = "int", key = "meter_topped", tip = "Group fights where nobody did more damage than you." },
        { label = "Your average share of group damage", fmt = "pct", naKey = "group_fights", get = function(v) return Div(C(v, "group_dmg_mine") * 100, C(v, "group_dmg_all")) end },
        { label = "Group members who died near you", fmt = "int", key = "allies_died" },
        { label = "Buffs given", fmt = "int", key = "buffs_given" },
        { label = "Buffs received from others", fmt = "int", key = "buffs_from_others" },
        { label = "Debuffs received", fmt = "int", key = "debuffs_taken" },
        { label = "Duels won", fmt = "int", key = "duels_won" },
        { label = "Duels lost", fmt = "int", key = "duels_lost" },
        { label = "Duels started", fmt = "int", key = "duels_started" },
        { label = "Battlegrounds played", fmt = "int", key = "runs_pvp" },
        { label = "Battlegrounds won", fmt = "int", key = "bg_won" },
        { label = "Battlegrounds lost", fmt = "int", key = "bg_lost" },
        { label = "Battleground win rate", fmt = "pct", get = function(v) local w, l = C(v, "bg_won"), C(v, "bg_lost") return (w + l) > 0 and w * 100 / (w + l) or 0 end },
        { label = "Battleground killing blows", fmt = "int", key = "bg_killing_blows", tip = "From the battleground scoreboard at the end of each game." },
        { label = "Battleground honorable kills", fmt = "int", key = "bg_hks" },
        { label = "Battleground deaths", fmt = "int", key = "bg_deaths" },
        { label = "Honor from battlegrounds", fmt = "int", key = "bg_honor" },
        { label = "Flags captured", fmt = "int", key = "bg_flags_captured" },
        { label = "Flags returned", fmt = "int", key = "bg_flags_returned" },
        { label = "Flags picked up", fmt = "int", key = "bg_flags_picked" },
        { label = "Bases assaulted", fmt = "int", key = "bg_bases_assaulted" },
        { label = "Bases defended", fmt = "int", key = "bg_bases_defended" },
    },
    deaths = {
        { label = "Deaths", fmt = "int", key = "deaths" },
        { label = "Killed by creatures", fmt = "int", key = "deaths_npc" },
        { label = "Killed by players", fmt = "int", key = "deaths_pvp" },
        { label = "Died falling", fmt = "int", key = "deaths_fall" },
        { label = "Drowned", fmt = "int", key = "deaths_drown" },
        { label = "Died to fatigue", fmt = "int", key = "deaths_fatigue" },
        { label = "Died to lava / fire", fmt = "int", key = "deaths_lava", tip = "From the game's death recap (fire, lava) or the combat log." },
        { label = "Died to slime", fmt = "int", key = "deaths_slime" },
        { label = "Damage in death recaps", fmt = "int", key = "recap_damage", tip = "The hits listed in the game's death recap each time you died." },
        { label = "Overkill on your deaths", fmt = "int", key = "death_overkill" },
        { label = "Died while mounted", fmt = "int", key = "deaths_mounted" },
        { label = "Died while swimming", fmt = "int", key = "deaths_swimming" },
        { label = "Died while AFK", fmt = "int", key = "deaths_afk" },
        { label = "Deaths in dungeons", fmt = "int", key = "deaths_party" },
        { label = "Deaths in raids", fmt = "int", key = "deaths_raid" },
        { label = "Deaths in the open world", fmt = "int", key = "deaths_world" },
        { label = "Deaths in battlegrounds", fmt = "int", key = "deaths_bg" },
        { label = "Spirit releases", fmt = "int", key = "releases" },
        { label = "Corpse runs", fmt = "int", key = "corpse_runs" },
        { label = "Corpses retrieved", fmt = "int", key = "corpses_retrieved" },
        { label = "Resurrections offered", fmt = "int", key = "rez_offered" },
        { label = "Resurrections accepted", fmt = "int", key = "rez_accepted" },
        { label = "Raised where you fell", fmt = "int", key = "rezzed_in_place" },
        { label = "Resurrections you cast", fmt = "int", key = "rezzes_cast" },
        { label = "Time spent dead", fmt = "time", key = "time_dead" },
        { label = "Falls that hurt", fmt = "int", key = "falls" },
        { label = "Falls survived", fmt = "int", key = "falls_survived" },
        { label = "Falling damage taken", fmt = "int", key = "dmg_fall" },
        { label = "Drowning damage taken", fmt = "int", key = "dmg_env_drowning" },
        { label = "Lava damage taken", fmt = "int", key = "dmg_env_lava" },
        { label = "Fatigue damage taken", fmt = "int", key = "dmg_env_fatigue" },
        { label = "Kills per death", fmt = "ratio", get = function(v) return Div(Kills(v), C(v, "deaths")) end },
    },
    adventure = {
        { label = "Quests accepted", fmt = "int", key = "quests_accepted" },
        { label = "Quests completed", fmt = "int", key = "quests_done" },
        { label = "Quests abandoned", fmt = "int", key = "quests_abandoned" },
        { label = "Quest completion rate", fmt = "pct", get = function(v) return Div(C(v, "quests_done") * 100, C(v, "quests_accepted")) end },
        { label = "XP gained", fmt = "int", key = "xp" },
        { label = "XP from quests", fmt = "int", key = "xp_quest" },
        { label = "XP from kills", fmt = "int", key = "xp_kill" },
        { label = "XP from exploring", fmt = "int", key = "xp_explore" },
        { label = "Group bonus XP", fmt = "int", key = "xp_group" },
        { label = "XP per hour (online)", fmt = "int", get = function(v) return Div(C(v, "xp") * 3600, C(v, "time_online")) end },
        { label = "Levels gained", fmt = "int", key = "levels" },
        { label = "Spells learned", fmt = "int", key = "spells_learned" },
        { label = "Talent points spent", fmt = "int", key = "talents_spent" },
        { label = "Skill-ups", fmt = "int", key = "skillups" },
        { label = "Reputation gained", fmt = "int", key = "rep_gained" },
        { label = "Reputation lost", fmt = "int", key = "rep_lost" },
        { label = "Dungeon runs", fmt = "int", key = "runs_party", tip = "A /reload or a quick zone-out does not count twice; an instance reset starts a new run." },
        { label = "Dungeon runs with a boss kill", fmt = "int", key = "runs_party_boss" },
        { label = "Dungeon bosses killed", fmt = "int", key = "boss_kills_party" },
        { label = "Dungeons entered", fmt = "int", get = function(v) return (v.un and v.un.dungeons_seen) or 0 end, tip = "Out of 35 dungeons and 3 raids in Forever." },
        { label = "Dungeons fully cleared", fmt = "int", get = function(v) return (v.un and v.un.dungeons_cleared) or 0 end, tip = "Different dungeons where you killed every required boss in one run." },
        { label = "Full clears", fmt = "int", key = "dj_full_clears" },
        { label = "Forever's new dungeons cleared", fmt = "int", get = function(v) return (v.un and v.un.forever_dungeons_cleared) or 0 end, tip = "Out of the 9 dungeons added in Forever." },
        { label = "Bosses found (dungeon book)", fmt = "int", key = "dj_bosses_found" },
        { label = "Dungeon runs under level", fmt = "int", key = "dj_runs_under", tip = "You were below the dungeon's level range when you went in." },
        { label = "Dungeon runs at level", fmt = "int", key = "dj_runs_in" },
        { label = "Dungeon runs over level", fmt = "int", key = "dj_runs_over" },
        { label = "Full clears under level", fmt = "int", key = "dj_clears_under" },
        { label = "Raid runs", fmt = "int", key = "runs_raid" },
        { label = "Raid runs with a boss kill", fmt = "int", key = "runs_raid_boss" },
        { label = "Raid bosses killed", fmt = "int", key = "boss_kills_raid" },
        { label = "Raids fully cleared", fmt = "int", key = "raid_clears", tip = "Your raid lockout showed every encounter killed." },
        { label = "World bosses killed", fmt = "int", key = "boss_kills_world" },
        { label = "Time in dungeons", fmt = "time", key = "time_party" },
        { label = "Time in raids", fmt = "time", key = "time_raid" },
        { label = "Time in battlegrounds", fmt = "time", key = "time_pvp" },
        { label = "Times grouped", fmt = "int", key = "groups_joined" },
        { label = "Time in a group", fmt = "time", key = "time_grouped" },
        { label = "Gear changes", fmt = "int", key = "gear_changes", tip = "Items you put on or took off." },
        { label = "Group invites received", fmt = "int", key = "invites_in" },
        { label = "Herbs gathered", fmt = "int", key = "gather_herb" },
        { label = "Ore mined", fmt = "int", key = "gather_mine" },
        { label = "Creatures skinned", fmt = "int", key = "gather_skin" },
        { label = "Fish caught", fmt = "int", key = "fish" },
        { label = "Items crafted", fmt = "int", key = "items_crafted" },
        { label = "Conjured items made", fmt = "int", key = "conjured" },
        { label = "Trainer visits", fmt = "int", key = "trainer_visits" },
    },
    wealth = {
        { label = "Gold earned", fmt = "money", key = "money_in" },
        { label = "Gold per hour (online)", fmt = "money", get = function(v) return math.floor(Div(C(v, "money_in") * 3600, C(v, "time_online"))) end },
        { label = "Gold spent", fmt = "money", key = "money_out" },
        { label = "Net gold per hour", fmt = "money", get = function(v) return Div((C(v, "money_in") - C(v, "money_out")) * 3600, C(v, "time_online")) end },
        { label = "Gold looted", fmt = "money", key = "money_loot" },
        { label = "Gold from quests", fmt = "money", key = "money_quest" },
        { label = "Sold to vendors", fmt = "money", key = "money_vendor_in" },
        { label = "Spent at vendors (incl. repairs)", fmt = "money", key = "money_vendor_out" },
        { label = "Spent on repairs", fmt = "money", key = "money_repair" },
        { label = "Repairs", fmt = "int", key = "repairs" },
        { label = "Spent on flights", fmt = "money", key = "money_taxi" },
        { label = "Spent on training", fmt = "money", key = "money_train" },
        { label = "Auction house in", fmt = "money", key = "money_ah_in" },
        { label = "Auction house out", fmt = "money", key = "money_ah_out" },
        { label = "Received by mail", fmt = "money", key = "money_mail_in" },
        { label = "Sent by mail (incl. postage)", fmt = "money", key = "money_mail_out" },
        { label = "Vendor visits", fmt = "int", key = "vendor_visits" },
        { label = "Bank visits", fmt = "int", key = "bank_visits" },
        { label = "Auction house visits", fmt = "int", key = "ah_visits" },
        { label = "Mailbox opens", fmt = "int", key = "mailbox_opens" },
        { label = "Mails sent", fmt = "int", key = "mails_sent" },
        { label = "Loot windows opened", fmt = "int", key = "loot_windows" },
        { label = "Items looted", fmt = "int", key = "items_looted" },
        { label = "Poor (grey) items", fmt = "int", key = "loot_q0" },
        { label = "Common (white) items", fmt = "int", key = "loot_q1" },
        { label = "Uncommon (green) items", fmt = "int", key = "loot_q2" },
        { label = "Rare (blue) items", fmt = "int", key = "loot_q3" },
        { label = "Epic (purple) items", fmt = "int", key = "loot_q4" },
        { label = "Legendary items", fmt = "int", key = "loot_q5" },
        { label = "Items destroyed", fmt = "int", key = "items_destroyed" },
        { label = "Times your bags were full", fmt = "int", key = "bags_full" },
        { label = "Gear changes", fmt = "int", key = "gear_changes" },
        { label = "Trades completed", fmt = "int", key = "trades" },
        { label = "Items bought from vendors", fmt = "int", key = "items_bought" },
        { label = "Items sold to vendors", fmt = "int", key = "items_sold" },
        { label = "Buybacks", fmt = "int", key = "buybacks" },
        { label = "Spent at the barber", fmt = "money", key = "money_barber" },
        { label = "Auctions posted", fmt = "int", key = "auctions_posted" },
        { label = "Auction bids", fmt = "int", key = "auction_bids" },
        { label = "Mail items taken", fmt = "int", key = "mail_items_taken" },
        { label = "Mail returned", fmt = "int", key = "mail_returned" },
        { label = "Loot rolls: need", fmt = "int", key = "rolls_need" },
        { label = "Loot rolls: greed", fmt = "int", key = "rolls_greed" },
        { label = "Loot rolls: pass", fmt = "int", key = "rolls_pass" },
        { label = "Loot rolls won", fmt = "int", key = "rolls_won" },
        { label = "Times your gear broke", fmt = "int", key = "gear_broken_seen" },
    },
    social = {
        { label = "Chat messages sent", fmt = "int", key = "chat_sent" },
        { label = "Whispers sent", fmt = "int", key = "whispers_sent" },
        { label = "Whispers received", fmt = "int", key = "whispers_in" },
        { label = "Whispers received while AFK", fmt = "int", key = "whispers_afk" },
        { label = "People who whispered you", fmt = "int", get = function(v) return (v.un and v.un.whisperers) or 0 end },
        { label = "People you whispered", fmt = "int", get = function(v) return (v.un and v.un.whispered) or 0 end },
        { label = "Battle.net whispers received", fmt = "int", key = "bn_whispers_in" },
        { label = "Battle.net whispers sent", fmt = "int", key = "bn_whispers_sent" },
        { label = "/say messages", fmt = "int", key = "chat_say" },
        { label = "/yell messages", fmt = "int", key = "chat_yell" },
        { label = "Party messages", fmt = "int", key = "chat_party" },
        { label = "Raid messages", fmt = "int", key = "chat_raid" },
        { label = "Guild messages", fmt = "int", key = "chat_guild" },
        { label = "Channel messages (General, Trade...)", fmt = "int", key = "chat_channel" },
        { label = "Characters typed in chat", fmt = "int", key = "chars_typed" },
        { label = "Questions asked (?)", fmt = "int", key = "questions_asked" },
        { label = "Times you said lol", fmt = "int", key = "lols" },
        { label = "Times you said thanks", fmt = "int", key = "thanks_said" },
        { label = "Greetings (hi, hello, hey)", fmt = "int", key = "greetings" },
        { label = "Things you overheard (/say, /yell)", fmt = "int", get = function(v) return (v.c.heard_say or 0) + (v.c.heard_yell or 0) end },
        { label = "Friends added", fmt = "int", key = "friends_added" },
        { label = "Friends removed", fmt = "int", key = "friends_removed" },
        { label = "Players ignored", fmt = "int", key = "players_ignored" },
        { label = "Group invites sent", fmt = "int", key = "invites_sent" },
        { label = "Group invites accepted", fmt = "int", key = "invites_accepted" },
        { label = "Group invites declined", fmt = "int", key = "invites_declined" },
        { label = "Groups left", fmt = "int", key = "groups_left" },
        { label = "Guild invites received", fmt = "int", key = "guild_invites" },
        { label = "Guilds joined", fmt = "int", get = function(v) return (v.un and v.un.guilds) or 0 end },
        { label = "Ready checks", fmt = "int", key = "ready_checks_seen" },
        { label = "Raid markers placed", fmt = "int", key = "raid_marks" },
        { label = "Haircuts (barber)", fmt = "int", key = "haircuts" },
        { label = "Barber visits", fmt = "int", key = "barber_visits" },
        { label = "Emotes performed", fmt = "int", key = "emotes" },
        { label = "Dances", fmt = "int", key = "emote_DANCE" },
        { label = "Hugs given", fmt = "int", key = "emote_HUG" },
        { label = "Waves", fmt = "int", key = "emote_WAVE" },
        { label = "Laughs", fmt = "int", key = "emote_LAUGH" },
        { label = "Cheers", fmt = "int", key = "emote_CHEER" },
        { label = "Bows", fmt = "int", key = "emote_BOW" },
        { label = "Chickens (/chicken)", fmt = "int", key = "emote_CHICKEN" },
        { label = "Critters loved (/love)", fmt = "int", key = "critters_loved", tip = "Times you used /love while targeting a critter." },
        { label = "Critters loved and spared", fmt = "int", get = function(v) return math.max(0, C(v, "critters_loved") - C(v, "critters_love_kill")) end },
        { label = "Appearances collected", fmt = "int", key = "appearances", tip = "\"has been added to your appearance collection\" messages." },
        { label = "Loves given (/love)", fmt = "int", key = "emote_LOVE" },
        { label = "Rude gestures", fmt = "int", key = "emote_RUDE" },
        { label = "/roll rolls", fmt = "int", key = "rolls" },
        { label = "Average roll", fmt = "num1", get = function(v) return Div(C(v, "roll_sum"), C(v, "rolls")) end },
        { label = "Perfect rolls (max)", fmt = "int", key = "rolls_max" },
        { label = "Worst rolls (min)", fmt = "int", key = "rolls_min" },
        { label = "Duel challenges received", fmt = "int", key = "duels_asked" },
        { label = "Players inspected", fmt = "int", key = "inspects" },
        { label = "Assists", fmt = "int", key = "assists" },
        { label = "Targets selected", fmt = "int", key = "targets" },
        { label = "NPC conversations", fmt = "int", key = "gossip_opens" },
        { label = "Food eaten", fmt = "int", key = "food" },
        { label = "Drinks drunk", fmt = "int", key = "drink" },
        { label = "Bandages applied", fmt = "int", key = "bandages" },
        { label = "Times gone AFK", fmt = "int", key = "afk_count" },
        { label = "Time AFK", fmt = "time", key = "time_afk" },
        { label = "Active time (not AFK)", fmt = "time", get = function(v) return math.max(0, C(v, "time_online") - C(v, "time_afk")) end },
        { label = "Play sessions", fmt = "int", get = function(v) return ns.SessionStats and ns.SessionStats(v).n or 0 end, tip = "A /reload continues the same session." },
        { label = "Average session", fmt = "time", get = function(v) return ns.SessionStats and ns.SessionStats(v).avg or 0 end },
        { label = "Average play per day played", fmt = "time", get = function(v) return ns.SessionStats and ns.SessionStats(v).perDay or 0 end },
        { label = "Daily average, last 7 days", fmt = "time", get = function(v) return ns.SessionStats and ns.SessionStats(v).weekPerDay or 0 end },
        { label = "Bags opened", fmt = "int", key = "bags_opened" },
        { label = "Character sheet opened", fmt = "int", key = "char_opens" },
        { label = "Spellbook opened", fmt = "int", key = "spellbook_opens" },
        { label = "Talents opened", fmt = "int", key = "talent_opens" },
        { label = "Quest log opened", fmt = "int", key = "questlog_opens" },
        { label = "Friends list opened", fmt = "int", key = "friends_opens" },
        { label = "World map opened", fmt = "int", key = "map_opens" },
        { label = "Red error messages seen", fmt = "int", key = "ui_errors" },
        { label = "Screenshots taken", fmt = "int", key = "screenshots" },
        { label = "Logins", fmt = "int", key = "logins" },
        { label = "UI reloads", fmt = "int", key = "reloads" },
        { label = "Times you checked these stats", fmt = "int", key = "lts_opens", tip = "Yes, this counts too." },
        { label = "Times you shared your stats", fmt = "int", key = "shares" },
    },
    life = {
        { label = "Times you got drunk", fmt = "int", key = "times_drunk", tip = "Going from sober to tipsy or worse." },
        { label = "Times tipsy", fmt = "int", key = "drunk_tipsy" },
        { label = "Times drunk", fmt = "int", key = "drunk_drunk" },
        { label = "Times completely smashed", fmt = "int", key = "drunk_smashed" },
        { label = "Times you sobered up", fmt = "int", key = "sobered_up" },
        { label = "Campfires lit", fmt = "int", key = "campfires" },
        { label = "Nights camped out", fmt = "int", key = "nights_camped", tip = "Logged out away from an inn or city." },
        { label = "Nights at an inn or city", fmt = "int", key = "nights_inn" },
        { label = "Time in the wild", fmt = "time", key = "time_wild", tip = "Online time outside inns and cities." },
        { label = "Time adventuring at night (game time)", fmt = "time", key = "time_night", tip = "21:00 to 06:00 server time." },
        { label = "Time adventuring by day (game time)", fmt = "time", key = "time_day" },
        { label = "Days adventured", fmt = "int", get = function(v) return (v.un and v.un.days_played) or 0 end },
        { label = "Unique hearthstones owned", fmt = "int", get = function(v) return (v.un and v.un.hearthstones) or 0 end, tip = "Different hearthstone items and toys seen in your bags, loot or toy box." },
        { label = "Hearthstone uses", fmt = "int", key = "hearths" },
        { label = "Different hearth locations", fmt = "int", get = function(v) return (v.un and v.un.bindspots) or 0 end, tip = "Different inns or places your hearthstone has been set to." },
        { label = "Times you moved your hearth", fmt = "int", key = "hearth_moves" },
        { label = "Flight paths discovered", fmt = "int", key = "flightpaths_found" },
        { label = "Flight paths known (most seen)", fmt = "int", rec = "flightpaths_known", tip = "Read from the flight map each time you open it." },
        { label = "Mounts owned (most seen)", fmt = "int", rec = "mounts_owned" },
        { label = "Pets owned (most seen)", fmt = "int", rec = "pets_owned" },
        { label = "Mounts learned", fmt = "int", key = "mounts_learned" },
        { label = "Pets learned", fmt = "int", key = "pets_learned" },
        { label = "Dismounts", fmt = "int", key = "dismounts" },
        { label = "Spirit healer resurrections", fmt = "int", key = "spirit_healer" },
        { label = "Summons accepted", fmt = "int", key = "summons_accepted" },
        { label = "Professions learned", fmt = "int", get = function(v) return (v.un and v.un.professions) or 0 end },
        { label = "Abilities learned", fmt = "int", key = "abilities_learned" },
        { label = "Recipes learned", fmt = "int", key = "recipes_learned" },
        { label = "Books and letters read", fmt = "int", key = "books_read" },
        { label = "Potions drunk", fmt = "int", key = "potions" },
        { label = "Elixirs and flasks", fmt = "int", key = "elixirs" },
        { label = "Food eaten", fmt = "int", key = "food" },
        { label = "Drinks drunk", fmt = "int", key = "drink" },
        { label = "Bandages applied", fmt = "int", key = "bandages" },
        { label = "Chests, doors and objects opened", fmt = "int", key = "objects_opened" },
        { label = "Fish caught", fmt = "int", key = "fish" },
        { label = "Herbs gathered", fmt = "int", key = "gather_herb" },
        { label = "Ore mined", fmt = "int", key = "gather_mine" },
        { label = "Creatures skinned", fmt = "int", key = "gather_skin" },
        { label = "Conjured items made", fmt = "int", key = "conjured" },
        { label = "Rested XP gained", fmt = "int", key = "rested_xp" },
        { label = "Times you held your breath", fmt = "int", key = "breath_held" },
        { label = "Times you swam into fatigue", fmt = "int", key = "fatigue_entered" },
        { label = "Critters loved (/love)", fmt = "int", key = "critters_loved" },
        { label = "Times you sat down", fmt = "int", key = "sits" },
        { label = "Times Well Fed", fmt = "int", key = "well_fed" },
        { label = "Time spent eating", fmt = "time", key = "time_eating" },
        { label = "Time spent drinking", fmt = "time", key = "time_drinking" },
        { label = "Inn visits", fmt = "int", key = "inn_visits" },
        { label = "Different inns rested at", fmt = "int", get = function(v) return (v.un and v.un.inns) or 0 end },
        { label = "Innkeepers met", fmt = "int", get = function(v) return (v.un and v.un.innkeepers) or 0 end },
        { label = "Zones in your travel log", fmt = "int", get = function(v) local n = 0 for _ in pairs(v.zonelog or {}) do n = n + 1 end return n end },
        { label = "Mounts ridden", fmt = "int", get = function(v) return (v.un and v.un.mounts) or 0 end },
        { label = "Pets summoned", fmt = "int", key = "pets_summoned" },
        { label = "Different pets", fmt = "int", get = function(v) return (v.un and v.un.pets) or 0 end },
        { label = "Gear changes", fmt = "int", key = "gear_changes" },
        { label = "Times you went naked (no chest)", fmt = "int", key = "times_naked" },
        { label = "Time spent naked", fmt = "time", key = "time_naked" },
        { label = "Logins at dawn (game time)", fmt = "int", key = "logins_dawn" },
        { label = "Logins at dusk (game time)", fmt = "int", key = "logins_dusk" },
        { label = "Fights ended without a kill", fmt = "int", key = "fights_no_kill", tip = "You left combat alive but nothing died: fled, evaded or reset." },
        { label = "Killed by something 5+ levels below you", fmt = "int", key = "deaths_lowbie" },
    },
    records = {
        { label = "Adventurer score", fmt = "int", get = function(v) return ns.Score and ns.Score(v) or 0 end, tip = "One number for how far you have come: levels, quests, exploration, dungeons, achievements, professions, gear and gold, minus 25 per death. /lts score shows the breakdown." },
        { label = "Best average item level", fmt = "num1", rec = "max_ilvl" },
        { label = "Highest strength", fmt = "int", rec = "max_str" },
        { label = "Highest agility", fmt = "int", rec = "max_agi" },
        { label = "Highest stamina", fmt = "int", rec = "max_sta" },
        { label = "Highest intellect", fmt = "int", rec = "max_int" },
        { label = "Highest spirit", fmt = "int", rec = "max_spi" },
        { label = "Highest armor", fmt = "int", rec = "max_armor" },
        { label = "Highest attack power", fmt = "int", rec = "max_ap" },
        { label = "Highest spell power", fmt = "int", rec = "max_spellpower" },
        { label = "Highest healing power", fmt = "int", rec = "max_healpower" },
        { label = "Highest crit chance", fmt = "pct", rec = "max_crit_pct" },
        { label = "Highest spell crit chance", fmt = "pct", rec = "max_spellcrit_pct" },
        { label = "Highest dodge chance", fmt = "pct", rec = "max_dodge_pct" },
        { label = "Highest parry chance", fmt = "pct", rec = "max_parry_pct" },
        { label = "Highest block chance", fmt = "pct", rec = "max_block_pct" },
        { label = "Highest fire resistance", fmt = "int", rec = "max_res_fire" },
        { label = "Highest nature resistance", fmt = "int", rec = "max_res_nature" },
        { label = "Highest frost resistance", fmt = "int", rec = "max_res_frost" },
        { label = "Highest shadow resistance", fmt = "int", rec = "max_res_shadow" },
        { label = "Highest arcane resistance", fmt = "int", rec = "max_res_arcane" },
        { label = "Factions at Friendly or better", fmt = "int", rec = "max_friendly" },
        { label = "Factions at Honored or better", fmt = "int", rec = "max_honored" },
        { label = "Factions at Revered or better", fmt = "int", rec = "max_revered" },
        { label = "Factions at Exalted", fmt = "int", rec = "max_exalted" },
        { label = "Longest play session", fmt = "time", rec = "max_session_time" },
        { label = "Longest battleground win streak", fmt = "int", rec = "max_bg_streak" },
        { label = "Most killing blows in one battleground", fmt = "int", rec = "max_bg_kb" },
        { label = "Most honorable kills in one battleground", fmt = "int", rec = "max_bg_hks" },
        { label = "Biggest hit", fmt = "int", rec = "max_hit" },
        { label = "Biggest crit", fmt = "int", rec = "max_crit" },
        { label = "Highest health", fmt = "int", rec = "max_health" },
        { label = "Highest mana", fmt = "int", rec = "max_mana" },
        { label = "Biggest share of group damage", fmt = "pct", rec = "max_group_share" },
        { label = "Most damage to one boss", fmt = "int", rec = "max_boss_damage" },
        { label = "Best DPS on a boss", fmt = "num1", rec = "best_boss_dps" },
        { label = "Most avoidable damage in one fight", fmt = "int", rec = "max_fight_avoidable" },
        { label = "Most crits in a row", fmt = "int", rec = "max_crit_streak" },
        { label = "Biggest heal", fmt = "int", rec = "max_heal" },
        { label = "Biggest critical heal", fmt = "int", rec = "max_heal_crit" },
        { label = "Biggest heal received", fmt = "int", rec = "max_heal_taken" },
        { label = "Biggest hit taken", fmt = "int", rec = "max_hit_taken" },
        { label = "Biggest crit taken", fmt = "int", rec = "max_crit_taken" },
        { label = "Biggest killing blow", fmt = "int", rec = "max_killing_blow", tip = "From the game's death recap." },
        { label = "Most health before a killing blow", fmt = "int", rec = "max_hp_before_killing_blow", tip = "One-shot meter: your health right before the hit that killed you." },
        { label = "Biggest fall (damage)", fmt = "int", rec = "max_fall" },
        { label = "Biggest fall survived (damage)", fmt = "int", rec = "max_fall_survived" },
        { label = "Biggest fall survived (% of health)", fmt = "pct", rec = "max_fall_survived_pct" },
        { label = "Biggest fatal fall (damage)", fmt = "int", rec = "max_fall_fatal" },
        { label = "Longest time in the air", fmt = "sec", rec = "max_airtime" },
        { label = "Longest fatal fall (airtime)", fmt = "sec", rec = "max_airtime_fatal" },
        { label = "Longest corpse run (time)", fmt = "time", rec = "max_corpse_time" },
        { label = "Longest corpse run (distance)", fmt = "yards", rec = "max_corpse_dist" },
        { label = "Longest wait for a resurrection", fmt = "time", rec = "max_dead_wait" },
        { label = "Longest life (online time between deaths)", fmt = "time", rec = "max_alive" },
        { label = "Longest fight", fmt = "time", rec = "max_fight" },
        { label = "Longest fight (game damage meter)", fmt = "time", rec = "max_dm_fight" },
        { label = "Most damage in one fight", fmt = "int", rec = "max_fight_damage" },
        { label = "Best damage per second in one fight", fmt = "num1", rec = "max_fight_dps", tip = "From the game damage meter. Fights of 3 seconds or more." },
        { label = "Most damage by one spell in one fight", fmt = "int", rec = "max_spell_fight" },
        { label = "Most healing in one fight", fmt = "int", rec = "max_fight_heal" },
        { label = "Most damage taken in one fight", fmt = "int", rec = "max_fight_taken" },
        { label = "Most kills in one fight", fmt = "int", rec = "max_fight_kills" },
        { label = "Longest kill streak without dying", fmt = "int", rec = "max_streak" },
        { label = "Most kills in one session", fmt = "int", rec = "max_session_kills" },
        { label = "Most deaths in one session", fmt = "int", rec = "max_session_deaths" },
        { label = "Slowest quest (accept to turn-in)", fmt = "time", rec = "quest_slow" },
        { label = "Slowest level", fmt = "time", rec = "level_slow" },
        { label = "Longest flight", fmt = "time", rec = "flight_long" },
        { label = "Most gold carried", fmt = "money", rec = "max_money" },
        { label = "Most gold looted at once", fmt = "money", rec = "max_loot_money" },
        { label = "Highest skill", fmt = "int", rec = "max_skill" },
        { label = "Highest /roll", fmt = "int", rec = "max_roll" },
        { label = "Fastest speed", fmt = "speed", rec = "max_speed", tip = "As % of normal run speed (flight paths excluded)." },
        { label = "Longest session", fmt = "time", rec = "max_session" },
        { label = "Longest time in the wild", fmt = "time", rec = "max_wild", tip = "Online without visiting an inn or city." },
        { label = "Drunkest you have been", fmt = "int", rec = "max_drunk", tip = "1 tipsy · 2 drunk · 3 completely smashed." },
        { label = "Highest level reached", fmt = "level", rec = "max_level" },
    },
}

-- Fastest times (lower is better). Dynamic per-instance entries are added by the UI.
ns.FASTEST = {
    { key = "level_fast",          label = "Fastest level-up" },
    { key = "fight_fast",          label = "Shortest fight won" },
    { key = "ten_kills",           label = "10 kills" },
    { key = "quest_fast",          label = "Quest accept to turn-in" },
    { key = "corpse_fast",         label = "Corpse run" },
    { key = "flight_fast",         label = "Shortest flight" },
    { key = "first_death_session", label = "Session start to first death" },
    { key = "bg_win",              label = "Battleground win" },
}

ns.UNIQUES = {
    { set = "npcs",          label = "NPCs met" },
    { set = "worn",          label = "Items worn" },
    { set = "vendors",       label = "Vendors used" },
    { set = "trainers",      label = "Trainers visited" },
    { set = "flightmasters", label = "Flight masters" },
    { set = "bankers",       label = "Bankers" },
    { set = "auctioneers",   label = "Auctioneers" },
    { set = "creatures",     label = "Creature types killed" },
    { set = "pvp_victims",   label = "Different players killed" },
    { set = "bosses_party",  label = "Dungeon bosses" },
    { set = "bosses_raid",   label = "Raid bosses" },
    { set = "bosses_world",  label = "World bosses" },
    { set = "instances",     label = "Instances entered" },
    { set = "zones",         label = "Zones visited" },
    { set = "subzones",      label = "Subzones visited" },
    { set = "quests",        label = "Different quests completed" },
    { set = "items",         label = "Different items looted" },
    { set = "spells",        label = "Different spells cast" },
    { set = "groupmates",    label = "Players grouped with" },
    { set = "duelers",       label = "Players duelled" },
    { set = "emotes",        label = "Different emotes used" },
    { set = "critter_kinds", label = "Kinds of critters killed" },
    { set = "rares",         label = "Different rares killed" },
    { set = "hearthstones",  label = "Unique hearthstones" },
    { set = "books",         label = "Different books read" },
    { set = "bindspots",     label = "Different hearth locations" },
    { set = "inns",          label = "Different inns" },
    { set = "whisperers",    label = "People who whispered you" },
    { set = "whispered",     label = "People you whispered" },
    { set = "flightpoints",  label = "Flight points known" },
    { set = "professions",   label = "Professions learned" },
    { set = "guilds",        label = "Guilds joined" },
    { set = "innkeepers",    label = "Innkeepers met" },
    { set = "mounts",        label = "Mounts ridden" },
    { set = "pets",          label = "Pets summoned" },
    { set = "days_played",   label = "Days adventured" },
    { set = "appearances",   label = "Appearances collected" },
    { set = "critters_loved", label = "Kinds of critters loved" },
}

ns.FIRSTS = {
    { key = "kill",     label = "First kill" },
    { key = "death",    label = "First death" },
    { key = "jump",     label = "First jump" },
    { key = "quest",    label = "First quest" },
    { key = "npc",      label = "First NPC met" },
    { key = "levelup",  label = "First level-up" },
    { key = "green",    label = "First green" },
    { key = "blue",     label = "First blue" },
    { key = "epic",     label = "First epic" },
    { key = "dungeon",  label = "First dungeon" },
    { key = "boss",     label = "First boss" },
    { key = "raid",     label = "First raid" },
    { key = "pvp_kill", label = "First player kill" },
    { key = "duel_won", label = "First duel won" },
    { key = "bg_win",   label = "First battleground win" },
    { key = "mount",    label = "First mount ride" },
    { key = "fish",     label = "First fish" },
    { key = "critter_kill",  label = "First critter killed" },
    { key = "elite",    label = "First elite killed" },
    { key = "drunk",    label = "First time drunk" },
    { key = "campfire", label = "First campfire" },
    { key = "book",     label = "First book read" },
    { key = "flightpath", label = "First flight path found" },
    { key = "hearthstone", label = "First hearthstone" },
    { key = "bindspot", label = "First hearth location" },
    { key = "whisper_in", label = "First whisper received" },
    { key = "whisper_out", label = "First whisper sent" },
    { key = "haircut", label = "First haircut" },
    { key = "profession", label = "First profession" },
    { key = "guild",    label = "First guild" },
    { key = "rare",     label = "First rare killed" },
    { key = "appearance", label = "First appearance" },
    { key = "critter_loved", label = "First critter loved" },
}

ns.LISTS = {
    { id = "creatures",  name = "Most killed creatures", fmt = "int" },
    { id = "players",    name = "Players killed by class", fmt = "int" },
    { id = "killers",    name = "Killed most often by", fmt = "int" },
    { id = "foughtenemies", name = "Enemies fought most", fmt = "int" },
    { id = "spelldamage", name = "Damage by spell", fmt = "int" },
    { id = "spellheal",  name = "Healing by spell", fmt = "int" },
    { id = "hurtby",     name = "Who hurt you most", fmt = "int" },
    { id = "hurtbyspell", name = "What hurt you most", fmt = "int" },
    { id = "dungeonbook", name = "Dungeon book",
      count = function(v) local n = 0 for _, d in ipairs(ns.DUNGEONS or {}) do if ns.DungeonProgress(d, v) > 0 then n = n + 1 end end return n end,
      rows = function(v, sess)
          local rows = {}
          for i, d in ipairs(ns.DUNGEONS or {}) do
              local found, total = ns.DungeonProgress(d, v)
              local clears = (v.t.dungeonclears or {})[d.name] or 0
              local runs = (v.t.dungeonruns or {})[d.name] or 0
              local fast = v.f and v.f["clear:" .. d.key]
              local tag = (d.raid and "raid " or "") .. d.min .. (d.max ~= d.min and ("-" .. d.max) or "") .. (d.new and " · new" or "")
              local extra = runs > 0 and (Int(runs) .. " run" .. (runs == 1 and "" or "s") .. (clears > 0 and (" · " .. Int(clears) .. " clear" .. (clears == 1 and "" or "s")) or "") .. (fast and (" · best " .. Time(type(fast) == "table" and fast.v or fast)) or "")) or ""
              rows[#rows + 1] = { tostring(i), d.name .. "  |cff8a8a8a" .. tag .. "|r", total > 0 and found / total or 0, found .. " / " .. total, extra }
          end
          return rows
      end },
    { id = "sessionlog", name = "Session history",
      count = function(v) return #(v.sessionlog or {}) end,
      rows = function(v)
          local rows, log = {}, v.sessionlog or {}
          local longest = 1
          for _, e in ipairs(log) do if (e.d or 0) > longest then longest = e.d end end
          for i = #log, math.max(1, #log - 99), -1 do
              local e = log[i]
              rows[#rows + 1] = { tostring(#log - i + 1), date("%a %b %d  %H:%M", e.s or 0) .. "  |cff8a8a8alevel " .. (e.l or "?") .. (e.z and (" · " .. e.z) or "") .. "|r",
                  (e.d or 0) / longest, Time(e.d or 0), Int(e.k or 0) .. " kills · " .. Int(e.steps or 0) .. " steps" }
          end
          return rows
      end },
    { id = "bgwins", name = "Battlegrounds won", fmt = "int" },
    { id = "bglosses", name = "Battlegrounds lost", fmt = "int" },
    { id = "bgobjectives", name = "Battleground objectives", fmt = "int" },
    { id = "dungeonruns", name = "Dungeon runs", fmt = "int" },
    { id = "dungeonclears", name = "Dungeon full clears", fmt = "int" },
    { id = "killedwith", name = "What killed you", fmt = "int" },
    { id = "envdamage",  name = "Damage in your death recaps", fmt = "int" },
    { id = "damagetoenemy", name = "Damage dealt to each enemy", fmt = "int" },
    { id = "standinfire", name = "What you stood in", fmt = "int" },
    { id = "petdamage",  name = "Pet damage by pet", fmt = "int" },
    { id = "bossdamage", name = "Damage per boss", fmt = "int" },
    { id = "bandspells", name = "Spells by level band", fmt = "int" },
    { id = "groupedtime", name = "Time grouped with", fmt = "time" },
    { id = "wornitems",  name = "Items worn", fmt = "int" },
    { id = "bosses_party", name = "Dungeon bosses killed", fmt = "int" },
    { id = "bosses_raid", name = "Raid bosses killed", fmt = "int" },
    { id = "instances",  name = "Instance runs", fmt = "int" },
    { id = "zonetime",   name = "Zones by time spent", fmt = "time" },
    { id = "citytime",   name = "Capital cities by time", fmt = "time" },
    { id = "continenttime", name = "Continents by time", fmt = "time" },
    { id = "continentdist", name = "Continents by distance", fmt = "yards" },
    { id = "instancetime", name = "Instances by time", fmt = "time" },
    { id = "zonedist",   name = "Zones by distance travelled", fmt = "yards" },
    { id = "zonekills",  name = "Zones by kills", fmt = "int" },
    { id = "zonedeaths", name = "Zones by deaths", fmt = "int" },
    { id = "spells",     name = "Most cast spells", fmt = "int" },
    { id = "formtime",   name = "Time in each form", fmt = "time" },
    { id = "emotes",     name = "Favourite emotes", fmt = "int" },
    { id = "critters",   name = "Critters killed", fmt = "int" },
    { id = "killcolor",  name = "Kills by level colour", fmt = "int" },
    { id = "rares",      name = "Rares killed", fmt = "int" },
    { id = "campzones",  name = "Where you camped", fmt = "int" },
    { id = "campfirezones", name = "Where you lit campfires", fmt = "int" },
    { id = "drunkzones", name = "Where you got drunk", fmt = "int" },
    { id = "books",      name = "Books read", fmt = "int" },
    { id = "potions",    name = "Potions and elixirs", fmt = "int" },
    { id = "hearthsowned", name = "Hearthstones owned", fmt = "int" },
    { id = "hearthsused", name = "Hearthstones used", fmt = "int" },
    { id = "bindspots",  name = "Hearth locations", fmt = "int" },
    { id = "innvisits",  name = "Inns by visits", fmt = "int" },
    { id = "whisperers", name = "Who whispers you most", fmt = "int" },
    { id = "whispered",  name = "Who you whisper most", fmt = "int" },
    { id = "loginhour",  name = "Logins by hour", fmt = "int" },
    { id = "mounts",     name = "Mounts", fmt = "int" },
    { id = "pets",       name = "Pets", fmt = "int" },
    { id = "herbzones",  name = "Herbs by zone", fmt = "int" },
    { id = "orezones",   name = "Mining by zone", fmt = "int" },
    { id = "fishzones",  name = "Fish by zone", fmt = "int" },
    { id = "gamehour",   name = "Time per game hour", fmt = "time" },
    { id = "lowbiekillers", name = "Embarrassing killers", fmt = "int" },
    { id = "herbs",      name = "Herbs by type", fmt = "int" },
    { id = "ores",       name = "Ore and stone by type", fmt = "int" },
    { id = "created",    name = "Items created", fmt = "int" },
    { id = "critters_loved", name = "Critters loved", fmt = "int" },
    { id = "npcnames",   name = "Most visited NPCs", fmt = "int" },
    { id = "reps",       name = "Reputation gained", fmt = "int" },
    { id = "skills",     name = "Skill-ups by skill", fmt = "int" },
    { id = "leveltime",  name = "Time per level", fmt = "time" },
    { id = "uierrors",   name = "Red error messages", fmt = "int" },
    { id = "epics",      name = "Epic+ items looted", fmt = "int" },
}

-- Journal wording for firsts.
ns.FIRST_LABEL = {
    kill = "First kill", death = "First death", quest = "First quest done", npc = "First NPC met", levelup = "First level-up",
    green = "First green item", blue = "First blue item", epic = "First epic item", dungeon = "First dungeon", boss = "First boss",
    raid = "First raid", pvp_kill = "First player killed", duel_won = "First duel won", bg_win = "First battleground won",
    mount = "First mount ride", fish = "First fish", critter_kill = "First critter killed", critter_loved = "First critter loved",
    elite = "First elite killed", rare = "First rare killed", appearance = "First appearance", drunk = "First time drunk",
    campfire = "First campfire", book = "First book read", flightpath = "First flight path found", hearthstone = "First hearthstone",
    bindspot = "Hearth set", whisper_in = "First whisper from", whisper_out = "First whisper to", haircut = "First haircut",
    profession = "Learned profession", guild = "Joined guild", inn = "First inn", innkeeper = "First innkeeper", pet = "First pet", wellfed = "First time Well Fed",
}

ns.milestoneKeys = {
    jumps = "Jumps", kills_npc = "Enemies killed", kills_pvp = "Enemy players killed",
    quests_done = "Quests completed", deaths = "Deaths", emote_DANCE = "Dances",
}

function ns.StatValue(stat, view)
    if stat.label2 then
        local t = ns.TopList(view, stat.label2, 1)[1]
        return t and t[2] or 0, t and tostring(t[1]) or nil
    end
    if stat.get then return stat.get(view) end
    if stat.rec then return view.r[stat.rec] or 0, view.r[stat.rec .. "_what"] end
    return view.c[stat.key] or 0
end

-- "n/a" for statistics only the combat log can give, while it is unavailable.
ns.NA_TIP = "Forever does not give addons the combat log, so this cannot be measured here. It fills in automatically if that ever changes."
ns.NA_AMOUNT_TIP = "Forever hides the size of each hit from addons, so this cannot be measured here. Hit, crit and miss counts still work."
-- Filled by the game damage meter once it has been read once.
ns.DM_KEYS = { dmg_done = true, heal_done = true, interrupts = true, dispels = true }
function ns.IsNA(stat, value)
    local k = stat.naKey or stat.key or stat.rec
    if not k or (value or 0) ~= 0 or ns.cleuSeen then return false end
    local s = ns.settings or {}
    local dm = s.dmReadable or (ns.src and ns.src.dmReadable)
    if dm and ns.DM_KEYS[k] then return false end
    if s.dmHitReadable and (k == "max_hit" or k == "max_crit") then return false end
    if ns.CLEU_ONLY and ns.CLEU_ONLY[k] then return true, ns.NA_TIP end
    if ns.AMOUNT_KEYS and ns.AMOUNT_KEYS[k] and s.amountsSecret and not (ns.src and ns.src.amountReadable) then return true, ns.NA_AMOUNT_TIP end
    if ns.HEALTH_KEYS and ns.HEALTH_KEYS[k] and s.amountsSecret and s.healthSecret then return true, ns.NA_AMOUNT_TIP end
    return false
end

function ns.FormatStat(stat, value)
    local f = FMT[stat.fmt] or Int
    return f(value)
end

function ns.TopList(view, id, n)
    local t = view.t and view.t[id]
    local out = {}
    if not t then return out end
    for k, v in pairs(t) do out[#out + 1] = { k, v } end
    table.sort(out, function(a, b)
        if a[2] == b[2] then return tostring(a[1]) < tostring(b[1]) end
        return a[2] > b[2]
    end)
    for i = #out, (n or 25) + 1, -1 do out[i] = nil end
    return out
end

-- Total number of statistics (for docs / about line).
function ns.CountStats()
    local n = 0
    for _, list in pairs(ns.STATS) do n = n + #list end
    return n + #ns.FASTEST + #ns.UNIQUES + #ns.FIRSTS + #ns.LISTS
end

function ns.PrintSummary()
    local v = ns.char
    if not v then return end
    ns.Print(string.format("Steps %s · Jumps %s · Kills %s · PvP kills %s · Deaths %s · Quests %s",
        Int(Steps(v)), Int(v.c.jumps), Int(v.c.kills_npc), Int(v.c.kills_pvp), Int(v.c.deaths), Int(v.c.quests_done)))
end

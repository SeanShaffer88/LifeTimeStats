-- LifeTimeStats - sections: every stat page is split into named sections (shown as headings in
-- its table and as tabs down the right side of the window), and the Top Lists page is grouped
-- the same way. Rows are matched by stat key or label; anything unmatched falls into the page's
-- default section, so new statistics always appear somewhere.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

-- Rows that were listed on two pages (or twice on one). Each now lives on one page only.
local DUPLICATES = {
    wealth = { mail_items_taken = 2 },  -- "Mail items taken" repeated "Items taken from mail"
    social = { food = 1, drink = 1, bandages = 1 },                 -- kept on Life on the Road
    life = { critters_loved = 1, sits = 1, gear_changes = 1, hearths = 1, fish = 1,
             gather_herb = 1, gather_mine = 1, gather_skin = 1, conjured = 1 }, -- kept on their own pages
    adventure = { gear_changes = 1 },                                -- kept on Purse & Pack
}
-- value 1: drop every copy on that page; value 2: keep the first, drop later copies
ns.DUPLICATE_ROWS_REMOVED = 0
for cat, keys in pairs(DUPLICATES) do
    local list, seen, kept = ns.STATS[cat], {}, {}
    if list then
        for _, st in ipairs(list) do
            local k = st.key
            local rule = k and keys[k]
            if rule == 1 or (rule == 2 and seen[k]) then
                ns.DUPLICATE_ROWS_REMOVED = ns.DUPLICATE_ROWS_REMOVED + 1
            else
                kept[#kept + 1] = st
            end
            if k then seen[k] = true end
        end
        ns.STATS[cat] = kept
    end
end

-- Rules: { section, "key" | "label", Lua pattern }. Keys are matched as written, labels in
-- lower case. The first rule that matches wins; `order` is the display order.
ns.STAT_SECTIONS = {
    travel = {
        order = { "Distance", "Getting around", "Places", "Movement samples" },
        default = "Getting around",
        rules = {
            { "Movement samples", "key", "^ex_time_" }, { "Movement samples", "key", "^ex_dist_" },
            { "Movement samples", "label", "movement" }, { "Movement samples", "label", "moving speed" },
            { "Distance", "key", "^dist_" }, { "Distance", "label", "^steps" },
            { "Places", "key", "^time_rest" }, { "Places", "key", "^time_in" }, { "Places", "key", "^time_out" },
            { "Places", "label", "^most visited" }, { "Places", "key", "zone" }, { "Places", "key", "rest_entered" },
            { "Places", "key", "loading_screens" },
        },
    },
    combat = {
        order = { "Damage dealt", "Damage taken", "Healing", "Kills", "Fights", "Spells & auras", "Crowd control", "PvP & duels", "Health & movement" },
        default = "Damage dealt",
        rules = {
            { "Crowd control", "key", "^cc_" },
            { "PvP & duels", "key", "^duel" }, { "PvP & duels", "key", "^bg_" }, { "PvP & duels", "key", "runs_pvp" },
            { "PvP & duels", "key", "kills_pvp" }, { "PvP & duels", "key", "hk_server" }, { "PvP & duels", "key", "honor" },
            { "PvP & duels", "key", "dmg_taken_pvp" }, { "PvP & duels", "label", "battleground" },
            { "Health & movement", "key", "^ex_time_" }, { "Health & movement", "key", "^ex_dist_" },
            { "Health & movement", "label", "health time" }, { "Health & movement", "label", "combat samples" },
            { "Healing", "key", "heal" }, { "Healing", "label", "heal" },
            { "Spells & auras", "key", "^casts" }, { "Spells & auras", "key", "interrupts" }, { "Spells & auras", "key", "dispels" },
            { "Spells & auras", "key", "buffs" }, { "Spells & auras", "label", "casts per" },
            { "Spells & auras", "label", "^interrupts" }, { "Spells & auras", "label", "^dispels" },
            { "Damage taken", "key", "^dmg_taken" }, { "Damage taken", "key", "_taken$" }, { "Damage taken", "key", "_in$" },
            { "Damage taken", "key", "^in_" }, { "Damage taken", "key", "deadly_hits" }, { "Damage taken", "key", "avoidable" },
            { "Damage taken", "key", "in_fire" }, { "Damage taken", "label", "dodge rate" }, { "Damage taken", "label", "damage taken" },
            { "Damage dealt", "key", "overkill" },
            { "Kills", "key", "kill" }, { "Kills", "key", "critter" }, { "Kills", "key", "allies_died" }, { "Kills", "label", "^kills" },
            { "Fights", "key", "fight" }, { "Fights", "key", "time_combat" }, { "Fights", "key", "meter_topped" }, { "Fights", "label", "fight" },
        },
    },
    deaths = {
        order = { "Deaths", "Falls & the elements", "Recovering" },
        default = "Deaths",
        rules = {
            { "Recovering", "key", "^ex_" }, { "Recovering", "key", "releases" }, { "Recovering", "key", "corpse" },
            { "Recovering", "key", "^rez" }, { "Recovering", "key", "time_dead" }, { "Recovering", "label", "recover" },
            { "Recovering", "label", "time alive" },
            { "Falls & the elements", "key", "^falls" }, { "Falls & the elements", "key", "^dmg_" },
        },
    },
    adventure = {
        order = { "Experience & growth", "Quests", "Dungeons & raids", "Bosses", "Groups", "Professions" },
        default = "Experience & growth",
        rules = {
            { "Professions", "key", "^gather_" }, { "Professions", "key", "^fish" }, { "Professions", "key", "crafted" },
            { "Professions", "key", "conjured" }, { "Professions", "key", "skillups" }, { "Professions", "key", "trainer" },
            { "Professions", "label", "^trainer" }, { "Professions", "label", "herbs" }, { "Professions", "label", "ore mined" },
            { "Professions", "label", "skinning" }, { "Professions", "label", "fish" }, { "Professions", "label", "crafted" },
            { "Quests", "key", "quest" }, { "Quests", "label", "quest" },
            { "Bosses", "key", "boss" }, { "Bosses", "key", "^guide_pulls" }, { "Bosses", "key", "^guide_wipes" },
            { "Bosses", "key", "max_wipe_fight" }, { "Bosses", "label", "boss" },
            { "Groups", "key", "groups_joined" }, { "Groups", "key", "time_grouped" }, { "Groups", "key", "invites_in" },
            { "Groups", "label", "grouped with" },
            { "Dungeons & raids", "key", "^runs_" }, { "Dungeons & raids", "key", "^dj_" }, { "Dungeons & raids", "key", "raid" },
            { "Dungeons & raids", "key", "^guide_run" }, { "Dungeons & raids", "key", "^time_party" }, { "Dungeons & raids", "key", "^time_pvp" },
            { "Dungeons & raids", "key", "dungeon" }, { "Dungeons & raids", "key", "_bg_" }, { "Dungeons & raids", "key", "arena" },
            { "Dungeons & raids", "label", "dungeon" }, { "Dungeons & raids", "label", "instance" },
        },
    },
    wealth = {
        order = { "Income & spending", "Loot", "Vendors, bank & auction", "Mail & trade", "Bags & gear", "Best hours" },
        default = "Vendors, bank & auction",
        rules = {
            { "Best hours", "key", "^max_.*_per_hour$" },
            { "Bags & gear", "key", "bag" }, { "Bags & gear", "key", "destroyed" }, { "Bags & gear", "key", "^gear" },
            { "Loot", "key", "^loot" }, { "Loot", "key", "looted" }, { "Loot", "key", "^items_logged" }, { "Loot", "key", "item_level" },
            { "Loot", "key", "gather" }, { "Loot", "key", "max_loot_value" }, { "Loot", "key", "^rolls_" },
            { "Loot", "label", "loot window" }, { "Loot", "label", "items looted" },
            { "Mail & trade", "key", "mail" }, { "Mail & trade", "key", "^trade" }, { "Mail & trade", "key", "_trade$" },
            { "Mail & trade", "label", "players mailed" }, { "Mail & trade", "label", "traded with" },
            { "Mail & trade", "label", "^mailbox" }, { "Mail & trade", "label", "^trade window" },
            { "Income & spending", "key", "^money_" }, { "Income & spending", "key", "^repairs" },
            { "Income & spending", "label", "share of recorded" }, { "Income & spending", "label", "gold" },
            { "Income & spending", "label", "income" }, { "Income & spending", "label", "spending" },
            { "Income & spending", "label", "repair bill" }, { "Income & spending", "label", "flight fare" },
        },
    },
    social = {
        order = { "Chat", "Friends & groups", "Emotes & fun", "Milestones", "Playtime", "Interface" },
        default = "Interface",
        rules = {
            { "Interface", "key", "_opens$" }, { "Interface", "key", "^gossip" },
            { "Chat", "key", "^chat" }, { "Chat", "key", "whisper" }, { "Chat", "key", "chars_typed" }, { "Chat", "key", "questions" },
            { "Chat", "key", "lols" }, { "Chat", "key", "thanks" }, { "Chat", "key", "greetings" },
            { "Chat", "label", "whisper" }, { "Chat", "label", "overheard" }, { "Chat", "label", "messages sent" }, { "Chat", "label", "typed" },
            { "Friends & groups", "key", "^people" }, { "Friends & groups", "key", "friends_" }, { "Friends & groups", "key", "ignore" },
            { "Friends & groups", "key", "^invites" }, { "Friends & groups", "key", "groups_left" }, { "Friends & groups", "key", "guild_invites" },
            { "Friends & groups", "key", "ready_checks" }, { "Friends & groups", "key", "raid_marks" }, { "Friends & groups", "key", "inspects" },
            { "Friends & groups", "key", "assists" }, { "Friends & groups", "key", "duels_asked" }, { "Friends & groups", "key", "who_searches" },
            { "Friends & groups", "key", "unignored" }, { "Friends & groups", "label", "guilds joined" },
            { "Emotes & fun", "key", "emote" }, { "Emotes & fun", "key", "critters" }, { "Emotes & fun", "key", "^rolls" },
            { "Emotes & fun", "key", "haircuts" }, { "Emotes & fun", "key", "barber" }, { "Emotes & fun", "key", "appearances" },
            { "Emotes & fun", "label", "critters" }, { "Emotes & fun", "label", "roll" },
            { "Milestones", "key", "factions" }, { "Milestones", "key", "^rep_" }, { "Milestones", "key", "goals" },
            { "Milestones", "key", "milestones" }, { "Milestones", "key", "deaths_located" },
            { "Playtime", "key", "afk" }, { "Playtime", "key", "logins" }, { "Playtime", "key", "reloads" }, { "Playtime", "key", "lts_opens" },
            { "Playtime", "key", "shares" }, { "Playtime", "key", "screenshots" }, { "Playtime", "label", "session" },
            { "Playtime", "label", "active time" }, { "Playtime", "label", "per day" }, { "Playtime", "label", "daily" },
        },
    },
    life = {
        order = { "Drink & rest", "Food & potions", "Hearth & road", "Mounts & pets", "Lore & learning", "Curiosities" },
        default = "Curiosities",
        rules = {
            { "Drink & rest", "key", "drunk" }, { "Drink & rest", "key", "sobered" }, { "Drink & rest", "key", "campfire" },
            { "Drink & rest", "key", "^nights" }, { "Drink & rest", "key", "time_wild" }, { "Drink & rest", "key", "time_night" },
            { "Drink & rest", "key", "time_day" }, { "Drink & rest", "key", "inn" }, { "Drink & rest", "key", "logins_d" },
            { "Drink & rest", "key", "rested" }, { "Drink & rest", "label", "days adventured" }, { "Drink & rest", "label", "inn" },
            { "Food & potions", "key", "potions" }, { "Food & potions", "key", "elixirs" }, { "Food & potions", "key", "^food" },
            { "Food & potions", "key", "^drink" }, { "Food & potions", "key", "bandages" }, { "Food & potions", "key", "well_fed" },
            { "Food & potions", "key", "time_eating" }, { "Food & potions", "key", "time_drinking" }, { "Food & potions", "key", "items_used" },
            { "Hearth & road", "key", "hearth" }, { "Hearth & road", "key", "flightpaths" }, { "Hearth & road", "key", "dismounts" },
            { "Hearth & road", "key", "summons" }, { "Hearth & road", "key", "spirit_healer" }, { "Hearth & road", "label", "hearth" },
            { "Hearth & road", "label", "travel log" },
            { "Mounts & pets", "key", "mounts" }, { "Mounts & pets", "key", "pets" }, { "Mounts & pets", "label", "mounts" },
            { "Mounts & pets", "label", "pets" },
            { "Lore & learning", "key", "learned" }, { "Lore & learning", "key", "books" }, { "Lore & learning", "key", "book" },
            { "Lore & learning", "key", "cinematic" }, { "Lore & learning", "key", "movies" }, { "Lore & learning", "key", "respec" },
            { "Lore & learning", "key", "talent" }, { "Lore & learning", "key", "spec_changes" }, { "Lore & learning", "label", "professions" },
            { "Lore & learning", "label", "book" },
        },
    },
    records = {
        order = { "Character", "Combat", "Deaths & falls", "Travel & time", "Observed intervals", "Oddities" },
        default = "Oddities",
        rules = {
            { "Character", "key", "^max_health" }, { "Character", "key", "^max_healpower" },
            { "Observed intervals", "key", "^ex_longest_" }, { "Observed intervals", "key", "^ex_farthest_" },
            { "Observed intervals", "key", "^ex_visit_longest_" },
            { "Deaths & falls", "key", "fall" }, { "Deaths & falls", "key", "airtime" }, { "Deaths & falls", "key", "corpse" },
            { "Deaths & falls", "key", "dead_wait" }, { "Deaths & falls", "key", "max_alive" }, { "Deaths & falls", "key", "^ex_recovery" },
            { "Deaths & falls", "key", "session_deaths" },
            { "Combat", "key", "hit" }, { "Combat", "key", "crit_streak" }, { "Combat", "key", "max_crit$" }, { "Combat", "key", "crit_taken" },
            { "Combat", "key", "heal" }, { "Combat", "key", "fight" }, { "Combat", "key", "boss" }, { "Combat", "key", "group_share" },
            { "Combat", "key", "killing_blow" }, { "Combat", "key", "streak" }, { "Combat", "key", "kills" }, { "Combat", "key", "max_bg" },
            { "Combat", "key", "cc_longest" },
            { "Travel & time", "key", "session" }, { "Travel & time", "key", "_slow$" }, { "Travel & time", "key", "flight_long" },
            { "Travel & time", "key", "max_speed" }, { "Travel & time", "key", "max_wild" },
            { "Character", "key", "^max_ilvl" }, { "Character", "key", "^max_str" }, { "Character", "key", "^max_agi" },
            { "Character", "key", "^max_sta" }, { "Character", "key", "^max_int" }, { "Character", "key", "^max_spi" },
            { "Character", "key", "armor" }, { "Character", "key", "^max_ap" }, { "Character", "key", "power" }, { "Character", "key", "_pct$" },
            { "Character", "key", "^max_res_" }, { "Character", "key", "^max_health" }, { "Character", "key", "^max_mana" },
            { "Character", "key", "^max_level" }, { "Character", "key", "^max_skill" }, { "Character", "key", "^max_friendly" },
            { "Character", "key", "^max_honored" }, { "Character", "key", "^max_revered" }, { "Character", "key", "^max_exalted" },
            { "Character", "label", "adventurer score" },
        },
    },
}

-- Which section a stat row belongs to on a page.
function ns.StatSection(cat, st)
    local def = ns.STAT_SECTIONS[cat]
    if not def then return nil end
    local key = st.key or st.rec or ""
    local label = (st.label or ""):lower()
    for _, r in ipairs(def.rules) do
        local subject = r[2] == "key" and key or label
        if subject ~= "" and subject:find(r[3]) then return r[1] end
    end
    return def.default
end

-- The page's rows grouped in display order: { { name = "Chat", stats = { ... } }, ... }.
-- Empty sections are left out.
function ns.SectionedStats(cat)
    local def = ns.STAT_SECTIONS[cat]
    local list = ns.STATS[cat] or {}
    if not def then return { { name = nil, stats = list } } end
    local buckets = {}
    for _, st in ipairs(list) do
        local name = ns.StatSection(cat, st)
        buckets[name] = buckets[name] or {}
        table.insert(buckets[name], st)
    end
    local out = {}
    for _, name in ipairs(def.order) do
        if buckets[name] then out[#out + 1] = { name = name, stats = buckets[name] } end
    end
    return out
end

-- ------------------------------------------------------------ Top Lists groups
ns.LIST_SECTIONS = {
    order = { "Combat", "Bosses & dungeons", "Places", "Wealth & items", "People & chat", "Life & habits", "Time", "Other" },
    default = "Other",
    rules = {
        { "Bosses & dungeons", "^guide_" }, { "Bosses & dungeons", "dungeon" }, { "Bosses & dungeons", "^boss" }, { "Bosses & dungeons", "instance" },
        { "Bosses & dungeons", "^bg" }, { "Bosses & dungeons", "_party$" }, { "Bosses & dungeons", "_raid$" },
        { "People & chat", "groupedtime" }, { "Life & habits", "^skills$" },
        { "Places", "zone" }, { "Places", "continent" }, { "Places", "city" }, { "Places", "bindspots" }, { "Places", "innvisits" },
        { "Time", "hour" }, { "Time", "weekdays" }, { "Time", "time$" }, { "Time", "leveltime" }, { "Time", "sessionlog" },
        { "Time", "recordhistory" },
        { "Wealth & items", "item" }, { "Wealth & items", "loot" }, { "Wealth & items", "gold" }, { "Wealth & items", "epics" },
        { "Wealth & items", "herbs" }, { "Wealth & items", "ores" }, { "Wealth & items", "created" }, { "Wealth & items", "worn" },
        { "Wealth & items", "^mail" }, { "Wealth & items", "^trade" }, { "Wealth & items", "hearthsowned" },
        { "People & chat", "whisper" }, { "People & chat", "npcnames" }, { "People & chat", "^reps$" }, { "People & chat", "emotes" },
        { "People & chat", "grouprun" }, { "People & chat", "firstkillmates" }, { "People & chat", "players" },
        { "Combat", "spell" }, { "Combat", "creature" }, { "Combat", "killer" }, { "Combat", "kill" }, { "Combat", "hurt" },
        { "Combat", "damage" }, { "Combat", "enem" }, { "Combat", "critters" }, { "Combat", "rares" }, { "Combat", "envdamage" },
        { "Combat", "standinfire" }, { "Combat", "^cc_" }, { "Combat", "formtime" }, { "Combat", "lowbie" }, { "Combat", "death" },
        { "Life & habits", "." },
    },
}
function ns.ListSection(l)
    local id = l.id or ""
    for _, r in ipairs(ns.LIST_SECTIONS.rules) do
        if id:find(r[2]) then return r[1] end
    end
    return ns.LIST_SECTIONS.default
end
function ns.SectionedLists()
    local buckets = {}
    for _, l in ipairs(ns.LISTS) do
        local name = ns.ListSection(l)
        buckets[name] = buckets[name] or {}
        table.insert(buckets[name], l)
    end
    local out = {}
    for _, name in ipairs(ns.LIST_SECTIONS.order) do
        if buckets[name] then out[#out + 1] = { name = name, lists = buckets[name] } end
    end
    return out
end

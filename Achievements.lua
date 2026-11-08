-- LifeTimeStats - achievements: tiered badges earned from lifetime values
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local function c(v, k) return (v.c and v.c[k]) or 0 end
local function r(v, k) return (v.r and v.r[k]) or 0 end
local function u(v, k) return (v.un and v.un[k]) or 0 end
local function f(v, k) return v.f and v.f[k] end
local G = 10000 -- copper per gold
local H = 3600

ns.TIER_POINTS = { 5, 10, 25, 50, 100, 200 }
ns.TIER_NAMES = { "I", "II", "III", "IV", "V", "VI" }

-- desc uses %s for the formatted tier target. below = lower is better (fastest times).
ns.ACHIEVEMENTS = {
    -- Travel
    { id = "steps", name = "Walk It Off", cat = "Travel", icon = "steps", desc = "Take %s steps", fmt = "int", tiers = { 1000, 10000, 100000, 1000000, 10000000 }, value = ns.Steps },
    { id = "jumps", name = "Bunny Hopper", cat = "Travel", icon = "jump", desc = "Jump %s times", fmt = "int", tiers = { 100, 1000, 10000, 50000, 250000 }, value = function(v) return c(v, "jumps") end },
    { id = "airtime", name = "Frequent Flier (Unlicensed)", cat = "Travel", icon = "fall", desc = "Spend %s in the air", fmt = "time", tiers = { 60, 600, H, 10 * H }, value = function(v) return c(v, "airtime") end },
    { id = "flights", name = "Window Seat", cat = "Travel", icon = "wing", desc = "Take %s flight paths", fmt = "int", tiers = { 10, 50, 250, 1000 }, value = function(v) return c(v, "flights") end },
    { id = "taxi", name = "Gryphon Miles", cat = "Travel", icon = "wing", desc = "Fly %s on flight paths", fmt = "yards", tiers = { 10000, 100000, 1000000, 5000000 }, value = function(v) return c(v, "dist_taxi") end },
    { id = "swim", name = "Fish Out of Water", cat = "Travel", icon = "travel", desc = "Swim %s", fmt = "yards", tiers = { 1000, 10000, 100000, 1000000 }, value = function(v) return c(v, "dist_swim") end },
    { id = "mounted", name = "Saddle Sore", cat = "Travel", icon = "horseshoe", desc = "Ride %s mounted", fmt = "yards", tiers = { 10000, 100000, 1000000, 10000000 }, value = function(v) return c(v, "dist_mount") end },
    { id = "zones", name = "Tourist", cat = "Travel", icon = "travel", desc = "Visit %s different zones", fmt = "int", tiers = { 5, 15, 30, 45 }, value = function(v) return u(v, "zones") end },
    { id = "subzones", name = "Off the Beaten Path", cat = "Travel", icon = "travel", desc = "Visit %s different subzones", fmt = "int", tiers = { 25, 100, 250, 500 }, value = function(v) return u(v, "subzones") end },
    { id = "hearth", name = "There's No Place Like Home", cat = "Travel", icon = "star", desc = "Use your Hearthstone %s times", fmt = "int", tiers = { 10, 100, 500, 1000 }, value = function(v) return c(v, "hearths") end },
    { id = "shapeshift", name = "Identity Crisis", cat = "Travel", icon = "star", desc = "Shapeshift %s times", fmt = "int", tiers = { 100, 1000, 10000, 50000 }, value = function(v) return c(v, "shapeshifts") end },
    -- Combat
    { id = "kills", name = "Slayer", cat = "Combat", icon = "sword", desc = "Kill %s enemies", fmt = "int", tiers = { 100, 1000, 10000, 50000, 100000 }, value = ns.Kills },
    { id = "pvp", name = "Gladiator", cat = "Combat", icon = "crown", desc = "Kill %s enemy players", fmt = "int", tiers = { 1, 100, 1000, 10000 }, value = function(v) return c(v, "kills_pvp") end },
    { id = "rares", name = "Rare Hunter", cat = "Combat", icon = "crown", desc = "Kill %s rares", fmt = "int", tiers = { 1, 10, 50, 200 }, value = function(v) return c(v, "kills_rare") end },
    { id = "elites", name = "Elite Squad", cat = "Combat", icon = "crown", desc = "Kill %s elites", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "kills_elite") end },
    { id = "giant", name = "Giant Slayer", cat = "Combat", icon = "sword", desc = "Kill %s enemies 5+ levels above you", fmt = "int", tiers = { 1, 25, 100 }, value = function(v) return c(v, "kills_red") end },
    { id = "bully", name = "Bully", cat = "Silly", icon = "skull", desc = "Kill %s grey enemies", fmt = "int", tiers = { 100, 1000, 10000 }, value = function(v) return c(v, "kills_grey") end },
    { id = "duels", name = "Duelist", cat = "Combat", icon = "sword", desc = "Win %s duels", fmt = "int", tiers = { 1, 10, 50, 250 }, value = function(v) return c(v, "duels_won") end },
    { id = "crits", name = "Critical Mass", cat = "Combat", icon = "star", desc = "Land %s critical hits", fmt = "int", tiers = { 100, 1000, 10000, 100000 }, value = function(v) return c(v, "crits") end },
    { id = "critchain", name = "On a Roll", cat = "Combat", icon = "star", desc = "Crit %s times in a row", fmt = "int", tiers = { 3, 5, 8, 12 }, value = function(v) return r(v, "max_crit_streak") end },
    { id = "avoid", name = "Untouchable", cat = "Combat", icon = "shield", desc = "Dodge or parry %s attacks", fmt = "int", tiers = { 100, 1000, 10000, 50000 }, value = function(v) return c(v, "in_dodge") + c(v, "in_parry") end },
    { id = "blocks", name = "Wall", cat = "Combat", icon = "shield", desc = "Block %s attacks", fmt = "int", tiers = { 50, 500, 5000 }, value = function(v) return c(v, "in_block") end },
    { id = "bighit", needs = "amount", name = "Heavy Hitter", cat = "Combat", icon = "sword", desc = "Hit for %s in one blow", fmt = "int", tiers = { 500, 1000, 2500, 5000 }, value = function(v) return r(v, "max_hit") end },
    { id = "heal", needs = "dm", name = "Field Medic", cat = "Combat", icon = "heart", desc = "Heal %s", fmt = "int", tiers = { 10000, 100000, 1000000, 10000000 }, value = function(v) return c(v, "heal_done") end },
    { id = "interrupts", needs = "dm", name = "Rude Interruption", cat = "Combat", icon = "sword", desc = "Interrupt %s spells", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "interrupts") end },
    { id = "sigspell", needs = "dm", name = "Signature Spell", cat = "Combat", icon = "star", desc = "Deal %s damage with one spell", fmt = "int", tiers = { 10000, 100000, 1000000, 10000000 }, value = function(v) local t = ns.TopList(v, "spelldamage", 1)[1] return t and t[2] or 0 end },
    { id = "topmeter", needs = "dm", name = "Top of the Meter", cat = "Combat", icon = "crown", desc = "Top the damage meter in %s group fights", fmt = "int", tiers = { 1, 10, 100, 1000 }, value = function(v) return c(v, "meter_topped") end },
    { id = "petpower", needs = "dm", name = "Good Boy", cat = "Combat", icon = "heart", desc = "Let your pet deal %s damage", fmt = "int", tiers = { 10000, 100000, 1000000 }, value = function(v) return c(v, "dmg_pet") end },
    { id = "infire", needs = "dm", name = "Is This Lava?", cat = "Silly", icon = "fall", desc = "Stand in the fire in %s fights", fmt = "int", tiers = { 1, 25, 250 }, value = function(v) return c(v, "fights_in_fire") end },
    { id = "streak", name = "Unstoppable", cat = "Combat", icon = "skull", desc = "Get %s kills without dying", fmt = "int", tiers = { 50, 250, 1000, 5000 }, value = function(v) return r(v, "max_streak") end },
    { id = "bgwins", name = "Warmonger", cat = "Combat", icon = "crown", desc = "Win %s battlegrounds", fmt = "int", tiers = { 1, 10, 50, 250 }, value = function(v) return c(v, "bg_won") end },
    -- Deaths
    { id = "deaths", name = "Mortal", cat = "Deaths", icon = "skull", desc = "Die %s times", fmt = "int", tiers = { 1, 10, 100, 500, 1000 }, value = function(v) return c(v, "deaths") end },
    { id = "gravity", name = "Gravity Always Wins", cat = "Deaths", icon = "fall", desc = "Die from falling %s times", fmt = "int", tiers = { 1, 10, 50 }, value = function(v) return c(v, "deaths_fall") end },
    { id = "drown", name = "Forgot to Breathe", cat = "Deaths", icon = "skull", desc = "Drown %s times", fmt = "int", tiers = { 1, 5, 25 }, value = function(v) return c(v, "deaths_drown") end },
    { id = "survivor", name = "Stuck the Landing", cat = "Deaths", icon = "fall", desc = "Survive %s painful falls", fmt = "int", tiers = { 10, 100, 500 }, value = function(v) return c(v, "falls_survived") end },
    { id = "bigfall", name = "Barely", cat = "Deaths", icon = "fall", desc = "Survive a fall costing %s of your health", fmt = "pct", tiers = { 50, 75, 90, 95 }, value = function(v) return r(v, "max_fall_survived_pct") end },
    { id = "ghostrun", name = "Marathon Ghost", cat = "Deaths", icon = "travel", desc = "Run %s back to your corpse in one go", fmt = "yards", tiers = { 500, 1500, 3000 }, value = function(v) return r(v, "max_corpse_dist") end },
    { id = "corpses", name = "Spirit Walker", cat = "Deaths", icon = "travel", desc = "Make %s corpse runs", fmt = "int", tiers = { 10, 100, 500 }, value = function(v) return c(v, "corpse_runs") end },
    { id = "alive", name = "Still Breathing", cat = "Deaths", icon = "heart", desc = "Stay alive for %s of play", fmt = "time", tiers = { H, 10 * H, 50 * H }, value = function(v) return r(v, "max_alive") end },
    -- Adventure
    { id = "quests", name = "Questor", cat = "Adventure", icon = "scroll", desc = "Complete %s quests", fmt = "int", tiers = { 10, 100, 500, 1000, 2500 }, value = function(v) return c(v, "quests_done") end },
    { id = "abandon", name = "Commitment Issues", cat = "Adventure", icon = "scroll", desc = "Abandon %s quests", fmt = "int", tiers = { 10, 50, 200 }, value = function(v) return c(v, "quests_abandoned") end },
    { id = "dboss", name = "Dungeoneer", cat = "Adventure", icon = "tower", desc = "Kill %s dungeon bosses", fmt = "int", tiers = { 1, 25, 100, 500 }, value = function(v) return c(v, "boss_kills_party") end },
    { id = "score", name = "Living Legend", cat = "Adventure", icon = "star", desc = "Reach an Adventurer score of %s", fmt = "int", tiers = { 1000, 5000, 15000, 40000 }, value = function(v) return ns.Score and ns.Score(v) or 0 end },
    { id = "flags", name = "Capture the Flag", cat = "Combat", icon = "sword", desc = "Capture %s flags", fmt = "int", tiers = { 1, 10, 50 }, value = function(v) return c(v, "bg_flags_captured") end },
    { id = "bgstreak", name = "On a Roll", cat = "Combat", icon = "sword", desc = "Win %s battlegrounds in a row", fmt = "int", tiers = { 3, 5, 10 }, value = function(v) return r(v, "max_bg_streak") end },
    { id = "exalted", name = "Best Friends Forever", cat = "Adventure", icon = "social", desc = "Be Exalted with %s factions", fmt = "int", tiers = { 1, 3, 8 }, value = function(v) return r(v, "max_exalted") end },
    { id = "djclear", name = "Dungeon Crawler", cat = "Adventure", icon = "tower", desc = "Fully clear %s different dungeons", fmt = "int", tiers = { 1, 5, 15, 35 }, value = function(v) return u(v, "dungeons_cleared") end },
    { id = "djnew", name = "Brave New World", cat = "Adventure", icon = "tower", desc = "Fully clear %s of Forever's new dungeons", fmt = "int", tiers = { 1, 3, 6, 9 }, value = function(v) return u(v, "forever_dungeons_cleared") end },
    { id = "djbook", name = "Bestiary Complete", cat = "Adventure", icon = "scroll", desc = "Find every boss of %s dungeons", fmt = "int", tiers = { 1, 5, 15, 35 }, value = function(v) return u(v, "dj_books") end },
    { id = "djunder", name = "Punching Up", cat = "Adventure", icon = "sword", desc = "Fully clear a dungeon below its level range %s times", fmt = "int", tiers = { 1, 5, 20 }, value = function(v) return c(v, "dj_clears_under") end },
    { id = "dbossu", name = "Collector of Heads", cat = "Adventure", icon = "tower", desc = "Kill %s different dungeon bosses", fmt = "int", tiers = { 5, 25, 75 }, value = function(v) return u(v, "bosses_party") end },
    { id = "rboss", name = "Raider", cat = "Adventure", icon = "crown", desc = "Kill %s raid bosses", fmt = "int", tiers = { 1, 10, 50, 200 }, value = function(v) return c(v, "boss_kills_raid") end },
    { id = "clears", name = "Clean Sweep", cat = "Adventure", icon = "crown", desc = "Fully clear %s raids", fmt = "int", tiers = { 1, 5, 25 }, value = function(v) return c(v, "raid_clears") end },
    { id = "runs", name = "Instance Regular", cat = "Adventure", icon = "tower", desc = "Run %s dungeons", fmt = "int", tiers = { 10, 50, 250, 1000 }, value = function(v) return c(v, "runs_party") end },
    { id = "levels", name = "Growing Up", cat = "Adventure", icon = "adventure", desc = "Gain %s levels", fmt = "int", tiers = { 5, 20, 40, 59 }, value = function(v) return c(v, "levels") end },
    { id = "fish", name = "Patient Angler", cat = "Adventure", icon = "star", desc = "Catch %s fish", fmt = "int", tiers = { 10, 100, 1000, 5000 }, value = function(v) return c(v, "fish") end },
    { id = "gather", name = "Gatherer", cat = "Adventure", icon = "star", desc = "Gather %s herbs, ore or skins", fmt = "int", tiers = { 50, 500, 2500, 10000 }, value = function(v) return c(v, "gather_herb") + c(v, "gather_mine") + c(v, "gather_skin") end },
    { id = "craft", name = "Artisan", cat = "Adventure", icon = "star", desc = "Craft %s items", fmt = "int", tiers = { 50, 500, 2500 }, value = function(v) return c(v, "items_crafted") end },
    { id = "rep", name = "Well Regarded", cat = "Adventure", icon = "star", desc = "Gain %s reputation", fmt = "int", tiers = { 1000, 10000, 100000, 500000 }, value = function(v) return c(v, "rep_gained") end },
    -- Wealth
    { id = "earned", name = "Earner", cat = "Wealth", icon = "coin", desc = "Earn %s", fmt = "money", tiers = { G, 100 * G, 1000 * G, 10000 * G, 100000 * G }, value = function(v) return c(v, "money_in") end },
    { id = "spent", name = "Big Spender", cat = "Wealth", icon = "coin", desc = "Spend %s", fmt = "money", tiers = { 100 * G, 1000 * G, 10000 * G }, value = function(v) return c(v, "money_out") end },
    { id = "hoard", name = "Dragon's Hoard", cat = "Wealth", icon = "coin", desc = "Carry %s at once", fmt = "money", tiers = { 100 * G, 1000 * G, 5000 * G }, value = function(v) return r(v, "max_money") end },
    { id = "repair", name = "Fix It Again", cat = "Wealth", icon = "shield", desc = "Spend %s on repairs", fmt = "money", tiers = { 10 * G, 100 * G, 1000 * G }, value = function(v) return c(v, "money_repair") end },
    { id = "loot", name = "Loot Goblin", cat = "Wealth", icon = "chest", desc = "Loot %s items", fmt = "int", tiers = { 100, 1000, 10000, 50000 }, value = function(v) return c(v, "items_looted") end },
    { id = "epics", name = "Purple Rain", cat = "Wealth", icon = "chest", desc = "Loot %s epic items", fmt = "int", tiers = { 1, 10, 50 }, value = function(v) return c(v, "loot_q4") end },
    { id = "grey", name = "Junk Drawer", cat = "Wealth", icon = "chest", desc = "Loot %s grey items", fmt = "int", tiers = { 100, 1000, 10000 }, value = function(v) return c(v, "loot_q0") end },
    { id = "bagsfull", name = "Hoarder's Dilemma", cat = "Wealth", icon = "chest", desc = "See \"Inventory is full\" %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "bags_full") end },
    -- Social & Silly
    { id = "dance", name = "Dance Floor", cat = "Silly", icon = "social", desc = "Dance %s times", fmt = "int", tiers = { 1, 10, 100, 1000 }, value = function(v) return c(v, "emote_DANCE") end },
    { id = "chicken", name = "Bawk Bawk", cat = "Silly", icon = "social", desc = "/chicken %s times", fmt = "int", tiers = { 1, 10, 100 }, value = function(v) return c(v, "emote_CHICKEN") end },
    { id = "critterlove", name = "Critter Whisperer", cat = "Silly", icon = "heart", desc = "/love a critter %s times", fmt = "int", tiers = { 1, 10, 50, 250 }, value = function(v) return c(v, "critters_loved") end },
    { id = "critterkill", name = "You Monster", cat = "Silly", icon = "skull", desc = "Kill %s critters", fmt = "int", tiers = { 1, 25, 100, 500 }, value = function(v) return c(v, "critter_kills") end },
    { id = "lovekill", name = "Love It, Then End It", cat = "Silly", icon = "skull", desc = "/love a critter, then kill it, %s times", fmt = "int", tiers = { 1, 10, 50 }, value = function(v) return c(v, "critters_love_kill") end },
    { id = "fashion", name = "Fashionista", cat = "Wealth", icon = "chest", desc = "Collect %s appearances", fmt = "int", tiers = { 10, 100, 500, 2000 }, value = function(v) return c(v, "appearances") end },
    { id = "conjure", name = "Conjurer", cat = "Adventure", icon = "star", desc = "Conjure %s items", fmt = "int", tiers = { 100, 1000, 10000 }, value = function(v) return c(v, "conjured") end },
    { id = "drunk", name = "Barfly", cat = "Silly", icon = "social", desc = "Get drunk %s times", fmt = "int", tiers = { 1, 10, 50, 250 }, value = function(v) return c(v, "times_drunk") end },
    { id = "smashed", name = "Completely Smashed", cat = "Silly", icon = "social", desc = "Get completely smashed %s times", fmt = "int", tiers = { 1, 10, 50 }, value = function(v) return c(v, "drunk_smashed") end },
    { id = "fire", name = "Firestarter", cat = "Adventure", icon = "star", desc = "Light %s campfires", fmt = "int", tiers = { 1, 25, 250, 1000 }, value = function(v) return c(v, "campfires") end },
    { id = "camp", name = "Sleeping Rough", cat = "Adventure", icon = "travel", desc = "Camp out %s nights", fmt = "int", tiers = { 1, 10, 100, 500 }, value = function(v) return c(v, "nights_camped") end },
    { id = "wild", name = "Wanderer", cat = "Adventure", icon = "travel", desc = "Spend %s in the wild without visiting a town", fmt = "time", tiers = { 1800, 7200, 28800 }, value = function(v) return r(v, "max_wild") end },
    { id = "books", name = "Bookworm", cat = "Adventure", icon = "scroll", desc = "Read %s books or letters", fmt = "int", tiers = { 1, 10, 50, 200 }, value = function(v) return c(v, "books_read") end },
    { id = "paths", name = "Pathfinder", cat = "Travel", icon = "wing", desc = "Discover %s flight paths", fmt = "int", tiers = { 1, 10, 25, 40 }, value = function(v) return c(v, "flightpaths_found") end },
    { id = "potions", name = "Potion Junkie", cat = "Adventure", icon = "heart", desc = "Drink %s potions", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "potions") end },
    { id = "bindspots", name = "Home Is Where the Hearth Is", cat = "Travel", icon = "star", desc = "Set your hearth in %s different places", fmt = "int", tiers = { 2, 5, 10, 20 }, value = function(v) return u(v, "bindspots") end },
    { id = "hearthsown", name = "Homesick", cat = "Travel", icon = "star", desc = "Own %s different hearthstones", fmt = "int", tiers = { 1, 3, 10, 25 }, value = function(v) return u(v, "hearthstones") end },
    { id = "nightowl", name = "Night Owl", cat = "Silly", icon = "clock", desc = "Adventure %s at night (game time)", fmt = "time", tiers = { 3600, 36000, 360000 }, value = function(v) return c(v, "time_night") end },
    { id = "inns", name = "Innhopper", cat = "Travel", icon = "star", desc = "Rest at %s different inns", fmt = "int", tiers = { 3, 10, 25 }, value = function(v) return u(v, "inns") end },
    { id = "mounts", name = "Stable Master", cat = "Travel", icon = "horseshoe", desc = "Ride %s different mounts", fmt = "int", tiers = { 1, 5, 20 }, value = function(v) return u(v, "mounts") end },
    { id = "naked", name = "Wardrobe Malfunction", cat = "Silly", icon = "person", desc = "Spend %s with no chest armor", fmt = "time", tiers = { 60, 3600, 36000 }, value = function(v) return c(v, "time_naked") end },
    { id = "lowbie", name = "Humbled", cat = "Deaths", icon = "skull", desc = "Get killed by something 5+ levels below you %s times", fmt = "int", tiers = { 1, 5, 25 }, value = function(v) return c(v, "deaths_lowbie") end },
    { id = "wellfed", name = "Gourmand", cat = "Adventure", icon = "heart", desc = "Be Well Fed %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "well_fed") end },
    { id = "whispered", name = "Popular", cat = "Silly", icon = "social", desc = "Get whispered by %s different people", fmt = "int", tiers = { 5, 25, 100 }, value = function(v) return u(v, "whisperers") end },
    { id = "haircut", name = "New Look", cat = "Silly", icon = "person", desc = "Get %s haircuts", fmt = "int", tiers = { 1, 5, 25 }, value = function(v) return c(v, "haircuts") end },
    { id = "fpknown", name = "Gryphon Master", cat = "Travel", icon = "wing", desc = "Know %s flight paths", fmt = "int", tiers = { 5, 15, 30 }, value = function(v) return r(v, "flightpaths_known") end },
    { id = "lol", name = "LOL", cat = "Silly", icon = "social", desc = "Say lol %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "lols") end },
    { id = "polite", name = "Well Mannered", cat = "Silly", icon = "heart", desc = "Say thanks %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "thanks_said") end },
    { id = "hug", name = "Free Hugs", cat = "Silly", icon = "heart", desc = "Hug %s times", fmt = "int", tiers = { 1, 25, 250 }, value = function(v) return c(v, "emote_HUG") end },
    { id = "chat", name = "Chatterbox", cat = "Silly", icon = "social", desc = "Send %s chat messages", fmt = "int", tiers = { 100, 1000, 10000, 50000 }, value = function(v) return c(v, "chat_sent") end },
    { id = "rolls", name = "Gambler", cat = "Silly", icon = "star", desc = "/roll %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "rolls") end },
    { id = "perfect", name = "Natural 100", cat = "Silly", icon = "star", desc = "Roll the maximum %s times", fmt = "int", tiers = { 1, 5, 25 }, value = function(v) return c(v, "rolls_max") end },
    { id = "friends", name = "Social Butterfly", cat = "Silly", icon = "person", desc = "Group with %s different players", fmt = "int", tiers = { 10, 50, 250, 1000 }, value = function(v) return u(v, "groupmates") end },
    { id = "npcs", name = "NPC Whisperer", cat = "Silly", icon = "person", desc = "Meet %s different NPCs", fmt = "int", tiers = { 25, 100, 500, 1000 }, value = function(v) return u(v, "npcs") end },
    { id = "errors", name = "Not Enough Mana", cat = "Silly", icon = "skull", desc = "See %s red error messages", fmt = "int", tiers = { 100, 1000, 10000, 50000 }, value = function(v) return c(v, "ui_errors") end },
    { id = "sits", name = "Take a Seat", cat = "Silly", icon = "person", desc = "Sit down %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "sits") end },
    { id = "afk", name = "Brb", cat = "Silly", icon = "clock", desc = "Be AFK for %s", fmt = "time", tiers = { H, 10 * H, 100 * H }, value = function(v) return c(v, "time_afk") end },
    { id = "map", name = "Where Am I?", cat = "Silly", icon = "travel", desc = "Open the world map %s times", fmt = "int", tiers = { 100, 1000, 10000 }, value = function(v) return c(v, "map_opens") end },
    { id = "selfaware", name = "Self-Aware", cat = "Silly", icon = "dashboard", desc = "Open LifeTimeStats %s times", fmt = "int", tiers = { 10, 100, 1000 }, value = function(v) return c(v, "lts_opens") end },
    -- Fastest (lower is better)
    { id = "fastlevel", name = "Speed Leveler", cat = "Fastest", icon = "fastest", desc = "Gain a level in under %s", fmt = "time", below = true, tiers = { 60 * 60, 30 * 60, 15 * 60, 5 * 60 }, value = function(v) return f(v, "level_fast") end },
    { id = "fastquest", name = "Express Delivery", cat = "Fastest", icon = "fastest", desc = "Finish a quest in under %s", fmt = "time", below = true, tiers = { 300, 60, 30 }, value = function(v) return f(v, "quest_fast") end },
    { id = "tenkills", name = "Rapid Fire", cat = "Fastest", icon = "fastest", desc = "Kill 10 enemies in under %s", fmt = "time", below = true, tiers = { 120, 60, 30, 15 }, value = function(v) return f(v, "ten_kills") end },
    { id = "fastcorpse", name = "Back in a Flash", cat = "Fastest", icon = "fastest", desc = "Finish a corpse run in under %s", fmt = "time", below = true, tiers = { 120, 60, 30 }, value = function(v) return f(v, "corpse_fast") end },
    { id = "fastfight", name = "Blink and You Miss It", cat = "Fastest", icon = "fastest", desc = "Win a fight in under %s", fmt = "time", below = true, tiers = { 5, 2, 1 }, value = function(v) return f(v, "fight_fast") end },
}

-- ------------------------------------------------------------ engine
-- Some achievements need data Forever keeps from addons. They stay listed but are
-- left out of the totals until the data shows up.
function ns.AchAvailable(def)
    if not def.needs or ns.cleuSeen then return true end
    if def.needs == "dm" then return (ns.settings and ns.settings.dmReadable) or (ns.src and ns.src.dmReadable) or false end
    if def.needs == "amount" then
        if ns.settings.dmHitReadable then return true end
        return not (ns.settings.amountsSecret and not (ns.src and ns.src.amountReadable))
    end
    return false
end
local function Tier(def, v)
    if v == nil then return 0 end
    local t = 0
    for i, target in ipairs(def.tiers) do
        if def.below then
            if v > 0 and v <= target then t = i end
        elseif v >= target then t = i end
    end
    return t
end
ns.AchTier = Tier

-- Returns state for one definition against a view.
function ns.AchState(def, view)
    local v = def.value(view)
    local tier = Tier(def, v)
    local nextT = def.tiers[tier + 1]
    local prog
    if not nextT then prog = 1
    elseif def.below then
        local prev = def.tiers[tier] or (nextT * 2)
        prog = (v and v > 0) and math.max(0, math.min(1, (prev - v) / (prev - nextT))) or 0
    else
        local prev = def.tiers[tier] or 0
        prog = math.max(0, math.min(1, ((v or 0) - prev) / (nextT - prev)))
    end
    return { value = v, tier = tier, max = #def.tiers, nextTarget = nextT, progress = prog }
end

function ns.AchKey(def, tier) return def.id .. ":" .. tier end

function ns.AchTotals(view)
    local earned, total, points, maxPoints = 0, 0, 0, 0
    local ach = view.ach or {}
    for _, def in ipairs(ns.ACHIEVEMENTS) do
        if not ns.AchAvailable(def) then
            -- skipped: not measurable on this client
        else
        for t = 1, #def.tiers do
            total = total + 1
            maxPoints = maxPoints + ns.TIER_POINTS[t]
            if ach[ns.AchKey(def, t)] then earned = earned + 1; points = points + ns.TIER_POINTS[t] end
        end
        end
    end
    return earned, total, points, maxPoints
end

function ns.AchNewCount()
    return (ns.char and ns.char.meta.achUnseen) or 0
end

function ns.AchMarkSeen()
    if ns.char then ns.char.meta.achUnseen = 0 end
end

-- ------------------------------------------------------------ toast
local toast
local function ShowToast(def, tier)
    local T, W = ns.THEME, ns.W
    if not toast then
        toast = W.Panel(UIParent, T.bg)
        toast:SetSize(300, 58)
        toast:SetPoint("TOP", UIParent, "TOP", 0, -140)
        toast:SetFrameStrata("DIALOG")
        local bar = W.Fill(toast, T.amber, "ARTWORK"); bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("BOTTOMLEFT", 1, 1); bar:SetWidth(3)
        toast.icon = W.Icon(toast, "star", 30); toast.icon:SetPoint("LEFT", 14, 0)
        toast.head = W.Text(toast, 10, T.dim); toast.head:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 12, 2)
        toast.name = W.Text(toast, 14, T.amber); toast.name:SetPoint("TOPLEFT", toast.head, "BOTTOMLEFT", 0, -3)
        toast.desc = W.Text(toast, 11, T.text); toast.desc:SetPoint("TOPLEFT", toast.name, "BOTTOMLEFT", 0, -2)
        toast:EnableMouse(true)
        toast:SetScript("OnMouseUp", function()
            toast:Hide()
            ns.ToggleWindow()
            if ns.ShowPage then ns.ShowPage("achievements") end
        end)
    end
    toast.icon:SetTexture(W.MEDIA .. "icons\\" .. def.icon)
    toast.head:SetText("ACHIEVEMENT EARNED · " .. ns.TIER_POINTS[tier] .. " POINTS")
    toast.name:SetText(def.name .. " " .. ns.TIER_NAMES[tier])
    toast.desc:SetText(string.format(def.desc, ns.FMT[def.fmt](def.tiers[tier])))
    toast:SetAlpha(1)
    toast:Show()
    toast.hideAt = GetTime() + 5
    toast:SetScript("OnUpdate", function(self)
        local left = self.hideAt - GetTime()
        if left <= 0 then self:Hide(); self:SetScript("OnUpdate", nil)
        elseif left < 1 then self:SetAlpha(left) end
    end)
end

local function Announce(def, tier)
    local mode = ns.settings.achAnnounce
    if mode == "chat" or mode == "both" then
        ns.Print(string.format("Achievement earned: %s%s %s|r - %s", ns.GOLD, def.name, ns.TIER_NAMES[tier],
            string.format(def.desc, ns.FMT[def.fmt](def.tiers[tier]))))
    end
    if mode == "toast" or mode == "both" then ShowToast(def, tier) end
end

-- Checks every definition against this character. Returns how many tiers were newly earned.
function ns.CheckAchievements(silent)
    local ch = ns.char
    if not ch then return 0 end
    local now = time()
    local retro = not ch.meta.achInit
    local newly = 0
    for _, def in ipairs(ns.ACHIEVEMENTS) do
        local ok, v = pcall(def.value, ch)
        if ok then
            local tier = Tier(def, v)
            for t = 1, tier do
                local key = ns.AchKey(def, t)
                if not ch.ach[key] then
                    ch.ach[key] = now
                    if retro then
                        ch.achr[key] = true
                    else
                        newly = newly + 1
                        ch.meta.achUnseen = (ch.meta.achUnseen or 0) + 1
                        if not silent then Announce(def, t) end
                        if ns.Journal then ns.Journal("Achievement: " .. def.name .. " " .. ns.TIER_NAMES[t]) end
                        if ns.OnAchievement and not silent then ns.OnAchievement(def, t) end
                    end
                end
            end
        end
    end
    ch.meta.achInit = true
    return newly
end

local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", ns.Guard("achievements", function(_, el)
    acc = acc + el
    if acc < 2 then return end
    acc = 0
    if ns.char then
        local ok, err = pcall(ns.CheckAchievements)
        if not ok then ns.LogError("achievements", err) end
    end
end))

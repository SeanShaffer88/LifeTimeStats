-- LifeTimeStats - dungeon book: every Forever dungeon and raid with its level range and bosses.
-- Counts bosses found per dungeon, full clears, fastest clear, and runs under / in / over level.
-- Boss lists: Warcraft Tavern Forever guides (2026-11). Where a guide was incomplete
-- (marked learn = true) bosses you kill there are added as you meet them.
-- If DungeonJournal (Exehn) is installed, Dungeons.lua can read its data too (see DJ section).
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Tally, Unique, On = ns.Add, ns.Tally, ns.Unique, ns.On
local S = ns.IsSecret

-- key, name, min, max, zone, instance (GetInstanceInfo name when it differs), bosses (* = optional / rare), flags
local D = {
    { "rfc",   "Ragefire Chasm", 13, 18, "Orgrimmar", nil, "Oggleflint, Taragaman the Hungerer, Jergosh the Invoker, Bazzalan" },
    { "thanes","Hall of Thanes", 13, 20, "Ironforge", nil, "Faldrim Anvilmar, Magmatus, Plunder, Durgen Dirgehammer", new = true },
    { "rol",   "Ruins of Lordaeron", 15, 22, "Tirisfal Glades", nil, "Witherfang, The Baron, Viktor the Vile*, The Abandoned*, Bjork, Rath'mael, Lordaeron Captain*", new = true },
    { "wc",    "Wailing Caverns", 15, 24, "The Barrens", nil, "Kresh, Lady Anacondra, Lord Cobran, Deviate Faerie Dragon*, Lord Pythas, Skum, Lord Serpentis, Verdan the Everliving, Mutanus the Devourer" },
    { "dm",    "The Deadmines", 17, 26, "Westfall", nil, "Rhahk'zor, Miner Johnson*, Sneed's Shredder, Gilnid, Mr. Smite, Captain Greenskin, Edwin VanCleef, Cookie*" },
    { "sfk",   "Shadowfang Keep", 20, 30, "Silverpine Forest", nil, "Rethilgore, Razorclaw the Butcher, Baron Silverlaine, Commander Springvale, Odo the Blindwatcher, Deathsworn Captain*, Fenrus the Devourer, Wolf Master Nandos, Archmage Arugal" },
    { "bfd",   "Blackfathom Deeps", 24, 32, "Ashenvale", nil, "Ghamoo-ra, Lady Sarevess, Gelihast*, Lorgus Jett, Baron Aquanis, Twilight Lord Kelris, Old Serra'kis*, Aku'mai" },
    { "stocks","The Stockade", 25, 29, "Stormwind City", nil, "Targorr the Dread, Kam Deepfury, Hamhock, Bazil Thredd, Bruegal Ironknuckle*, Dextren Ward" },
    { "exc",   "Excavation Site: Wetlands", 26, 33, "Wetlands", nil, "Saltspine, Shadetooth, Highland Horror*, Relic Guardian", new = true },
    { "dal",   "City of Dalaran", 28, 35, "Alterac Mountains", nil, "Atrexis the Grave Knight, Lyn the Ignored*, Mana Devourer, Arcane Anomaly, Fel Ancient, Arcanic Enigma, Unstable Sentry, Shade of the Archmage", new = true },
    { "rfk",   "Razorfen Kraul", 29, 38, "The Barrens", nil, "Roogug, Aggem Thorncurse, Death Speaker Jargba, Overlord Ramtusk, Earthcaller Halmgar*, Agathelos the Raging, Blind Hunter*, Charlga Razorflank" },
    { "gnomer","Gnomeregan", 29, 38, "Dun Morogh", nil, "Grubbis, Viscous Fallout, Electrocutioner 6000, Crowd Pummeler 9-60, Dark Iron Ambassador*, Mekgineer Thermaplugg" },
    { "smgy",  "Scarlet Monastery Graveyard", 30, 38, "Tirisfal Glades", "Scarlet Monastery", "Interrogator Vishas, Ironspire*, Fallen Champion*, Azshir the Sleepless*, Bloodmage Thalnos" },
    { "smlib", "Scarlet Monastery Library", 33, 41, "Tirisfal Glades", "Scarlet Monastery", "Houndmaster Loksey, Arcanist Doan" },
    { "drown", "The Drowned City", 35, 42, "Stranglethorn Vale", nil, "Zul'Alai, Zin'aka, Var'Taka, Captain Dreadrise", new = true },
    { "smarm", "Scarlet Monastery Armory", 36, 44, "Tirisfal Glades", "Scarlet Monastery", "Herod" },
    { "rfd",   "Razorfen Downs", 37, 46, "The Barrens", nil, "Tuten'kash, Plaguemaw the Rotting*, Mordresh Fire Eye, Ragglesnout*, Glutton, Amnennar the Coldbringer" },
    { "smcath","Scarlet Monastery Cathedral", 38, 46, "Tirisfal Glades", "Scarlet Monastery", "High Inquisitor Fairbanks, Scarlet Commander Mograine, High Inquisitor Whitemane" },
    { "krol",  "Krol'Dok Stronghold", 40, 47, "Riverglades", nil, "Overlord Mugg", new = true, learn = true },
    { "ulda",  "Uldaman", 41, 51, "Badlands", nil, "The Lost Dwarves*, Revelosh, Ironaya, Obsidian Sentinel, Ancient Stone Keeper, Galgann Firehammer, Grimlok, Archaedas" },
    { "zf",    "Zul'Farrak", 44, 54, "Tanaris", nil, "Zerillis*, Antu'sul, Theka the Martyr, Witch Doctor Zum'rah, Dustwraith*, Shadowpriest Sezz'ziz, Sergeant Bly, Chief Ukorz Sandscalp, Hydromancer Velratha, Gahz'rilla, Sandarr Dunereaver*" },
    { "mara",  "Maraudon", 46, 55, "Desolace", nil, "Tinkerer Gizlock, Lord Vyletongue, Noxxion, Razorlash, Celebras the Cursed, Meshlok the Harvester*, Landslide, Rotgrip, Princess Theradras" },
    { "alcaz", "Alcaz Island Prison", 48, 55, "Dustwallow Marsh", nil, "Blazeroar*", new = true, learn = true },
    { "st",    "Sunken Temple", 50, 60, "Swamp of Sorrows", "The Temple of Atal'Hakkar", "Atal'alarion, Spawn of Hakkar, Jammal'an the Prophet, Weaver, Dreamscythe, Hazzas, Morphaz, Shade of Eranikus, Avatar of Hakkar" },
    { "brd",   "Blackrock Depths", 52, 60, "Blackrock Mountain", nil, "High Interrogator Gerstahn, Lord Roccor, Houndmaster Grebmar, Hedrum the Creeper, Gorosh the Dervish, Anub'shiah, Ok'thor the Breaker, Grizzle, Eviscerator, Theldren, Pyromancer Loregrain, Warder Stilgiss, Watchman Doomgrip, Fineous Darkvire, Lord Incendius, Bael'gar, General Angerforge, Golem Lord Argelmach, Ribbly Screwspigot*, Hurley Blackbreath*, Plugger Spazzring*, Phalanx, Ambassador Flamelash, Panzor the Invincible*, The Seven, Magmus, Emperor Dagran Thaurissan" },
    { "dme",   "Dire Maul (East)", 54, 60, "Feralas", "Dire Maul", "Pusillin, Lethtendris, Hydrospawn, Zevrin Thornhoof, Alzzin the Wildshaper, Isalien*" },
    { "lbrs",  "Lower Blackrock Spire", 55, 60, "Blackrock Mountain", "Blackrock Spire", "Burning Felguard*, Spirestone Butcher*, Spirestone Battle Lord*, Spirestone Lord Magus*, Highlord Omokk, Shadow Hunter Vosh'gajin, War Master Voone, Mor Grayhoof*, Bannok Grimaxe*, Mother Smolderweb, Crystal Fang*, Urok Doomhowl, Quartermaster Zigris, Halycon, Gizrul the Slavener, Ghok Bashguud*, Overlord Wyrmthalak" },
    { "black", "Blackmaw Hold", 55, 60, "Azshara", nil, "Varrox Bleakhoof", new = true, learn = true },
    { "dmw",   "Dire Maul (West)", 56, 60, "Feralas", "Dire Maul", "Tendris Warpwood, Magister Kalendris, Tsu'zee*, Illyanna Ravenoak, Immol'thar, Prince Tortheldrin, Lord Hel'nurath*" },
    { "dmn",   "Dire Maul (North)", 56, 60, "Feralas", "Dire Maul", "Guard Mol'dar*, Stomper Kreeg*, Guard Fengus*, Guard Slip'kik*, Captain Kromcrush*, King Gordok" },
    { "shaper","Shaper's Terrace", 58, 60, "Un'Goro Crater", nil, "Bolt, Cinder, Snowtalon, Nanaya", new = true, learn = true },
    { "stratl","Stratholme (Main Gate)", 58, 60, "Eastern Plaguelands", "Stratholme", "Skul*, The Unforgiven, Hearthsinger Forresten*, Postmaster Malown*, Timmy the Cruel, Crimson Hammersmith, Cannon Master Willey, Archivist Galford, Balnazzar, Jarien and Sothos*" },
    { "stratu","Stratholme (Service Gate)", 58, 60, "Eastern Plaguelands", "Stratholme", "Nerub'enkan, Stonespire*, Black Guard Swordsmith, Baroness Anastari, Maleki the Pallid, Magistrate Barthilas, Ramstein the Gorger, Baron Rivendare" },
    { "scholo","Scholomance", 58, 60, "Western Plaguelands", nil, "Kirtonos the Herald*, Jandice Barov*, Rattlegore, Death Knight Darkreaver*, Marduk Blackpool, Vectus, Ras Frostwhisper, Kormok*, Lady Illucia Barov, Lord Alexei Barov, The Ravenian, Lorekeeper Polkelt, Doctor Theolen Krastinov, Instructor Malicia, Darkmaster Gandling" },
    { "ubrs",  "Upper Blackrock Spire", 59, 60, "Blackrock Mountain", "Blackrock Spire", "Pyroguard Emberseer, Solakar Flamewreath, Goraluk Anvilcrack*, Warchief Rend Blackhand, The Beast, General Drakkisath, Jed Runewatcher*, Lord Valthalak*" },
    -- raids (open 2026-12-09)
    { "ony",   "Onyxia's Lair", 60, 60, "Dustwallow Marsh", nil, "Onyxia", raid = true },
    { "barrow","Barrow Deeps", 60, 60, "Mount Hyjal", nil, "Deepscar Matriarch, Khalith the Dreadspinner, Amethrax, Ravus and Darlissa, Elder Tangleclaw, Well of Sorrow, Del'lynar Songwood, Sonya Darkhallow", raid = true, new = true },
    { "hyjal", "Hyjal Summit", 60, 60, "Mount Hyjal", nil, "Bandalar, Time-Lost Battalion, Old Gloomlurker, Kathris the Haunted, Elder Minderei, Council of Thorns, The Wild King, Ancient of Decay, Sylvestris Dusksong, Gharalis the Abyssal, Anara Chillwind, Tracker Stillwind, Nythus the Dreadbound", raid = true, new = true },
}

-- Normalise names for matching: lower case, no "the ", no punctuation.
local function Norm(s)
    if type(s) ~= "string" or S(s) then return nil end
    s = s:lower():gsub("^the ", ""):gsub("[^%w ]", ""):gsub("%s+", " ")
    return s
end

ns.DUNGEONS, ns.DUNGEON_BY_KEY = {}, {}
local byInstance = {}   -- normalised instance name -> list of dungeons
for i, row in ipairs(D) do
    local d = { key = row[1], name = row[2], min = row[3], max = row[4], zone = row[5], instance = row[6] or row[2],
        new = row.new, raid = row.raid, learn = row.learn, order = i, bosses = {}, required = 0 }
    for b in row[7]:gmatch("[^,]+") do
        b = b:gsub("^%s+", ""):gsub("%s+$", "")
        local opt = b:sub(-1) == "*"
        if opt then b = b:sub(1, -2) end
        d.bosses[#d.bosses + 1] = { name = b, n = Norm(b), optional = opt }
        if not opt then d.required = d.required + 1 end
    end
    ns.DUNGEONS[i] = d
    ns.DUNGEON_BY_KEY[d.key] = d
    local k = Norm(d.instance)
    byInstance[k] = byInstance[k] or {}
    table.insert(byInstance[k], d)
    if d.instance ~= d.name then
        local k2 = Norm(d.name)
        byInstance[k2] = byInstance[k2] or {}
        table.insert(byInstance[k2], d)
    end
end
ns.DUNGEON_COUNT, ns.NEW_DUNGEON_COUNT = 0, 0
for _, d in ipairs(ns.DUNGEONS) do
    if not d.raid then
        ns.DUNGEON_COUNT = ns.DUNGEON_COUNT + 1
        if d.new then ns.NEW_DUNGEON_COUNT = ns.NEW_DUNGEON_COUNT + 1 end
    end
end

-- Does an encounter / unit name match a boss entry? Encounters can be pairs ("Weaver & Dreamscythe").
local function BossIndex(d, name)
    local n = Norm(name)
    if not n then return nil end
    for i, b in ipairs(d.bosses) do
        if b.n == n then return i end
    end
    for i, b in ipairs(d.bosses) do
        if #b.n >= 5 and (n:find(b.n, 1, true) or b.n:find(n, 1, true)) then return i end
    end
end

-- Which dungeon is this run? Wings share an instance name; the first boss you kill settles it.
local function Resolve(run, bossName)
    if not run or not run.name then return nil end
    if run.dkey then return ns.DUNGEON_BY_KEY[run.dkey] end
    local list = byInstance[Norm(run.name) or ""]
    if not list then return nil end
    if #list == 1 then run.dkey = list[1].key return list[1] end
    if bossName then
        for _, d in ipairs(list) do
            if BossIndex(d, bossName) then run.dkey = d.key return d end
        end
    end
end
ns.ResolveDungeon = Resolve

-- Progress lives in the standard sections so backups and the account view carry it:
-- u["djboss_<key>"] = bosses found, u["djlearn_<key>"] = bosses learned in partial dungeons,
-- t.dungeonruns / t.dungeonclears (by name), t.djlevel (first level), f["clear:<key>"] (fastest).
local function Set(v, name) return (v.u and v.u[name]) or {} end
function ns.DungeonProgress(d, v)
    v = v or ns.char
    if not v then return 0, #d.bosses end
    local total, found = #d.bosses, 0
    for _ in pairs(Set(v, "djlearn_" .. d.key)) do total = total + 1 end
    for _ in pairs(Set(v, "djboss_" .. d.key)) do found = found + 1 end
    if ns.DJBossCount then total = math.max(total, ns.DJBossCount(d) or 0) end
    return math.min(found, total), total
end

local function LevelBand(d, lvl)
    if lvl < d.min then return "under" elseif lvl > d.max then return "over" else return "in" end
end

-- A run's dungeon became known (first boss, or entering a dungeon with one name).
local function Placed(run, d)
    if run.placed then return end
    run.placed = true
    local lvl = UnitLevel("player") or 1
    local t = ns.char.t
    t.djlevel = t.djlevel or {}
    if not t.djlevel[d.name] then t.djlevel[d.name] = lvl end
    local band = LevelBand(d, lvl)
    run.band = band
    Add("dj_runs_" .. band)
    Tally("dungeonruns", d.name)
    Unique("dungeons_seen", d.key)
    if d.new and not d.raid then Unique("forever_dungeons_seen", d.key) end
end

function ns.DungeonRunStart(run)
    if not run or (run.type ~= "party" and run.type ~= "raid") then return end
    run.killedSet = {}
    local d = Resolve(run)
    if d then Placed(run, d) end
end

function ns.DungeonBossKill(name, kind)
    local run = ns.char and ns.char.run
    if not run or run.left or (kind ~= "party" and kind ~= "raid") then return end
    local d = Resolve(run, name)
    if not d then return end
    Placed(run, d)
    local idx = BossIndex(d, name)
    local label
    if idx then label = d.bosses[idx].name
    elseif d.learn and type(name) == "string" and not S(name) and name ~= "" and name ~= "?" then
        label = name
        Unique("djlearn_" .. d.key, name)
    end
    if not label then return end
    run.killedSet = run.killedSet or {}
    run.killedSet[label] = true
    if Unique("djboss_" .. d.key, label) then
        Add("dj_bosses_found")
        local found, total = ns.DungeonProgress(d)
        if found >= total and total > 0 and Unique("dj_books", d.key) then
            if ns.Journal then ns.Journal("Every boss of " .. d.name .. " found (" .. total .. ")") end
        end
    end
    -- full clear: every required boss down in this one run
    if not run.cleared then
        local need = 0
        for _, b in ipairs(d.bosses) do
            if not b.optional then
                need = need + 1
                if not run.killedSet[b.name] then return end
            end
        end
        for n in pairs(Set(ns.char, "djlearn_" .. d.key)) do if not run.killedSet[n] then return end end
        if need == 0 then return end
        run.cleared = true
        Add("dj_full_clears")
        Add("dj_clears_" .. (run.band or "in"))
        Unique("dungeons_cleared", d.key)
        if d.new and not d.raid then Unique("forever_dungeons_cleared", d.key) end
        Tally("dungeonclears", d.name)
        local secs = time() - (run.start or time())
        if secs > 0 then ns.Min("clear:" .. d.key, secs, "level " .. (UnitLevel("player") or "?")) end
        if ns.Journal then ns.Journal("Full clear: " .. d.name .. " in " .. (ns.FormatTime and ns.FormatTime(secs) or (secs .. " s"))) end
    end
end

-- ------------------------------------------------------------ DungeonJournal (Exehn), optional
-- Read only. Nothing from it is bundled. Its data layout is probed at runtime; when it is not
-- recognised, /lts debug says so and LifeTimeStats keeps using its own table.
ns.src.dj = "not installed"
local function ProbeDJ()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("DungeonJournal")
    if not loaded and IsAddOnLoaded then loaded = IsAddOnLoaded("DungeonJournal") end
    if not loaded then return end
    ns.src.dj = "installed, data not read yet"
    local found = {}
    for _, g in ipairs({ "DungeonJournal", "DungeonJournalDB", "DungeonJournalData", "DJ", "DJ_Data", "DungeonJournalAddon" }) do
        if type(_G[g]) == "table" then found[#found + 1] = g end
    end
    ns.src.djGlobals = #found > 0 and table.concat(found, ", ") or "none"
end
On("PLAYER_LOGIN", function() pcall(ProbeDJ) end)

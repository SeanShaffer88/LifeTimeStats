# Changelog

All notable changes to LifeTimeStats. Format: [Keep a Changelog](https://keepachangelog.com/), versions follow [SemVer](https://semver.org/).

## [1.12.1-forever] - 2026-11-08

From an in-game test of `/lts score` (score 752, every part shown).

### Fixed
- Gear part of the score stayed 0 on low-level characters: the best average item level now counts once 3 slots have an item level (was 8).
- `/lts score` lines no longer rely on space padding (the game font is not fixed-width).

 - 2026-11-08

Ideas from TimePlayed+, PlayedTracker, PvP Stats Tracker, Classic Score, Siouxx Classic Stats, Extended Character Stats and CharacterStatsClassic (public descriptions only).

### Added
- **Adventurer score**: one number for how far your character has come (levels, quests, exploration, dungeons, achievements, professions, gear, gold, minus 25 per death). Shown next to your level in the header and on Records; `/lts score` shows the breakdown. Achievement: Living Legend.
- **Session history**: one entry per play session (a /reload continues it) with length, AFK time, level, zone, steps, kills, deaths, quests, XP and damage. Top Lists → Session history; `/lts csv` exports it for a spreadsheet. Play sessions, average session, average per day played, daily average over the last 7 days, longest session.
- **Active time** (online minus AFK).
- **Peak character stats** on Records: best average item level, highest strength / agility / stamina / intellect / spirit, armor, attack power, spell power, healing power, crit, spell crit, dodge, parry, block and each resistance.
- **Reputation standings**: factions at Friendly, Honored, Revered and Exalted. Achievement: Best Friends Forever.
- **Battlegrounds**: wins and losses per battleground, win rate, win streak, and your scoreboard row at the end of each game (killing blows, honorable kills, deaths, honor, objectives); flags captured, returned and picked up, bases assaulted and defended. Achievements: Capture the Flag, On a Roll.

### Fixed
- Dashboard: legend values no longer run into their labels (e.g. "Vendors4s 65c"); long labels are cut instead.
- Deaths by cause has its own Fire / lava slice (fire deaths were under Other).

 - 2026-11-08

### Added: dungeon book
- All 35 Forever dungeons and 3 raids (Onyxia's Lair, Barrow Deeps, Hyjal Summit) with level range, zone and boss list, including the 9 new dungeons.
- Top Lists → Dungeon book: every instance in level order with bosses found / total, runs, full clears and fastest clear.
- Full clears: every required boss killed in one run (optional and rare bosses not needed). Fastest clear per dungeon.
- Scarlet Monastery, Dire Maul, Stratholme and Blackrock Spire wings are told apart by the first boss you kill.
- Runs and clears under, at and over the dungeon's level range.
- Krol'Dok Stronghold, Alcaz Island Prison, Blackmaw Hold and Shaper's Terrace have incomplete public boss lists: bosses you kill there are learned and added.
- Adventure page: dungeons entered, dungeons fully cleared, full clears, Forever's new dungeons cleared, bosses found, runs by level band.
- Achievements: Dungeon Crawler, Brave New World, Bestiary Complete, Punching Up (107 achievements).
- Progress is stored in the standard sections, so backups and the account view include it.
- DungeonJournal (Exehn): detected when installed and reported in `/lts debug`; its data is not read yet.

 - 2026-11-08

From an in-game test: fire death, `/lts debug` shows "from recap 1"; `/lts dm` shows the recap's amounts are readable.

### Added
- Death recap amounts (readable on Forever, unlike hit sizes elsewhere): biggest killing blow, most health before a killing blow, overkill on your deaths, damage in death recaps.
- Biggest hit taken and biggest crit taken now fill from death recaps instead of showing n/a.
- "Damage in your death recaps" list: damage per cause (Fire, or attacker · spell), replacing the tick count.

 - 2026-11-08

From an in-game test: died to fire out of combat, `/lts debug` and `/lts dm`.

### Fixed
- Deaths out of combat were blamed on the last enemy you fought: the damage meter's "current" fight is an old one then. The meter's killing blow is now used only during a fight (or within 3 seconds of one).
- Death causes now come from the game's own death recap (C_DeathRecap): the killing blow names fire, lava, falling, drowning, fatigue or slime, or the attacker and spell. The cause is settled 0.7 s after death so the recap is ready.
- "Who hurt you most" and killing blows read the attacker from the meter's per-spell details (unitName); pet damage uses its isPet flag.
- `/lts debug` says the meter was readable before even when no fight was read yet this session.
- Settings: the achievement alerts button overflowed its frame.

### Added
- "Fire, lava and falls before death" list and "Died to slime" counter.
- `/lts debug`, `/lts dm` and `/lts errors` open in a copyable text window instead of chat. `/lts dm` also lists the last five fights and your last death recap.

### Changed
- Settings rebuilt in the addon's own theme: header with Open window; Appearance (theme picker with colour swatches and a Reload button, class colour, scale slider, lock, minimap), Chat and display (session column, recap, level-up line, tooltip kill counts, milestones, achievement alerts as Off / Chat / Toast / Both), Screenshots, Tracking and title (title picker with arrows), Your data (stats, size, history, Backup / Restore / Character sheet / Reset session / Reset window / Erase). Whole rows are clickable; every option has a one-line description.

## [1.10.0-forever] - 2026-11-08

### Fixed
- Damage meter: every fight not yet counted is read after combat, oldest first (before, only the newest fight was read, so a fight that ended right before another one was lost). A meter that restarts its numbering after a relog is handled; fights from before a login or /reload are not counted twice.

### Added: damage meter
- Avoidable damage taken ("stood in the fire"), with the spells that did it.
- Damage dealt to each enemy (solo fights).
- Pet damage, total and per pet (spell rows that carry a creature name).
- Group fights: your share of the group's damage, best share, times you topped the meter, allies who died.
- Boss records: damage per boss, most damage and best DPS in one boss kill.
- Biggest hit and biggest crit from the meter's per-spell details, when Forever exposes them (Heavy Hitter unlocks then). `/lts dm` dumps the detail fields.
- Death causes from the meter's killing blow (attacker and spell): "What killed you" list; deaths in the open world vs battlegrounds.
- Damage by spell per level band; DPS by level (Timeline chart).
- Achievements: Signature Spell, Top of the Meter, Good Boy (pet damage), Is This Lava? (103 achievements, 368 tiers).
- `/lts debug`: meter total since login vs counted (missed-fight check) and the detail fields seen.

### Added: chronicle (ideas from AutoBiographer, Played Plus, TrackMe, Ultra Statistics, Hardcore Stat Companion)
- XP from kills, group bonus and exploring.
- Time grouped, and players you grouped with by time.
- Gear changes and unique items worn.
- Highest health and mana.
- Level-up line in chat (time at the last level, total online, favourite spell).
- Kill count, fights and damage taken on enemy tooltips.
- Optional screenshots on level-up, first boss kill and achievements.

### Added: interface
- Themes: Auto, Odometer, Blizzard, ElvUI, Tukui, EllesmereUI. Auto picks the UI addon you run and uses its live colours and font (EllesmereUI via its skinning API). Optional dependencies make sure those load first.
- Week and Month ranges next to Lifetime / Session / Today.
- Dashboard "Your legend" card: signature spell, nemesis, most hunted, best fight, homeland.
- Sidebar Today box: steps, kills, damage, healing, deaths, quests, online.
- Search also finds Top Lists entries.
- Account scope: hover a value to see each character's part.
- Login recap adds damage, healing and top spell.

## [1.9.3-forever] - 2026-11-08

### Changed
- Melee shows as "Melee" instead of "Attack" in the spell lists; existing "Attack" entries are merged on login.
- Enemies fought, damage/healing by spell and who/what hurt you moved up the Lists page, right after "Killed most often by".

## [1.9.2-forever] - 2026-11-08

From the 1.9.1 dump: Forever's damage meter gives readable amounts per fight and per spell.

### Added
- Damage by spell, healing by spell, who hurt you most, what hurt you most (Lists page).
- Overkill damage, deadly hits taken, fights read from the damage meter (Combat page).
- Records: best DPS in one fight, most damage by one spell in a fight, most healing and most damage taken in one fight.
- Interrupts and dispels now count from the damage meter.

### Changed
- Healing done, interrupts and dispels stop showing n/a once the meter has been read once (remembered across sessions). Field Medic and Rude Interruption achievements unlock on Forever.

## [1.9.1-forever] - 2026-11-08

From the `/lts dm` dump (Enum.DamageMeterType: DamageDone 0, HealingDone 2, DamageTaken 7; SessionType: Overall 0, Current 1; fight list readable).

### Changed
- Damage meter: after each fight the newest fight is read once by its session ID (both argument orders tried); damage done, healing done and damage taken fill in if Forever lets addons read them.
- New from the fight list (always readable): enemies fought most, fight time and longest fight from the game's own meter, most damage in one fight.
- `/lts dm` dump shows only the newest fight and then each damage-meter call, so nothing gets cut off. `/lts debug` shows fights read and which call worked.

## [1.9.0-forever] - 2026-11-08

### Added
- **Chat by channel** from chat events (say, yell, party, raid, guild, channels, instance), characters typed, questions asked, lols, thanks, greetings, things overheard.
- **Whispers**: received/sent, unique people both ways, top lists "Who whispers you most" / "Who you whisper most", Battle.net whispers, firsts.
- **Social**: friends added/removed, players ignored, invites sent/accepted/declined, groups left, guild invites, guilds joined, ready checks, raid markers.
- **Barber**: haircuts, visits, gold spent.
- **Mounts and pets owned** (most seen), mounts/pets learned, dismounts.
- **Flight paths known** (read from the flight map) and unique flight points.
- **Merchants and loot**: items bought/sold, buybacks, auctions posted, bids, mail taken/returned, loot rolls need/greed/pass/won, gear broken.
- Professions learned (unique), abilities and recipes learned, spirit healer, summons accepted, logins by hour.
- Achievements: Popular, New Look, Gryphon Master, LOL, Well Mannered. Now 99 achievements, 354 tiers, 7,110 points.
- `/lts dm`: dumps what Forever's damage meter returns, so it can be wired up next.

### Fixed
- Chat you send was counted from a hook that misses typed chat; now counted from chat events.
- Reputation from Forever's "Reputation with X increased by N." lines.
- Damage meter: also tries the per-source call with your GUID.

## [1.8.0-forever] - 2026-11-08

### Added
- **Adventurer's Life** page (key J): drunk levels, sobered up, campfires (and where), nights camped vs at an inn, time in the wild + longest stretch, inns and innkeepers, unique hearthstones, different hearth locations and hearth moves, flight paths discovered, books read, potions/elixirs, Well Fed, time eating/drinking, mounts and pets by name, times and time naked, breath held, fatigue, day/night game time, dawn/dusk logins, days adventured, fights ended without a kill, deaths to enemies 5+ levels below you.
- **Journal** page (key L): auto-written story (firsts, level-ups, zones, inns, deaths, achievements), Life per level, Travel log.
- **Titles** (20) unlocked by achievements; `/lts title` or settings; shown by your name and on the sheet.
- **Character sheet**: footer button and `/lts sheet`.
- **Damage meter**: reads Forever's built-in meter (`C_DamageMeter`) after each fight if its numbers are readable; damage and healing done then fill in.
- Top lists: inns, mounts, pets, herbs/mining/fish by zone, time per game hour, embarrassing killers, where you camped / lit fires / got drunk, books, potions, hearthstones owned/used, hearth locations.
- Achievements: Barfly, Completely Smashed, Firestarter, Sleeping Rough, Wanderer, Bookworm, Pathfinder, Potion Junkie, Homesick, Home Is Where the Hearth Is, Night Owl, Innhopper, Stable Master, Wardrobe Malfunction, Humbled, Gourmand. Now 94 achievements, 339 tiers, 6,910 points.
- Achievements page: sort by closest to next tier.

### Fixed
- Deaths were blamed on **fatigue** whenever no other cause was known: the breath/fatigue check read 0 when no bar was showing. Bars are now tracked by their start/stop events.
- Gold sources ring showed "0g" for amounts under a gold; now shows gold/silver/copper.
- Sidebar rows a little shorter so all 16 pages and the Today box fit.

## [1.7.0-forever] - 2026-11-08

### Added
- **Kills by level colour** (grey, green, yellow, orange, red), **elites** and **rares** killed; top lists "Kills by level colour" and "Rares killed"; unique rares; firsts for elite and rare.
- **Critters loved, then killed** and **critters loved and spared**.
- **Appearances collected** (from "added to your appearance collection"), with uniques and a first.
- **Herbs by type**, **ore by type**, **items created** top lists; **conjured items** counter.
- Achievements: Love It, Then End It · Rare Hunter · Elite Squad · Giant Slayer · Bully · Fashionista · Conjurer. Now 78 achievements, 284 tiers, 5,920 points.
- **Last-session recap** at login (setting, default on) and `/lts recap`.
- Backups for missed events: quest accepted/completed system lines; loot-money lines when gold is hidden. Never double-counted.
- `/lts debug`: quests, gold, deaths, appearances, and any damage-meter APIs the client exposes.

### Changed
- Empty charts say "Nothing recorded yet"; empty rings say "nothing yet".
- Odometer leading zeros dimmer.
- Social page counter: Critters loved (red errors moved underneath).

## [1.6.1-forever] - 2026-11-08

From the 1.6.0 in-game test (/love on a Hare, then killed it: both stayed 0; Emotes performed 0).

### Fixed
- **Emotes were never counted**: typed emotes on this client do not go through the hooked function. Both emote paths (`DoEmote` and `C_ChatInfo.PerformEmote`) are hooked now, and your own emote chat line ("You love Hare.") is a backup. Each emote is counted once.
- **Critters not recognised** when the creature type is hidden: a creature you attack is treated as a critter if its type says Critter, its classification is "minus", or, when the type is hidden, it is level 1 and you are level 3 or higher.
- `/lts debug` adds critter lines (engaged, killed, type readable/hidden) and emote lines (from hooks / from chat lines).

## [1.6.0-forever] - 2026-11-08

### Added
- **Critters killed**: critters (creature type Critter) that die after you hit them, cast at them or auto-attack them, even when that never puts you in combat. Counted on their own, never as enemies killed.
- **Critters loved**: `/love` while targeting a critter. All `/love` emotes are also counted ("Loves given").
- Top lists "Critters killed" and "Critters loved"; uniques "Kinds of critters killed" and "Kinds of critters loved"; firsts "First critter killed" and "First critter loved".
- Achievements **Critter Whisperer** (/love critters: 1/10/50/250) and **You Monster** (critters killed: 1/25/100/500). Now 71 achievements, 261 tiers, 5,540 points.
- `/lts debug` shows critter kills.

## [1.5.4-forever] - 2026-11-08

From the WoW Forever addon API cheat sheet (wowforeverguides.com) checked against LifeTimeStats.

### Changed
- Kills from watched units: nameplates are now swept directly (nameplate1-40) on every check, because `NAME_PLATE_UNIT_ADDED` can fire before the unit is filled in. Units seen on nameplates while you are in combat are marked as engaged.
- Every yes/no game check used by the trackers (in combat, dead, mounted, swimming, falling, on a flight path, can attack, tapped by others, is a player, exists, …) is secret-safe: a hidden answer counts as "no" instead of raising an error.
- `/lts debug` also counts hidden yes/no checks.

## [1.5.3-forever] - 2026-11-08

### Fixed
- `ADDON_ACTION_FORBIDDEN: AddOn 'LifeTimeStats' tried to call the protected function 'UNKNOWN()'` at login: Forever forbids addons from even registering the combat log event. LifeTimeStats no longer registers it on clients that use these rules (secure combat-log reader present, secret values in use, or no readable reader). Nothing is lost: Forever never delivered it.
- `/lts debug` says when the combat log was deliberately not registered.

## [1.5.2-forever] - 2026-11-08

### Fixed
- **Lua error spam** (`Trackers.lua:763: attempt to compare local 'speed' (a secret number value)`, 547×): Forever sometimes hides your movement speed. Speed is now checked before use; when hidden, distance comes from the change in your world position (teleports and hearths ignored); if that is hidden too the moment is skipped. Distance per continent uses the same source.
- Every per-frame script (distance ticker, watcher, falls, unit watch, achievements) now catches its own errors, so a hidden value can never spam errors or stop tracking; anything caught shows in `/lts errors` (with a repeat count).
- `/lts debug` reports movement: speed readable, position ticks used, ticks skipped.

### Known (Forever)
- Your own health is hidden from addons too, so damage taken, healing received and falls show n/a.

## [1.5.1-forever] - 2026-11-08

From the 1.5.0 in-game test (`/lts debug`: 6 kills from XP lines, 53 combat-text events, 152 hidden values, 0 errors).

### Fixed
- Forever hides the size of each hit in the combat text feed: damage done, DPS, biggest hit and biggest crit now show **n/a** with an explanation instead of 0. Hit, crit and miss counts keep working.
- Damage taken, biggest hit taken and healing received are now worked out from your own health when hit sizes are hidden (healing only while in combat, so regeneration is ignored).
- Combat page: first counter is now Hits landed (damage and DPS shown underneath when available).
- Achievements that cannot be measured on Forever (Heavy Hitter, Field Medic, Rude Interruption) are marked "Not measurable on Forever" and left out of the totals until the data appears.
- Sidebar: the new-achievements count ran into the "Achievements" label; it is now a small badge on the icon.
- `/lts debug` also reports whether hit sizes and your health are readable.

## [1.5.0-forever] - 2026-11-08

Forever follows Midnight's addon rules: the combat log (`COMBAT_LOG_EVENT_UNFILTERED` / `CombatLogGetCurrentEventInfo`) is secure-only, so addons never receive it. In-game screenshots showed every combat-log statistic stuck at 0. This release rebuilds them from sources Forever still allows.

### Added
- **Kills** from "X dies, you gain N experience" and honorable-kill lines, plus a watch on hostile units you fight (target, mouseover, nameplates, boss frames) that counts them when they die untapped by others. Both are matched so one kill counts once. Grey mobs count via the unit watch.
- **Attacks on you** from the combat text feed (`UNIT_COMBAT` on yourself): damage taken, hits, crits, crushing blows, partial blocks, dodges, parries, blocks, misses, resists, absorbs, immunes, healing received.
- **Your attacks** from `UNIT_COMBAT` on your target while you fight alone: damage, hits, melee vs spell hits, crits, crit streaks, glancing blows, attacks missed/dodged/parried/blocked/resisted, biggest hit and crit (with the spell you last cast).
- **Falls** measured from the health you lose on landing; survived and fatal falls.
- **Death cause** worked out at the moment of death: recent fall, breath or fatigue timer, or your hostile target (killer list and creature/player split).
- `/lts debug`: which data sources are working this session.
- Statistics that only the combat log can give (healing you do, overhealing, interrupts, dispels, buffs, debuffs, killing blows, DoT ticks, ranged hits, environment damage types) show **n/a** with an explanation instead of a misleading 0. They fill in automatically if the combat log ever reaches addons.
- How it works: new "Forever and the combat log" section; kills, damage and deaths sections rewritten.

### Fixed
- Loot quality was never read: Forever item links use `|cnIQ#:` quality tags. Also falls back to the item's quality from the client.
- `LOGINEFFECT` and other all-caps internal effects no longer count as spells cast.
- Levels gained stayed 0: level-ups are now also detected from your level changing (and `PLAYER_LEVEL_CHANGED`), never counted twice.
- Compare page said "Different different …"; uniques now have their own section with plain labels.
- Firsts are capitalised; Uniques "NEW" column header fits.
- Achievement tiles: names and descriptions left-aligned and kept clear of the tier pips.
- Secret values (hidden names/GUIDs inside instances) can never reach saved data or cause a Lua error.

### Limits (Forever)
- Inside instances names are hidden from addons; kills there are listed as "Unknown (instance)".
- In a group, damage you deal is not counted (the combat text feed cannot tell whose hit it was); attacks on you still are.

## [1.4.1-forever] - 2026-11-08

First fixes from in-game screenshots (Forever 1.60.1, Mage, 1920×1080).

### Fixed
- Header: the class/level/realm line ran under the Settings button; it now shows class and level only.
- Charts with a legend (By level band, Distance per day): axis labels overlapped the legend; every column chart now draws inside its own area.
- Ring legends with 7 rows (Attacks on you, Your attacks) spilled past the card bottom; row spacing now fits the card.
- Sidebar: "Fastest & Uniques" ran into its shortcut badge; shown as "Fastest/Uniques" and long labels shrink to fit.
- Odometer cards showed an empty session line at zero ("this session", "· 0 players"); they now show +0.
- Travel ring said "0 miles" and Zones by distance "0k" for short distances; under a mile shows yards.

### Added
- Today summary (steps, kills, deaths, quests) in the empty space under the sidebar.

## [1.4.0-forever] - 2026-11-08

### Added
- **Compare** page (key C, `/lts compare`): your characters (class-coloured, level, /played); click for the right side, Ctrl+click for the left, or All characters; side-by-side table of every statistic, unique count, fastest time and achievement points with lead bars and + markers; counters for stats each side leads and achievement points; Swap sides.
- **Forget character** for deleted alts (asks first; never the current character).
- **Share**: footer button and `/lts share [channel] [topic]`. Editable preview, channel picker (Say, Party, Raid, Guild, Instance — only those you can use), Send. 11 topics; plain text under 255 characters. Posting only on an explicit Send or a typed channel.
- "Times you shared your stats" counter.
- How it works: Compare and Sharing sections.

## [1.3.0-forever] - 2026-11-07

### Added
- **Achievements**: 69 of LifeTimeStats' own, up to 6 tiers each (253 badges, 5,360 points) across Travel, Combat, Deaths, Adventure, Wealth, Silly and Fastest.
- Achievements page (key A): earned / points / completion / fully completed counters, category filter, badge tiles with tier pips and progress bars, tier dates on hover, Recently earned, Closest to the next tier.
- "N new" count on the sidebar; cleared when you open the page.
- Settings → Achievement alerts: Off (default), Chat, Toast, Both. The toast opens the page when clicked.
- Achievements are included in backups, restore and the All characters view.

### Changed
- Progress you already had is awarded silently on first load and marked "before v1.3".
- How it works page has an Achievements section.

## [1.2.0-forever] - 2026-11-07

### Added
- **How it works** page (key H): plain-language explanation of every measurement.
- Settings: **Reset window** (centre + fit-to-screen size) and a data line (statistics tracked, characters, data size, days of history).
- Minimap tooltip shows today's steps, kills and online time.

### Changed
- The session now survives /reload; it resets on a real login.
- "All characters" view is rebuilt at most every 5 s (and immediately when you switch scope) instead of every 2 s.
- Repeated identical Lua errors are collapsed into one line with a count in `/lts errors`.

### Fixed / hardened
- Events that fire before the saved data is ready are ignored instead of touching missing tables.
- Invalid numbers (NaN, infinity, negative fastest times) can no longer enter the saved data.
- Unique lists are capped at 20,000 entries each to keep SavedVariables small.
- Verified upgrade of 1.0 records and restore of 1.0 (LTS1) backups.

## [1.1.0-forever] - 2026-11-07

### Added
- New dashboard window: sidebar with 11 pages, search (Ctrl+F), This character / All characters, Lifetime / Session / Today, portrait header, odometer counters on every page, gridded stat tables and charts (tick rings, bar lists, mirrored bars, daily columns, dot matrix).
- Class-colour accents (default on; toggle in settings, needs /reload).
- Dashboard: kills vs deaths by zone, gold per day, deaths by cause, level bands, gold sources, jumps by hour, steps per day, rates, fastest.
- Fastest & Uniques page: fastest level-up, fight won, 10 kills, quest, corpse run, flight, first death of a session, battleground win, and fastest clear per dungeon and raid; 20 unique counts (NPCs met, vendors, trainers, flight masters, creature types, bosses, zones, subzones, quests, items, spells, groupmates...); 17 firsts.
- Timeline page: today's counters, 30-day chart with 6 metrics, day-by-day table (40 days kept).
- Dungeon bosses, raid bosses and world bosses counted separately, with unique counts.
- Every avoidance type counted both ways (miss, dodge, parry, block, resist, absorb, immune, evade, reflect), crits and crushing blows taken, glancing blows, crit heals, crits in a row, dodge rate.
- Falls: biggest survived (damage and % health), biggest fatal, longest airtime survived and fatal, time in the air, big falls.
- Corpse runs: count, longest by time and distance, fastest; resurrections accepted, raised in place, cast; longest wait to be raised; longest life between deaths.
- Most visited capital city, continent and zone; time per capital, continent and instance; continent distance; indoors/outdoors time.
- Many more counters: fights and fights won, casts failed/interrupted, dispels, buffs given/received, debuffs, rep gained/lost, skill-ups, spells learned, talent points, /roll stats, red error messages, bags full, gear changes, bag/character/spellbook/talent/quest log/friends opens, sits, auto-run, inspects, assists, targets, NPC conversations, vendor/bank/auction/mailbox visits, whispers while AFK, deaths while mounted/swimming/AFK, battlegrounds lost.
- 23 top lists (was 10), top 100 per list.
- 325 statistics in total.

### Changed
- Backup format LTS2 (includes fastest times, uniques, firsts and daily history). LTS1 backups still restore.
- Restore keeps the faster time and the earliest first, and unions unique sets.

### Fixed
- Daily chart series handed a number instead of an empty day to chart callbacks (caught by tests before release).

## [1.0.0-forever] - 2026-10-31

### Added
- First release for WoW: Forever (interface 16001).
- Lifetime and per-session tracking of 130+ statistics and 10 top lists across Overview, Travel, Combat, Deaths, Adventure, Wealth & Loot, Social & Silly, Records and Top Lists.
- Odometer-style window: amber digit counters for steps, jumps, kills and deaths; lifetime and session columns; row tooltips explaining each measurement.
- "This character" / "All characters" scope.
- Minimap button (hideable), settings page under Options > AddOns, slash commands `/lts` and `/lifetimestats`.
- Dual storage (account + per-character SavedVariables) with automatic restore from the newer copy.
- Text backup and restore (numbers only, checksummed, values never lowered).
- Optional milestone announcements in chat (off by default).
- `/lts errors` log because Forever hides Lua errors.

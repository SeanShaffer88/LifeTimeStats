# LifeTimeStats

**Every step, jump and kill, counted for life.**

LifeTimeStats keeps a lifetime tally of your character in World of Warcraft: Forever: 943 statistics, top lists, fastest times, uniques and firsts, shown in a dashboard that takes on your class colour, or matches your UI addon: themes for ElvUI, Tukui, EllesmereUI and the default Blizzard look.

Version 1.13.0 adds 222 observation-based statistics: movement and combat contexts; measured ghost travel, confirmed corpse retrievals and other revivals; ten interface visit timers; combat survival and activity rates; and recorded XP, gold, healing and damage breakdowns. It also adds a bounded, backed-up personal-best timeline, optional local Journal milestones and new-record session recaps. Missing or hidden client data is skipped, and new counters are not reconstructed from pre-upgrade history.

Version 1.14.0 adds Journal filters by entry type and zone, private notes on Journal entries, and up to four pinned Dashboard counters.

Version 1.15.0 adds the Adventure Guide (key G), a Dungeon Journal-style compendium of all your characters: boss pages, a dungeon progress book, run history, a death codex, a bestiary, a zone atlas, Chronicle chapters, group memories, boss loot and suggestions for what to do next, plus 49 new statistics and top lists.

Version 1.16.0 adds `/lts export` (every statistic for every character as CSV), a 12-month Timeline view, an addon compartment entry, full DBM-checked boss rosters for the nine Forever dungeons, and reputation standings, form names and toy names on the Forever client.

Version 1.17.0 adds the Characters page (key R): every character with gold, /played, professions, saved instances, rested XP, bags and more; a local log of the players you grouped with; and farming sessions ranked by gold per hour, with the vendor value of your loot.

Version 1.19.0 adds reputation history, currencies, an item log with sources, gathering by zone, mail and trade partners, goals for any statistic, week and month trends, and a session summary window.

Version 1.20.0 adds quest, level and profession history, a death map with skulls on the world map, play habits by weekday and hour, item tooltips that say where you got an item, daily snapshots for safety, a saved-data size check and CSV exports of each log.

Version 1.21.0 adds the Adventurer's Notebook skin, the new default: parchment pages, a spiral binding, a wooden frame and chapter tabs (Hero, Deeds, Quests, Legends, Chronicle, Lore), made for roleplayers and RPG fans.

## The useless ones
Steps taken. Times jumped. Time spent in the air. Dances, hugs and chickens. Perfect /rolls. How often you sat down, opened your bags or toggled auto-run. Red error messages seen ("Not enough mana", we know). How many times you checked these stats.

## The useful ones
Gold per hour and per day, repair bills, vendor and auction totals. XP per hour. Lifetime DPS, crit rate, dodge rate. Kill/death ratio and what kills you most. Dungeon bosses and raid bosses killed, runs, full clears, battlegrounds won.

## What Forever's damage meter tells it
Forever hides the combat log from addons, so LifeTimeStats reads the game's own damage meter after every fight: damage and healing by spell, who hurt you most, the hit that killed you, time spent standing in the fire, your pet's damage, your share of the group's damage and how often you topped the meter.

## Records and fastest times
Biggest hit, crit and heal (with the spell). Biggest fall you survived, and the one that killed you. Longest corpse run, by time and by distance. Longest life between deaths. Fastest level-up, fastest quest, fastest 10 kills, fastest clear of every dungeon and raid you run.

## Uniques and firsts
Different NPCs met, creatures killed, bosses, zones, subzones, quests, items, spells and players grouped with. Your first kill, death, epic, dungeon, boss, duel win and more, with dates.

## Where you spend your life
Most visited capital city, continent and zone. Time and distance per zone and continent. Kills and deaths per zone.

## Achievements
111 achievements of its own with up to 6 tiers each: Walk It Off, Bunny Hopper, Gravity Always Wins, Marathon Ghost, Untouchable, Dragon's Hoard, Bawk Bawk, Not Enough Mana, Express Delivery and more. 396 badges and 7,890 points to chase. Alerts are optional.

## Compare and share
Put two characters side by side (or one against all of them) across every stat, and share a one-line summary to Say, Party, Raid, Guild or Instance chat when you choose to.

## An adventurer's life
Times you got drunk (and completely smashed), campfires lit, nights camped under the stars vs at the inn, hearthstones collected and every inn you have called home, books read, potions drunk, mounts ridden, time spent naked. A journal that writes your story as you play, life per level, a travel log, and titles to show off.

## The window
The Forever Journal theme uses Warcraft-style trim, ledger counters and dated journal entries. Browse sixteen pages, search your stats and switch between characters or time ranges.

## Safe with your data
LifeTimeStats stores data locally in account and character SavedVariables. Stats-only backup is the default and keeps the existing LTS1/LTS2 merge behavior. The optional full character backup includes saved history and private Journal notes. It previews a same-character replacement before you confirm. Account settings, other characters, Dashboard pins, and in-progress sessions and tracking stay outside the full backup. Share posts to your selected WoW chat channel when you send it.

## Commands
| Command | |
|---|---|
| `/lts` | Open or close the window |
| `/lts summary` | Headline stats in chat |
| `/lts settings` | Settings |
| `/lts minimap` | Show/hide minimap button |
| `/lts export` / `/lts import` | Backup / restore |
| `/lts errors` | Recent Lua errors |

## Installing manually
Unzip `LifeTimeStats-1.21.0-forever.zip` so the folder is `World of Warcraft\_forever_\Interface\AddOns\LifeTimeStats`.

Open source under GPL-3.0-or-later. Made by Malikor.

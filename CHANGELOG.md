# Changelog

All notable changes to LifeTimeStats. Format: [Keep a Changelog](https://keepachangelog.com/), versions follow [SemVer](https://semver.org/).

## [Unreleased]

From in-game screenshots of 1.24.0.

### Added
- **Fill screen window size** (Settings > Appearance > Window size, or `/lts size fill`; applies after a reload):
  - The window grows to fill your screen and still leaves room for the section tabs.
  - Stat tables, Top Lists, the Characters tables and the charts get taller and wider. At 1920×1080, a stat page shows 34 rows at once instead of 22, and the window is 1694×996.
  - Achievements show three columns of badges.
  - Window scale still makes the text bigger or smaller, and the window resizes to fit.
  - `/lts size normal` returns to the 1140×740 window.

### Changed
- **Easier to read on paper (Adventurer's Notebook):**
  - **Bigger type:** nothing is smaller than 11.5 points, and the common 11-point text is now 12.
  - **Ink, not paint:** any colour too light for parchment is darkened to ink strength, keeping its hue. This covers the bright gold section headings on the Characters, Dungeon Tome and Collections pages, grey details and realm names, class colours ("Hex", "Abraca") and white or green item names.
  - **Darker palette:** body text, faint text and the red-brown accent are all a step darker.
  - **No more "...":** single-line labels and table cells that are too long shrink slightly to fit instead of being cut off ("Vend..." in Gold sources).
  - **Bold headings:** table column headers and heading rows are set in faux bold.
  - **Lighter page fold:** the crease down the middle of the page no longer darkens the numbers it crosses.
  - **Tooltips:** they now use light parchment colours. They were drawn in dark ink on the game's dark tooltip background.
- **Options panel:** rows are taller and every description gets two full lines instead of being cut off. Hovering a row shows its full text.

### Fixed
- **Today box:** values sat under the margin rule and were cut off. They now sit inside the box in a larger type.
- **Play habits:** the # column showed "..." for most hours; hour rows now leave it empty, since the hour is in the entry.
- **Narrow # columns:** numbers were truncated in every table with a # column; these columns now use less padding.

## [1.24.0-forever] - 2026-11-16

Prerelease. Offline regression suites pass; not yet checked in the live client. Layout fixes come from in-game screenshots of 1.23.1.

### Added
- **Crowd control suffered** (Combat page): times stunned, feared, rooted, silenced, locked out, pacified, charmed, incapacitated and disarmed, with time spent in each, total time controlled, the longest effect (a record) and two top lists: by spell and time by spell.
- **Cinematics** (Adventurer's Life): cinematics and movies watched, watched to the end, skipped, time watching and the longest scene.
- **Talents** (Adventurer's Life): respecs, gold spent on respecs, the most expensive respec, talent loadouts loaded and specialization changes.
- **Your bags** (Adventurer's Life and Records): items used from your bags (with a top list by item), quest items used, different items ever carried, and records for the most bag space and most slots filled.
- **Interface habits** (Social & Silly): map pins placed and removed, /who searches, players unignored, bags sorted, sell-all-junk clicks, minimap tracking changes, macros created, walk/run toggles, camera and minimap zoom steps, and how often you open the game menu, calendar, collections, achievements, guild, chat channels and customer support windows.
- **Achievements:** Restless Wheel, A Place for Everything, Are We There Yet?, Pack Rat, Bottoms Up, Seeing Stars, Puppet on a String, Front Row Seat, No Spoilers and Change of Heart.
- 63 new catalog entries; with 14 duplicate rows removed the catalog has 992 entries and a "How it works" section on where these come from.

### Changed
- **Easier to find your way around:**
  - Every stat page is split into named sections, each with a heading in its table. For example, Battles has Damage dealt, Damage taken, Healing, Kills, Fights, Spells & auras, Crowd control, PvP & duels, and Health & movement.
  - **Section tabs down the right side of the window** jump straight to a section, and the tab for the section you are reading stays highlighted as you scroll.
  - Records, How it works (one tab per topic), Top Lists (grouped into Combat, Bosses & dungeons, Places, Wealth & items, People & chat, Life & habits and Time) and Achievements (its categories) have the same tabs.
  - Search results show the page and section (Battles › Crowd control). Clicking one opens the page scrolled to that statistic and highlights it.
- **No more duplicate rows:** food, drink and bandages appeared on two pages, as did gear changes, gathering, hearthstone uses, critters loved and sitting down. "Items taken from mail" was listed twice on one page. Each now has one home. The bag-space record added earlier in this release now feeds the existing "Most bag slots" record instead of being a second one.

### Fixed
- **Options panel** (Options > AddOns > LifeTimeStats) in the Adventurer's Notebook: it now sits on its own parchment sheet, so the dark ink is readable on the dark Options window.
- **Achievement alerts** buttons were covered by the Tracking and title card; the card moved down.
- **Theme** value shrinks to fit between its arrows ("Auto (Adventurer's Notebook)" overflowed).
- **Today** box in the notebook margin: values were clipped by the margin rule.
- **Gold sources** legend cut "Quests" and "Vendor" to "Qu..." and "Ve..."; the ring is a little smaller and values a point smaller.

## [1.23.1-forever] - 2026-11-16

Prerelease. Offline regression suites pass; not yet checked in the live client.

From in-game screenshots of 1.23.0, where the parchment sheet rendered as designed.

### Changed
- **More readable text in the Adventurer's Notebook:**
  - **Darker ink:** body, label and accent colours are darker so they read on aged paper.
  - **Bigger small print:** the smallest text sizes grow by a point.
  - **Small caps:** card titles and margin tags are set in capitals, emulating small caps (WoW fonts have no small-caps face).
  - **Bold:** headline numbers, table numbers, card titles, the chapter title, and the active tab and tag use a faux bold (a 1-pixel ink shadow, since WoW fonts have no bold face).
  - **Table headers:** set in full ink instead of grey.

### Fixed
- The scorched rim and darker corners reached into the page, which made the right column (Your legend, chart labels) and the Today numbers in the bottom-left hard to read. The rim is narrower, the vignette lighter, and the sheet's torn edges now sit further outside the window, so all content is on light paper.
- Long page names in the margin tags ("Life on the Road") shrink to fit.

## [1.23.0-forever] - 2026-11-16

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Changed
- **Hand-made parchment:** the Adventurer's Notebook window is now one sheet, drawn by `scripts/make_parchment_sheet.py`.
  - **The sheet:** torn, deckled edges with a few deep tears, a scorched brown rim, aged mottling, water stains, specks and faint creases, and an inked double frame with corner flourishes.
  - **Fit and shadow:** the sheet is drawn slightly larger than the window, so the torn edges sit just outside it, with a soft drop shadow.
  - **What it replaces:** the wood frame and spiral binding. The header and footer bands are see-through, so the sheet shows behind them.
  - **What stays:** the bookmark tabs, page index, sketches and the fold down the middle.

## [1.22.1-forever] - 2026-11-16

From in-game screenshots of 1.22.0, where the skin rendered as designed.

### Changed
- **Aged parchment** in the Adventurer's Notebook:
  - **Paper:** darker tan, mottled with blotches, faint water stains, specks and paper fibres.
  - **Edges:** a new edge-wear overlay browns and frays the edges and corners of the page.
  - **Cards and tables:** a darker, more transparent wash, so the old paper shows through.
- **Coin letters:** the gold, silver and copper letters (g, s, c) are inked darker on paper. The light silver "s" was nearly invisible.

### Fixed
- The margin's Today box ran labels into values ("Online23m 33s"). It is a little wider, with smaller values.

## [1.22.0-forever] - 2026-11-16

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Added
- **Ink sketches** in the Adventurer's Notebook: 19 original line drawings, one per page, inked in the margin between the page index and Today.

  | Page | Sketch |
  |---|---|
  | Overview | compass |
  | Characters | hero |
  | Compare | scales |
  | Travels | boot |
  | Battles | crossed swords |
  | Deaths | skull |
  | Purse & Pack | backpack |
  | Company | tavern mugs |
  | Adventures | map |
  | Dungeon Tome | tower |
  | Life on the Road | campfire |
  | Records | crown |
  | Feats & Firsts | hourglass |
  | Honours | medal |
  | Rolls of Note | scroll |
  | Journal | quill and ink |
  | Days | sun and moon |
  | How it works | open book |
  | Search | magnifier |

  They are drawn by `scripts/make_notebook_sketches.py`.
- **Wax seals:** an earned achievement on the Honours page is stamped with a red wax seal showing its tier numeral. It is fully opaque once every tier is earned. A pinned Dashboard statistic is sealed once its goal is reached.

## [1.21.0-forever] - 2026-11-16

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Added
- **Adventurer's Notebook** skin, now the Auto default when no UI addon is loaded. It follows the approved mockups in `docs/mockups/`:
  - **Look:** parchment pages in a wooden frame, a spiral binding down the left edge of the paper, and a soft fold between the two halves of the page.
  - **Chapter tabs down the side:** Hero, Deeds, Quests, Legends, Chronicle and Lore. Each opens the page you last read in it.
  - **Page margin:** the chapter number and name, the chapter's pages as tag buttons, and Today below them.
  - **Tome page names:** Overview, Travels, Battles, Purse & Pack, Company, Adventures, Dungeon Tome, Life on the Road, Feats & Firsts, Honours, Rolls of Note, Days.
  - **Ink and paper:** ink colours, mixed-case card titles, faint ledger lines in tables, and class colours darkened to read like ink.
- **Original textures** generated by `scripts/make_notebook_textures.py`: paper, wood, spiral ring, tab, tag, fold and wax seal.

### Changed
- **Spiral position:** the binding sits at the left edge of the paper rather than down the middle, as in the mockup. Rings down the middle would cut through the full-width tables on the Search, How it works, Timeline and Journal pages.
- **Keyboard shortcuts:** they still open pages, and the tabs follow.
- **Other skins:** they are unchanged; pick one in Settings and /reload.

## [1.20.0-forever] - 2026-11-15

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Added
- **Quest history** (Characters > Quest history): every quest turned in, with date, zone, level, XP, gold and the time from accepting it. It keeps up to 1,000.
- **Level history** (Characters > Level history): the per-level snapshot now also keeps gold, item level, /played, base stats and zone.
- **Profession history** (Characters > Professions): the date of every skill-up, the time each 75-point stretch took, and Journal lines at 75, 150, 225 and 300.
- **Death map** (Characters > Death map): each death's map position, cause, zone and level, plus skulls on the world map with tooltips (`/lts deathpins` toggles them). It keeps up to 500.
- **Play habits** (Characters > Play habits): time online by weekday and hour.
- **Item tooltips**: where and when you got an item from the item log.
- **Saved data size**: `/lts size`, the settings panel, and a warning at login above 4 MB per character.
- **Daily snapshots**: the newest three per character, kept in that character's own saved file. `/lts snapshot` lists them, with show and restore (merge).
- **CSV exports**: `/lts export items`, `quests`, `runs` and `deaths`.
- **Dashboard**: a pinned statistic with a goal shows its progress.
- **Locale table** (`ns.L`): new section names go through it, ready for translations.
- 6 catalog entries (943 in total). Full backups (LTS3) include quests, profession history, the death log and the new level-snapshot fields.

### Fixed
- `/lts summary` had two meanings; it now opens the session summary window.

### Not in this release
- Merging the eight per-frame timers into one, caching the all-characters view, and splitting UI.lua into one file per page were left out. They change nothing you can see, so they wait until there's an in-game check to compare against.

## [1.19.0-forever] - 2026-11-15

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Added
- **Reputation history** (Characters > Reputation): every faction's standing and progress, and the date each standing was first reached. A Journal line is written at Friendly and above.
- **Currencies** (Characters > Currencies): every currency per character with the account total. The highest amount ever held is kept as a record.
- **Item log** (Characters > Item log): every green-or-better item with its time, zone, level, item level and source (boss by name, quest reward, vendor, crafted, mail, trade, auction, gathered, fishing, looted). It holds up to 1,000 per character. Epic items after your first get a Journal line naming their source.
- **Gathering** (Characters > Gathering): herbs, ore, skins and fish by zone, items gathered by zone, and the best gathering sessions per hour.
- **Mail & trades** (Characters > Mail & trades): who you mailed and traded with, gold each way, and items given and received.
- **Goals**: a target for any statistic, set with `/lts goal <words> <target>` and listed with `/lts goal list`. They show as progress bars under Characters > Goals, are checked every 15 seconds, and write a Journal and chat line when reached.
- **Trends** (Characters > Trends): the last 7 days against the 7 before, and this month against last month, for 15 measures.
- **Session summary**: a window at login after a session of 10+ minutes. `/lts summary` shows the current session at any time. The existing session-recap setting turns both off.
- 34 catalog entries, bringing the total to 937:
  - item counts by quality and the highest item level found;
  - items gathered and best gathering per hour;
  - gold mailed and traded, items traded, and mail and trade partners;
  - factions met, standings reached (Honored, Revered, Exalted) and lost;
  - goals reached;
  - lists of items by source, epic sources by boss, items gathered by zone, mail and trade partners, and gold per partner.
- Full backups (LTS3) include reputation history, the item log and goals. Older full backups still restore.

### Changed
- The Characters page has a grid of section buttons under the character cards: All characters, People, Farming, Reputation, Currencies, Item log, Gathering, Mail & trades, Goals and Trends.

## [1.18.2-forever] - 2026-11-15

From in-game screenshots of 1.18.1.

### Fixed
- Minimap button on square minimaps: it was placed on a circle, so on a square minimap it sat over the map near the bottom-left corner and was easy to miss. It now follows the shape your minimap addon reports (`GetMinimapShape`, as used by Leatrix Plus, ElvUI, SexyMap and others) and sits on the edge. The icon is a little larger and round.
- The Journal got a "New personal record: Longest observed interval: stationary" entry every 10 seconds while you stood still. The same happened for any interval that kept growing. A running interval now records quietly and writes one entry when it ends. Duplicates already saved are cleaned up once at login (same record, back to back, within 2 minutes; entries with notes are kept). The personal-best history is cleaned the same way.

### Added
- With LibDataBroker and LibDBIcon loaded (bundled by Leatrix Plus, ElvUI, Titan Panel and many minimap-button bags), LifeTimeStats registers as a launcher, so those addons can place, hide or collect its button. Nothing is bundled here.
- `/lts minimap reset` shows the button again at the bottom-left. `/lts minimap square` and `/lts minimap round` set the shape when no minimap addon reports one.

## [1.18.1-forever] - 2026-11-15

From an in-game screenshot of 1.18.0. The 3D model and the class crests (`GetClassAtlas`) work on Forever.

### Fixed
- Characters page: the realm, last-seen line, fact values and the zone line on each card were centered instead of left-aligned.
- Characters page: the details table had an empty header row. Its columns are now labelled Entry, Value and Detail.

## [1.18.0-forever] - 2026-11-15

From in-game screenshots of 1.17.1.

### Changed
- The Characters page is laid out like the character select screen:
  - **Right side:** a card for each character, with class crest, name in class colour, level, class, last zone and how long ago you played it. The newest login is first, and the list scrolls with the mouse wheel. Account totals and **People** / **Farming** buttons sit below the cards.
  - **Left side:** the chosen character. You see your own 3D model; other characters show their class crest, because the client does not give addons other characters' appearance. Beside it are name, level, race, class, title, guild, last zone and ten key facts (gold, played, rested XP, progress to the next level, item level, bags, hearthstone, reputation, score, counting since). Below is a table of professions, saved instances and lifetime highlights.

### Fixed
- The character page's title line showed your own name when you had no title.

### Verified in game (1.17.1)
- Professions (Mining 14/75, Skinning 93/150, Fishing, Cooking), rested XP, hearthstone, bag space, best reputation (Friendly, Darkspear Trolls) and loot value (26c) all read correctly on Forever. The header and the 7-row Today box fit.

## [1.17.1-forever] - 2026-11-15

From in-game screenshots of 1.17.0 (Druid level 10, three characters, no Lua errors).

### Fixed
- Characters list: a two-digit level showed as "…". The level column is wider now.
- Characters that have not logged in since 1.17 showed 0c gold and a class written like "MAGE". They now show "—" with "log in to update", the class reads "Mage", and the account total's tooltip says how many characters it leaves out.
- The Detail column on the Characters and Adventure Guide pages was cut off. The columns are rebalanced.
- Header: "Druid · Level 10 · 2,108 pts" ran under the Settings button. It now reads "Level 10 · 2,108 pts", capped to fit.
- The sidebar Today box had dropped to 4 rows with 18 pages. Page buttons are 2 px shorter, so all 7 rows fit again.

## [1.17.0-forever] - 2026-11-15

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Added
- **Characters** page (key R), with ideas from Exlist, Warbandeer: Characters, PlayerTracker and Haul (public descriptions only):
  - **All characters**: level, class, gold, /played, item level, last seen, and account totals.
  - **A page for each character**: race, class, title, guild and rank, gold, /played, rested XP, last zone, hearthstone, item level, bag space, best reputation, score, professions, and saved instances with time to reset. It is refreshed every minute and at logout.
  - **People**: a local log of the players who were in your group, with time grouped, times joined, first and last time, class, level and the zone where you met. It holds up to 2,000 players per character.
  - **Farming sessions**: sessions ranked by net gold per active hour, with XP, kills and loot value per hour.
- 15 statistics:
  - vendor value of loot, in total and by quality;
  - the most valuable single loot;
  - items without a known price;
  - best gold, loot value, XP and kills per hour (sessions with 10+ active minutes);
  - most bag slots;
  - players grouped with, and times a player joined your group.
- The session log records net gold, gold earned, loot value and items looted.
- Full text backups (LTS3) include the people log and the new session fields. Snapshots are rebuilt at login and are not backed up.

## [1.16.0-forever] - 2026-11-15

Prerelease. Offline regression suites pass; not yet checked in the live client.

### Added
- `/lts export`: every statistic, fastest time, unique count, first and top list for every character plus the account total, as CSV with raw numbers.
- Timeline **Days / Months** switch. Months shows the last 12 months, built from the monthly totals added in 1.14.1.
- Addon compartment entry: click to open, right-click for settings.
- `scripts/api_scan.py` lists calls the Forever client does not have, using the captured Forever API surface from Thunderz96/forever-addon-kit (not bundled).

### Changed
- Boss rosters for the nine Forever dungeons were checked against DBM-Dungeons' Forever encounter scaffolds (build 1.60.1.70840; names and encounter IDs only, no code). Hall of Thanes gains Infurnus. Ruins of Lordaeron gains The Butcher. City of Dalaran gains Mana Elemental, Mana Wraith and Unstable Sentinel. The Drowned City gains Deathless Guardians, Min'loth the Serpent and Primeval Elemental. Krol'Dok Stronghold, Alcaz Island Prison, Blackmaw Hold and Shaper's Terrace now have full rosters (5, 5, 7 and 11). Older guide names are kept as optional so earlier kills still count.
- Boss fights use the Forever encounter ID to get the listed boss name.
- The four dungeons where optional bosses are unknown show progress as found / total with a * and still do not count full clears.

### Fixed
- Reputation standings (Friendly to Exalted counts) were never read on Forever: `GetNumFactions`/`GetFactionInfo` do not exist on this Retail-based client. They now use `C_Reputation`.
- Time in each form showed "Form 1" instead of the form name, because only `GetSpellInfo` was used. It now uses `C_Spell`.
- Toy hearthstones were recorded without a name, because only `GetItemInfo` was used. It now uses `C_Item.GetItemNameByID`.
- Card titles follow the Forever Journal skin's casing on the Adventure Guide and Timeline pages.

## [1.15.0-forever] - 2026-11-15

Prerelease. Offline regression suites pass; the Adventure Guide has not been checked in the live client yet.

### Added
- **Adventure Guide** page (key G), a Dungeon Journal-style compendium of every character in Account scope:
  - boss pages with kills, pulls, wipes, kill rate, deaths in the fight, fight time, fastest kill, first pull, first kill with level, item level and group, killing abilities and loot;
  - a dungeon progress book with bosses seen and killed;
  - run history for the last 200 dungeon and raid runs;
  - a death codex by boss, dungeon, zone, killing ability and level;
  - a bestiary of up to 3,000 creatures with type, classification, zone, level range and first and last kill;
  - a zone atlas;
  - Chronicle chapters of ten levels, copyable as text;
  - group memories;
  - boss loot from your own loot messages;
  - suggestions for what to do next.
- 29 statistics: boss pulls, wipes, fight time, longest won and lost fight, deaths in boss fights and instances, first boss kills, boss kills and instance runs by group size, boss loot by quality, different boss items, groupmates, bestiary entries and creature types.
- 20 top lists: kills, pulls, wipes, deaths, time and loot per boss, deaths by dungeon, world bosses, runs and boss kills together, first-kill groupmates, kills by creature type and classification, zones by new creatures, quests, visits and loot, where you levelled up, deaths by level and by hour.
- Full text backups (LTS3) include run history and the bestiary. Older full backups still restore.

## [1.14.1-forever] - 2026-11-15

Prerelease. Offline regression suites pass; the changes below have not been checked in the live client yet.

### Fixed
- The login `/played` reply is hidden without replacing Blizzard's chat function. Chat frames briefly stop listening for the reply instead, which avoids tainting the default UI.
- If the login `/played` reply never arrives, `/played` shows again after 10 seconds.
- Time online, `/played`, AFK, combat and other time counters no longer lose loading screens and frame hitches longer than 2 seconds. Each gap counts up to 2 minutes and is never turned into distance.
- Daily history older than 40 days is folded into monthly totals instead of being deleted. A day restored again from a backup is not counted twice.
- Logout always saves, even when an earlier logout step fails.

### Changed
- Full text backups (LTS3) include the monthly totals. Older full backups still restore. Stats-only backups (LTS2) are unchanged.

## [1.14.0-forever] - 2026-11-14

Prerelease. The regression suites and live-client checks were skipped for this release.

### Added
- Journal filters by entry type and zone, and private notes on individual entries.
- Up to four Dashboard pins with values for the selected character or account and date range.
- Full character text backups for saved statistics, Journal entries and notes, level and travel history, and saved session history. Restore previews a same-character replacement before confirmation. Stats-only backup remains the default. Restore still accepts LTS1 and LTS2.

### Changed
- Added a WoW Forever-inspired default skin and a dated Journal feed for character milestones.
- Restricted release write access to tag publishing after verification passes.

### Fixed
- Corrected the live Forever AddOns path and download filename.
- Reconciled direct and damage-meter totals by fight and damage direction.
- Deduplicated restored unique IDs and retained the newest personal-best records during restore.
- Preserved session history across quick relogs and resumed Journal milestones after reload.
- Logged meaningful movement records and marked incomplete dungeon boss rosters as provisional.
- Fixed the Windows packaging fixture and added archive verification from the actual checkout.

## [1.13.0-forever] - 2026-11-11

### Added
- 222 observation-based statistics, a personal-best history list (839 total entries): movement context/time/distance records, verified corpse-recovery outcomes and zone lists, ten sampled interface-visit timers, fight observations and records, activity rates, and XP, money, healing and damage ratios.
- A movement-observation coverage stat; hidden or missing client values are not counted as zero movement.
- Persisted, reload-safe recovery measurements. Only observed ghost time counts; the method is identified only after a recent user action and confirmed revival. New counters are not backfilled.
- Bounded, timestamped record improvements, with a local Journal toggle and top-three record highlights in the existing last-session recap.
- Versioned release ZIP/ SHA-256 generation and Lua 5.1 regression/package checks.

### Changed
- Documented data sources, overlap, missing observations, record-history retention, and limitations of the stubbed tests.

### Fixed
- Survival-rate denominator now excludes fight endings where alive/dead status was unavailable.
- Moving-speed average now uses distance and movement time observed by the same version.

## [1.12.2-forever] - 2026-11-08

From a full set of in-game screenshots of 1.12.1.

### Fixed
- Most cast spells: internal spells such as LOGINEFFECT no longer appear; "Attack" (auto attack) is listed as Melee. Existing entries are repaired once at login.
- Deaths: data written by versions before 1.5, when every death was blamed on Fatigue, is repaired once: those deaths move to Unknown cause (Killed most often by, first death, Deaths by cause, daily history).
- Time per level and Life per level were empty until your next level-up: the level you are on now is shown as it grows, and the level you installed on is marked "(since install)" and not used for fastest or slowest level records.
- How it works: the combat-log, damage and death-cause texts describe the damage meter and death recap instead of the old n/a behaviour.

## [1.12.1-forever] - 2026-11-08

From an in-game test of `/lts score` (score 752, every part shown).

### Fixed
- Gear part of the score stayed 0 on low-level characters: the best average item level now counts once 3 slots have an item level (was 8).
- `/lts score` lines no longer rely on space padding (the game font is not fixed-width).

### Changed
- Docs: README and DESCRIPTION achievement counts corrected (111 achievements, 396 tiers, 7,890 points); README file list updated; Support section with the Issues link; README images load from GitHub so they also show inside the ZIP.

## [1.12.0-forever] - 2026-11-08

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

## [1.11.0-forever] - 2026-11-08

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

## [1.10.2-forever] - 2026-11-08

From an in-game test: fire death, `/lts debug` shows "from recap 1"; `/lts dm` shows the recap's amounts are readable.

### Added
- Death recap amounts (readable on Forever, unlike hit sizes elsewhere): biggest killing blow, most health before a killing blow, overkill on your deaths, damage in death recaps.
- Biggest hit taken and biggest crit taken now fill from death recaps instead of showing n/a.
- "Damage in your death recaps" list: damage per cause (Fire, or attacker · spell), replacing the tick count.

## [1.10.1-forever] - 2026-11-08

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

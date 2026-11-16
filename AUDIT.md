# Audit - LifeTimeStats 1.23.0-forever

Date: 2026-11-08 · Target: WoW: Forever 1.60.1 (interface 16001) · Author: Malikor

## Evidence labels
- **Verified (offline):** run under Lua 5.1 with a stubbed WoW API (`tests/run.py`, 245 assertions, all passing). Proves syntax, load order, tracker logic, data model upgrade, formatting, backup round-trip and that every page, scope and range renders without a Lua error against the stubs.
- **Partially verified (in client, 1.4.0 screenshots from Malikor, Forever 1.60.1, Mage level 4, 1920×1080):** addon loads without errors; window opens and fits the screen; class-colour accent applied; sidebar, odometer counters, tables with gridlines, tick rings (`SetRotation` works), dot matrix, column charts and tooltips render; distance on foot, steps, jumps, time in the air, session column, jumps-by-hour and zone distance track live; round portrait mask works. Layout defects found there are fixed in 1.4.1.
- **Unverified (in client):** combat, deaths, loot, quests, instances, achievements alerts, compare with a second character, share posting. Layout, textures, fonts and every client API below need an in-game check. No screenshots exist yet.

## Toolchain
Lua 5.1 (lupa) for offline checks · Python Pillow for icon, logo and glyph textures · Playwright for the design mockups · no external addon libraries.

## What the offline tests cover
1.0 coverage (movement, jumps, damage, kills, deaths, money contexts, repairs, loot messages, duels, exploration, XP across level-up, Hearthstone, run counting, emotes, whispers, /played, backup, account view, dual-storage restore) plus 1.1:
avoidance split (dodge/parry in and out) · crits and crushing blows taken · unique creatures by NPC ID · fall survived vs fatal · corpse run time · quest accept→turn-in fastest with title · unique quests · dungeon boss typing and unique bosses · unique NPCs/vendors and first NPC · /roll, reputation, skill-up, bags-full parsing · continent time via map parents · daily buckets and Today view · class colour accent · LTS2 backup with fastest/labels/uniques/firsts and merge recount · every page in Lifetime, Today and Session ranges and in account scope · search page.

**Bug caught by tests during this release:** the daily series passed `0` instead of an empty day to chart callbacks, which would have broken six pages on any day without activity. Fixed.

## 1.23.0
- Verified (offline): the notebook suite has 155 assertions. It checks that the sheet texture exists and is power-of-two RGBA, that the sheet and shadow are drawn, that the spiral is gone, and that the Forever Journal keeps its gold rim. All suites pass.
- Unverified (in client): how crisp the stretched 1024x1024 sheet is at window scale; the torn edges sitting just outside the window; the inked frame line behind the header controls.

## 1.22.1
- In game (1.22.0, 3 screenshots):
  - The notebook renders: wood frame, tiled paper, spiral rings, stacked tab letters, page index tags, margin sketch (compass, open book), Today box, fold shadow, journal-style cards and charts, and the Settings panel with the theme "Auto (Adventurer's Notebook)".
  - Defects fixed here: the paper was too light, the silver coin letter was hard to read, and the Today values ran into their labels.
- Verified (offline): the notebook suite has 154 assertions (aged palette, edge-wear overlay, dark coin letters). All suites pass.

## 1.22.0
- Verified (offline): `tests/notebook.py` (now 152 assertions) checks:
  - the 19 sketch textures exist, are power-of-two and RGBA;
  - every page has a sketch, and the margin sketch follows the page;
  - the seal on each visible achievement tile follows its tier and shows the numeral;
  - a reached goal's Dashboard pin is sealed.

  All suites pass.
- Unverified (in client): sketch sharpness at 84 px on the margin; seal overhang at the tile corners; seal numeral legibility.

## 1.21.0
- Verified (offline): new `tests/notebook.py` (116 assertions plus a texture check) covers:
  - **textures:** present, power-of-two and RGBA;
  - **theme:** Auto picks the notebook, the paper palette swaps into the journal colours and back to Forever Journal's when switching, and card titles are mixed case;
  - **frame:** the frame, six tabs and spiral are built, and the sidebar buttons are hidden;
  - **chapters:** every category is in exactly one chapter, with a tome name;
  - **navigation:** tab and tag selection follow the page, tags open pages, tabs reopen the last page read, and stacked tab letters work;
  - **rendering:** every page renders under the notebook.

  The existing suites pass, with the default-skin expectations updated (Auto is the notebook; class colours are inked at 62%).
- Unverified (in client):
  - texture tiling with `SetHorizTile`/`SetVertTile` and how the paper grain and wood read at real scale;
  - stacked tab letters (rotated FontStrings are not relied on);
  - whether the header and footer paper bands sit cleanly over the wood;
  - the gold dialog rim around the notebook;
  - card readability at 62% class-colour ink for very light classes (Priest, Rogue).

## 1.20.0
- In game (1.19.0 screenshots): every page renders, including the 10 section buttons. `C_Reputation` was read (factions met: 4). No item log entries yet (no green loot).
- Verified (offline): new `tests/history.py` (62 assertions) covers:
  - **quests:** title, XP, gold, duration and zone;
  - **level snapshots:** the new fields;
  - **skills:** skill-up dates, the 75 milestone with its Journal line, and span maths;
  - **deaths:** map position, and skulls drawn only on the matching map and only while enabled;
  - **play habits:** weekday-hour tallies;
  - **item tooltips:** the line text, the `TooltipDataProcessor` hook, and the setting;
  - **size and snapshots:** the size estimate and report, the daily snapshot (replace on the same day, keep 3, restore merges);
  - **exports and the rest:** all four CSV exports, the locale fallback, goals on pins, the five new Characters sections, and the LTS3 round trip.

  Bugs caught and fixed: a CSV row with an empty field broke the join, and Upkeep, History and HistoryUI were listed twice in the TOC while the release was being built. The `WorldMapFrame.ScrollContainer` read is now defensive. All 11 suites pass.
- Unverified (in client):
  - `C_Map.GetPlayerMapPosition` at death, which may be unreadable in instances, and skull placement and scale on the Forever world map;
  - `TooltipDataProcessor` on Forever;
  - the skill-up chat line wording for profession history;
  - `UnitStat` values at level-up;
  - the size of the per-character snapshot texts.

## 1.19.0
- Verified (offline): new `tests/compendium_collections.py` (111 assertions) covers:
  - **reputation:** read, standing gained with its date and Journal line, standing lost;
  - **currencies:** read, with the record of the highest amount;
  - **item log sources:** loot, quest, vendor, crafted and boss, with item level, quality, white items not logged, and one Journal line per epic;
  - **gathering:** items gathered by zone;
  - **mail:** gold sent and received, and items taken (via the `SendMail`/`TakeInbox*` hooks);
  - **trades:** partner, gold each way and items;
  - **goals:** found by words, refused targets, reached once, and the slash commands with commas;
  - **trends, summary text and the page:** every Characters section button;
  - **backup:** the LTS3 round trip of reputation, items and goals.

  All nine suites pass. The catalog has 937 entries. Every new client call is in the captured Forever API dump: `C_Reputation`, `C_CurrencyInfo`, `SendMail`, `GetSendMailMoney`, `TakeInboxMoney`, `TakeInboxItem`, `GetInboxHeaderInfo`, `GetPlayerTradeMoney`, `GetTargetTradeMoney`, `GetTradePlayerItemLink` and `GetTradeTargetItemLink`.
- Unverified (in client):
  - the `C_Reputation.GetFactionDataByIndex` field names on Forever (`reaction`, `currentStanding`, thresholds), and collapsed reputation headers hiding their factions;
  - `C_CurrencyInfo` list contents;
  - hooking `SendMail` and the inbox functions with `hooksecurefunc` on Forever;
  - `UnitName("NPC")` as the trade partner;
  - item-level reads for links not yet cached;
  - layout of the 10 section buttons on the Characters page.

## 1.18.2
- In game (1.18.1, 16 screenshots):
  - Every page renders. The Characters page is left-aligned with labelled columns. Hex's snapshot and Troll model load.
  - The minimap button sat inside a square minimap. The Journal had a stationary-interval record every 10 s (55 entries in about 3 days).
  - `/lts errors`: none.
- Verified (offline): new `tests/minimap.py` (32 assertions) covers:
  - round and square placement maths, corner shapes, and the reset, hide, square and round commands;
  - LibDBIcon registration, click and tooltip, with the own button not created;
  - the one-time record-spam repair of the Journal and history;
  - a long stationary stretch writing no Journal entry while it lasts.

  The expanded suite now checks one record when an interval ends instead of six milestones during it.
- Unverified (in client): `GetMinimapShape` from the user's minimap addon, and LibDBIcon presence and behaviour with Leatrix Plus.

## 1.18.1
- In game (1.18.0 screenshot): PlayerModel `SetUnit("player")` shows the character, framed well. `GetClassAtlas` crests load for Druid, Mage and Warlock. Cards, the fact grid and the details table render. A FontString with a width set defaults to centered text, so the hero and card texts now set LEFT explicitly.

## 1.18.0
- In game (1.17.1, 5 screenshots): `GetProfessions`/`GetProfessionInfo` are readable on Forever (Mining 14/75, Skinning 93/150, Fishing 1/75, Cooking 1/75). `GetXPExhaustion` gives 1,380. `GetBindLocation` gives Bloodhoof Village. `C_Container` bag space is 3/38 free. `C_Reputation` gives Friendly with Darkspear Trolls. The `C_Item.GetItemInfo` sell price works (vendor value of loot is 26c). The header and Today box layout fixes hold.
- Verified (offline): the roster suite (73 assertions) now also covers:
  - cards ordered by last login, with the selection, name, level and class;
  - your model shown and alts' crest shown instead;
  - the hero lines and fact grid, and the details table sections;
  - clicking a card, and the People and Farming buttons;
  - a missing title no longer shown as the name.
- Unverified (in client): the PlayerModel framing and `GetClassAtlas` crests on Forever (texture-coordinate fallback included), how the card list looks, and wheel scrolling with many characters.

## 1.17.1
- In game (1.17.0, 4 screenshots and `/lts debug`):
  - The Characters page opens and lists 3 characters. /played (5h 12m) matches the game's /played.
  - Wealth shows the new loot-value and per-hour rows. Most bag slots is 38. Adventurer's Life renders.
  - `/lts errors`: none recorded. Damage meter readable. Speed readable. Hit sizes and player health hidden, as known.
  - Layout defects found there are fixed in this release.
- Still to check in client: loot value after new loot (no loot messages yet in that session), professions and lockouts on a character page, the people log in a group, and Adventure Guide boss pages after a dungeon.

## 1.17.0
- Verified (offline): new `tests/roster.py` (47 assertions) covers:
  - the snapshot: race, class, guild, gold, rested XP, hearthstone, professions, lockouts, bag space and best reputation;
  - gold updates on PLAYER_MONEY;
  - the people log: joins counted once per grouping, grouped seconds, rejoining, and the account merge;
  - vendor value of loot and unpriced loot;
  - session farming fields and the best gold-per-hour record;
  - every Characters section and character page;
  - the LTS3 round trip of the people log and the new session fields.
- Bug caught by those tests and fixed: `GetProfessions` can return nil for a middle slot, which would have stopped the profession scan early.
- Every new client call is in the captured Forever API dump: `GetProfessions`, `GetProfessionInfo`, `GetSavedInstanceInfo`, `GetXPExhaustion`, `GetGuildInfo`, `UnitRace`, `GetCurrentTitle`, `GetTitleName`, `C_Container.GetContainerNumFreeSlots`, `C_Reputation.*`, `C_Item.GetItemInfo` and `RAID_CLASS_COLORS`. The globals check still passes.
- Unverified (in client): the sell price index of `C_Item.GetItemInfo` on Forever (11th return, as on Retail), whether profession ranks are readable and not secret, lockout reset seconds, class and level of party members out of range, and the sidebar Today box, which now has 5 rows with 18 pages.

## 1.16.0
- Research instead of in-game checks (2026-11-15):
  - **Forever API surface:** Thunderz96/forever-addon-kit publishes `data/forever_api.json`, captured from the live beta client (build 1.60.1.69893: 6,045 global functions and 269 namespaces). `scripts/api_scan.py` compares every LifeTimeStats call against it. Unguarded removed calls found and fixed: `GetNumFactions`/`GetFactionInfo` (reputation never read), `GetSpellInfo` for form names and `GetItemInfo` for toy names. Every remaining hit is a guarded fallback behind a `C_` call or is our own function.
  - **Present in that dump:** `ChatFrame_DisplayTimePlayed`, `RequestTimePlayed`, `UnitCreatureType`, `UnitClassification`, `GetNumGroupMembers`, `IsInRaid`, `UnitPosition`, `GetUnitSpeed`, `C_Item.GetDetailedItemLevelInfo`/`GetItemQualityByID`/`GetItemNameByID`, `C_Spell.GetSpellName`, `C_Reputation.*`, `C_DamageMeter.*`, `C_DeathRecap.*`, `C_ChatInfo.SendChatMessage`, `C_Secrets.*`. Missing: `GetBattlefieldStatInfo` (already optional).
  - **Same kit, measured in game:** `UNIT_COMBAT` amounts are plain while health is secret in combat. That matches 1.10's health-based fallbacks. Registering an unknown event throws, and LifeTimeStats already wraps registration in pcall. `EncounterJournalDisabled=1` on the beta.
  - The kit also reported a beta bug where saved variables were never read back. Guides for moving beta settings to live, and the in-game data kept between 1.12 sessions, indicate it does not affect live.
  - **DBM-Dungeons** ships `DBM-Party-Forever` with 57 encounter scaffolds (`SetEncounterID`, `SetZone`, English names) for the nine Forever dungeons. DBM registering these encounters means ENCOUNTER_START/END fire for them on Forever. Names and IDs were used for the rosters and `ns.FOREVER_ENCOUNTERS`. No DBM code is included.
- Verified (offline): new `tests/compendium.py` (913 assertions) covers month records, the Timeline Months view for every metric, CSV columns, sums and quoting, `/lts export`, the compartment functions, and a globals check after loading and opening every page. Only the slash command, saved variables, two named frames and the three compartment functions are global. The existing suites pass, with roster tests updated to the DBM rosters and an encounter-ID mapping check.
- Unverified (in client): whether optional status of the four provisional rosters matches the game; addon compartment presence on Forever; CSV size in the copy window for large accounts.

## 1.15.0
- Verified (offline, Python 3.14 + lupa 2.8): new `tests/guide.py` (159 assertions) covers a full dungeon run with members, a wipe, a death in the fight, a kill with fastest time and first-kill group, boss loot inside and outside the 3-minute window, world bosses, bestiary type, classification and level, zone atlas, suggestions, chapters, every section and every dungeon and boss page in character and account scope, the page refresh, and the LTS3 round trip of run history and bestiary. The existing suites pass with the catalog at 888 entries. No new globals.
- Unverified (in client): ENCOUNTER_START names on Forever (wipes and pulls depend on it), group member names during instances, UnitCreatureType and UnitClassification values for the bestiary, loot attribution timing, layout of the Adventure Guide page and the shorter Today box below the 17-entry sidebar.

## 1.14.1
- Verified (offline, Python 3.14 + lupa 2.8): run, expanded, journal and package suites pass. New checks cover `/played` muting and unmuting of the chat frames, Blizzard's display function left in place, the 10 s fallback, hitch time counted and capped with no distance, monthly fold totals, no double count of a re-imported day, and the LTS3 round trip of monthly totals.
- Unverified (in client): that `UnregisterEvent`/`RegisterEvent` on ChatFrame1-N for TIME_PLAYED_MSG hides only the login reply on Forever; whether other chat addons keep their own TIME_PLAYED_MSG listeners.

## 1.12.2
- In game (1.12.1, 16 screenshots, every page): all pages render; defects seen and fixed here: LOGINEFFECT and Attack in Most cast spells, Fatigue blamed for a death (pre-1.5 data), empty per-level tables at the install level, outdated How it works texts.
- Verified (offline): repairs run once (spells, fatigue deaths, first death, killer list), install level marked partial with a starting snapshot, Records and Journal pages render.

## 1.12.1
- Release audit (2026-11-08): TOC, structure, globals (runtime diff: only SLASH_LIFETIMESTATS1/2 and the SavedVariables), API guards, secrets, ZIP layout and tests (269 assertions) pass. Fixed from it: achievement counts in README/DESCRIPTION (111 / 396 tiers / 7,890 points), README file list, internal screenshot to-do removed, Issues link added, README images use absolute URLs so they show inside the ZIP. Open: in-game taint check of the /played chat suppression (Trackers.lua replaces ChatFrame_DisplayTimePlayed), luacheck (not run here), git tags and releases.
- In game (1.12.1): score 812, gear part 50 (best average item level 5 on a level 6), lines readable without padding.
- In game (1.12.0): `/lts score` window opens; score 752 = level 600, quests 50, exploration 45, achievements 90, professions 42, deaths -75; gear 0 (item-level threshold too high for a level 6), wealth 0 (under 1 gold earned). 0 Lua errors seen.

## 1.12.0
- In game (1.10.0 screenshot): Legend card, Week/Month ranges, 7-row Today box render; defects seen and fixed: gold-source legend value overlapping its label, fire death counted under Other.
- Verified (offline): session log updates in place, CSV, score and breakdown, peak stats from stubbed UnitStat/UnitArmor/GetCritChance/item levels, battleground wins per map, streak and reset, flag capture only for your name, score/csv text windows, every computed list renders.
- Unverified (in client): GetBattlefieldScore / stat columns on Forever, battleground system message wording, GetSpellBonusDamage and resistance values, item level from GetDetailedItemLevelInfo, faction standings API.

## 1.11.0
- Data: dungeon list, level ranges and boss lists from Warcraft Tavern's Forever dungeon and raid guides (fetched 2026-11-08). Four new dungeons had partial boss lists online (Krol'Dok 1 boss, Alcaz 1 optional, Blackmaw 1, Shaper's Terrace 4 with no final named); those learn bosses in game.
- Verified (offline): wing resolved from the first boss, full clear once per run, learned boss raises the total, 38 instances / 9 new, book list renders, progress included in backups.
- Unverified (in client): GetInstanceInfo names for the new dungeons (matching uses the guide names), ENCOUNTER_END names on Forever (pair encounters matched by substring), DungeonJournal globals.

## 1.10.2
- In game (1.10.1): fire death; `/lts debug` "Death cause: from recap 1"; 0 Lua errors. `/lts dm`: recap 3 events readable (event ENVIRONMENTAL_DAMAGE, environmentalType Fire, amount 14/14/13, currentHP, overkill, critical, school 4). Deaths(9) lists one source per death with deathRecapID 2 and 3.
- Verified (offline): recap amounts feed killing blow, biggest hit taken, damage per cause.
- Unverified (in client): recap amounts for creature and player hits (only environmental seen).

## 1.10.1
- In game (1.10.0): fire death out of combat. `/lts debug`: deaths seen 1, death cause from meter 0, theme ElvUI (chosen by hand), 0 Lua errors. `/lts dm`: avoidable(8) readable (0 that fight); deaths(9) gives deathRecapID 2 for you; enemy damage taken(10) readable with name and sourceCreatureID; combatSpellDetails = { isPet, unitName, unitClassFilename, isMob, classification, amount } (no hit size, so biggest hit stays n/a); C_DeathRecap present.
- Root cause found by reading the code: out of combat the meter's current fight is the previous one, so a fire death would have been blamed on Dire Mottled Boar.
- Death recap event fields (environmentalType, spellName, sourceName, event) taken from Blizzard_DeathRecap.lua in Gethe/wow-ui-source; event 1 is the killing blow.
- Verified (offline): fire death from recap, old fight not blamed, recap ID remembered, settings panel builds and every control clicks without error, debug/dm/errors render to the text window.
- Unverified (in client): recap fields readable (not secret) on Forever; settings layout at different UI scales; thumb texture on the custom slider.

## 1.10.0
- Verified (offline): all assertions pass, including catch-up of two unread fights, meter numbering restart, pet/avoidable/enemy/group/boss reads, killer from the meter, biggest-hit probe, XP sources, week/month views, every page in every range and scope, theme switching and ElvUI live colours.
- Unverified (in client): meter types 8 (avoidable), 9 (deaths), 10 (enemy damage taken) and the contents of combatSpellDetails; creatureName on pet spells; group share in a real party; EllesmereUI/ElvUI/Tukui live colours (Tukui global layout is a guess); tooltip hook on Forever; Screenshot() from an addon; header fit with five range buttons at all UI scales.
- Research: reference addons reviewed from their public CurseForge pages (no code used). The StatTracker link given (wowinterface 26891) points to a nameplate addon, so nothing was taken from it. EllesmereUI integration follows its public SKINNING_API.md.

## 1.9.3
- In game (1.9.2) screenshot: Lists show Damage by spell 1, Who hurt you most 1, What hurt you most "Attack" 49 (+49 session). Damage-taken path verified. Melee renamed.

## 1.9.2
- In game (1.9.1) `/lts dm` + `/lts debug`: amounts readable. Session 93 (Dire Mottled Boar, 13 s): totalAmount 152, Frostbolt (116) 152, overall 7,999. `/lts debug`: "Damage meter readable: yes · fights read 1 · via GetCombatSessionSourceFromID". `GetCombatSessionFromID(0,93)` errors, so arg order is (sessionID, type). 0 Lua errors.
- Added per-spell damage/healing, who/what hurt you, overkill, deadly hits, interrupts, dispels, fight DPS/heal/taken records. Shape of combatSpells taken from the dump; offline test uses it.
- Unverified: taken (type 7) creatureName/isDeadly, interrupts (5) and dispels (6) totals in client.

## 1.9.1
- In game (1.9.0) `/lts dm`: enums listed; `IsDamageMeterAvailable` true; `GetAvailableCombatSessions` returns readable {sessionID, name, durationSeconds}. Per-fight amount calls were cut off in the dump (40-line cap) — dump reworked.
- Reader now goes by newest sessionID, counted once (meta.dmLastID). Unverified whether amounts are secret.

## 1.9.0
- In game (1.8.0): hearth locations 2, hearth moved 1, quests 6 events, 0 errors. `C_DamageMeter` functions listed; built-in meter shows 7,708 damage but addon read "no".
- Added Social.lua; chat counting moved from hook to events; rep alt format; `/lts dm` dump.
- Unverified: barber events, mount journal on Forever, taxi node API, hook names for friends/invites/rolls/merchant.

## 1.8.0
- In game (1.7.0): gold 3s 56c, 5 quest events / 2 turned in, 1 death with corpse run 22 s, 0 errors. `C_DamageMeter` present.
- Found: death cause "Fatigue" was wrong (GetMirrorTimerProgress reads 0 with no bar). Fixed with MIRROR_TIMER_START/STOP.
- Added Life.lua (drink, fire, camp, hearths, books, potions, wild time) and Story.lua (journal, level snapshots, inns, travel log, mounts, pets, food, clothes, game hour, titles, sheet, damage meter).
- Unverified in game: `C_DamageMeter` call shape (several names tried, all in pcall; `/lts debug` reports readable/hidden), drunk messages, `GetBindLocation`, aura names out of combat, innkeeper gossip text (English).

## 1.7.0
- In game (1.6.1): critters loved 1, critters killed 1, emotes from hook 1, creature type readable, 0 errors.
- Added kill colour (Classic grey formula), elite/rare, love-then-kill, appearances, herbs/ore/created tallies, conjured, recap, quest/money chat backups, debug probes.
- Offline tests cover all of these. In game unverified: classification on Forever, quest/money events (debug now reports them), damage-meter API presence.

## 1.6.1 emote/critter fix
- In game (1.6.0): "You love Hare." in chat but Emotes performed 0 → emote hook path wrong. Critter kill 0 → creature type likely hidden (unconfirmed; new debug lines will show).
- Fixed: both emote hooks + `CHAT_MSG_TEXT_EMOTE` backup with de-dup; critter fallback (classification "minus", or level 1 when type hidden and player ≥ 3).
- Offline: chat-line emote counts and loves a critter; hook + chat line counted once; other players' emotes ignored; critter kill with hidden type.

## 1.6.0 critters
- In game (1.5.4): 13 kills, loot quality by tier (2 poor / 16 common / 1 uncommon), levels 1, no errors, no hidden yes/no checks. Watched-unit kills still 0 because every kill gave XP and was counted from the XP line first (expected).
- Critter = `UnitCreatureType` type ID 8 (or localised name). Engaged on any cast, auto-attack (`PLAYER_ENTER_COMBAT`) or `UNIT_COMBAT` hit on a critter target, without needing combat. Counted separately from enemies.
- `/love` on a critter target via the emote hook (target argument or current target).
- Offline tests: critter kill out of combat, not counted as enemy, tally/first set; /love on critter vs non-critter.
- In game unverified: whether `UnitCreatureType` returns the type ID on Forever (name fallback covers English and main locales).

## 1.5.4 cheat-sheet review
Sources: wowforeverguides.com/addons/api-cheatsheet, classicwowforever.com Forever API compatibility guide.
- Confirmed by the sheet: combat log unavailable and registering it errors (fixed in 1.5.3); `UnitHealth`/`UnitHealthMax` may be secret (matches in-game debug); secret values forbid arithmetic, comparison, table keys and truthiness of secret booleans (all guarded).
- Applied: nameplate1-40 sweep (plates may be announced before they are populated); `ns.Bool` wraps 65 boolean API calls across Trackers, Extras and Fallback.
- Offline tests: unannounced nameplate kill counted; hidden `UnitCanAttack` and `IsMounted` raise no errors.

## 1.5.3 in-game results (1.5.2)
- **Verified:** no more speed errors; `/lts errors` empty; speed readable (position fallback used 4 ticks); steps, kills (10), hits (55), crits, fights won keep counting.
- **Found:** `ADDON_ACTION_FORBIDDEN ... protected function 'UNKNOWN()'` from `RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")` (Core.lua:75 via Trackers.lua:399). Registering the event itself is forbidden on Forever.
- **Fixed:** `ns.ShouldRegister` skips the combat log event when `C_CombatLogSecure` exists, `issecretvalue` exists, or `CombatLogGetCurrentEventInfo` is missing. Offline tests cover all three.

## 1.5.2 in-game results (1.5.1)
- **Found:** `GetUnitSpeed("player")` can return a secret number; comparing it raised 547 errors from the unguarded ticker (not captured by `/lts errors` because per-frame scripts were not wrapped).
- **Found:** `UnitHealth("player")` is secret (`/lts debug`: health readable no), so health-derived statistics stay n/a.
- **Verified:** n/a display, Hits landed counter, achievement badge on icon, kills 8, crit rate.
- **Fixed:** speed guarded with position-delta fallback (`UnitPosition`, teleport filter); all OnUpdate scripts wrapped in `ns.Guard`. Offline tests cover hidden speed, hidden position, teleport and a throwing ticker.

## 1.5.1 in-game results (Malikor, Mage level 5-6, Durotar, 1.5.0)
**Verified in client:** kills from XP chat lines (6, matching the dashboard); `UNIT_COMBAT` delivers actions and flags for you (20) and your target (33): hits 31, crits 2, misses 2, hits taken 46; fights won 6; shortest fight won; loot quality read; jumps-by-hour, steps, kills by zone; 0 Lua errors.
**Found:** `UNIT_COMBAT` amounts are secret (152 hidden values), so damage totals stayed 0. Unit-watch kills were 0 that session (all kills were matched by XP lines first, as designed, or the units were not engaged); still to confirm with grey mobs.
**Changed:** amount-based statistics show n/a; damage taken / healing received from player health (unverified whether `UnitHealth("player")` is readable on Forever; `/lts debug` now reports it).

## 1.5 Forever combat sources
**Finding (from 1.4.1 in-game screenshots + public sources):** every statistic fed by the combat log read 0 while XP, skill-ups, loot, fights and movement worked. Forever applies Midnight's addon rules: `COMBAT_LOG_EVENT_UNFILTERED` is restricted and its reader moved to `C_CombatLogSecure` (SecureOnly); `UNIT_DIED`/`PARTY_KILL` are secret when unit identity is restricted. Hiding the combat-log chat tab is unrelated.

**Replacement sources** (all wrapped in secret-value checks, inactive whenever combat-log events do arrive so nothing double counts):
| Statistic group | Source | Status |
|---|---|---|
| Kills | `CHAT_MSG_COMBAT_XP_GAIN` (`COMBATLOG_XPGAIN_FIRSTPERSON` prefix) + unit watch (`UNIT_HEALTH`, `NAME_PLATE_UNIT_*`, `PLAYER_TARGET_CHANGED`, `UnitIsDead`, `UnitIsTapDenied`), de-duplicated by name within 5 s | Offline verified; in-game unverified |
| PvP kills | `CHAT_MSG_COMBAT_HONOR_GAIN` (`COMBATLOG_HONORGAIN`) + unit watch | Offline verified |
| Attacks on you | `UNIT_COMBAT` "player" | Offline verified; whether Forever marks its amounts secret is unverified |
| Your attacks | `UNIT_COMBAT` "target", solo only | Offline verified |
| Falls | `UnitHealth("player")` before/after landing | Offline verified |
| Death cause | recent fall, `GetMirrorTimerProgress` BREATH/EXHAUSTION, hostile target | Offline verified |
| Loot quality | `|cnIQ#:` tag, hex colour, `C_Item.GetItemQualityByID`, `GetItemInfo` | Offline verified |
| Levels | `PLAYER_LEVEL_UP`, `PLAYER_LEVEL_CHANGED`, XP watcher; counted once per level | Offline verified |
| n/a | healing done, overhealing, interrupts, dispels, buffs, debuffs, killing blows, DoT ticks, ranged hits, environment damage types, resurrections cast | Shown as n/a until combat-log events are seen |

`/lts debug` reports per-source counts in game.

**Bug found by tests during this release:** the secret-value check captured `issecretvalue` once at load; now read on every call.

## 1.4 compare + share (offline)
- Compare page renders with a second character and with All characters; Ctrl/plain click handlers; Swap sides.
- Forget character: removes an alt; refuses the current character.
- Share text for all 11 topics: 21-250 characters, no `|` escape codes (chat would reject them).
- `/lts share g wealth` sends exactly once to GUILD and counts a share; `/lts share deaths` (no channel) only opens the preview; unknown topic sends nothing.
- Channel picker only offers channels the player is in (Say always; Party/Raid/Guild/Instance when applicable).
- Found by tests: page fields that start unset relied on frames returning nil; now initialised explicitly.
- 14 pages refresh in 10.6 ms against stubs.
- Not verified: whether Forever blocks addon `SendChatMessage` to Say outside instances without a hardware event (a button click and a typed command both are hardware events). Errors are shown in chat instead of failing silently.

## 1.3 achievements (offline)
- 69 definitions, 253 tiers, 5,360 points; every definition evaluates without error against a full record, an empty record and the account view.
- First check after upgrade awards existing progress silently and flags it "before v1.3" (no alert spam).
- New tiers increment an unseen counter (not a timestamp compare: a tier earned in the same second you opened the page was missed by the first version of this check; caught by tests and fixed).
- Chat and toast alerts fire only when enabled; default is off.
- "Lower is better" tiers (fastest times) verified: 41 s quest earns the under-60 s tier, no time earns nothing, progress moves toward the next target.
- Achievements survive backup, restore (earliest date wins) and appear in All characters.
- Check runs every 2 s inside pcall; 13 pages refresh in 6.5 ms against stubs.

## 1.2 hardening results (offline, stubbed API — relative numbers, not in-client timings)
| Check | Result |
|---|---|
| 20,000 damage events + 6,667 kills through the combat handlers | 105 ms total, 0.004 ms per event |
| Refresh of all 12 pages | 5.2 ms (stub widgets; real widget calls cost more) |
| Heavy character (3,000 items + 3,000 subzones in uniques, 500 creatures, 60 days) backup size | 133 KB |
| Day history pruned at logout | 40 days kept |
| Tallies pruned at logout | 400 entries max |
| Unique cap | new keys refused at 20,000 |
| NaN / infinity / negative fastest | ignored |
| Events before the DB exists | ignored, no errors |
| Session across /reload | kept; reset on real login, login counted after the reset |
| 1.0 record in account file | upgraded in place, merged in account view |
| LTS1 (1.0) backup | restores |

## Client APIs relied on (verify in game)
| API / event | Used for | If missing on Forever |
|---|---|---|
| `Texture:SetRotation` | tick-ring charts | ticks stay upright (ring still readable) |
| `Texture:SetMask` | round portrait | square portrait |
| `SetPropagateKeyboardInput` | page shortcuts | shortcuts off; mouse still works |
| `C_Map.GetBestMapForUnit` / `GetMapInfo` | capital city, continent | those lists stay empty |
| `IsIndoors` | indoors/outdoors time | outdoors only |
| `RAID_CLASS_COLORS` / `C_ClassColor` | class accent | amber accent |
| `GetShapeshiftFormInfo` | time per form | form list empty |
| `C_QuestLog.GetTitleForQuestID` | quest names in fastest quest | "Quest #id" |
| `RANDOM_ROLL_RESULT`, `FACTION_STANDING_*`, `SKILL_RANK_UP`, `ERR_INV_FULL` | rolls, rep, skills, bags full | those stay 0 |
| `UI_ERROR_MESSAGE` arg order (Classic vs modern) | red error list | handled both ways |
| Plus everything from 1.0: CLEU, `JumpOrAscendStart`, `GetUnitSpeed`, `ENCOUNTER_END`, `GetSavedInstanceInfo`, `QUEST_TURNED_IN`, `TIME_PLAYED_MSG`, `GetPVPLifetimeStats`, emote/chat hooks, Settings API, BackdropTemplate |

Event registration, every handler, every init step and every page update run inside `pcall`; failures go to `/lts errors` instead of breaking the addon.

## Design decisions (this release)
- Own dashboard window per approved mockups; Odometer theme kept.
- **Accent follows class colour** (in place on the theme table, so every widget follows). Very light colours (Priest) are darkened ~18% so they stay distinct from cream text. Changing it needs /reload.
- **Shortcuts** only fire with the mouse over the window, out of combat and not while typing, so action-bar keys are never stolen.
- **Gold sources** shown as one ring of where earned gold came from (the mockup's nested rings had unclear percentages).
- **No free resize**: fixed 1140×740 layout; scale defaults to fit 92% of screen height; Ctrl+wheel to change.
- Tables have row and column gridlines.
- Records that only make sense lifetime show "—" in the Today range.

## Known limitations
- History before install cannot be recovered.
- "Dungeon complete" has no Classic event: runs with a boss kill + fastest clear to last boss (only runs matching your best boss count qualify).
- Kill credit: died within 3 minutes after you or your pet damaged it.
- Steps are an estimate. Flight path distance depends on `GetUnitSpeed` reporting speed on a taxi.
- Fall "survived" = alive 1.5 s after the damage. Airtime counts jumps too (records only).
- Capital cities use the six Classic capital map IDs; other cities are not "capitals".
- Daily history keeps 40 days; top lists keep 400 entries each.
- Gold contexts are inferred from which window is open.
- Level timing starts from the first level-up after install (the level you were already on is unknown).

## Performance
- One 4 Hz ticker (Trackers) + one per-frame watcher that only checks `IsFalling`/`UnitOnTaxi`; everything else in the watcher is 4 Hz.
- Map lookups cached per zone change.
- Window refreshes once per second only while open, and only the visible page.
- Account view cached for 2 s.

## Privacy and safety
No network, no addon comms, no telemetry. Backups contain numbers and plain names only; import never runs code. Erase character asks first.

## In-game test checklist
1. `/lts` opens the dashboard; window fits the screen; Esc closes; header drags; Ctrl+wheel scales.
2. Accent is your class colour; untick in settings + /reload → amber.
3. Hover window, press 2 → Travel; press 2 with mouse elsewhere → your action bar fires.
4. Jump 10 times → Jumps +10 and Jumps by hour lights up.
5. Swim, ride a flight path → Swimming and Flight paths distances rise.
6. Get dodged/parried by a mob → Combat page "Attacks you dodged/parried".
7. Jump off a ledge and survive → Records "Biggest fall survived".
8. Die, release, run back → Corpse runs +1, Records "Longest corpse run".
9. Accept and turn in a quest → Fastest "Quest accept to turn-in".
10. Talk to a new NPC → Uniques "NPCs met" +1, Firsts "NPC met".
11. Run a dungeon to the last boss → Dungeon bosses, Fastest table gets a row for it.
12. Stand in Orgrimmar a minute → Travel "Most visited capital: Orgrimmar".
13. Timeline shows today; switch chart metrics.
14. Search "fall" lists fall stats; clicking a row opens its page.
15. `/lts export`, `/lts import` round trip; `/lts errors` empty after a session.
16. `/reload` mid-session: Session column keeps its numbers. Log out and in: it resets.
17. Press H over the window: How it works page scrolls with the mouse wheel.
18. Settings: Reset window centres the window; the data line shows a size.
19. First load of 1.3: Achievements page shows existing tiers as "before v1.3", sidebar shows no "new".
20. /dance 10 times: sidebar shows "1 new" (Dance Floor II); opening the page clears it.
21. Set alerts to Toast, earn a tier: toast appears for 5 s; clicking it opens the page.
22. Log in a second character, open Compare: both listed in class colour; click/Ctrl+click switches sides.
23. Share → Party while grouped: the line appears in party chat; Close posts nothing.
24. `/lts share s` posts the summary to Say; `/lts share` alone only previews.
25. Kill 5 mobs solo: Enemies killed +5; `/lts debug` shows XP and/or unit kills; Combat shows damage done and crits.
26. Get hit and dodge/parry: Attacks on you ring fills.
27. Jump off a ledge that hurts: Falls that hurt +1, biggest fall survived set.
28. Loot a green: Loot by quality shows Uncommon +1.
29. Ding: Levels gained +1, Time per level gets a row on the next level.
30. Wealth/Combat: healing done etc. show n/a.

# Expanded statistics (1.13.0)

LifeTimeStats 1.13.0 appends **222** observed statistics and a Personal Best History list, raising the dashboard catalog from 616 to **839 entries**. Existing saves remain valid; these new counters begin when the upgraded addon starts observing play. No previous activity is estimated or backfilled.

## Movement context

The addon's existing movement ticker supplies the distance and elapsed-time sample. The additional counters split readable samples into moving/stationary, foot/mount/swimming, combat/peace, AFK/active, rest-area, indoor/outdoor, group/solo, open-world/party-dungeon/raid/battleground/arena, falling, low/full health, casting, and channeling contexts. The corresponding rows report time, distance where meaningful, and longest/farthest continuous observed intervals.

Contexts overlap: a sample can be moving, grouped, indoors, and in combat at once. Their totals must not be added. The movement coverage row reports the share of accepted samples with a readable movement signal; a missing signal is not counted as stationary. New movement speed uses only movement distance and time observed by 1.13.0, not older lifetime distance.

## Ghost and corpse recovery

Ghost travel distance is accumulated from observed moving samples while the public API identifies the character as a ghost. It is measured travel distance—not the straight-line distance from release point to corpse. Time spent offline, loading, dead before becoming a ghost, or in hidden/unknown state is excluded.

Runs first seen after the player has already become a ghost are marked partial. Only runs observed from the death-release interaction through a public alive/non-ghost state contribute to fully observed averages and records. A `RetrieveCorpse`, `AcceptXPLoss`, or `AcceptResurrect` action is only a method hint; it is classified as confirmed after the subsequent revival is observed within 30 seconds. Button presses without revival and endings with expired or unavailable evidence remain unknown. Spirit-healer revival and another player's ghost resurrection are distinct from corpse retrieval. Recovery progress is saved across `/reload`; time while logged out is never added.

Recovery distance and time lists group the sampled movement by the zone being observed; recovery-ending lists use the zone where the revival is observed. When the client does not supply readable ghost/alive state, measurements are skipped rather than inferred.

## Interaction windows

Ten standard game windows (vendor, bank, mailbox, auction house, trade, trainer, flight map, NPC conversation, quest dialog and book/item text) are timed using their public open/close events. Duration means the window was open during an accepted online sample; it does not prove active interaction. Repeated open/close events are deduplicated, visit averages use completed online intervals, and overlapping windows are intentionally counted independently. Loading, logout and reload close an interval so offline time is not fabricated.

## Fights and rates

Combat records use observed player-combat start/end events, movement samples, and existing counters. Fight survival rates include only endings with readable alive/dead state. An interrupted fight is reported separately and is not counted as a completed fight record.

Per-hour rates use existing counters divided by existing online time. XP, currency, healing, damage, crafted items and loot averages/percentages compare the source counters already captured by the addon. These are observed recorded-counter ratios, not independently reconciled totals.

## Adventure chronicle and records

The Top Lists page includes a local, dated Personal Best History, with the latest improvements from the lifetime record and current session. It retains up to 200 entries per character and per session, carries character names into account view, and is preserved by the plain-text backup/restore format. The existing session recap can mention up to three recent record changes. By default, substantial new personal bests also make a Journal entry; turn off **Record new highs in the journal** in Settings → Chat and display to disable those local story beats. No notifications are sent to chat channels or other players. Sampled interval records require a meaningful improvement so the chronicle does not record every update tick.

## Test scope

`tests/run.py`, `tests/expanded.py` and `tests/package_release.py` run under a stubbed Lua 5.1 client and validate calculations, missing/hidden values, interruptions, reload handling, UI integration, packaging and checksums. They are automated regression tests, **not a live World of Warcraft: Forever in-game test**.

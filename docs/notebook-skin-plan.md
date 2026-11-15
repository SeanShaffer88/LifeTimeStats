# Adventurer's Notebook skin: build plan (1.21.0)

The user approved the mockups (`docs/mockups/notebook-dashboard.png`, `notebook-characters.png`) and asked to make the skin feel made for RPG fans.

## Layout (in game)
- **Frame:** wood around the window. The header and footer sit on a darker parchment band with ink text, because ink text can't be read on wood.
- **Left edge:** vertical tabs at x 4-50, a spiral binding at x 50-78 (ring texture repeated), and paper from x 78 to the right edge.
- **Page margin (x 78-186):** sub-tab "tags" stacked vertically like a page index, with the Today box under them. Page content keeps its current position and size (CW x CH), so no page layout changes.
- **Spine:** a soft crease shadow down the middle gives the two-page look. Hard rings down the middle would cut through full-width tables (Search, Help, Timeline, Journal), so they move to the left edge.
- **Tabs (6 groups):**
  - Character: Dashboard, Characters, Compare
  - Stats: Travel, Combat, Deaths, Wealth & Loot, Social
  - Adventure: Adventure, Adventure Guide, Adventurer's Life
  - Records: Records, Fastest/Uniques, Achievements, Top Lists
  - Journal: Journal, Timeline
  - Notes: How it works (plus a settings link)

  Hotkeys still open pages and select the matching tab. For vertical tab text, try `pcall(fs.SetRotation, ...)` and fall back to stacked letters.
- **Theme:** "notebook" in `Themes.lua`.
  - Palette: paper `ece2c8`, ink `3a2e22`, soft ink `6e5d48`, accent `8b3a1e`. Class accent darkened about 0.75 for paper.
  - Fonts: Friz for text, Morpheus for headings.
  - It becomes the Auto default when no UI addon is loaded. Layout changes need /reload.
- **Widgets (branch on `ns.themeId == "notebook"`):**
  - `W.Card`: ink border box, centered title, mixed case.
  - `W.Table`: no dark header or zebra fills; faint ink ledger lines.
  - `W.Odometer`: ink box with the value in the accent colour.
  - `W.FlatButton` and `W.Segmented`: paper tags.
- **Textures** (Pillow, `Media/notebook/*.tga`, power-of-two, 32-bit): tileable paper (512), wood (256), spiral ring (64x32), tab shape (64x128, white with alpha), tag shape (128x32), crease gradient.

## RPG flavour (user request, mid-build)
- **Tab names as an adventurer's tome:** Hero, Deeds, Quests, Legends, Chronicle, Lore.
- **Page headings:** "Chapter" headings, e.g. "Chapter III: Battles".
- **Ink sketches** on the main cards: backpack (wealth), sword (combat), skull (deaths), boot (travel), quill (journal).
- **Hero sheet:** the Characters page laid out like a character sheet: portrait frame, attributes block (Str/Agi/Sta/Int/Spi from level snapshots), "Purse" and "Pack".
- **Wax-seal markers** for achievements and goals reached.
- **Wording:** "Enemies slain", "Gold earned (purse)" and similar labels on notebook pages only. Statistic keys stay the same.

## Status
Mockups are done and approved. No addon code has changed for the skin yet. Branch: `feat/notebook-skin`.

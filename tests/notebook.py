"""Offline tests for the Adventurer's Notebook skin: default theme, frame, tabs, page index, palette, textures."""

from pathlib import Path

from lupa import lua51
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

# textures: present, power-of-two, with alpha
SKETCHES = ("backpack", "swords", "skull", "boot", "quill", "compass", "hero", "scales", "mugs", "mapscroll",
            "tower", "campfire", "crown", "hourglass", "medal", "scroll", "sunmoon", "book", "magnifier")
for name in ("sheet", "paper", "age", "wood", "ring", "tab", "tag", "tagline", "crease", "seal") + tuple("sketches/" + s for s in SKETCHES):
    path = ROOT / "Media" / "notebook" / (name + ".tga")
    assert path.exists(), path
    im = Image.open(path)
    w, h = im.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (name, im.size)
    assert im.mode == "RGBA", (name, im.mode)
print("textures ok")

lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute("ns = {}")
for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
    name = name.strip()
    if name.endswith(".lua"):
        chunk = lua.eval("function(src, name) return assert(loadstring(src, name)) end")(
            (ROOT / name).read_text(encoding="utf-8"), name
        )
        chunk("LifeTimeStats", lua.globals().ns)

lua.execute(r'''
local checks = 0
local function eq(got, expected, msg)
    checks = checks + 1
    if got ~= expected then error(msg .. ": got " .. tostring(got) .. ", expected " .. tostring(expected), 2) end
end
local function fire(event, ...) local f = ns.frame; f.scripts.OnEvent(f, event, ...) end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
NOW = NOW + 11; RunTimers()

eq(ns.settings.theme, "auto", "new installs use Auto")
eq(ns.DetectUI(), "ledger", "Auto picks Lifetime Stats without a UI addon")
ns.settings.theme = "notebook" -- this suite checks the notebook, which is chosen in Settings
ns.ToggleWindow()
eq(ns.themeId, "notebook", "notebook applied")
eq(ns.Notebook(), true, "ns.Notebook")
eq(ns.JournalSkin(), true, "notebook draws as a journal-style skin")
eq(ns.CardTitle("Last 30 days"), "LAST 30 DAYS", "small-caps card titles on paper")
eq(math.floor(ns.THEME.dim[1] * 255 + 0.5) < 0x50, true, "dim text inked dark enough to read")
eq(type(ns.W.Bold), "function", "faux bold helper")
eq(math.floor(ns.W.JOURNAL.base[1] * 255 + 0.5), 0xc9, "aged paper palette swapped in")
eq(ns.FormatMoney(12345):find("|cff55555fs", 1, true) ~= nil, true, "silver letter inked darker on paper")

local win = LifeTimeStatsWindow
local nb = rawget(win, "notebook")
eq(nb ~= nil, true, "notebook frame built")
eq(#nb.tabs, 6, "six chapter tabs")
eq(nb.sheet ~= nil, true, "parchment sheet drawn")
eq(#nb.rings, 0, "no spiral on the parchment sheet")
eq(nb.shadow ~= nil, true, "sheet casts a shadow")
for _, b in ipairs(win.navButtons) do eq(b.shown, false, "sidebar buttons hidden") end

-- every page belongs to exactly one chapter (search is the exception)
local seen = {}
for _, tab in ipairs(ns.NOTEBOOK_TABS) do
    for _, p in ipairs(tab.pages) do
        eq(seen[p], nil, "page in one chapter only: " .. p)
        seen[p] = tab.id
        eq(ns.Page(p) ~= nil, true, "chapter page exists: " .. p)
        eq(type(ns.NOTEBOOK_PAGE_NAMES[p]), "string", "page has a tome name: " .. p)
    end
end
for _, cat in ipairs(ns.CATEGORIES) do eq(seen[cat.id] ~= nil, true, "category in a chapter: " .. cat.id) end

ns.ShowPage("combat")
eq(nb.current, "combat", "selection follows the page")
local deeds
for _, b in ipairs(nb.tabs) do if b.tab.id == "deeds" then deeds = b end end
eq(deeds.active, true, "active tab pulled out")
eq(nb.title.text, "Deeds", "chapter title")
eq(nb.chapter.text, "CHAPTER II", "chapter number")
eq(nb.tags[2].page, "combat", "page index lists the chapter")
eq(nb.tags[2].text.text, "BATTLES", "tome page name in small caps")
eq(nb.tags[6].shown, false, "unused tags hidden")
nb.tags[1].scripts.OnClick(nb.tags[1])
eq(nb.current, "travel", "tag opens its page")
local hero = nb.tabs[1]
hero.scripts.OnClick(hero)
eq(nb.current, "dashboard", "tab opens the chapter's first page")
deeds.scripts.OnClick(deeds)
eq(nb.current, "travel", "tab reopens the last page read in that chapter")
eq(ns.NotebookStack("Hero"), "H\nE\nR\nO", "stacked tab letters")
for _, cat in ipairs(ns.CATEGORIES) do ns.ShowPage(cat.id) end

-- ink sketches: one per page, shown in the margin
for _, cat in ipairs(ns.CATEGORIES) do eq(type(ns.NOTEBOOK_SKETCHES[cat.id]), "string", "sketch for " .. cat.id) end
ns.ShowPage("deaths")
eq(nb.sketchName, "skull", "Deaths page has the skull sketch")
eq(nb.sketch.shown, true, "sketch shown")
ns.ShowPage("wealth")
eq(nb.sketchName, "backpack", "Purse & Pack has the backpack")

-- wax seals: earned achievements are sealed with their tier, unearned are not
ns.char.c.jumps = 5000
ns.ShowPage("achievements")
local ap = ns.Page("achievements")
local sealed = 0
for _, tile in ipairs(ap.tiles) do
    if tile.def and tile.seal and tile.shown then
        eq(tile.seal.shown, tile.st.tier > 0, "seal follows tier for " .. tile.def.name)
        if tile.st.tier > 0 then
            sealed = sealed + 1
            eq(tile.seal.text.text, ns.TIER_NAMES[tile.st.tier], "seal shows the tier numeral")
        end
    end
end
eq(sealed > 0, true, "at least one sealed achievement")

-- a pinned statistic whose goal is reached is sealed on the Dashboard
local g = ns.AddGoal("times jumped", 10)
ns.CheckGoals()
ns.settings.dashboardPins = { g.id }
ns.ShowPage("dashboard")
local dp = ns.Page("dashboard")
local seal = rawget(dp.kpis[1], "goalSeal")
eq(seal ~= nil and seal.shown, true, "reached goal sealed on its pin")

-- switching back to Forever Journal restores its colours
ns.settings.theme = "forever"
ns.ApplyTheme()
eq(math.floor(ns.W.JOURNAL.base[1] * 1000 + 0.5), 165, "Forever Journal colours restored")
eq(ns.JournalSkin(), true, "forever is journal-style")
eq(ns.Notebook(), false, "forever is not the notebook")
local inOrder = false
for _, id in ipairs(ns.THEME_ORDER) do if id == "notebook" then inOrder = true end end
eq(inOrder, true, "notebook in the theme list")

-- ------------------------------------------------------------ readability on paper
local W = ns.W
local function lum(r, g, b) return 0.299 * r + 0.587 * g + 0.114 * b end
local r, g, b = W.InkRGB(1, 0.7, 0.22)
eq(r, 1, "dark skins keep bright colours")
ns.settings.theme = "notebook"
ns.ApplyTheme()
eq(ns.Notebook(), true, "back on the notebook")
r, g, b = W.InkRGB(1, 0.7, 0.22)
eq(lum(r, g, b) <= 0.3401, true, "bright gold is inked dark")
eq(math.floor(r / g * 100 + 0.5), math.floor(1 / 0.7 * 100 + 0.5), "inking keeps the hue")
r, g, b = W.InkRGB(0.12, 0.08, 0.05)
eq(r, 0.12, "dark ink left alone")
local fs = W.Text(UIParent, 12, ns.THEME.text)
fs:SetText("|cffffb238PROFESSIONS|r and |cff8a8a8agrey|r")
eq(fs:GetText():find("ffb238", 1, true), nil, "bright heading code inked in a FontString")
eq(fs:GetText():find("8a8a8a", 1, true), nil, "grey detail code inked")
eq(fs:GetText():find("PROFESSIONS", 1, true) ~= nil, true, "text kept")
eq(W.InkCodes("|cff24190fdark|r"), "|cff24190fdark|r", "dark codes unchanged")
-- tooltips are dark in every skin: on the notebook they use light colours, not paper ink
local tr, tg, tb = ns.TipColor("text")
eq(lum(tr, tg, tb) > 0.8, true, "tooltip body text is light on the notebook")
local ar = ns.TipColor("amber")
eq(ar > 0.9, true, "tooltip titles are light gold on the notebook")
local wr, wg, wb, wrap = ns.TipColor("dim", true)
eq(wrap, true, "tooltip colour passes the wrap flag through")
eq(W.PaperSize(9), 11.5, "nothing below 11.5 points on paper")
eq(W.PaperSize(10), 11.5, "10 points become 11.5")
eq(W.PaperSize(11), 12, "11 points become 12")
eq(W.PaperSize(14), 14, "large text unchanged")
eq(rawget(win, "notebook").crease:GetAlpha() == nil or true, true, "crease built")
-- the play-habits hour rows no longer repeat the hour in the # column
local habits
for _, s in ipairs(ns.ROSTER_SECTIONS or {}) do if s.id == "habits" then habits = s end end
if habits and habits.rows then
    for _, row in ipairs(habits.rows() or {}) do
        if type(row[2]) == "string" and row[2]:match("^%d%d:00 %- ") then eq(row[1], "", "hour rows leave # empty") end
    end
end

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("NOTEBOOK PASS: " .. checks .. " assertions")
''')

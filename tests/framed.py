"""Offline tests for the framed tome skins (Lifetime Stats, the default, and Stats Explorer):
frame, plaque, header controls, menu, both overview pages and their data."""

from pathlib import Path

from lupa import lua51
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

for name in ("parchment", "wood", "edge_h", "edge_v", "corner", "plaque", "emblem", "crest", "crest_rim", "navsel", "divider", "arrow"):
    path = ROOT / "Media" / "framed" / (name + ".tga")
    assert path.exists(), path
    im = Image.open(path)
    w, h = im.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (name, im.size)
    assert im.mode == "RGBA", (name, im.mode)
print("textures ok")

COMMON = r'''
local checks = 0
function eq(got, expected, msg)
    checks = checks + 1
    if got ~= expected then error(msg .. ": got " .. tostring(got) .. ", expected " .. tostring(expected), 2) end
end
local function fire(event, ...) local f = ns.frame; f.scripts.OnEvent(f, event, ...) end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
NOW = NOW + 11; RunTimers()
'''


def load():
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
    return lua


# ---------------------------------------------------------------- data helpers and the default skin
lua = load()
print("ledger:", lua.execute(COMMON + r'''
-- data
local now = time()
eq(ns.Ago(now - 30, now), "just now", "seconds ago")
eq(ns.Ago(now - 300, now), "5m ago", "minutes ago")
eq(ns.Ago(now - 7200, now), "2h ago", "hours ago")
eq(ns.Ago(now - 86400, now), "1 day ago", "one day")
eq(ns.Ago(now - 86400 * 6, now), "6 days ago", "days")
eq(ns.ScoreMotto(0), "Every road starts with a single step.", "first motto")
eq(ns.ScoreMotto(2500), "A long road, well traveled.", "a long road")
eq(ns.ScoreMotto(99999), "A legend, written one step at a time.", "the last motto")

local ch = ns.char
ch.journal = {
    { now - 86400 * 6, "Reached level 10 in Mulgore", 10, zone = "Mulgore" },
    { now - 86400 * 2, "Killed Hogger for the first time.", 10, kind = "boss", zone = "Elwynn Forest" },
}
ch.quests = { { t = now - 3600, n = "The Hunt Begins", l = 10 }, { t = now - 86400 * 3, n = "Rite of Strength", l = 9 } }
ch.items = { { t = now - 600, n = "Swift Windsteed", q = 4, src = "boss" }, { t = now - 60, n = "Linen Cloth", q = 1 } }
local ms = ns.OverviewMilestones(ch, 5)
eq(#ms, 2, "two milestones")
eq(ms[1].title, "Killed Hogger for the first time.", "newest milestone first")
eq(ms[1].icon:find("Dragon", 1, true) ~= nil, true, "boss icon")
eq(ms[2].icon:find("SurgeOfLight", 1, true) ~= nil, true, "level-up icon")
eq(ms[1].sub, "Elwynn Forest · level 10", "where and when")
local act = ns.OverviewActivity(ch, 10)
eq(#act, 5, "quests, a good item and the Journal (grey items left out)")
eq(act[1].title, "Obtained Swift Windsteed", "newest first")
eq(act[2].title, "Completed a quest", "quests in the feed")
for i = 2, #act do eq(act[i - 1].at >= act[i].at, true, "sorted newest first") end

ch.r.max_hit, ch.r.max_hit_what = 1234, "Wrath"
ch.rh = { { k = "max_hit", v = 1234, at = now - 86400, d = "max", w = "Wrath" } }
ch.days[date("%Y%m%d", now - 86400 * 4)] = { money_in = 50000, quests_done = 7, kills_npc = 3 }
ch.days[date("%Y%m%d")] = { kills_npc = 2 }
local hl = ns.OverviewHighlights(ch, 5)
eq(hl[1].label, "Biggest hit", "biggest hit first")
eq(hl[1].source, "Wrath", "with its source")
eq(hl[1].at, now - 86400, "and when")
local labels = {}
for _, h in ipairs(hl) do labels[h.label] = h end
eq(labels["Most gold in a day"] ~= nil, true, "best gold day")
eq(labels["Most quests in a day"].value, "7", "best quest day")
eq(labels["Best DPS on a boss"], nil, "missing records are left out")

ch.c.kills_npc = 105
local series = ns.CumulativeSeries(ch, function(d) return (d.kills_npc or 0) end, 105, 30)
eq(#series, 30, "30 days")
eq(series[30].total, 105, "ends at today's total")
eq(series[29].total, 103, "yesterday was before today's kills")
eq(series[1].total, 100, "a month ago, before both days")

-- the default skin
eq(ns.DetectUI(), "ledger", "Lifetime Stats is the default")
ns.ToggleWindow()
eq(ns.themeId, "ledger", "applied")
eq(ns.Framed() and ns.Paper() and ns.Ledger(), true, "a framed paper skin")
local win = LifeTimeStatsWindow
local fr = rawget(win, "framed")
eq(fr ~= nil, true, "frame built")
eq(fr.title:GetText(), "Lifetime Stats", "plaque title")
eq(#fr.corners, 4, "four gold corners")
eq(rawget(win, "notebook"), nil, "no notebook frame")
-- header controls
local scope, range = win.scopeSeg, win.rangeSeg
eq(scope.text:GetText(), "Malikor", "character dropdown shows the character")
eq(range.text:GetText(), "All time", "range dropdown")
range.scripts.OnClick(range)
eq(range.menu:IsShown(), true, "menu opens")
range.rows[3].scripts.OnClick(range.rows[3])
eq(ns.settings.range, "today", "picking Today")
eq(range.menu:IsShown(), false, "menu closes")
eq(range.text:GetText(), "Today", "dropdown shows the choice")
scope.rows[2].scripts.OnClick(scope.rows[2])
eq(ns.settings.scope, "account", "all characters")
eq(scope.text:GetText(), "All characters", "dropdown shows all characters")
scope.rows[1].scripts.OnClick(scope.rows[1]); range.rows[1].scripts.OnClick(range.rows[1])
-- achievements: categories are the right-hand tabs, so the bar that covered Sort is hidden
ns.ShowPage("achievements")
eq(ns.Page("achievements").seg:IsShown(), false, "category bar hidden in the card")
eq(rawget(win, "sectionBar"):IsShown(), true, "categories shown as tabs")
-- menu
ns.ShowPage("combat")
local selCount = 0
for _, b in ipairs(win.navButtons) do if b.sel:IsShown() then selCount = selCount + 1; eq(b.id, "combat", "the open page is selected") end end
eq(selCount, 1, "one selected entry")
-- the overview
ns.ShowPage("dashboard")
local p = ns.Page("dashboard")
eq(p.heroName:GetText(), "Malikor", "hero name")
eq(p.tiles[1].value:GetText(), ns.FormatInt(ns.Kills(ch)), "kills tile")
eq(p.tiles[1].sub:GetText(), "Lifetime", "range under the counters")
eq(p.milestones.rows[1].title:GetText(), "Killed Hogger for the first time.", "milestones listed")
eq(p.highlights.rows[1].title:GetText():find("Biggest hit", 1, true) ~= nil, true, "highlights listed")
eq(p.activity.rows[1].title:GetText(), "Obtained Swift Windsteed", "activity listed")
eq(p.pageText:GetText(), "1 / " .. math.max(1, math.ceil(#ns.OverviewActivity(ch, 200) / p.per)), "pager")
-- every page renders in this skin
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
return checks
'''))

# ---------------------------------------------------------------- Stats Explorer
lua = load()
print("explorer:", lua.execute(COMMON + r'''
ns.settings.theme = "explorer"
ns.ToggleWindow()
eq(ns.themeId, "explorer", "applied")
eq(ns.Explorer() and ns.Framed(), true, "explorer is framed")
local win = LifeTimeStatsWindow
eq(rawget(win, "framed").title:GetText(), "Stats Explorer", "plaque title")
-- segmented time range
local seg = win.rangeSeg
eq(#seg.buttons, 5, "five ranges")
eq(seg.buttons[2].text:GetText(), "Daily", "daily")
seg.buttons[3].scripts.OnClick(seg.buttons[3])
eq(ns.settings.range, "week", "weekly picked")
seg.buttons[5].scripts.OnClick(seg.buttons[5])
eq(ns.settings.range, "lifetime", "lifetime picked")
eq(rawget(win.navButtons[1].text, "noInk"), true, "menu text stays light on the wood")
eq(win.todayBox:IsShown(), false, "no Today box: pinned stats sit at the bottom")
-- overview
ns.ShowPage("dashboard")
local p = ns.Page("dashboard")
eq(p.score:GetText(), ns.FormatInt((ns.Score(ns.char))), "lifetime score")
eq(p.motto:GetText():sub(1, 1), '"', "the motto is quoted")
eq(#p.cards, 4, "four cards")
eq(p.cards[1].title:GetText(), "Combat", "combat card")
eq(p.cards[4].title:GetText(), "Collections", "collections card")
eq(p.cards[3].stats[1].v:GetText():find("^Level") ~= nil, true, "progression shows the level")
p.cards[2].scripts.OnClick(p.cards[2])
eq(ns.activePage, "travel", "the exploration card opens Travel")
ns.ShowPage("dashboard")
local shown = 0
for _, b in ipairs(p.pins) do if b:IsShown() then shown = shown + 1 end end
eq(shown > 0, true, "pinned statistics shown")
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
return checks
'''))

# ---------------------------------------------------------------- framed skins fill the screen too
lua = load()
lua.execute("UIParent.wdt = 1920; UIParent.h = 1080")
print("fill:", lua.execute(COMMON + r'''
ns.settings.window.size = "fill"; ns.settings.window.scale = 1
ns.ToggleWindow()
local w, h = ns.WindowSize()
eq(w > 1140 and w + 30 + 164 <= 1920, true, "fill width leaves room for the frame and tabs")
eq(h + 60 <= 1080, true, "fill height leaves room for the plaque")
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
return checks
'''))
print("FRAMED PASS")

"""Offline tests for the statistic detail card: history numbers, record history, every character,
and the card opening from a stat page row."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
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
local ch = ns.char

local function day(offset) return date("%Y%m%d", time() - offset * 86400) end
local function find(cat, key)
    for _, st in ipairs(ns.STATS[cat]) do if (st.key or st.rec) == key then return st end end
end

-- ------------------------------------------------------------ a counter's history
ch.days[day(0)] = { jumps = 5 }
ch.days[day(1)] = { jumps = 12 }
ch.days[day(3)] = { jumps = 2 }
ch.days[day(10)] = { jumps = 40 }
ch.days[day(35)] = { jumps = 99 } -- on file, older than the chart
ch.c.jumps = 500
ns.session.c.jumps = 5
local st = find("travel", "jumps")
local h = ns.StatHistory(st, ch)
eq(h.kind, "counter", "a counter")
eq(h.value, 500, "lifetime value")
eq(h.session, 5, "session value")
eq(h.today, 5, "today")
eq(h.last7, 19, "last 7 days")
eq(h.last30, 59, "last 30 days")
eq(h.daysActive, 4, "days with any in the chart")
eq(#h.series, 30, "30 days charted")
eq(h.best.v, 40, "best charted day")
eq(h.bestEver.v, 99, "best day on file, beyond the chart")
eq(h.bestEver.d, day(35), "best day's date")
eq(h.daysOnFile, 5, "days on file with any")
eq(h.home, "Travel › Getting around", "where the statistic lives")

-- ------------------------------------------------------------ every character
ns.db.chars["Hex-Forever"] = { c = { jumps = 800 }, r = {}, t = {}, un = {}, days = {}, meta = { name = "Hex", class = "WARLOCK" } }
ns.db.chars["Abraca-Forever"] = { c = { jumps = 10 }, r = {}, t = {}, un = {}, days = {}, meta = { name = "Abraca", class = "MAGE" } }
h = ns.StatHistory(st, ch)
eq(#h.chars, 3, "three characters")
eq(h.chars[1].name, "Hex", "most jumps first")
local mine
for _, c in ipairs(h.chars) do if c.me then mine = c end end
eq(mine and mine.v, 500, "this character marked")

-- ------------------------------------------------------------ a record's history
ch.r.max_hit = 300; ch.r.max_hit_what = "Wrath"
ch.rh = {
    { k = "max_hit", v = 120, at = time() - 86400 * 5, d = "max", w = "Moonfire" },
    { k = "max_crit", v = 90, at = time() - 86400 * 4, d = "max" },
    { k = "max_hit", v = 300, at = time() - 3600, d = "max", w = "Wrath" },
}
ns.db.chars["Hex-Forever"].r.max_hit = 450
local rs = find("records", "max_hit")
local rh = ns.StatHistory(rs, ch)
eq(rh.kind, "record", "a record")
eq(rh.value, 300, "best")
eq(rh.what, "Wrath", "set with")
eq(#rh.history, 2, "only this record's entries")
eq(rh.history[1].v, 300, "newest first")
eq(rh.series, nil, "records have no daily chart")
eq(rh.chars[1].v, 450, "best on the account")

-- ------------------------------------------------------------ the card
ns.ToggleWindow()
ns.ShowPage("travel")
local p = ns.Page("travel")
local row
for i, d in ipairs(p.table.data) do if d.def == st then row = i end end
eq(row ~= nil, true, "the row carries its statistic")
p.table:Reveal(row)
local btn
for _, r in ipairs(p.table.rows) do if r.data and r.data.def == st then btn = r end end
btn.scripts.OnClick(btn)
local layer
for _, f in ipairs(frames) do if rawget(f, "stat") == st then layer = f end end
eq(layer ~= nil and layer:IsShown(), true, "clicking a row opens the card")
eq(layer.title:GetText(), "Times jumped", "card title")
eq(layer.facts[1].val:GetText(), "500", "lifetime fact")
eq(layer.facts[3].val:GetText(), "5", "today fact")
eq(layer.chartHost:IsShown(), true, "counter chart shown")
eq(layer.charTable:IsShown(), true, "character list shown")
eq(#layer.charTable.data, 3, "one row per character")
eq(layer.charTable.data[1][1], "Hex", "characters sorted")

ns.ShowStatDetail(rs)
eq(layer.chartHost:IsShown(), false, "no chart for a record")
eq(layer.recTable:IsShown(), true, "record history shown")
eq(#layer.recTable.data, 2, "every time it was beaten")
eq(layer.facts[3].val:GetText(), "2", "times beaten")

-- headings are not clickable
local headRow = p.table.rows[1]
p.table:ScrollTo(1)
eq(headRow.data.header, true, "first row is a heading")

-- a computed statistic opens without a chart and without errors
for _, s in ipairs(ns.STATS.combat) do if s.get then ns.ShowStatDetail(s); break end end
eq(layer.chartHost:IsShown(), false, "computed stats have no daily chart")

-- changing page closes the card
ns.ShowPage("combat")
eq(layer:IsShown(), false, "a page change closes the card")

-- ------------------------------------------------------------ pace forecasts
eq(ns.NextMilestone(0), 10, "first milestone")
eq(ns.NextMilestone(10), 25, "after 10 comes 25")
eq(ns.NextMilestone(500), 1000, "after 500 comes 1,000")
eq(ns.NextMilestone(999), 1000, "999 heads for 1,000")
eq(ns.NextMilestone(2600), 5000, "2,600 heads for 5,000")
eq(ns.NextMilestone(3000, "time"), 3600, "times count in hours: 50 minutes heads for 1 hour"); eq(ns.NextMilestone(4000, "time"), 9000, "then 2.5 hours")
eq(ns.NextMilestone(15000, "money"), 2.5 * 10000, "money counts in gold")
local pace = ns.StatPace(st, ns.StatHistory(st, ch))
eq(math.floor(pace.rate * 100 + 0.5), math.floor(59 / 30 * 100 + 0.5), "pace over 30 days")
eq(pace.target, 1000, "heading for 1,000 jumps")
eq(pace.days, math.ceil(500 / (59 / 30)), "days to go")
ns.ShowStatDetail(st)
eq(layer.pace:GetText():find("1,000", 1, true) ~= nil or layer.pace:GetText():find("1000", 1, true) ~= nil, true, "pace line names the next milestone")
eq(layer.pace:IsShown(), true, "pace line shown for counters")
local idle = find("travel", "flights")
ch.c.flights = 3
ns.ShowStatDetail(idle)
eq(layer.pace:GetText(), "Not done in the last 30 days.", "no pace without recent activity")
ns.ShowStatDetail(rs)
eq(layer.pace:IsShown(), false, "no pace line for records")

-- ------------------------------------------------------------ tiles open their statistic
eq(ns.FindStat("counter:jumps"), st, "find by tile id")
eq(ns.FindStat("Steps taken") ~= nil, true, "find by label")
eq(ns.FindStat("nonsense"), nil, "unknown ids find nothing")
ns.ShowPage("dashboard")
local dash = ns.Page("dashboard")
layer:Hide()
-- the overview of the default skin (Lifetime Stats): its counters open their statistic
local killTile
for _, t in ipairs(dash.tiles) do if rawget(t, "stat") and t.stat.label == "Enemies killed" then killTile = t end end
eq(killTile ~= nil, true, "the kills tile knows its statistic")
killTile.scripts.OnClick(killTile)
eq(layer:IsShown() and layer.stat == killTile.stat, true, "clicking a tile opens its card")
layer:Hide()

-- the page tiles of the other skins open theirs too (left-click only)
ns.ShowPage("combat")
local combat = ns.Page("combat")
local hitTile
for _, t in ipairs(combat.kpis) do if rawget(t, "stat") then hitTile = t end end
eq(hitTile ~= nil, true, "a page tile knows its statistic")
hitTile.scripts.OnMouseUp(hitTile, "LeftButton")
eq(layer:IsShown() and layer.stat == hitTile.stat, true, "clicking a page tile opens its card")
layer:Hide()
hitTile.scripts.OnMouseUp(hitTile, "RightButton")
eq(layer:IsShown(), false, "right-click does not open it")

-- every statistic on every page opens without an error
for _, list in pairs(ns.STATS) do for _, s in ipairs(list) do ns.ShowStatDetail(s) end end
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("STATDETAIL PASS: " .. checks .. " assertions")
''')

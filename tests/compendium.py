"""Offline checks for monthly trends, the compendium CSV export, the addon compartment and globals."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute("ns = {}; globalsBefore = {}; for k in pairs(_G) do globalsBefore[k] = true end")
toc = (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8")
for name in toc.splitlines():
    name = name.strip()
    if name.endswith(".lua"):
        chunk = lua.eval("function(src, name) return assert(loadstring(src, name)) end")(
            (ROOT / name).read_text(encoding="utf-8"), name
        )
        chunk("LifeTimeStats", lua.globals().ns)

compartment = [l.split(":", 1)[1].strip() for l in toc.splitlines() if l.startswith("## AddonCompartmentFunc")]
assert len(compartment) == 3, compartment
lua.globals().compartmentNames = lua.table_from(compartment)

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

-- ------------------------------------------------------------ month records
local thisMonth = os.date("%Y%m")
ch.months["202001"] = { jumps = 5, deaths = 1 }
ch.days[thisMonth .. "01"] = { jumps = 2, dist_foot = 100 }
local rec = ns.MonthRecord(ch, "202001")
eq(rec.jumps, 5, "folded month")
local cur = ns.MonthRecord(ch, thisMonth)
eq(cur.jumps >= 2, true, "current month includes kept days")
local list = ns.MonthRecords(ch, 12)
eq(#list, 12, "twelve months")
eq(list[12].m, thisMonth, "ends at this month")
local y, m = tonumber(thisMonth:sub(1, 4)), tonumber(thisMonth:sub(5, 6))
local first = list[1].m
local fy, fm = tonumber(first:sub(1, 4)), tonumber(first:sub(5, 6))
eq((y - fy) * 12 + (m - fm), 11, "starts eleven months back")

-- ------------------------------------------------------------ timeline months view
ns.OpenPage("timeline")
local tl = ns.Page("timeline")
eq(tl ~= nil, true, "timeline page")
tl.period = "months"
for _, metric in ipairs({ "steps", "kills", "deaths", "xp", "gold", "time", "dmg", "dpslvl" }) do
    tl.metric = metric
    ns.RefreshWindow()
end
eq(tl.tableTitle.text, ns.CardTitle("Month by month"), "month table title")
eq(#tl.dayT.data >= 1, true, "month rows")
eq(tl.dayT.data[1][1]:find("so far", 1, true) ~= nil, true, "current month first")
tl.period = "days"; tl.metric = "steps"; ns.RefreshWindow()
eq(tl.tableTitle.text, ns.CardTitle("Day by day"), "back to days")

-- ------------------------------------------------------------ compendium CSV
ch.c.jumps = 42
ns.db.chars["Forever-Alt"] = { meta = { rev = 1, name = "Altie", created = 1 }, c = { jumps = 8 }, r = {}, t = {}, u = {}, un = {},
    f = {}, fw = {}, fd = {}, first = {}, firstd = {}, days = {}, months = {}, runlog = {}, bestiary = {} }
ns.InvalidateAccount()
local csv = ns.CompendiumCSV()
local lines = {}
for line in csv:gmatch("[^\n]+") do lines[#lines + 1] = line end
eq(lines[1], "section,statistic,unit,Forever-Alt,Forever-Malikor,account", "header lists every character and the account")
local jumpRow
for _, l in ipairs(lines) do if l:find(",Times jumped,", 1, true) then jumpRow = l end end
eq(jumpRow ~= nil, true, "jumps row present")
eq(jumpRow:match(",(%d+),(%d+),(%d+)$") ~= nil, true, "three numeric columns")
local a, b, total = jumpRow:match(",(%d+),(%d+),(%d+)$")
eq(tonumber(a), 8, "alt column")
eq(tonumber(total), tonumber(a) + tonumber(b), "account is the sum")
eq(#lines > ns.CountStats() - #ns.LISTS, true, "a row for (nearly) every catalog entry")
local commas
for _, l in ipairs(lines) do
    local n = select(2, l:gsub('"[^"]*"', ""):gsub(",", ","))
    commas = commas or n
    eq(n, commas, "same column count on every row: " .. l)
end
SlashCmdList.LIFETIMESTATS("export")

-- ------------------------------------------------------------ addon compartment
for _, name in ipairs(compartmentNames) do eq(type(_G[name]), "function", "compartment function " .. name) end
local shown
local realToggle = ns.ToggleWindow
ns.ToggleWindow = function() shown = "window" end
local realOptions = ns.OpenOptions
ns.OpenOptions = function() shown = "options" end
LifeTimeStats_OnAddonCompartmentClick("LifeTimeStats", "LeftButton"); eq(shown, "window", "left click opens the window")
LifeTimeStats_OnAddonCompartmentClick("LifeTimeStats", "RightButton"); eq(shown, "options", "right click opens settings")
ns.ToggleWindow, ns.OpenOptions = realToggle, realOptions
LifeTimeStats_OnAddonCompartmentEnter("LifeTimeStats", UIParent)
LifeTimeStats_OnAddonCompartmentLeave("LifeTimeStats", UIParent)

-- ------------------------------------------------------------ globals: only the documented ones
for _, cat in ipairs(ns.CATEGORIES) do ns.ShowPage(cat.id) end
local allowed = { SLASH_LIFETIMESTATS1 = true, SLASH_LIFETIMESTATS2 = true, ns = true,
    LifeTimeStatsDB = true, LifeTimeStatsCharDB = true, compartmentNames = true,
    -- Named frames, so Escape closes them (UISpecialFrames needs global names).
    LifeTimeStatsWindow = true, LifeTimeStatsBackupDialog = true }
for _, name in ipairs(compartmentNames) do allowed[name] = true end
local extra = {}
for k in pairs(_G) do
    if not globalsBefore[k] and not allowed[k] then extra[#extra + 1] = tostring(k) end
end
table.sort(extra)
eq(table.concat(extra, ", "), "", "no undeclared globals")

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("COMPENDIUM PASS: " .. checks .. " assertions")
''')

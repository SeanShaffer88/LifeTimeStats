"""Offline tests for the minimap button (round/square placement, LibDBIcon) and the 1.18.2 record-spam repair."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
TOC = (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8")


def runtime(prelude=""):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
    lua.execute("ns = {}\n" + prelude)
    for name in TOC.splitlines():
        name = name.strip()
        if name.endswith(".lua"):
            chunk = lua.eval("function(src, name) return assert(loadstring(src, name)) end")(
                (ROOT / name).read_text(encoding="utf-8"), name
            )
            chunk("LifeTimeStats", lua.globals().ns)
    lua.execute(r'''
checks = 0
function eq(got, expected, msg)
    checks = checks + 1
    if got ~= expected then error(msg .. ": got " .. tostring(got) .. ", expected " .. tostring(expected), 2) end
end
function near(got, expected, msg) eq(math.abs((got or 0) - expected) < 0.01, true, msg .. " (" .. tostring(got) .. ")") end
function fire(event, ...) local f = ns.frame; f.scripts.OnEvent(f, event, ...) end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
NOW = NOW + 11; RunTimers()
''')
    return lua


# ---------------------------------------------------------------- own button, placement maths, repair
lua = runtime()
lua.execute(r'''
-- round minimap: on the circle; square minimap: on the edge, never inside the map
local x, y = ns.MinimapButtonOffset(225, 140, 140, "ROUND")
near(math.sqrt(x * x + y * y), 75, "round: on the circle (radius 75)")
x, y = ns.MinimapButtonOffset(225, 140, 140, "SQUARE")
eq(x <= -65 and y <= -65, true, "square: bottom-left corner sits on the corner edge (" .. x .. ")")
x, y = ns.MinimapButtonOffset(180, 140, 140, "SQUARE")
near(x, -75, "square: left side on the edge")
near(y, 0, "square: left side centred")
x, y = ns.MinimapButtonOffset(225, 140, 140, "CORNER-BOTTOMLEFT")
near(math.sqrt(x * x + y * y), 75, "rounded corner quadrant stays on the circle")
x, y = ns.MinimapButtonOffset(45, 140, 140, "CORNER-BOTTOMLEFT")
eq(x > 65 and y > 65, true, "square quadrant of a corner shape goes to the edge")

local btn = ns.MinimapButton()
eq(btn ~= nil, true, "own minimap button created")
GetMinimapShape = function() return "SQUARE" end
ns.ResetMinimapButton()
eq(ns.settings.minimap.angle, 215, "reset angle")
eq(btn.shown, true, "reset shows the button")
SlashCmdList.LIFETIMESTATS("minimap")
eq(ns.settings.minimap.hide, true, "/lts minimap hides")
SlashCmdList.LIFETIMESTATS("minimap reset")
eq(ns.settings.minimap.hide, false, "/lts minimap reset shows")
GetMinimapShape = nil
SlashCmdList.LIFETIMESTATS("minimap square")
eq(ns.settings.minimap.square, true, "/lts minimap square without a shape addon")
SlashCmdList.LIFETIMESTATS("minimap round")
eq(ns.settings.minimap.square, false, "/lts minimap round")

-- 1.18.2 repair: runs of the same growing interval record collapse to their last entry
local ch = ns.char
ch.meta.repairs.recordSpam = nil
ch.journal = {
    { 1000, "New personal record: Longest observed interval: stationary — 10s in Durotar", 7, kind = "personalBest" },
    { 1010, "New personal record: Longest observed interval: stationary — 20s in Durotar", 7, kind = "personalBest" },
    { 1020, "New personal record: Longest observed interval: stationary — 30s in Durotar", 7, kind = "personalBest" },
    { 1030, "Boss killed: Hogger", 7, kind = "boss" },
    { 5000, "New personal record: Longest observed interval: stationary — 40s in Durotar", 7, kind = "personalBest" },
}
ch.rh = {
    { k = "ex_longest_stationary", v = 10, at = 1000, d = "max" },
    { k = "ex_longest_stationary", v = 20, at = 1010, d = "max" },
    { k = "ex_longest_stationary", v = 30, at = 1020, d = "max" },
    { k = "max_hit", v = 99, at = 1025, d = "max" },
}
ns.RepairRecordSpam()
eq(#ch.journal, 3, "journal: one entry per run kept, other entries untouched")
eq(ch.journal[1][2]:find("30s", 1, true) ~= nil, true, "journal keeps the last of the run")
eq(ch.journal[2][2], "Boss killed: Hogger", "boss entry kept")
eq(#ch.rh, 2, "record history: run collapsed")
eq(ch.rh[1].v, 30, "record history keeps the best of the run")
local n = #ch.journal
ns.RepairRecordSpam()
eq(#ch.journal, n, "repair runs once")

-- a long stationary stretch writes one Journal moment, when it ends
ns.settings.recordMoments = true
ns.loggedIn = true
local j0 = #ch.journal
NOW = NOW + 100
for _ = 1, 400 do ns.TrackExpandedSample(0.25, 0, 0) end
local spam = 0
for i = j0 + 1, #ch.journal do if ch.journal[i][2]:find("stationary", 1, true) then spam = spam + 1 end end
eq(spam, 0, "no Journal entries while still standing")
ns.TrackExpandedSample(0.25, 2, 7)
local moments = 0
for i = j0 + 1, #ch.journal do if ch.journal[i][2]:find("stationary", 1, true) then moments = moments + 1 end end
eq(moments <= 1, true, "at most one Journal entry when the stretch ends")
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("MINIMAP PASS (own button): " .. checks .. " assertions")
''')

# ---------------------------------------------------------------- LibDBIcon present: register there instead
lua2 = runtime(r'''
registered, shownState = nil, nil
local ldb = { NewDataObject = function(_, name, obj) obj.name = name; return obj end }
local dbi = {
    Register = function(_, name, obj, db) registered = { name = name, obj = obj, db = db } end,
    Show = function() shownState = true end,
    Hide = function() shownState = false end,
}
LibStub = function(lib) if lib == "LibDataBroker-1.1" then return ldb end if lib == "LibDBIcon-1.0" then return dbi end end
''')
lua2.execute(r'''
eq(registered ~= nil, true, "registered with LibDBIcon")
eq(registered.name, "LifeTimeStats", "broker name")
eq(registered.obj.type, "launcher", "launcher object")
eq(type(registered.db), "table", "position saved in settings")
eq(ns.MinimapButton(), nil, "no own button when LibDBIcon handles it")
local opened
local realToggle = ns.ToggleWindow
ns.ToggleWindow = function() opened = true end
registered.obj.OnClick(nil, "LeftButton")
eq(opened, true, "broker click opens the window")
ns.ToggleWindow = realToggle
local lines = {}
registered.obj.OnTooltipShow({ AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, a) lines[#lines + 1] = a end })
eq(lines[1], "LifeTimeStats", "broker tooltip")
SlashCmdList.LIFETIMESTATS("minimap")
eq(shownState, false, "/lts minimap hides the LibDBIcon button")
SlashCmdList.LIFETIMESTATS("minimap reset")
eq(shownState, true, "reset shows it again")
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("MINIMAP PASS (LibDBIcon): " .. checks .. " assertions")
''')

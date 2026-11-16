"""Offline tests for interface habits (Habits.lua): every hook counts once and is catalogued."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
local function stub() end
C_Map = C_Map or {}; C_Map.SetUserWaypoint = stub; C_Map.ClearUserWaypoint = stub
C_FriendList = C_FriendList or {}; C_FriendList.SendWho = stub; C_FriendList.DelIgnore = stub
C_Container = C_Container or {}; C_Container.SortBags = stub
C_MerchantFrame = { SellAllJunkItems = stub }
C_Minimap = { SetTracking = stub }
for _, n in ipairs({ "CreateMacro", "ToggleRun", "CameraZoomIn", "CameraZoomOut", "Minimap_ZoomIn", "Minimap_ZoomOut",
    "ToggleMinimap", "ToggleGameMenu", "ToggleCalendar", "ToggleCollectionsJournal", "ToggleAchievementFrame",
    "ToggleGuildFrame", "ToggleChannelFrame" }) do _G[n] = stub end
-- ToggleHelpFrame is left out on purpose: a missing function must be skipped
''')
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
local c = ns.char.c

for _, h in ipairs(ns.HABITS) do
    local fn = hooks[h[2]]
    if h[2] == "ToggleHelpFrame" then
        eq(fn, nil, "missing function is not hooked")
    else
        eq(type(fn), "function", "hooked " .. h[2])
        local before = c[h[3]] or 0
        fn(); fn()
        eq(c[h[3]], before + 2, h[4] .. " counts each call")
    end
end
ns.InstallHabits() -- a second install must not double-hook
hooks.SortBags()
eq(c.bags_sorted, 3, "installing twice does not double count")

local found = {}
for _, row in ipairs(ns.STATS.social) do found[row.key or row.label] = row end
for _, h in ipairs(ns.HABITS) do eq(found[h[3]] ~= nil, true, "catalog row " .. h[3]) end
eq(found["Camera zoom steps"].get(ns.char), 4, "zoom steps add in and out")
eq(found["Camera zoom steps"].get({}), 0, "zoom steps with no counters")

local ach = {}
for _, d in ipairs(ns.ACHIEVEMENTS) do ach[d.id] = d end
eq(ach.fidget.value(ns.char), 4, "Restless Wheel")
eq(ach.tidy.value(ns.char), 3, "A Place for Everything")
eq(ach.lost.value(ns.char), 2, "Are We There Yet?")

ns.ToggleWindow(); ns.ShowPage("social")
print("HABITS PASS: " .. checks .. " assertions")
''')

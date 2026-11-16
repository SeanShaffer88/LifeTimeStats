"""Offline tests for the Fill screen window size: sizing maths, every page laid out at the larger
size without errors, more table rows, the setting, the slash command and the Options control."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent


def run(screen_w, screen_h, body):
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
    lua.execute("ns = {}; UIParent.wdt = %d; UIParent.h = %d" % (screen_w, screen_h))
    for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
        name = name.strip()
        if name.endswith(".lua"):
            chunk = lua.eval("function(src, name) return assert(loadstring(src, name)) end")(
                (ROOT / name).read_text(encoding="utf-8"), name
            )
            chunk("LifeTimeStats", lua.globals().ns)
    return lua.execute(r'''
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
''' + body + r'''
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
return checks
''')


# ---------------------------------------------------------------- sizing maths and Normal
normal = run(1920, 1080, r'''
local w, h = ns.WindowSizeFor("normal", 1920, 1080, 1, true)
eq(w, 1140, "normal width"); eq(h, 740, "normal height")
w, h = ns.WindowSizeFor("fill", 1920, 1080, 1, true)
eq(w > 1140 and w + 46 + 164 <= 1920, true, "fill width uses the screen and leaves room for the tabs")
eq(h > 740 and h + 60 <= 1080, true, "fill height leaves room for the parchment overhang")
local w2 = ns.WindowSizeFor("fill", 1920, 1080, 1.25, true)
eq(w2 < w, true, "a larger scale means a smaller window in its own units")
local w3, h3 = ns.WindowSizeFor("fill", 1024, 768, 1, true)
eq(w3, 1140, "never smaller than normal"); eq(h3, 740, "never shorter than normal")
local w4 = ns.WindowSizeFor("fill", 1920, 1080, 1, false)
eq(w4 > w, true, "the dark skins have no parchment overhang")

ns.ToggleWindow()
local nw, nh = ns.WindowSize()
eq(nw, 1140, "the default window is normal")
ns.ShowPage("combat")
normalRows = ns.Page("combat").table.visible
''')
print("normal ok:", normal)

# ---------------------------------------------------------------- Fill screen at 1920 x 1080 and 2560 x 1440
for sw, sh in ((1920, 1080), (2560, 1440)):
    checks = run(sw, sh, r'''
ns.settings.window.size = "fill"
ns.settings.window.scale = 1
ns.ToggleWindow()
local w, h = ns.WindowSize()
eq(w > 1140 and h > 740, true, "fill screen enlarges the window")
-- every page builds and renders at the larger size
for _, cdef in ipairs(ns.CATEGORIES) do ns.ShowPage(cdef.id) end
ns.ShowPage("search")
local t = ns.Page("combat").table
eq(t.visible > 22, true, "stat tables show more rows than at Normal (22)")
ns.ShowPage("combat")
eq(rawget(LifeTimeStatsWindow, "sectionBar"):IsShown(), true, "section tabs still shown")
local ach = ns.Page("achievements")
eq(#ach.tiles > 14, true, "more achievement tiles on screen")
''')
    print("fill %dx%d ok:" % (sw, sh), checks)

# ---------------------------------------------------------------- the setting, slash command and Options
checks = run(1920, 1080, r'''
ns.ToggleWindow()
lastPopup = nil
eq(ns.SetWindowSize("fill"), true, "switching to fill")
eq(ns.settings.window.size, "fill", "setting saved")
eq(lastPopup and lastPopup.name, "LIFETIMESTATS_RELOAD_SIZE", "asks to reload")
eq(ns.settings.window.scale, 1, "fill starts at 100% scale")
eq(ns.settings.window.x < 0, true, "nudged left so the tabs fit")
eq(ns.SetWindowSize("fill"), false, "already filling")
SlashCmdList.LIFETIMESTATS("size normal")
eq(ns.settings.window.size, "normal", "/lts size normal")
SlashCmdList.LIFETIMESTATS("fill")
eq(ns.settings.window.size, "fill", "/lts fill")
ns.ResetWindow()
eq(ns.settings.window.scale, 1, "reset keeps 100% in fill mode")
-- the Options panel builds with the new Window size row
ns.optionsPanel:Show()
''')
print("setting ok:", checks)
print("FILLSCREEN PASS")

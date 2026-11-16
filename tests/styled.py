"""Offline tests for the Stone & Gold (Altoholic style) and Adventure Journal (Dungeon Journal style) skins."""

from pathlib import Path

from lupa import lua51
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent

for name in ("rock", "leather", "sedge_h", "sedge_v", "jedge_h", "jedge_v", "rivet", "ring", "hbar"):
    path = ROOT / "Media" / "styled" / (name + ".tga")
    assert path.exists(), path
    im = Image.open(path)
    w, h = im.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (name, im.size)
    assert im.mode == "RGBA", (name, im.mode)
print("textures ok")


def run(theme, body):
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
    return lua.execute(r'''
local checks = 0
local function eq(got, expected, msg)
    checks = checks + 1
    if got ~= expected then error(msg .. ": got " .. tostring(got) .. ", expected " .. tostring(expected), 2) end
end
local function fire(event, ...) local f = ns.frame; f.scripts.OnEvent(f, event, ...) end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
ns.settings.theme = "''' + theme + r'''"
ns.ToggleWindow()
local win = LifeTimeStatsWindow
local st = rawget(win, "styled")
eq(ns.themeId, "''' + theme + r'''", "theme applied")
eq(ns.Styled(), true, "a styled skin")
eq(ns.Paper(), false, "dark, not paper")
eq(st ~= nil, true, "frame built")
eq(#st.corners, 4, "four corner plates")
eq(win.scopeSeg.text:GetText(), "Malikor", "character dropdown")
win.rangeSeg.rows[4].scripts.OnClick(win.rangeSeg.rows[4])
eq(ns.settings.range, "week", "range dropdown picks")
win.rangeSeg.rows[1].scripts.OnClick(win.rangeSeg.rows[1])
''' + body + r'''
for _, c in ipairs(ns.CATEGORIES) do ns.ShowPage(c.id) end
eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
return checks
''')


print("stone:", run("stone", r'''
eq(st.title:GetText():find("LifeTimeStats", 1, true) ~= nil, true, "title line")
eq(st.portrait ~= nil and st.ring ~= nil, true, "portrait in a gold ring")
eq(#st.headers, #ns.NOTEBOOK_TABS, "a gold header per chapter")
eq(#st.tabs, #ns.NOTEBOOK_TABS, "chapter tabs along the bottom")
eq(win.todayBox:IsShown(), false, "the chapter list fills the column")
-- a chapter tab opens its chapter; the selected page gets the gold bar
st.tabs[2].scripts.OnClick(st.tabs[2])
eq(ns.activePage, ns.NOTEBOOK_TABS[2].pages[1], "chapter tab opens its first page")
local b
for _, n in ipairs(win.navButtons) do if n.id == ns.activePage then b = n end end
eq(b.hbar:IsShown(), true, "selected page highlighted")
st.headers[4].scripts.OnClick(st.headers[4])
eq(ns.activePage, ns.NOTEBOOK_TABS[4].pages[1], "chapter header opens its first page")
ns.ShowPage("combat")
st.tabs[1].scripts.OnClick(st.tabs[1])
ns.ShowPage("deaths")
st.tabs[2].scripts.OnClick(st.tabs[2])
eq(ns.activePage, "deaths", "a chapter tab reopens the page last read in it")
'''))

print("djournal:", run("djournal", r'''
eq(st.title:GetText(), "LifeTimeStats Journal", "journal title")
eq(st.tabs, nil, "no bottom tabs")
eq(ns.JournalSkin(), true, "journal-style cards")
local b = win.navButtons[1]
eq(rawget(b, "jfill") ~= nil, true, "gold-edged buttons")
'''))
print("STYLED PASS")

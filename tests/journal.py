"""Offline regression tests for the Forever Journal skin and its entry feed."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
BackdropTemplateMixin = {}
local makeFrame = CreateFrame
function CreateFrame(kind, name, parent, template)
    local frame = makeFrame(kind, name, parent, template)
    frame.testParent, frame.testTemplate = parent, template
    function frame:SetEnabled(enabled) self.testEnabled = enabled end
    function frame:SetBackdrop(backdrop)
        if rejectGoldRim and backdrop.edgeFile:find("Gold%-Border") then
            self.testRejected = true
            error("optional edge rejected")
        end
        self.testBackdrop = backdrop
    end
    return frame
end
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
    assert(got == expected, msg .. ": got " .. tostring(got) .. ", expected " .. tostring(expected))
end
local function fire(event, ...)
    local f = ns.frame
    f:GetScript("OnEvent")(f, event, ...)
end
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD", true, false)
eq(ns.settings.theme, "auto", "new installs use Auto")
eq(ns.DetectUI(), "notebook", "Auto uses the Adventurer's Notebook without a UI replacement")
local loaded = { Tukui = true, ElvUI = true, EllesmereUI = true }
C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] end }
eq(ns.DetectUI(), "ellesmere", "Auto keeps EllesmereUI precedence")
loaded.EllesmereUI = false
eq(ns.DetectUI(), "elvui", "Auto keeps ElvUI precedence")
loaded.ElvUI = false
eq(ns.DetectUI(), "tukui", "Auto still detects Tukui")
for _, id in ipairs({ "odometer", "blizzard", "forever" }) do
    ns.settings.theme = id
    ns.ApplyTheme()
    eq(ns.themeId, id, "explicit theme overrides Auto")
end
ns.settings.classColor = false
ns.ApplyTheme()
local ledger = ns.W.Odometer(UIParent, 0, 0, 200, 72, "Count", "scroll")
ledger:SetValue(10032)
eq(rawget(ledger, "cells"), nil, "Forever counters use ledger numbers")
eq(ns.W.FONT, STANDARD_TEXT_FONT, "Forever uses the client's localized game font")
local nativeTitle = ns.W.Card(UIParent, "Life per level", "scroll", 0, 0, 200, 100).title
eq(nativeTitle:GetText(), "Life per level", "Forever keeps ledger heading case")
ns.settings.theme = "odometer"
ns.ApplyTheme()
local old = ns.W.Odometer(UIParent, 0, 0, 200, 72, "Count", "scroll")
old:SetValue(10032)
eq(#old.cells, 8, "Odometer keeps eight digit cells")
eq(old.cells[8].d:GetText(), "2", "Odometer digit still updates")
eq(ns.W.Card(UIParent, "Life per level", "scroll", 0, 0, 200, 100).title:GetText(),
    "LIFE PER LEVEL", "older skins keep their own heading treatment")
eq(nativeTitle:GetText(), "Life per level", "changing skins does not rewrite built widget headings")
eq(ns.THEME.bg[1], ns.THEME_BY_ID.odometer.bg[1], "legacy theme replaces the Forever palette")
ns.settings.theme = "forever"
ns.ApplyTheme()
rejectGoldRim = true
local plainWindow = ns.W.Window(UIParent)
eq(plainWindow.testBackdrop.edgeFile, ns.W.WHITE, "retains base panel when native rim is rejected")
eq(frames[#frames].testRejected, true, "attempts native rim before falling back")
rejectGoldRim = false
local savedCreateColor = CreateColor
CreateColor = function(...) return {...} end
local texture = {
    SetColorTexture = function(self, r, g, b) self.color = { r, g, b } end,
    SetGradient = function(self) self.rejected = true; error("optional gradient rejected") end,
}
ns.W.Shade(texture, ns.W.JOURNAL.base, ns.W.JOURNAL.top)
eq(texture.rejected, true, "attempts native gradient before falling back")
eq(texture.color[1], ns.W.JOURNAL.base[1], "uses solid journal colour when gradient is rejected")
CreateColor = savedCreateColor
ns.settings.theme = "forever"
loaded.Tukui = false
ns.char.journal = {}
ns.ToggleWindow()
ns.ShowPage("journal")
eq(ns.themeId, "forever", "the window applies the chosen skin on creation")
eq(ns.settings.window.scale * 1140 <= UIParent:GetWidth(), true, "initial scale checks screen width")

local feed, nativeClose, nativeRim
for _, f in ipairs(frames) do
    if rawget(f, "SetEntries") then feed = f end
    if rawget(f, "testTemplate") == "UIPanelCloseButtonNoScripts" then nativeClose = f end
    local backdrop = rawget(f, "testBackdrop")
    if backdrop and backdrop.edgeFile == [[Interface\DialogFrame\UI-DialogBox-Gold-Border]] then
        nativeRim = f
    end
end
eq(nativeClose ~= nil, true, "uses native close control where available")
eq(nativeRim ~= nil, true, "uses native rim where available")
eq(feed ~= nil, true, "journal feed built")
local newer, older
for _, f in ipairs(frames) do
    local text = rawget(f, "text")
    if rawget(f, "testParent") == feed and type(text) == "table" then
        if text:GetText() == "Newer" then newer = f end
        if text:GetText() == "Older" then older = f end
    end
end
local function click(b) b:GetScript("OnClick")(b) end
eq(newer.testEnabled, false, "empty feed disables Newer")
eq(older.testEnabled, false, "empty feed disables Older")
eq(feed.rows[1]:IsShown(), false, "empty feed has no entry rows")

local stamp = time({ year = 2026, month = 11, day = 14, hour = 12 })
for i = 1, 600 do
    local when = stamp - math.floor((600 - i) / 5) * 86400
    ns.char.journal[i] = { when, "Entry " .. i, 20 }
end
local frameCount = #frames
ns.RefreshWindow()
eq(#feed.rows, 10, "journal uses a bounded pool")
eq(feed.rows[1].prose:GetText(), "Entry 600", "newest entry first")
eq(feed.rows[1].day:GetText(), date("%A, %B %d, %Y", stamp), "starts the newest date group")
eq(feed.rows[2].day:IsShown(), false, "does not repeat date for the same day")
eq(feed.rows[6].day:IsShown(), true, "shows the preceding date group")
eq(older.testEnabled, true, "can turn to older entries")
for page = 1, 60 do
    local first = 601 - (page - 1) * 10
    for i, row in ipairs(feed.rows) do
        eq(row.prose:GetText(), "Entry " .. (first - i), "ordered entry remains reachable")
    end
    if page < 60 then click(older) end
end
eq(older.testEnabled, false, "oldest page disables Older")
eq(newer.testEnabled, true, "oldest page can return toward newer")
eq(#frames, frameCount, "paging reuses frames")
click(newer)
local anchor = feed.rows[1].entry
table.remove(ns.char.journal, 1)
table.insert(ns.char.journal, { stamp + 1, "New arrival", 21 })
ns.RefreshWindow()
eq(feed.rows[1].entry, anchor, "refresh preserves the older page's first entry even at retention cap")
-- A click opens the personal-note editor showing the full original entry.
local widget = getmetatable(frames[1])
local baseIndex, shownTexts = widget.__index, {}
widget.__index = function(t, k)
    if k == "SetText" then
        return function(self, v) self.text = v; shownTexts[#shownTexts + 1] = v end
    end
    return baseIndex(t, k)
end
local beforeClick = #frames
local ok, err = pcall(click, feed.rows[1])
widget.__index = baseIndex
assert(ok, err)
local opened = false
for i = beforeClick + 1, #frames do
    if frames[i]:IsShown() then opened = true end
end
eq(opened, true, "click opens the journal note editor")
local found = false
for _, v in ipairs(shownTexts) do if v == anchor[2] then found = true end end
eq(found, true, "note editor shows the full original entry")
eq(#ns.errors, 0, "no handler or rendering errors")
print("JOURNAL PASS: " .. checks .. " assertions")
''')

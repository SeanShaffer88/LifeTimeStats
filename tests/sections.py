"""Offline tests for page sections, the right-hand section tabs, grouped Top Lists and search focus."""

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

-- ------------------------------------------------------------ every row has one home
local PAGES = { "travel", "combat", "deaths", "adventure", "wealth", "social", "life", "records" }
local where = {}
for _, cat in ipairs(PAGES) do
    local def = ns.STAT_SECTIONS[cat]
    eq(def ~= nil, true, cat .. " has sections")
    local known = {}
    for _, n in ipairs(def.order) do known[n] = true end
    eq(known[def.default], true, cat .. " default section is shown")
    for _, r in ipairs(def.rules) do eq(known[r[1]], true, cat .. " rule names a shown section: " .. r[1]) end
    local total, seen = 0, {}
    for _, group in ipairs(ns.SectionedStats(cat)) do
        eq(#group.stats > 0, true, cat .. " / " .. group.name .. " is not empty")
        total = total + #group.stats
        for _, st in ipairs(group.stats) do
            local k = st.key or st.rec
            if k and st.key then
                eq(seen[k], nil, cat .. ": " .. k .. " listed once on its page")
                seen[k] = true
                if where[k] and not (k:find("^gear") ) then
                    -- a counter may only appear on one stat page
                    eq(where[k], cat, k .. " appears on one page only")
                end
                where[k] = where[k] or cat
            end
        end
    end
    eq(total, #ns.STATS[cat], cat .. ": sections hold every row")
end
eq(ns.DUPLICATE_ROWS_REMOVED > 0, true, "duplicate rows removed")

-- spot checks of where rows land
local function sec(cat, key)
    for _, st in ipairs(ns.STATS[cat]) do if (st.key or st.rec) == key then return ns.StatSection(cat, st) end end
end
eq(sec("combat", "cc_stun"), "Crowd control", "stuns under crowd control")
eq(sec("combat", "overkill"), "Damage dealt", "overkill is damage dealt")
eq(sec("combat", "bg_won"), "PvP & duels", "battlegrounds under PvP")
eq(sec("combat", "heal_done"), "Healing", "healing")
eq(sec("social", "friends_opens"), "Interface", "opening the friends list is an interface habit")
eq(sec("social", "whispers_sent"), "Chat", "whispers are chat")
eq(sec("social", "map_pins"), "Interface", "map pins are an interface habit")
eq(sec("life", "respecs"), "Lore & learning", "respecs under learning")
eq(sec("life", "items_used"), "Food & potions", "items used under food and potions")
eq(sec("records", "max_health"), "Character", "highest health is a character record")
eq(sec("records", "max_hit"), "Combat", "biggest hit is a combat record")
eq(sec("records", "ex_longest_moving"), "Observed intervals", "intervals grouped")
eq(sec("wealth", "rolls_won"), "Loot", "loot rolls under loot")
eq(sec("adventure", "gather_herb"), "Professions", "herbalism under professions")

-- Top Lists: every list in exactly one group
local n = 0
for _, g in ipairs(ns.SectionedLists()) do n = n + #g.lists end
eq(n, #ns.LISTS, "every list grouped")

-- ------------------------------------------------------------ the window
ns.ToggleWindow()
local win = LifeTimeStatsWindow
local bar = rawget(win, "sectionBar")
eq(bar ~= nil, true, "section bar built")

ns.ShowPage("dashboard")
eq(bar:IsShown(), false, "no section tabs on the dashboard")

ns.ShowPage("combat")
local p = ns.Page("combat")
eq(bar:IsShown(), true, "section tabs on a stat page")
local groups = ns.SectionedStats("combat")
eq(#p.sections, #groups, "one tab per section")
local heads = 0
for _, d in ipairs(p.table.data) do if d.header then heads = heads + 1 end end
eq(heads, #groups, "a heading row per section")
eq(p.table.data[1].header, true, "the table starts with a heading")
eq(bar.tabs[1].text:GetText(), ns.Notebook() and ns.W.SmallCaps(groups[1].name) or groups[1].name, "first tab names the first section")
eq(bar.tabs[1].def.active, true, "first section active at the top")
eq(bar.tabs[#groups + 1]:IsShown(), false, "spare tabs hidden")

-- click the crowd control tab: the table scrolls there and that tab becomes active
local ccTab
for i, b in ipairs(bar.tabs) do local d = rawget(b, "def"); if d and d.name == "Crowd control" then ccTab = b end end
eq(ccTab ~= nil, true, "crowd control tab")
ccTab.scripts.OnClick(ccTab)
local first = p.table.data[p.table.offset + 1]
eq(first.header, true, "scrolled to a heading")
eq(first[1], "Crowd control", "scrolled to crowd control")
eq(ccTab.def.active, true, "clicked tab is active")
eq(bar.tabs[1].def.active, false, "first tab no longer active")

-- scrolling the table with the wheel moves the active tab
p.table.scripts.OnMouseWheel(p.table, 1000)
eq(bar.tabs[1].def.active, true, "back at the top: first tab active")

-- headings are not clickable and carry no tooltip data
eq(p.table.rows[1].data.header, true, "first visible row is a heading")

-- Records and Top Lists have tabs too
ns.ShowPage("records")
eq(bar:IsShown(), true, "records has section tabs")
eq(#ns.Page("records").sections, #ns.SectionedStats("records"), "records sections")
ns.ShowPage("lists")
eq(bar:IsShown(), true, "Top Lists has section tabs")
eq(#ns.Page("lists").sections, #ns.SectionedLists(), "a tab per list group")

-- Achievements: its categories as tabs; clicking one filters the page
ns.ShowPage("achievements")
eq(bar:IsShown(), true, "achievements has tabs")
local combatTab
for _, b in ipairs(bar.tabs) do local d = rawget(b, "def"); if d and d.name == "Combat" then combatTab = b end end
combatTab.scripts.OnClick(combatTab)
eq(ns.Page("achievements").cat, "Combat", "achievement tab filters the page")
eq(combatTab.def.active, true, "achievement tab active")

-- How it works: a tab per topic, all of them fit
ns.ShowPage("help")
eq(bar:IsShown(), true, "help has topic tabs")
eq(#ns.HELP <= #bar.tabs, true, "every help topic fits a tab")
local helpTabs = 0
for _, b in ipairs(bar.tabs) do if b:IsShown() then helpTabs = helpTabs + 1 end end
eq(helpTabs, #ns.HELP, "one tab per help topic")
eq(rawget(bar.tabs[1], "def").name, "Finding your way", "help opens with how to find your way")
bar.tabs[5].scripts.OnClick(bar.tabs[5])

-- ------------------------------------------------------------ search opens the page at the stat
ns.ShowPage("search")
local sp = ns.Page("search")
local target = "Stunned: times"
-- a search result row carries the page and the stat label; click it through the table
local row = { target, cat = "combat", stat = target }
local handler = sp.table.rows[1].scripts.OnClick
sp.table.rows[1].data = row
handler(sp.table.rows[1])
eq(ns.activePage, "combat", "search opened the stat page")
local cp = ns.Page("combat")
local shown = false
for i = cp.table.offset + 1, cp.table.offset + cp.table.visible do
    local d = cp.table.data[i]
    if d and d.stat == target then shown = true; eq(d.color ~= nil, true, "the found row is highlighted") end
end
eq(shown, true, "the found row is scrolled into view")
ns.ShowPage("deaths")
ns.ShowPage("combat")
eq(rawget(cp, "focus"), nil, "the highlight clears when the page is opened normally")

local bar = LifeTimeStatsWindow.sectionBar
local first = bar.tabs[1]
local originalText, writes = first.text.SetText, 0
first.text.SetText = function(self, value) writes = writes + 1; originalText(self, value) end
local originalTabs, tabUpdates = ns.UpdateSectionTabs, 0
ns.UpdateSectionTabs = function(...) tabUpdates = tabUpdates + 1; return originalTabs(...) end
ns.RefreshWindow()
eq(tabUpdates, 1, "page rebuild updates section tabs once")
eq(writes, 0, "unchanged section label is not redrawn")
cp.table:ScrollTo(cp.sections[#cp.sections].index)
eq(tabUpdates, 2, "direct scrolling still refreshes section tabs")
local active = 1
for i, section in ipairs(cp.sections) do if section.index <= cp.table.offset + 2 then active = i end end
eq(bar.tabs[active].def.active, true, "scroll updates active section after clamping")
first.text.SetText, ns.UpdateSectionTabs = originalText, originalTabs

print("SECTIONS PASS: " .. checks .. " assertions")
''')

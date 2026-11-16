"""Offline tests for the satchel: items used, quest items used and everything carried (Satchel.lua)."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
bags = {
    [0] = { [1] = { itemID = 6948, hyperlink = "|cffffffff|Hitem:6948|h[Hearthstone]|h|r" },
            [2] = { itemID = 4540, itemName = "Tough Hunk of Bread" },
            [3] = { itemID = 2589, hyperlink = "|cffffffff|Hitem:2589|h[Linen Cloth]|h|r" },
            [4] = { itemID = 25, hyperlink = "|cffffffff|Hitem:25|h[Worn Shortsword]|h|r" } },
    [1] = { [1] = { itemID = 4540, itemName = "Tough Hunk of Bread" } },
}
bagSize = { [0] = 16, [1] = 6 }
C_Container = {
    GetContainerNumSlots = function(b) return bagSize[b] or 0 end,
    GetContainerItemInfo = function(b, s) return bags[b] and bags[b][s] end,
    UseContainerItem = function() end,
}
C_Item = { IsEquippableItem = function(item) return item == 25 or item == "Worn Shortsword" end, UseItemByName = function() end }
function UseQuestLogSpecialItem() end
merchantShown = false
MerchantFrame = { IsShown = function() return merchantShown end }
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
NOW = NOW + 30; RunTimers()
local ch = ns.char
local c = ch.c

-- ------------------------------------------------------------ items used
local use = hooks.UseContainerItem
use(0, 2)                 -- bread
use(1, 1)                 -- more bread
use(0, 1)                 -- hearthstone (link only)
use(0, 4)                 -- a sword is equipped, not used
use(0, 9)                 -- an empty slot
merchantShown = true
use(0, 3)                 -- sold to the vendor, not used
merchantShown = false
eq(c.items_used, 3, "three items used")
eq(ch.t.itemsused["Tough Hunk of Bread"], 2, "bread twice")
eq(ch.t.itemsused.Hearthstone, 1, "name read from the link")
eq(ch.t.itemsused["Worn Shortsword"], nil, "gear is not an item use")
eq(ch.t.itemsused["Linen Cloth"], nil, "selling is not an item use")

hooks.UseItemByName("|cffffffff|Hitem:118|h[Minor Healing Potion]|h|r")
hooks.UseItemByName("Worn Shortsword")
eq(c.items_used, 4, "/use by name counts")
eq(ch.t.itemsused["Minor Healing Potion"], 1, "/use with a link")

hooks.UseQuestLogSpecialItem(3)
eq(c.quest_items_used, 1, "quest item used")

-- ------------------------------------------------------------ what you carry
ns.ScanSatchel(true)
eq(ch.r.bag_slots_max, 22, "bag space across bags")
eq(ch.r.bag_filled_max, 5, "slots filled")
eq(ch.un.itemsheld, 4, "different items carried, by item ID")
local history = #(ch.rh or {})
bagSize[1] = 10
NOW = NOW + 1; fire("BAG_UPDATE_DELAYED")
eq(ch.r.bag_slots_max, 22, "scans are throttled to one per 2 s")
NOW = NOW + 3; fire("BAG_UPDATE_DELAYED")
eq(ch.r.bag_slots_max, 26, "a bigger bag raises the record")
eq(#(ch.rh or {}), history, "bag records stay out of the Journal and history")

-- ------------------------------------------------------------ catalog and achievements
local found = {}
for _, rows in pairs(ns.STATS) do for _, row in ipairs(rows) do found[row.key or row.rec or ""] = true end end
for _, key in ipairs({ "items_used", "quest_items_used", "bag_slots_max", "bag_filled_max" }) do
    eq(found[key], true, "catalog row " .. key)
end
local uniq = false
for _, u in ipairs(ns.UNIQUES) do if u.set == "itemsheld" then uniq = true end end
eq(uniq, true, "unique set listed")
local ach = {}
for _, d in ipairs(ns.ACHIEVEMENTS) do ach[d.id] = d end
eq(ach.packrat.value(ch), 4, "Pack Rat reads items carried")
eq(ach.consumer.value(ch), 4, "Bottoms Up reads items used")

ns.ToggleWindow()
for _, id in ipairs({ "life", "records", "fastest", "lists" }) do ns.ShowPage(id) end
print("SATCHEL PASS: " .. checks .. " assertions")
''')

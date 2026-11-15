"""Offline tests for 1.19 collections: reputation history, currencies, item log, gathering,
mail and trades, goals, trends and the session summary."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute(r'''
ns = {}
factions = {
    { name = "Horde", isHeader = true },
    { name = "Orgrimmar", reaction = 5, currentStanding = 3500, currentReactionThreshold = 3000, nextReactionThreshold = 9000 },
    { name = "Darkspear Trolls", reaction = 4, currentStanding = 100, currentReactionThreshold = 0, nextReactionThreshold = 3000 },
}
C_Reputation = {
    GetNumFactions = function() return #factions end,
    GetFactionDataByIndex = function(i) return factions[i] end,
}
currencies = { { name = "Honor", isHeader = false, quantity = 120, maxQuantity = 0 }, { name = "PvP", isHeader = true }, { name = "Darkmoon Prize Ticket", quantity = 7 } }
C_CurrencyInfo = {
    GetCurrencyListSize = function() return #currencies end,
    GetCurrencyListInfo = function(i) return currencies[i] end,
}
C_Item = {
    GetDetailedItemLevelInfo = function(link) if link:find("Sword", 1, true) then return 21 end return 10 end,
    GetItemInfo = function() return nil end,
}
mailHooks = {}
function hooksecurefunc(a, b, c)
    if type(a) == "string" then mailHooks[a] = b else mailHooks[b] = c end
end
function SendMail() end
function GetSendMailMoney() return 2500 end
function TakeInboxMoney() end
function TakeInboxItem() end
function GetInboxHeaderInfo(i) return nil, nil, "Thrall", "Gift", i == 1 and 10000 or 0 end
tradeMoney = { player = 0, target = 0 }
function GetPlayerTradeMoney() return tradeMoney.player end
function GetTargetTradeMoney() return tradeMoney.target end
function GetTradePlayerItemLink(i) if i == 1 then return "|cffffffff|Hitem:1|h[Linen]|h|r" end end
function GetTradeTargetItemLink() return nil end
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
NOW = NOW + 11; RunTimers()
local ch = ns.char

-- ------------------------------------------------------------ reputation history
eq(ns.ScanFactions(), 2, "two factions read (header skipped)")
eq(ch.reps.Orgrimmar.s, 5, "Orgrimmar Friendly")
eq(ch.reps.Orgrimmar.c, 500, "progress in standing")
eq(ch.reps.Orgrimmar.m, 6000, "size of standing")
eq(ch.c.factions_met, 2, "factions met")
factions[2].reaction = 6; factions[2].currentStanding = 9100; factions[2].currentReactionThreshold = 9000; factions[2].nextReactionThreshold = 21000
local j0 = #(ch.journal or {})
ns.ScanFactions()
eq(ch.reps.Orgrimmar.s, 6, "now Honored")
eq(type(ch.reps.Orgrimmar.h[6]), "number", "date Honored was reached")
eq(ch.c.rep_levels_gained, 1, "one standing gained")
eq(ch.c.rep_levels_6, 1, "Honored counted")
eq(ch.journal[#ch.journal][2], "Reached Honored with Orgrimmar", "journal line")
factions[3].reaction = 3
ns.ScanFactions()
eq(ch.c.rep_levels_lost, 1, "standing lost")

-- ------------------------------------------------------------ currencies
eq(ns.ScanCurrencies(), 2, "two currencies (header skipped)")
eq(ch.snap.cur[1].n, "Honor", "currency name")
eq(ch.snap.cur[1].q, 120, "currency amount")
eq(ch.r["max_cur_Honor"], 120, "highest amount kept as a record")

-- ------------------------------------------------------------ item log and sources
fire("CHAT_MSG_LOOT", "You receive loot: |cff1eff00|Hitem:100|h[Green Sword]|h|r.")
eq(#ch.items, 1, "green item logged")
eq(ch.items[1].n, "Green Sword", "item name")
eq(ch.items[1].q, 2, "item quality")
eq(ch.items[1].il, 21, "item level")
eq(ch.items[1].src, "loot", "plain loot source")
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2|h[Linen Cloth]|h|r.")
eq(#ch.items, 1, "white items are counted by source but not logged")
eq(ch.t.itemsources.Looted, 2, "items by source")
fire("QUEST_TURNED_IN", 1, 100, 0)
fire("CHAT_MSG_LOOT", "You receive item: |cff0070dd|Hitem:101|h[Blue Ring]|h|r.")
eq(ch.items[2].src, "quest", "quest reward source")
eq(ch.c.items_logged_q3, 1, "rare counted")
fire("MERCHANT_SHOW")
NOW = NOW + 10
fire("CHAT_MSG_LOOT", "You receive item: |cff1eff00|Hitem:102|h[Bought Boots]|h|r.")
eq(ch.items[3].src, "vendor", "bought from a vendor")
fire("MERCHANT_CLOSED")
ns.OnCreateItem("|cff1eff00|Hitem:103|h[Crafted Belt]|h|r", 1)
eq(ch.items[4].src, "crafted", "crafted item")
ns.OnBossKill("Taragaman the Hungerer", "party")
fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:104|h[Epic Axe]|h|r.")
eq(ch.items[5].src, "boss", "boss loot")
eq(ch.items[5].from, "Taragaman the Hungerer", "which boss")
eq(ch.journal[#ch.journal][2]:find("Epic Axe", 1, true) ~= nil, true, "first epic: one journal line")
local jn = #ch.journal
fire("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:105|h[Epic Helm]|h|r.")
eq(ch.journal[#ch.journal][2], "Epic item: Epic Helm (Boss)", "later epics get a source line")
eq(#ch.journal, jn + 1, "exactly one line for a later epic")

-- ------------------------------------------------------------ gathering
ns.lastGather = { "herbs", GetTime() }
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:765|h[Silverleaf]|hx2.")
eq(ch.c.gathered_items, 2, "gathered items")
eq(ch.t.gatheritems_zone.Durotar, 2, "gathered items by zone")
ns.lastGather = nil

-- ------------------------------------------------------------ mail and trades
eq(type(mailHooks.SendMail), "function", "SendMail hooked")
mailHooks.SendMail("Thrall", "hi", "")
fire("MAIL_SEND_SUCCESS")
eq(ch.t.mailto.Thrall, 1, "mail sent to")
eq(ch.t.mailgold_to.Thrall, 2500, "gold mailed to")
eq(ch.c.mail_gold_sent, 2500, "gold sent counter")
mailHooks.TakeInboxMoney(1)
eq(ch.t.mailgold_from.Thrall, 10000, "gold mailed from")
mailHooks.TakeInboxItem(2)
eq(ch.c.mail_items_taken, 1, "items taken from mail")
units.NPC = { name = "Jaina" }
fire("TRADE_SHOW")
tradeMoney.player, tradeMoney.target = 300, 1200
fire("TRADE_ACCEPT_UPDATE")
fire("CHAT_MSG_SYSTEM", "Trade complete.")
eq(ch.c.trades, 1, "trade counted")
eq(ch.t.tradewith.Jaina, 1, "traded with")
eq(ch.t.tradegold_to.Jaina, 300, "gold given")
eq(ch.t.tradegold_from.Jaina, 1200, "gold received")
eq(ch.c.trade_items_given, 1, "items given")

-- ------------------------------------------------------------ goals
local g, info = ns.AddGoal("times jumped", 5)
eq(g ~= nil, true, "goal added: " .. tostring(info))
eq(info.stat.label, "Times jumped", "goal statistic found by words")
eq(select(1, ns.AddGoal("no such statistic anywhere", 5)), nil, "unknown statistic refused")
eq(select(1, ns.AddGoal("jumped", 0)), nil, "zero target refused")
ch.c.jumps = 10
eq(ns.CheckGoals(), 1, "goal reached")
eq(ch.c.goals_reached, 1, "goals reached counter")
eq(ns.CheckGoals(), 0, "reached only once")
SlashCmdList.LIFETIMESTATS("goal steps 1,000,000")
eq(#ch.goals, 2, "goal added by slash command")
eq(ch.goals[2].target, 1000000, "commas in the target")
SlashCmdList.LIFETIMESTATS("goal list")
SlashCmdList.LIFETIMESTATS("goal remove 1")
eq(#ch.goals, 1, "goal removed")

-- ------------------------------------------------------------ trends
ch.days[os.date("%Y%m%d")] = { jumps = 4, dist_foot = 100 }
ch.days[os.date("%Y%m%d", os.time() - 8 * 86400)] = { jumps = 2 }
local tr = ns.Trends(ch)
local jumps
for _, t in ipairs(tr) do if t.label == "Jumps" then jumps = t end end
eq(jumps.w0 >= 4, true, "this week")
eq(jumps.w1, 2, "last week")

-- ------------------------------------------------------------ session summary
local text = ns.SessionSummaryText({ time_online = 3600, jumps = 5, money_in = 10000, kills_npc = 12 }, 3600, "Test")
eq(text:find("Jumps", 1, true) ~= nil, true, "summary lists jumps")
eq(text:find("Gold per hour", 1, true) ~= nil, true, "summary has rates")
SlashCmdList.LIFETIMESTATS("summary")

-- ------------------------------------------------------------ Characters page sections
ns.OpenPage("roster")
local p = ns.rosterPage
for _, s in ipairs(ns.ROSTER_SECTIONS) do
    eq(p.sectionButtons[s.id] ~= nil, true, "button for " .. s.id)
    p.sectionButtons[s.id].scripts.OnClick(p.sectionButtons[s.id])
    eq(p.state.section, s.id, "button selects " .. s.id)
    eq(p.listView.shown, true, s.id .. " shows the list view")
    if s.id ~= "people" and s.id ~= "farming" then eq(#p.list.data > 0, true, s.id .. " has rows") end
end
local function Has(rows, text)
    for _, r in ipairs(rows) do if type(r[2]) == "string" and r[2]:find(text, 1, true) then return true end end
    return false
end
eq(Has(ns.RosterRows({ section = "reputation" }), "Orgrimmar"), true, "reputation rows")
eq(Has(ns.RosterRows({ section = "currencies" }), "Honor"), true, "currency rows")
eq(Has(ns.RosterRows({ section = "items" }), "Epic Axe"), true, "item rows")
eq(Has(ns.RosterRows({ section = "gathering" }), "Durotar"), true, "gathering rows")
eq(Has(ns.RosterRows({ section = "mail" }), "Thrall"), true, "mail rows")
eq(Has(ns.RosterRows({ section = "goals" }), "Steps"), true, "goal rows")
eq(Has(ns.RosterRows({ section = "trends" }), "Jumps"), true, "trend rows")

-- ------------------------------------------------------------ full backup keeps the collections
local backup = assert(ns.SerializeFullBackup())
local snap = assert(ns.DeserializeFullBackup(backup))
eq(snap.record.reps.Orgrimmar.s, 6, "reputation in backup")
eq(type(snap.record.reps.Orgrimmar.h[6]), "number", "standing dates in backup")
eq(#snap.record.items, 6, "item log in backup")
eq(snap.record.goals[1].target, 1000000, "goals in backup")
ch.reps, ch.items, ch.goals = {}, {}, {}
eq(ns.RestoreFullBackup(snap), true, "restore")
eq(ns.char.reps.Orgrimmar.s, 6, "reputation restored")
eq(#ns.char.items, 6, "items restored")

eq(#ns.errors, 0, "no handler errors: " .. table.concat(ns.errors, " | "))
print("COLLECTIONS PASS: " .. checks .. " assertions")
''')

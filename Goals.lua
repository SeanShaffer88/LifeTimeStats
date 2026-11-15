-- LifeTimeStats - goals (a target for any statistic), trends (this week vs last week, this
-- month vs last month) and the session summary window.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, On = ns.Add, ns.On

local GOAL_CAP = 20
ns.GOAL_CAP = GOAL_CAP

-- ------------------------------------------------------------ goals
-- rec.goals = { { id = catalog id, target, t = created, done = time reached } ... }
local function Catalog()
    if not ns.DashboardPinCatalog then return {}, {} end
    return ns.DashboardPinCatalog()
end

function ns.GoalValue(goal, view)
    local _, byID = Catalog()
    local entry = byID[goal.id]
    if not entry then return nil end
    local ok, v = pcall(ns.StatValue, entry.stat, view or ns.char)
    if ok and type(v) == "number" then return v, entry end
    return nil, entry
end

-- Find a statistic by words in its label: exact label first, then the shortest label containing it.
function ns.FindGoalStat(text)
    text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local catalog = Catalog()
    local best
    for _, e in ipairs(catalog) do
        local label = (e.stat.label or ""):lower()
        if label == text then return e end
        if label:find(text, 1, true) and (not best or #label < #best.stat.label) then best = e end
    end
    return best
end

function ns.AddGoal(text, target)
    local ch = ns.char
    if not ch then return nil, "No character loaded." end
    target = tonumber(target)
    if not target or target <= 0 then return nil, "Give a target number, e.g. /lts goal steps 1000000" end
    local e = ns.FindGoalStat(text)
    if not e then return nil, "No statistic matches \"" .. tostring(text) .. "\"." end
    ch.goals = ch.goals or {}
    if #ch.goals >= GOAL_CAP then return nil, "You already have " .. GOAL_CAP .. " goals; remove one first." end
    local g = { id = e.id, target = target, t = time() }
    ch.goals[#ch.goals + 1] = g
    local v = ns.GoalValue(g)
    if v and v >= target then g.done = time() end
    return g, e
end

-- The first open (or else reached) goal set on a catalog statistic, for the Dashboard pins.
function ns.GoalFor(id)
    local found
    for _, g in ipairs((ns.char and ns.char.goals) or {}) do
        if g.id == id then
            if not g.done then return g end
            found = found or g
        end
    end
    return found
end

function ns.RemoveGoal(index)
    local goals = ns.char and ns.char.goals
    index = tonumber(index)
    if not goals or not index or not goals[index] then return false end
    table.remove(goals, index)
    return true
end

function ns.CheckGoals()
    local goals = ns.char and ns.char.goals
    if not goals then return 0 end
    local reached = 0
    for _, g in ipairs(goals) do
        if not g.done then
            local v, entry = ns.GoalValue(g)
            if v and v >= g.target then
                g.done = time()
                reached = reached + 1
                Add("goals_reached")
                local label = entry and entry.stat.label or g.id
                local text = "Goal reached: " .. label .. " " .. ns.FormatInt(g.target)
                if ns.Journal then ns.Journal(text, "personalBest") end
                if ns.Print then ns.Print(ns.GREEN .. text .. "|r") end
            end
        end
    end
    return reached
end
On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(15, function() pcall(ns.CheckGoals) end) end
end)

function ns.GoalCommand(args)
    args = args or ""
    local sub, rest = args:match("^(%S*)%s*(.-)$")
    if sub == "remove" or sub == "delete" then
        if ns.RemoveGoal(rest) then ns.Print("Goal " .. rest .. " removed.") else ns.Print("No goal number " .. tostring(rest) .. ".") end
        return
    end
    if args == "" or sub == "list" then
        local goals = ns.char and ns.char.goals or {}
        if #goals == 0 then ns.Print("No goals yet. /lts goal <statistic words> <target>, e.g. /lts goal steps 1000000") return end
        for i, g in ipairs(goals) do
            local v, entry = ns.GoalValue(g)
            ns.Print(i .. ". " .. (entry and entry.stat.label or g.id) .. ": " .. ns.FormatInt(v or 0) .. " / " .. ns.FormatInt(g.target) .. (g.done and " (reached)" or ""))
        end
        return
    end
    local text, target = args:match("^(.-)%s+([%d,%.]+)$")
    if target then target = target:gsub(",", "") end
    local g, info = ns.AddGoal(text, target)
    if not g then ns.Print(info) return end
    ns.Print("Goal set: " .. info.stat.label .. " " .. ns.FormatInt(g.target) .. ". It shows under Characters > Goals.")
end

-- ------------------------------------------------------------ trends
-- Sum of a counter over n days ending `back` days ago (0 = today).
local function DaysSum(view, key, n, back)
    local total, now = 0, time()
    for i = back, back + n - 1 do
        local day = view.days and view.days[date("%Y%m%d", now - i * 86400)]
        if day then
            if type(key) == "function" then total = total + (key(day) or 0)
            elseif type(day[key]) == "number" then total = total + day[key] end
        end
    end
    return total
end

local function MonthKey(offset)
    local y, m = tonumber(date("%Y")), tonumber(date("%m")) - offset
    while m < 1 do m = m + 12; y = y - 1 end
    return string.format("%04d%02d", y, m)
end

ns.TREND_METRICS = {
    { "Steps", function(d) return (d.dist_foot or 0) * (ns.YARDS_TO_STEPS or 1) end, "int" },
    { "Kills", function(d) return (d.kills_npc or 0) + (d.kills_pvp or 0) end, "int" },
    { "Deaths", "deaths", "int" },
    { "Quests completed", "quests_done", "int" },
    { "XP gained", "xp", "int" },
    { "Gold earned", "money_in", "money" },
    { "Gold spent", "money_out", "money" },
    { "Items looted", "items_looted", "int" },
    { "Time online", "time_online", "time" },
    { "Time in combat", "time_combat", "time" },
    { "Damage done", "dmg_done", "int" },
    { "Jumps", "jumps", "int" },
    { "Boss kills", "boss_kills", "int" },
    { "Herbs, ore and skins gathered", function(d) return (d.gather_herb or 0) + (d.gather_mine or 0) + (d.gather_skin or 0) end, "int" },
    { "Fish caught", "fish", "int" },
}

-- { label, thisWeek, lastWeek, thisMonth, lastMonth, fmt } for each metric.
function ns.Trends(view)
    view = view or ns.char
    local out = {}
    local thisM, lastM = ns.MonthRecord and ns.MonthRecord(view, MonthKey(0)) or {}, ns.MonthRecord and ns.MonthRecord(view, MonthKey(1)) or {}
    for _, m in ipairs(ns.TREND_METRICS) do
        local key = m[2]
        local function Month(rec) if type(key) == "function" then return key(rec) or 0 end return rec[key] or 0 end
        out[#out + 1] = { label = m[1], w0 = DaysSum(view, key, 7, 0), w1 = DaysSum(view, key, 7, 7), m0 = Month(thisM), m1 = Month(lastM), fmt = m[3] }
    end
    return out
end

-- ------------------------------------------------------------ session summary
-- A window at login with the last session (when it lasted 10+ minutes), and /lts summary any time.
local SUMMARY = {
    { "Time played", "time_online", "time" }, { "Active (not AFK)", function(c) return (c.time_online or 0) - (c.time_afk or 0) end, "time" },
    { "Steps", function(c) return (c.dist_foot or 0) * (ns.YARDS_TO_STEPS or 1) end, "int" }, { "Jumps", "jumps", "int" },
    { "Enemies killed", function(c) return (c.kills_npc or 0) + (c.kills_pvp or 0) end, "int" }, { "Deaths", "deaths", "int" },
    { "Quests completed", "quests_done", "int" }, { "XP gained", "xp", "int" }, { "Levels gained", "levels", "int" },
    { "Gold earned", "money_in", "money" }, { "Gold spent", "money_out", "money" }, { "Items looted", "items_looted", "int" },
    { "Vendor value of loot", "loot_value", "money" }, { "Damage done", "dmg_done", "int" }, { "Boss kills", "boss_kills", "int" },
    { "Herbs, ore and skins gathered", function(c) return (c.gather_herb or 0) + (c.gather_mine or 0) + (c.gather_skin or 0) end, "int" },
    { "Fish caught", "fish", "int" }, { "Players grouped with", "people_met", "int" }, { "Goals reached", "goals_reached", "int" },
}
function ns.SessionSummaryText(c, elapsed, title, highlights)
    local F = ns.FMT or {}
    local lines = { title or "Session summary", "" }
    for _, row in ipairs(SUMMARY) do
        local v
        if type(row[2]) == "function" then v = row[2](c) else v = c[row[2]] end
        if type(v) == "number" and v > 0 then
            lines[#lines + 1] = string.format("%-30s %s", row[1], (F[row[3]] or ns.FormatInt)(v))
        end
    end
    if elapsed and elapsed > 0 then
        local h = elapsed / 3600
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("%-30s %s", "Gold per hour", (F.money or tostring)(math.floor((c.money_in or 0) / h)))
        lines[#lines + 1] = string.format("%-30s %s", "XP per hour", ns.FormatInt(math.floor((c.xp or 0) / h)))
        lines[#lines + 1] = string.format("%-30s %s", "Kills per hour", ns.FormatInt(math.floor(((c.kills_npc or 0) + (c.kills_pvp or 0)) / h)))
    end
    if type(highlights) == "table" and #highlights > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "New records: " .. table.concat(highlights, "; ")
    end
    if #lines == 2 then lines[#lines + 1] = "Nothing counted yet." end
    return table.concat(lines, "\n")
end

function ns.ShowSessionSummary(current)
    if not ns.ShowText then return end
    if current or not (type(LifeTimeStatsCharDB) == "table" and type(LifeTimeStatsCharDB.lastSession) == "table") then
        local s = ns.session
        ns.ShowText("This session", "Since you logged in. /lts summary shows it again.",
            ns.SessionSummaryText(s.c or {}, GetTime() - (s.start or GetTime()), "This session"))
        return
    end
    local last = LifeTimeStatsCharDB.lastSession
    ns.ShowText("Last session", "Shown at login after a session of 10+ minutes (Settings: session recap). /lts summary shows the current one.",
        ns.SessionSummaryText(last.c or {}, last.elapsed, "Last session", last.highlights))
end

On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if not isLogin or not ns.settings or ns.settings.recapWindow == false then return end
    local last = type(LifeTimeStatsCharDB) == "table" and LifeTimeStatsCharDB.lastSession
    if type(last) == "table" and type(last.c) == "table" and (last.elapsed or 0) >= 600 and C_Timer then
        C_Timer.After(4, function() pcall(ns.ShowSessionSummary, false) end)
    end
end)

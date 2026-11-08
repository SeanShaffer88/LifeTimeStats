-- LifeTimeStats - chronicle: extras inspired by AutoBiographer, Played Plus, TrackMe,
-- Ultra Statistics and Hardcore Stat Companion. XP by source, time grouped (and with
-- whom), gear changes, highest health / mana, level-up lines, screenshots, and your
-- kill count on creature tooltips.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Tally, Unique, On = ns.Add, ns.Max, ns.Tally, ns.Unique, ns.On
local S, B = ns.IsSecret, ns.Bool

-- ------------------------------------------------------------ XP by source
On("CHAT_MSG_COMBAT_XP_GAIN", function(_, msg)
    if S(msg) or type(msg) ~= "string" then return end
    local kill = msg:match("dies, you gain (%d+)") or msg:match("dies,.-(%d+) experience")
    if kill then Add("xp_kill", tonumber(kill)) end
    local grp = msg:match("%+(%d+) group bonus")
    if grp then Add("xp_group", tonumber(grp)) end
end)
On("CHAT_MSG_SYSTEM", function(_, msg)
    if S(msg) or type(msg) ~= "string" then return end
    local x = msg:match("^Discovered .-: (%d+) experience gained")
    if x then Add("xp_explore", tonumber(x)) end
end)

-- ------------------------------------------------------------ grouped time, and with whom
local acc, STEP = 0, 5
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", ns.Guard and ns.Guard("chronicle", function(_, el)
    acc = acc + el
    if acc < STEP then return end
    local dt = acc; acc = 0
    if not ns.char then return end
    local g = IsInGroup and IsInGroup()
    if S(g) or not g then return end
    Add("time_grouped", dt)
    local raid = IsInRaid and B(IsInRaid())
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    if S(n) then return end
    for i = 1, math.min(n, 40) do
        local u = raid and ("raid" .. i) or ("party" .. i)
        if B(UnitExists(u)) and not B(UnitIsUnit(u, "player")) then
            local name = UnitName(u)
            if name and not S(name) then Tally("groupedtime", name, dt) end
        end
    end
end) or nil)

-- ------------------------------------------------------------ gear
On("PLAYER_EQUIPMENT_CHANGED", function(_, slot, empty)
    if not ns.char or not ns.loggedIn then return end
    Add("gear_changes")
    if empty then return end
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
    if not link or S(link) then return end
    local id = tonumber(link:match("item:(%d+)"))
    if id and Unique("worn", id) then
        local name = link:match("%[(.-)%]")
        if name then Tally("wornitems", name) end
    end
end)
On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, function() ns.loggedIn = true end) end)

-- ------------------------------------------------------------ highest health / mana
local function Peaks()
    if not ns.char then return end
    local h = UnitHealthMax and UnitHealthMax("player")
    if h and not S(h) then Max("max_health", h, "Level " .. (UnitLevel("player") or 0)) end
    local p = UnitPowerMax and UnitPowerMax("player", 0)
    if p and not S(p) and p > 0 then Max("max_mana", p, "Level " .. (UnitLevel("player") or 0)) end
end
On("UNIT_MAXHEALTH", function(_, u) if u == "player" then Peaks() end end)
On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, Peaks) end)

-- ------------------------------------------------------------ level-up line + screenshots
local function Shot(delay) if Screenshot then C_Timer.After(delay or 1, function() pcall(Screenshot) end) end end
function ns.OnLevelUp(level, dur, online)
    Peaks()
    if ns.settings.shotLevel then Shot(1.2) end
    if ns.settings.levelMsg then
        local parts = { "Level " .. ns.GOLD .. level .. "|r!" }
        if dur then parts[#parts + 1] = "Level " .. (level - 1) .. " took " .. ns.FormatTime(dur) end
        parts[#parts + 1] = ns.FormatTime(online or 0) .. " online in total"
        local top = ns.TopList(ns.char, "spelldamage", 1)[1]
        if top then parts[#parts + 1] = "favourite spell " .. top[1] end
        ns.Print(table.concat(parts, " · "))
    end
end
function ns.OnBossKill(name, kind)
    if not ns.settings.shotBoss or kind == "world" then return end
    local t = ns.char.t.bosses
    if t and t[name] == 1 then Shot(1.5) end
end
function ns.OnAchievement() if ns.settings.shotAch then Shot(0.6) end end

-- ------------------------------------------------------------ kill counts on tooltips
local function AddKills(tt)
    if not ns.settings or not ns.settings.tooltipKills or not ns.char or not tt or not tt.GetUnit then return end
    local ok, name, unit = pcall(tt.GetUnit, tt)
    if not ok or not unit or S(name) or type(name) ~= "string" then return end
    if B(UnitIsPlayer(unit)) or not B(UnitCanAttack("player", unit)) then return end
    local t = ns.char.t
    local kills = t.creatures and t.creatures[name] or 0
    local fought = t.foughtenemies and t.foughtenemies[name] or 0
    local hurt = t.hurtby and t.hurtby[name] or 0
    if kills == 0 and fought == 0 and hurt == 0 then return end
    local a = ns.THEME.amber
    local line = "Killed " .. ns.FormatInt(kills)
    if fought > 0 then line = line .. " · fought " .. ns.FormatInt(fought) end
    if hurt > 0 then line = line .. " · hurt you for " .. ns.FormatInt(hurt) end
    tt:AddLine("LifeTimeStats: " .. line, a[1], a[2], a[3])
    tt:Show()
end
function ns.InstallTooltip()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(AddKills, tt) end)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tt) pcall(AddKills, tt) end)
    end
end

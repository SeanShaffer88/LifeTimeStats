-- LifeTimeStats - Adventurer's Life: drink, fire, camp, books, potions, hearthstones
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local B = ns.Bool
local Add, Max, Tally, Unique, First, On = ns.Add, ns.Max, ns.Tally, ns.Unique, ns.First, ns.On
local S = ns.IsSecret

local function Zone() local z = ns.GetZone and ns.GetZone() return (z and z ~= "") and z or "?" end
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellInfo then local i = C_Spell.GetSpellInfo(id) if type(i) == "table" then return i.name end end
    if GetSpellInfo then return (GetSpellInfo(id)) end
end

-- ------------------------------------------------------------ drink
-- "You feel tipsy/drunk/completely smashed." / "You feel sober again."
local DRUNK = {}
local function BuildDrunk()
    DRUNK[DRUNK_MESSAGE_SELF1 or "You feel sober again."] = 0
    DRUNK[DRUNK_MESSAGE_SELF2 or "You feel tipsy."] = 1
    DRUNK[DRUNK_MESSAGE_SELF3 or "You feel drunk."] = 2
    DRUNK[DRUNK_MESSAGE_SELF4 or "You feel completely smashed."] = 3
end
local DRUNK_KEY = { "drunk_tipsy", "drunk_drunk", "drunk_smashed" }

-- ------------------------------------------------------------ system lines
local newPath
On("CHAT_MSG_SYSTEM", function(_, msg)
    if S(msg) or type(msg) ~= "string" then return end
    local lvl = DRUNK[msg]
    if lvl then
        local m = ns.char.meta
        local was = m.drunk or 0
        if lvl == 0 then
            if was > 0 then Add("sobered_up") end
        else
            if was == 0 then Add("times_drunk"); First("drunk", Zone()); Tally("drunkzones", Zone()) end
            if lvl > was then Add(DRUNK_KEY[lvl]) end
            Max("max_drunk", lvl)
        end
        m.drunk = lvl
        return
    end
    if msg == (ERR_NEWTAXIPATH or "New flight path discovered!") then
        Add("flightpaths_found"); First("flightpath", Zone())
    end
end)

-- ------------------------------------------------------------ casts: campfires, potions, opening, hearths
local NAMES = {}
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" or not spellID or S(spellID) then return end
    if not NAMES.campfire then
        NAMES.campfire = SpellName(818) or "Basic Campfire"
        NAMES.opening = SpellName(3365) or "Opening"
        NAMES.cooking = SpellName(2550) or "Cooking"
    end
    local name = SpellName(spellID)
    if not name or S(name) then return end
    if name == NAMES.campfire then
        Add("campfires"); Tally("campfirezones", Zone()); First("campfire", Zone())
    elseif name == NAMES.opening or name:find("^Opening") then
        Add("objects_opened")
    elseif name:find("Potion") or name == "Restore Mana" or name == "Healing Potion" then
        Add("potions"); Tally("potions", name)
    elseif name:find("Elixir") or name:find("Flask") then
        Add("elixirs"); Tally("potions", name)
    elseif name:find("Hearthstone") and spellID ~= 8690 then
        Add("hearths") -- other hearthstone toys/items
        Tally("hearthsused", name)
    end
    if name:find("Hearthstone") then Tally("hearthsused", name); Tally("hearthzones", Zone()) end
end)

-- ------------------------------------------------------------ hearthstones owned
local function IsHearth(name) return type(name) == "string" and not S(name) and name:find("Hearthstone") ~= nil end
local function SeeHearth(id, name)
    if not IsHearth(name) then return end
    if Unique("hearthstones", tostring(id or name)) then First("hearthstone", name); Tally("hearthsowned", name) end
end
function ns.ScanHearthstones()
    local getInfo = (C_Container and C_Container.GetContainerItemInfo)
    local getNum = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if not getNum then return end
    for bag = 0, 4 do
        local ok, slots = pcall(getNum, bag)
        if ok and type(slots) == "number" and not S(slots) then
            for slot = 1, slots do
                local link
                if getInfo then
                    local ok2, info = pcall(getInfo, bag, slot)
                    if ok2 and type(info) == "table" then link = info.hyperlink end
                elseif GetContainerItemLink then
                    link = GetContainerItemLink(bag, slot)
                end
                if type(link) == "string" and not S(link) then
                    SeeHearth(link:match("|Hitem:(%d+)"), link:match("%[(.-)%]"))
                end
            end
        end
    end
    if C_ToyBox and C_ToyBox.GetNumToys and C_ToyBox.GetToyFromIndex and PlayerHasToy then
        local ok, n = pcall(C_ToyBox.GetNumToys)
        if ok and type(n) == "number" and not S(n) then
            for i = 1, n do
                local okI, id = pcall(C_ToyBox.GetToyFromIndex, i)
                if okI and type(id) == "number" and not S(id) and PlayerHasToy(id) then
                    local nm = GetItemInfo and GetItemInfo(id)
                    SeeHearth(id, nm)
                end
            end
        end
    end
end
On("CHAT_MSG_LOOT", function(_, msg)
    if S(msg) or type(msg) ~= "string" or not msg:find("Hearthstone") then return end
    local link = msg:match("(|c.-|r)") or msg
    SeeHearth(link:match("|Hitem:(%d+)"), link:match("%[(.-)%]"))
end)
On("BAG_UPDATE_DELAYED", function() if ns.char then ns.ScanHearthstones() end end)

-- ------------------------------------------------------------ hearth bind spots
local function CheckBind(changed)
    if not GetBindLocation then return end
    local loc = GetBindLocation()
    if not loc or S(loc) or loc == "" then return end
    local m = ns.char.meta
    if changed and m.bindLoc and m.bindLoc ~= loc then Add("hearth_moves"); Tally("bindspots", loc) end
    if Unique("bindspots", loc) then First("bindspot", loc) end
    if not changed and not m.bindLoc then Tally("bindspots", loc) end
    m.bindLoc = loc
end
On("HEARTHSTONE_BOUND", function() CheckBind(true) end)
On("CONFIRM_BINDER", function() C_Timer.After(2, function() CheckBind(true) end) end)

-- ------------------------------------------------------------ books, rested XP
On("ITEM_TEXT_BEGIN", function()
    Add("books_read")
    local t = ItemTextGetItem and ItemTextGetItem()
    if t and not S(t) then Unique("books", t); Tally("books", t); First("book", t) end
end)
On("CHAT_MSG_COMBAT_XP_GAIN", function(_, msg)
    if S(msg) or type(msg) ~= "string" then return end
    local r = msg:match("%(%+(%d+) [^)]*[Rr]ested")
    if r then Add("rested_xp", tonumber(r)) end
end)

-- ------------------------------------------------------------ camp vs inn, wild time, day/night
local wild = 0
local acc = 0
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", ns.Guard("life", function(_, el)
    acc = acc + el
    if acc < 1 then return end
    local dt = acc
    acc = 0
    if not ns.char or dt > 3 then return end
    if B(IsResting()) then
        wild = 0
    else
        wild = wild + dt
        Max("max_wild", wild, Zone())
        Add("time_wild", dt)
    end
    if GetGameTime then
        local h = GetGameTime()
        if type(h) == "number" and not S(h) then
            if h >= 21 or h < 6 then Add("time_night", dt) else Add("time_day", dt) end
        end
    end
end))
function ns.OnCampLogout()
    if not ns.char then return end
    if B(IsResting()) then Add("nights_inn") else Add("nights_camped"); Tally("campzones", Zone()) end
end
On("PLAYER_ENTERING_WORLD", function(_, isLogin)
    if isLogin then
        BuildDrunk()
        Unique("days_played", date("%Y%m%d"))
        C_Timer.After(3, function() if ns.char then ns.ScanHearthstones(); CheckBind(false) end end)
    end
end)
BuildDrunk()

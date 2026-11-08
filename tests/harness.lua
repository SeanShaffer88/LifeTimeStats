-- Minimal WoW API stubs for offline tests of LifeTimeStats (Lua 5.1).
local function noop() end
local Widget = {}
local function NewWidget()
    local w = { scripts = {}, shown = false, h = 400, wdt = 500 }
    return setmetatable(w, Widget)
end
Widget.__index = function(t, k)
    if k == "SetScript" then return function(self, s, f) self.scripts[s] = f end end
    if k == "HookScript" then return function(self, s, f) self.scripts[s] = f end end
    if k == "GetScript" then return function(self, s) return self.scripts[s] end end
    if k == "Show" then return function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
    if k == "Hide" then return function(self) self.shown = false end end
    if k == "SetShown" then return function(self, v) if v then self:Show() else self:Hide() end end end
    if k == "IsShown" then return function(self) return self.shown end end
    if k == "GetHeight" then return function(self) return self.h end end
    if k == "GetWidth" then return function(self) return self.wdt end end
    if k == "SetText" then return function(self, v) self.text = v end end
    if k == "GetText" then return function(self) return self.text end end
    if k == "GetPoint" then return function() return "CENTER", nil, "CENTER", 0, 0 end end
    if k == "GetChecked" then return function() return true end end
    if k == "GetStringWidth" then return function() return 40 end end
    if k == "GetLeft" then return function() return 0 end end
    if k == "GetCenter" then return function() return 0, 0 end end
    if k == "GetEffectiveScale" then return function() return 1 end end
    if k == "GetID" then return function() return 1 end end
    if k == "Text" or k == "Low" or k == "High" or k == "text" then return nil end
    if k:match("^Create") then return function() return NewWidget() end end
    if k:match("^Register") then return function(self, ev) local e = rawget(self, "evs") or {}; rawset(self, "evs", e); e[ev or 1] = true end end
    return noop
end

frames = {}
function CreateFrame() local f = NewWidget(); frames[#frames + 1] = f; return f end
UIParent, Minimap, GameTooltip, DEFAULT_CHAT_FRAME = NewWidget(), NewWidget(), NewWidget(), NewWidget()
printed = {}
DEFAULT_CHAT_FRAME.AddMessage = function(_, m) printed[#printed + 1] = m end
WorldMapFrame = NewWidget()
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
bit = { band = function(a, b)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
    end
    return r
end }
BreakUpLargeNumbers = function(n)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end
date = os.date; time = os.time

NOW = 1000
function GetTime() return NOW end
timers = {}
C_Timer = { After = function(d, f) timers[#timers + 1] = { t = NOW + d, f = f } end }
function RunTimers()
    local keep = {}
    for _, t in ipairs(timers) do if t.t <= NOW then t.f() else keep[#keep + 1] = t end end
    timers = keep
end

hooks = {}
function hooksecurefunc(a, b, c)
    local name, fn = a, b
    if type(a) ~= "string" then name, fn = b, c end
    local prev = hooks[name]
    hooks[name] = prev and function(...) prev(...); fn(...) end or fn
end

state = { money = 1000, xp = 0, xpmax = 1000, level = 10, speed = 0, falling = false, swimming = false,
          mounted = false, taxi = false, dead = false, combat = false, inInst = false, itype = "none", iname = "", mapid = 0 }
function UnitGUID(u) if u == "player" then return "Player-1-ME" end end
function UnitName() return "Malikor" end
function GetRealmName() return "Forever" end
function UnitClass() return "Druid", "DRUID" end
function UnitLevel() return state.level end
function UnitXP() return state.xp end
function UnitXPMax() return state.xpmax end
function GetMoney() return state.money end
function GetUnitSpeed() return state.speed end
function IsFalling() return state.falling end
function IsSwimming() return state.swimming end
function IsFlying() return false end
function IsMounted() return state.mounted end
function UnitOnTaxi() return state.taxi end
function UnitIsDeadOrGhost() return state.dead end
function UnitAffectingCombat() return state.combat end
function UnitIsAFK() return false end
function IsResting() return false end
function UnitExists() return false end
function UnitFactionGroup() return "Horde" end
function GetRealZoneText() return "Durotar" end
function IsInInstance() return state.inInst, state.itype end
function GetInstanceInfo() return state.iname, state.itype, 1, "", 5, 0, false, state.mapid end
function GetShapeshiftForm() return 0 end
function GetPVPLifetimeStats() return 42, 0, 0 end
function GetRepairAllCost() return state.repair or 0, true end
function GetSpellInfo(id)
    local n = { [8690] = "Hearthstone", [2366] = "Herb Gathering", [2575] = "Mining", [8613] = "Skinning",
                [433] = "Food", [430] = "Drink", [746] = "First Aid", [5176] = "Wrath" }
    return n[id]
end
function GetPlayerInfoByGUID() return "Mage", "MAGE" end
function RequestTimePlayed() end
function ChatFrame_DisplayTimePlayed() printed[#printed + 1] = "PLAYED" end

LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_PUSHED_SELF_MULTIPLE = "You receive item: %sx%d."
LOOT_ITEM_CREATED_SELF = "You create: %s."
LOOT_ITEM_CREATED_SELF_MULTIPLE = "You create: %sx%d."
DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel"
DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
ERR_TRADE_COMPLETE = "Trade complete."
INSTANCE_RESET_SUCCESS = "%s has been reset."
ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
ERR_ZONE_EXPLORED = "Discovered: %s"

CLEU = {}
function CombatLogGetCurrentEventInfo() return unpack(CLEU, 1, 21) end
for _, n in ipairs({"JumpOrAscendStart","DoEmote","SendChatMessage","RepopMe","DeleteCursorItem","TakeTaxiNode","AbandonQuest"}) do _G[n] = function() end end
function UnitHealthMax() return 1000 end
function GetSubZoneText() return "Razor Hill" end
function IsIndoors() return false end
C_Map = { GetBestMapForUnit = function() return 1411 end,
  GetMapInfo = function(id) if id == 1411 then return { name = "Durotar", mapType = 3, parentMapID = 1414 } elseif id == 1414 then return { name = "Kalimdor", mapType = 2, parentMapID = 947 } end end }
function IsInRaid() return false end
function GetNumGroupMembers() return state.group or 0 end
function UnitClassification() return "normal" end
function IsModifierKeyDown() return false end
function IsControlKeyDown() return false end
function InCombatLockdown() return false end
function GetCursorPosition() return 0, 0 end
function SetPortraitTexture() end
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UNKNOWNOBJECT = "Unknown"
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
FACTION_STANDING_INCREASED = "Your %s reputation has increased by %d."
FACTION_STANDING_DECREASED = "Your %s reputation has decreased by %d."
SKILL_RANK_UP = "Your skill in %s has increased to %d."
ERR_INV_FULL = "Inventory is full."
C_QuestLog = { GetTitleForQuestID = function(id) return "Lazy Peons" end }
for _, n in ipairs({"ToggleBackpack","OpenAllBags","ToggleBag","ToggleCharacter","SitStandOrDescendStart","StartDuel","AcceptResurrect","RetrieveCorpse","ConfirmBinder"}) do _G[n] = function() end end
function IsInGroup() return false end
function IsInGuild() return true end
LE_PARTY_CATEGORY_INSTANCE = 2
function StaticPopup_Show(name, a, b, data) lastPopup = { name = name, data = data } end
units = {}
function UnitExists(u) return units[u] ~= nil end
function UnitCanAttack(_, u) return units[u] and units[u].hostile or false end
function UnitIsTapDenied(u) return units[u] and units[u].tapdenied or false end
function UnitIsPlayer(u) return units[u] and units[u].player or false end
function UnitIsDead(u) return units[u] and units[u].dead or false end
local _UnitGUID, _UnitName, _UAC = UnitGUID, UnitName, UnitAffectingCombat
function UnitGUID(u) if units[u] then return units[u].guid end return _UnitGUID(u) end
function UnitName(u) if units[u] then return units[u].name end return _UnitName(u) end
function UnitAffectingCombat(u) if u ~= "player" and units[u] then return true end return state.combat end
function UnitHealth(u) return state.hp or 1000 end
function GetMirrorTimerProgress() return 1000 end
COMBATLOG_XPGAIN_FIRSTPERSON = "%s dies, you gain %d experience."
COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
function UnitCreatureType(u) if units[u] and units[u].critter then return "Critter", 8 end return "Beast", 1 end
bindLoc = "Razor Hill"
function GetBindLocation() return bindLoc end
function GetGameTime() return 22, 0 end
C_Container = { GetContainerNumSlots = function() return 2 end, GetContainerItemInfo = function(b, s) if b == 0 and s == 1 then return { hyperlink = "|cffffffff|Hitem:6948|h[Hearthstone]|h|r" } end end }
DRUNK_MESSAGE_SELF1 = "You feel sober again."; DRUNK_MESSAGE_SELF2 = "You feel tipsy."; DRUNK_MESSAGE_SELF3 = "You feel drunk."; DRUNK_MESSAGE_SELF4 = "You feel completely smashed."
function ItemTextGetItem() return "The Story of Thrall" end
function GetInventoryItemID(_, slot) if state.naked then return nil end return 1234 end
AuraUtil = { FindAuraByName = function(n) return state.auras and state.auras[n] end }
function GetSubZoneText() return state.subzone or "Razor Hill" end
C_GossipInfo = { GetOptions = function() return state.gossip or {} end }
function NumTaxiNodes() return 3 end
function TaxiNodeGetType(i) return i < 3 and "REACHABLE" or "NONE" end
function TaxiNodeName(i) return "Node" .. i end
function GetNumCompanions(t) return t == "MOUNT" and 2 or 1 end

-- LifeTimeStats - crowd control suffered, cinematics watched and talent respecs
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, On, Tally = ns.Add, ns.Max, ns.On, ns.Tally
local Bad = ns.BadNumber
local function S(v) return ns.IsSecret(v) end -- looked up each time, so the check is always current

local function Num(v) if type(v) == "number" and not S(v) and not Bad(v) then return v end end
local function Str(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end

-- ------------------------------------------------------------ crowd control suffered
-- C_LossOfControl reports each effect once, when it lands. Types are grouped the way a
-- player would name them.
local CC_KIND = {
    STUN = "stun", STUN_MECHANIC = "stun",
    FEAR = "fear", FEAR_MECHANIC = "fear",
    ROOT = "root",
    SILENCE = "silence",
    SCHOOL_INTERRUPT = "lockout",
    PACIFY = "pacify", PACIFYSILENCE = "pacify",
    CHARM = "charm", POSSESS = "charm",
    CONFUSE = "confuse",
    DISARM = "disarm",
}
ns.CC_KINDS = { "stun", "fear", "root", "silence", "lockout", "pacify", "charm", "confuse", "disarm", "other" }
local CC_LABEL = {
    stun = "Stunned", fear = "Feared", root = "Rooted", silence = "Silenced", lockout = "Spell school locked out",
    pacify = "Pacified", charm = "Charmed or mind-controlled", confuse = "Incapacitated (sap, polymorph...)",
    disarm = "Disarmed", other = "Other loss of control",
}

local function SpellName(id)
    id = Num(id)
    if not id then return end
    local get = C_Spell and C_Spell.GetSpellName
    if type(get) == "function" then
        local ok, name = pcall(get, id)
        if ok then return Str(name) end
    end
end

local function ReadControl(unit, index)
    local api = C_LossOfControl
    if type(api) ~= "table" then return end
    local ok, data
    if type(api.GetActiveLossOfControlDataByUnit) == "function" then
        ok, data = pcall(api.GetActiveLossOfControlDataByUnit, unit, index)
    end
    if (not ok or type(data) ~= "table") and unit == "player" and type(api.GetActiveLossOfControlData) == "function" then
        ok, data = pcall(api.GetActiveLossOfControlData, index)
    end
    -- While loss of control is restricted (Forever 1.60.1: SecretWhenLossOfControlRestricted) the
    -- whole entry is secret: it still counts once, with no type, spell or time read from it.
    if ok and data ~= nil and S(data) then return "secret" end
    if ok and type(data) == "table" then return data end
end

function ns.TrackLossOfControl(a, b)
    -- Newer clients pass (unit, index); older ones pass (index) for the player.
    local unit, index = "player", a
    if type(a) == "string" then unit, index = a, b end
    if unit ~= "player" or not Num(index) then return end
    local data = ReadControl(unit, index)
    if not data then return end
    if data == "secret" then
        Add("cc_taken"); Add("cc_other")
        ns.src.lossOfControl = true
        return
    end
    local kind = CC_KIND[Str(data.locType) or ""] or "other"
    local name = SpellName(data.spellID) or Str(data.displayText)
    Add("cc_taken")
    Add("cc_" .. kind)
    if name then Tally("cc_spells", name) end
    local dur = Num(data.duration)
    if dur and dur > 0 and dur < 600 then
        Add("cc_time", dur)
        Add("cc_time_" .. kind, dur)
        Max("cc_longest", dur, name)
        if name then Tally("cc_spell_time", name, dur) end
    end
    ns.src.lossOfControl = true
end
ns.TrackLossOfControl = ns.Guard and ns.Guard("loss of control", ns.TrackLossOfControl) or ns.TrackLossOfControl
On("LOSS_OF_CONTROL_ADDED", function(_, a, b) ns.TrackLossOfControl(a, b) end)

-- ------------------------------------------------------------ cinematics and movies
local scene = nil -- { kind = "cinematic" | "movie", at = GetTime(), skipped = bool }
local function SceneStart(kind)
    scene = { kind = kind, at = GetTime(), skipped = false }
    Add(kind == "movie" and "movies_seen" or "cinematics_seen")
end
local function SceneEnd(kind)
    if not scene or scene.kind ~= kind then return end
    local secs = GetTime() - scene.at
    if secs > 0 and secs < 3600 then
        Add("cinematic_time", secs)
        Max("cinematic_longest", secs)
    end
    if scene.skipped then Add("cinematics_skipped") else Add("cinematics_finished") end
    scene = nil
end
local function Skip() if scene then scene.skipped = true end end
On("CINEMATIC_START", function() SceneStart("cinematic") end)
On("CINEMATIC_STOP", function() SceneEnd("cinematic") end)
On("PLAY_MOVIE", function() SceneStart("movie") end)
On("STOP_MOVIE", function() SceneEnd("movie") end)

-- ------------------------------------------------------------ talent respecs and loadouts
local wipeCost = nil
On("CONFIRM_TALENT_WIPE", function(_, cost) wipeCost = Num(cost) end)
local function OnWipe()
    Add("respecs")
    if wipeCost and wipeCost > 0 then
        Add("respec_gold", wipeCost)
        Max("respec_cost_max", wipeCost)
    end
    wipeCost = nil
    if ns.Journal and ns.loggedIn then ns.Journal("Unlearned every talent at a trainer.") end
end
On("PLAYER_SPECIALIZATION_CHANGED", function(_, unit) if unit == nil or unit == "player" then Add("spec_changes") end end)

local function SafeHook(tbl, name, fn)
    if tbl then
        if type(tbl) == "table" and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) end
    elseif type(_G[name]) == "function" then
        hooksecurefunc(name, fn)
    end
end
On("PLAYER_LOGIN", function()
    SafeHook(nil, "ConfirmTalentWipe", OnWipe)
    SafeHook(nil, "CinematicFrame_CancelCinematic", Skip)
    SafeHook(nil, "StopCinematic", Skip)
    SafeHook(C_ClassTalents, "LoadConfig", function() Add("talent_loadouts") end)
    if MovieFrame and type(MovieFrame.HookScript) == "function" then
        pcall(MovieFrame.HookScript, MovieFrame, "OnKeyUp", function(_, key)
            if key == "ESCAPE" or key == "SPACE" or key == "ENTER" then Skip() end
        end)
    end
end)

-- ------------------------------------------------------------ catalog
local function Stat(cat, label, fmt, key, record, tip)
    local row = { label = label, fmt = fmt, tip = tip }
    if record then row.rec = key else row.key = key end
    table.insert(ns.STATS[cat], row)
end
local ccTip = "From the game's loss-of-control alerts (the large icon in the middle of the screen). Effects the game hides are not counted."
Stat("combat", "Crowd control suffered", "int", "cc_taken", false, ccTip)
Stat("combat", "Time crowd-controlled", "time", "cc_time", false, ccTip)
for _, kind in ipairs(ns.CC_KINDS) do
    Stat("combat", CC_LABEL[kind] .. ": times", "int", "cc_" .. kind, false, ccTip)
    Stat("combat", CC_LABEL[kind] .. ": time", "time", "cc_time_" .. kind, false, ccTip)
end
Stat("records", "Longest crowd control suffered", "time", "cc_longest", true, ccTip)

local sceneTip = "In-game cinematics and movies. A scene counts as skipped when you press Escape or Cancel."
Stat("life", "Cinematics watched", "int", "cinematics_seen", false, sceneTip)
Stat("life", "Movies watched", "int", "movies_seen", false, sceneTip)
Stat("life", "Scenes watched to the end", "int", "cinematics_finished", false, sceneTip)
Stat("life", "Scenes skipped", "int", "cinematics_skipped", false, sceneTip)
Stat("life", "Time watching cinematics", "time", "cinematic_time", false, sceneTip)
Stat("records", "Longest cinematic watched", "time", "cinematic_longest", true, sceneTip)

Stat("life", "Talent respecs", "int", "respecs", false, "Times you unlearned your talents at a trainer.")
Stat("life", "Gold spent on respecs", "money", "respec_gold", false, "What trainers charged to unlearn your talents.")
Stat("records", "Most expensive respec", "money", "respec_cost_max", true)
Stat("life", "Talent loadouts loaded", "int", "talent_loadouts", false, "Saved talent loadouts you switched to.")
Stat("life", "Specialization changes", "int", "spec_changes", false)

table.insert(ns.LISTS, { id = "cc_spells", name = "Crowd control suffered by spell", fmt = "int" })
table.insert(ns.LISTS, { id = "cc_spell_time", name = "Time controlled by spell", fmt = "time" })

ns.CONTROL_STAT_COUNT = 2 + #ns.CC_KINDS * 2 + 1 + 6 + 5 + 2

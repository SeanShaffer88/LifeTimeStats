-- LifeTimeStats - window themes. Match the look of popular UI replacements.
-- "Auto" follows the UI addon you run (EllesmereUI, ElvUI, Tukui), reading its live
-- colours and font when it is loaded. Applied when the window is first built (/reload
-- to switch). The class-colour option still overrides the accent.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...

local function hex(h, a)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
local function Mix(c, d) return { math.min(1, c[1] + d), math.min(1, c[2] + d), math.min(1, c[3] + d), 1 } end

local ARIALN, FRIZ = "Fonts\\ARIALN.TTF", "Fonts\\FRIZQT__.TTF"

-- Each theme: palette, fonts and a short description for the settings button.
ns.THEMES = {
    { id = "odometer", name = "Odometer", desc = "LifeTimeStats' own look: charcoal, cream text, amber digits.",
      bg = hex("17191c", 0.97), tile = hex("24272b"), tileHi = hex("2e3237"), edge = hex("33363b"),
      text = hex("efe6d2"), dim = hex("9b9486"), amber = hex("ffb238"),
      cream2 = hex("c9bfa8"), rust = hex("d9604a"), teal = hex("6fb7a8") },
    { id = "blizzard", name = "Blizzard", desc = "Default game look: near-black panels, gold borders and headings, Friz Quadrata.",
      bg = { 0.03, 0.03, 0.04, 0.95 }, tile = { 0.07, 0.07, 0.08, 0.95 }, tileHi = { 0.13, 0.12, 0.10, 1 }, edge = hex("6b5a32"),
      text = { 1, 1, 1, 1 }, dim = { 0.70, 0.70, 0.70, 1 }, amber = hex("ffd100"),
      cream2 = { 0.85, 0.85, 0.85, 1 }, rust = hex("e0402a"), teal = hex("40c0f0"), font = FRIZ, num = FRIZ },
    { id = "elvui", name = "ElvUI", desc = "Flat dark panels with black 1-pixel borders and the blue value colour. Uses ElvUI's own colours and font when ElvUI is loaded.",
      bg = { 0.06, 0.06, 0.06, 0.92 }, tile = { 0.10, 0.10, 0.10, 1 }, tileHi = { 0.16, 0.16, 0.16, 1 }, edge = { 0, 0, 0, 1 },
      text = { 1, 1, 1, 1 }, dim = { 0.62, 0.62, 0.62, 1 }, amber = { 0.09, 0.52, 0.82, 1 },
      cream2 = { 0.80, 0.80, 0.80, 1 }, rust = { 0.78, 0.25, 0.25, 1 }, teal = { 0.25, 0.75, 0.45, 1 }, font = ARIALN, num = ARIALN, live = "ElvUI" },
    { id = "tukui", name = "Tukui", desc = "Tukui's classic look: dark grey panels, grey borders, white text. Uses Tukui's colours when it is loaded.",
      bg = { 0.08, 0.08, 0.08, 0.92 }, tile = { 0.11, 0.11, 0.11, 1 }, tileHi = { 0.18, 0.18, 0.18, 1 }, edge = { 0.30, 0.30, 0.30, 1 },
      text = { 1, 1, 1, 1 }, dim = { 0.60, 0.60, 0.60, 1 }, amber = { 0.85, 0.85, 0.85, 1 },
      cream2 = { 0.70, 0.70, 0.70, 1 }, rust = { 0.75, 0.30, 0.30, 1 }, teal = { 0.30, 0.70, 0.50, 1 }, font = ARIALN, num = ARIALN, live = "Tukui" },
    { id = "ellesmere", name = "EllesmereUI", desc = "Warm near-black panels, faint white borders, soft-white text and EllesmereUI's accent (teal, bronze on Forever). Uses its live accent and font when loaded.",
      bg = { 0.069, 0.058, 0.047, 0.96 }, tile = { 0.095, 0.082, 0.068, 1 }, tileHi = { 0.13, 0.115, 0.098, 1 }, edge = { 0.12, 0.108, 0.097, 1 },
      text = { 1, 1, 1, 0.92 }, dim = { 0.53, 0.51, 0.49, 1 }, amber = { 220 / 255, 167 / 255, 127 / 255, 1 },
      cream2 = { 0.78, 0.76, 0.73, 1 }, rust = { 0.86, 0.36, 0.31, 1 }, teal = { 12 / 255, 210 / 255, 157 / 255, 1 }, font = ARIALN, num = ARIALN, live = "EllesmereUI" },
}
ns.THEME_BY_ID = {}
for _, t in ipairs(ns.THEMES) do ns.THEME_BY_ID[t.id] = t end

local function Loaded(name)
    local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not f then return false end
    local ok, r = pcall(f, name)
    return ok and r and true or false
end
local function Col(t) if type(t) == "table" then local r, g, b = t.r or t[1], t.g or t[2], t.b or t[3] if type(r) == "number" and type(g) == "number" and type(b) == "number" then return { r, g, b, 1 } end end end

-- Which UI addon is running (for "Auto").
function ns.DetectUI()
    if Loaded("EllesmereUI") or type(_G.EllesmereUI) == "table" and _G.EllesmereUI.ELLESMERE_GREEN then return "ellesmere" end
    if Loaded("ElvUI") then return "elvui" end
    if Loaded("Tukui") then return "tukui" end
    return "odometer"
end

-- Live colours / font from the UI addon itself, if loaded. Every read is guarded.
local LIVE = {
    ElvUI = function(p)
        local E = type(_G.ElvUI) == "table" and _G.ElvUI[1]
        local m = type(E) == "table" and E.media
        if type(m) ~= "table" then return end
        local bd, bo, val = Col(m.backdropcolor), Col(m.bordercolor), Col(m.rgbvaluecolor)
        if bd then p.tile = bd; p.tileHi = Mix(bd, 0.06); p.bg = { bd[1] * 0.6, bd[2] * 0.6, bd[3] * 0.6, 0.92 } end
        if bo then p.edge = bo end
        if val then p.amber = val end
        if type(m.normFont) == "string" then p.font = m.normFont; p.num = m.normFont end
        return true
    end,
    Tukui = function(p)
        local T = type(_G.Tukui) == "table" and _G.Tukui[1]
        local c = type(T) == "table" and T.Colors
        if type(c) ~= "table" then return end
        local bd, bo = Col(c.backdrop), Col(c.border)
        if bd then p.tile = bd; p.tileHi = Mix(bd, 0.06); p.bg = { bd[1] * 0.75, bd[2] * 0.75, bd[3] * 0.75, 0.92 } end
        if bo then p.edge = bo end
        return true
    end,
    EllesmereUI = function(p)
        local E = _G.EllesmereUI
        if type(E) ~= "table" then return end
        -- Official skinning API first (EllesmereUI.RegisterSkin hands us its getters).
        local Sk = ns.euiSkin
        if Sk and (not Sk.IsEnabled or Sk.IsEnabled()) then
            local ok, r, g, b = pcall(Sk.GetAccentColor)
            if ok and type(r) == "number" then p.amber = { r, g, b, 1 } end
            local ok2, pr, pg, pb, pa = pcall(Sk.GetPanelColor)
            if ok2 and type(pr) == "number" then
                p.tile = { pr, pg, pb, 1 }; p.tileHi = Mix(p.tile, 0.04)
                p.bg = { pr * 0.85, pg * 0.85, pb * 0.85, math.max(pa or 0.95, 0.92) }
            end
            local ok3, font = pcall(Sk.GetFont)
            if ok3 and type(font) == "string" and font ~= "" then p.font = font; p.num = font end
            if ok and type(r) == "number" then return true end
        end
        local r, g, b
        if type(E.ResolveActiveAccent) == "function" then
            local ok, a, bb, c = pcall(E.ResolveActiveAccent)
            if ok and type(a) == "number" then r, g, b = a, bb, c end
        end
        if not r then local c = Col(E.ELLESMERE_GREEN) if c then r, g, b = c[1], c[2], c[3] end end
        if r then p.amber = { r, g, b, 1 } end
        if type(E.GetFontPath) == "function" then
            local ok, f = pcall(E.GetFontPath)
            if ok and type(f) == "string" and f ~= "" then p.font = f; p.num = f end
        elseif type(E.EXPRESSWAY) == "string" then p.font = E.EXPRESSWAY; p.num = E.EXPRESSWAY end
        return true
    end,
}

local function Copy(dst, src) if src then dst[1], dst[2], dst[3], dst[4] = src[1], src[2], src[3], src[4] or 1 end end

-- Resolve the chosen theme into ns.THEME (in place, so every holder of these tables sees it).
function ns.ApplyTheme()
    local want = (ns.settings and ns.settings.theme) or "odometer"
    local id = want == "auto" and ns.DetectUI() or want
    local base = ns.THEME_BY_ID[id] or ns.THEME_BY_ID.odometer
    local p = {}
    for k, v in pairs(base) do p[k] = type(v) == "table" and { v[1], v[2], v[3], v[4] } or v end
    p.liveUsed = base.live and LIVE[base.live] and (function() local ok, r = pcall(LIVE[base.live], p) return ok and r end)() or false
    local T = ns.THEME
    for _, k in ipairs({ "bg", "tile", "tileHi", "edge", "text", "dim", "amber" }) do Copy(T[k], p[k]) end
    ns.themeId, ns.themeLive = id, p.liveUsed and true or false
    local W = ns.W
    if W then
        W.FONT = p.font or STANDARD_TEXT_FONT or FRIZ
        W.NUM = p.num or ARIALN
        if W.C then Copy(W.C.cream2, p.cream2); Copy(W.C.rust, p.rust); Copy(W.C.teal, p.teal) end
    end
    local a = T.amber
    ns.accent2 = { a[1] * 0.78, a[2] * 0.78, a[3] * 0.78, 1 }
    ns.GOLD = string.format("|cff%02x%02x%02x", math.floor(a[1] * 255), math.floor(a[2] * 255), math.floor(a[3] * 255))
    ns.GREEN = string.format("|cff%02x%02x%02x", math.floor(T.text[1] * 255), math.floor(T.text[2] * 255), math.floor(T.text[3] * 255))
    ns.GREY = string.format("|cff%02x%02x%02x", math.floor(T.dim[1] * 255), math.floor(T.dim[2] * 255), math.floor(T.dim[3] * 255))
    if ns.ApplyAccent then ns.ApplyAccent() end
end

function ns.ThemeName(id)
    if id == "auto" then return "Auto (" .. (ns.THEME_BY_ID[ns.DetectUI()] or {}).name .. ")" end
    return (ns.THEME_BY_ID[id] or ns.THEME_BY_ID.odometer).name
end
ns.THEME_ORDER = { "auto", "odometer", "blizzard", "elvui", "tukui", "ellesmere" }

-- EllesmereUI skinning API: register once; the getters feed the EllesmereUI theme.
if type(_G.EllesmereUI) == "table" and type(_G.EllesmereUI.RegisterSkin) == "function" then
    pcall(_G.EllesmereUI.RegisterSkin, "LifeTimeStats", function(Sk) ns.euiSkin = Sk end)
end

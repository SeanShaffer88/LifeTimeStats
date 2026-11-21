-- LifeTimeStats - history: every quest turned in, a fuller snapshot at each level, the date of
-- every profession skill-up, where you died (with map pins), when you play (weekday x hour),
-- and item tooltips that say where you got an item. Nothing is sent anywhere.
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, Max, Tally, On = ns.Add, ns.Max, ns.Tally, ns.On
local S = ns.IsSecret

local QUEST_CAP, DEATH_CAP = 1000, 500
ns.QUEST_LOG_CAP, ns.DEATH_LOG_CAP = QUEST_CAP, DEATH_CAP

local function N(v) if type(v) == "number" and not S(v) and v == v and v ~= math.huge and v ~= -math.huge then return v end end
local function Str(v) if type(v) == "string" and not S(v) and v ~= "" then return v end end
local function Zone() return Str(GetRealZoneText and GetRealZoneText()) or "Unknown" end
local function Level() return N(UnitLevel("player")) or 0 end

-- ------------------------------------------------------------ quest history
-- rec.quests = { { t, id, n title, z zone, l level, xp, g money, d accept-to-turn-in seconds } ... }
On("QUEST_TURNED_IN", function(_, qid, xp, money)
    local ch = ns.char
    if not ch then return end
    local info = ns.lastQuestTurnIn or {}
    ns.lastQuestTurnIn = nil
    ch.quests = ch.quests or {}
    local log = ch.quests
    log[#log + 1] = { t = time(), id = N(qid), n = Str(info.title) or (N(qid) and ("Quest " .. qid)) or "?", z = Zone(), l = Level(),
        xp = N(xp), g = N(money), d = info.id == qid and N(info.dur) or nil }
    while #log > QUEST_CAP do if ns.Retention then ns.Retention.Mark(ns.char, "h", "quests") end; table.remove(log, 1) end
    Tally("questzones", Zone())
    Tally("questlevels", "Level " .. Level())
end)

-- ------------------------------------------------------------ fuller level snapshots
-- Added to the existing per-level snapshot: gold, item level, /played, base stats, zone.
function ns.LevelSnapshotExtra(s)
    if type(s) ~= "table" then return end
    s.gold = N(GetMoney and GetMoney())
    s.il = ns.AvgItemLevel and N((ns.AvgItemLevel()))
    s.played = ns.char and N(ns.char.c.played_server)
    s.zone = Zone()
    if UnitStat then
        for i, key in ipairs({ "str", "agi", "sta", "int", "spi" }) do
            local ok, _, eff = pcall(UnitStat, "player", i)
            if ok then s[key] = N(eff) end
        end
    end
end

-- ------------------------------------------------------------ profession history
-- rec.skills[name] = { f first seen, r rank, h = { [rank] = time first reached } }
function ns.OnSkillUp(name, rank)
    local ch = ns.char
    name, rank = Str(name), N(tonumber(rank))
    if not ch or not name or not rank then return end
    ch.skills = ch.skills or {}
    local sk = ch.skills[name]
    if not sk then sk = { f = time(), h = {} }; ch.skills[name] = sk end
    if not sk.h[rank] then sk.h[rank] = time() end
    sk.r = math.max(sk.r or 0, rank)
    for _, m in ipairs({ 75, 150, 225, 300 }) do
        if rank == m then
            Add("skill_milestones")
            if ns.Journal then ns.Journal(name .. " reached " .. m, "first") end
        end
    end
end

-- Time taken between two ranks of a skill (nil when either is unknown).
function ns.SkillSpan(sk, from, to)
    if type(sk) ~= "table" or type(sk.h) ~= "table" then return nil end
    local a = from == 1 and (sk.h[1] or sk.f) or sk.h[from]
    local b = sk.h[to]
    if a and b and b >= a then return b - a end
end

-- ------------------------------------------------------------ where you died
-- rec.deathlog = { { t, m map ID, x, y (0-1), z zone, c cause, l level } ... }
local function PlayerMapPosition()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
    local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
    map = okM and N(map)
    if not map then return nil end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if not okP or type(pos) ~= "table" or S(pos) or not pos.GetXY then return map end
    local okX, x, y = pcall(pos.GetXY, pos)
    if not okX then return map end
    return map, N(x), N(y)
end
ns.PlayerMapPosition = PlayerMapPosition

local deathSpot
On("PLAYER_DEAD", function()
    if not ns.char then return end
    local m, x, y = PlayerMapPosition()
    deathSpot = { t = time(), m = m, x = x, y = y, z = Zone(), l = Level() }
end)
local deathHook = ns.OnPlayerDeath
function ns.OnPlayerDeath(cause, eventZone)
    if deathHook then deathHook(cause, eventZone) end
    local ch = ns.char
    if not ch then return end
    local spot = deathSpot or { t = time(), z = Zone(), l = Level() }
    deathSpot = nil
    spot.c = Str(cause) or "Unknown"
    ch.deathlog = ch.deathlog or {}
    local log = ch.deathlog
    log[#log + 1] = spot
    while #log > DEATH_CAP do if ns.Retention then ns.Retention.Mark(ns.char, "h", "deathlog") end; table.remove(log, 1) end
    if spot.x then Add("deaths_located") end
    if ns.RefreshDeathPins then pcall(ns.RefreshDeathPins) end
end

-- Map pins: a small skull for each death on the map you are looking at.
local pins = {}
function ns.RefreshDeathPins()
    for _, p in ipairs(pins) do p:Hide() end
    if not ns.settings or ns.settings.deathPins == false then return 0 end
    local map = WorldMapFrame
    if not map or not map.GetMapID or not map.GetCanvas or not (map.IsShown and map:IsShown()) then return 0 end
    local okM, id = pcall(map.GetMapID, map)
    local okC, canvas = pcall(map.GetCanvas, map)
    if not okM or not okC or not canvas then return 0 end
    local w, h = canvas:GetWidth() or 0, canvas:GetHeight() or 0
    if w <= 0 or h <= 0 then return 0 end
    local shown = 0
    for _, r in ipairs(ns.GuideRecords and ns.GuideRecords() or { { rec = ns.char } }) do
        for _, d in ipairs((r.rec and r.rec.deathlog) or {}) do
            if d.m == id and d.x and d.y then
                shown = shown + 1
                local p = pins[shown]
                if not p then
                    p = CreateFrame("Frame", nil, canvas)
                    p:SetSize(14, 14)
                    p.tex = p:CreateTexture(nil, "OVERLAY")
                    p.tex:SetAllPoints()
                    p.tex:SetTexture(ns.W and (ns.W.MEDIA .. "icons\\skull") or "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
                    p.tex:SetVertexColor(1, 0.3, 0.2)
                    p:EnableMouse(true)
                    p:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine("Died here", 1, 0.3, 0.2)
                        GameTooltip:AddLine(self.text or "", 1, 1, 1, true)
                        GameTooltip:Show()
                    end)
                    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    pins[shown] = p
                end
                if p:GetParent() ~= canvas and p.SetParent then p:SetParent(canvas) end
                p:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 20)
                p:ClearAllPoints()
                p:SetPoint("CENTER", canvas, "TOPLEFT", d.x * w, -d.y * h)
                local sc = map.ScrollContainer
                local okS, scale = false, nil
                if type(sc) == "table" and type(sc.GetCanvasScale) == "function" then okS, scale = pcall(sc.GetCanvasScale, sc) end
                scale = (okS and type(scale) == "number" and scale > 0) and scale or 1
                p:SetScale(1 / math.max(scale, 0.01))
                p.text = (d.c or "Unknown") .. " · level " .. (d.l or "?") .. " · " .. date("%b %d, %Y", d.t or 0) .. ((r.name and r.name ~= "" and r.rec ~= ns.char) and (" · " .. r.name) or "")
                p:Show()
            end
        end
    end
    return shown
end
local function HookWorldMap()
    if not WorldMapFrame or not hooksecurefunc then return end
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() pcall(ns.RefreshDeathPins) end) end
    if WorldMapFrame.HookScript then WorldMapFrame:HookScript("OnShow", function() pcall(ns.RefreshDeathPins) end) end
end
On("PLAYER_LOGIN", function() pcall(HookWorldMap) end)

-- ------------------------------------------------------------ when you play
-- Seconds online by weekday and hour: tally "playhours" keys "<weekday 0-6>-<hour 00-23>".
local lastPlayTick
local function PlayTick()
    local now = GetTime()
    local dt = lastPlayTick and (now - lastPlayTick) or 0
    lastPlayTick = now
    if dt <= 0 or dt > 120 or not ns.char then return end
    local wday, hour = tonumber(date("%w")), tonumber(date("%H"))
    if wday and hour then
        Tally("playhours", string.format("%d-%02d", wday, hour), dt)
        Tally("playweekdays", tostring(wday), dt)
    end
end
ns.PlayTick = PlayTick
On("PLAYER_LOGIN", function()
    lastPlayTick = GetTime()
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, function() pcall(PlayTick) end) end
end)

ns.WEEKDAYS = { [0] = "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- ------------------------------------------------------------ item tooltips
local index, indexSize
local function ItemIndex()
    local items = (ns.char and ns.char.items) or {}
    if index and indexSize == #items then return index end
    index, indexSize = {}, #items
    for _, e in ipairs(items) do
        if type(e) == "table" and e.id then index[e.id] = e end -- newest wins
    end
    return index
end
function ns.ItemTooltipLine(itemID)
    if not ns.settings or ns.settings.itemTooltips == false then return nil end
    itemID = N(tonumber(itemID))
    if not itemID then return nil end
    local e = ItemIndex()[itemID]
    if not e then return nil end
    local src = (ns.ITEM_SOURCE_LABEL and ns.ITEM_SOURCE_LABEL[e.src]) or e.src or "Got"
    return src .. (e.from and (" from " .. e.from) or "") .. " · " .. date("%b %d, %Y", e.t or 0) .. ", level " .. (e.l or "?") .. (e.z and (" · " .. e.z) or "")
end
local function AddLine(tt, itemID)
    local line = ns.ItemTooltipLine(itemID)
    if line and tt and tt.AddLine then tt:AddLine("LifeTimeStats: " .. line, 1, 0.70, 0.22, true) end
end
local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if tt == GameTooltip or tt == ItemRefTooltip then pcall(AddLine, tt, data and data.id) end
        end)
        return true
    end
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tt)
            local ok, _, link = pcall(tt.GetItem, tt)
            if ok and type(link) == "string" then pcall(AddLine, tt, link:match("item:(%d+)")) end
        end)
        return true
    end
end
On("PLAYER_LOGIN", function() pcall(HookTooltips) end)

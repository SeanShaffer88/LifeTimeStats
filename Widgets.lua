-- LifeTimeStats - themed UI building blocks
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local ADDON, ns = ...

local T = ns.THEME
local W = {}
ns.W = W

W.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
W.WHITE = "Interface\\Buttons\\WHITE8x8"
W.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
W.NUM = "Fonts\\ARIALN.TTF"

W.JOURNAL = {
    gold = { 0.918, 0.780, 0.451 },
    trim = { 0.698, 0.529, 0.306 },
    top = { 0.263, 0.192, 0.122 },
    base = { 0.165, 0.114, 0.075 },
    tab = { 0.298, 0.204, 0.125 },
    page = { 0.183, 0.136, 0.094 },
}

-- Chart palette (amber family + cream + rust + teal, all on charcoal)
W.C = {
    amber = T.amber,
    amber2 = { 0xd9 / 255, 0x8a / 255, 0x1c / 255, 1 }, -- replaced by a darker class shade in W.Init
    cream = T.text,
    cream2 = { 0xc9 / 255, 0xbf / 255, 0xa8 / 255, 1 },
    rust = { 0xd9 / 255, 0x60 / 255, 0x4a / 255, 1 },
    teal = { 0x6f / 255, 0xb7 / 255, 0xa8 / 255, 1 },
    dim = T.dim,
    empty = T.edge,
}

function W.Color(tex, c, a) tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1) end

function W.Fill(parent, c, layer, a)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    W.Color(t, c, a)
    return t
end

function W.Shade(texture, low, high)
    if texture.SetGradient and CreateColor and pcall(function()
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetGradient("VERTICAL", CreateColor(low[1], low[2], low[3], 1),
            CreateColor(high[1], high[2], high[3], 1))
    end) then return end
    W.Color(texture, low)
end

-- Faux bold: WoW fonts have no bold face, so an ink shadow one pixel to the right thickens
-- the strokes. Used for headings and numbers in the Adventurer's Notebook.
function W.Bold(fs, c)
    if not fs or not fs.SetShadowOffset then return fs end
    c = c or ns.THEME.text
    fs:SetShadowColor(c[1] * 0.85, c[2] * 0.85, c[3] * 0.85, 0.9)
    fs:SetShadowOffset(1, 0)
    return fs
end

-- Small caps: no WoW font has them, so headings are set in capitals one point smaller.
function W.SmallCaps(text) return tostring(text or ""):upper() end

-- Ink: on the notebook's paper, any colour lighter than a dark ink is darkened (same hue) until
-- it reads like ink. Bright gold headings, grey details, class colours, white and green item
-- names all pass through here. On the dark skins colours are left alone.
local INK_MAX = 0.34 -- brightest luminance allowed on paper
function W.InkRGB(r, g, b)
    if not (ns.Paper and ns.Paper()) or type(r) ~= "number" then return r, g, b end
    local lum = 0.299 * r + 0.587 * (g or 0) + 0.114 * (b or 0)
    if lum <= INK_MAX then return r, g, b end
    local k = INK_MAX / lum
    return r * k, (g or 0) * k, (b or 0) * k
end
function W.InkCodes(text)
    if type(text) ~= "string" or not (ns.Paper and ns.Paper()) or not text:find("|c", 1, true) then return text end
    return (text:gsub("|c(%x%x)(%x%x)(%x%x)(%x%x)", function(a, rr, gg, bb)
        local r, g, b = W.InkRGB(tonumber(rr, 16) / 255, tonumber(gg, 16) / 255, tonumber(bb, 16) / 255)
        return string.format("|c%s%02x%02x%02x", a, math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    end))
end
-- Every FontString made by W.Text inks its own colours on paper.
local function InkFontString(fs)
    local setText, setColor = fs.SetText, fs.SetTextColor
    if type(setText) == "function" then
        fs.SetText = function(self, t)
            if rawget(self, "noInk") then return setText(self, t) end
            setText(self, W.InkCodes(t))
            -- single-line text that is too long shrinks a little instead of ending in "..."
            local canWrap = self.CanWordWrap or self.GetWordWrap
            if t and t ~= "" and canWrap and canWrap(self) == false and not rawget(self, "fitting") then
                self.fitting = true
                W.FitText(self)
                self.fitting = nil
            end
        end
    end
    if type(setColor) == "function" then
        fs.SetTextColor = function(self, r, g, b, a)
            if not rawget(self, "noInk") then r, g, b = W.InkRGB(r, g, b) end
            return setColor(self, r, g, b, a)
        end
    end
end

-- Notebook type sizes: nothing below 11 points on paper, and the common 11 becomes 12.
function W.PaperSize(size)
    size = size or 12
    if size <= 10 then return 11.5 end
    if size < 12 then return 12 end
    return size
end

function W.Text(parent, size, c, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    size = size or 12
    if ns.Paper and ns.Paper() then
        size = W.PaperSize(size)
        if fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
        InkFontString(fs)
    end
    fs:SetFont(font or W.FONT, size, "")
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    if justify then fs:SetJustifyH(justify) end
    fs:SetWordWrap(false)
    return fs
end

function W.Icon(parent, name, size, c)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(W.MEDIA .. "icons\\" .. name)
    c = c or T.amber
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    return t
end

function W.Line(parent, c, layer)
    local t = parent:CreateTexture(nil, layer or "BORDER")
    W.Color(t, c or T.edge)
    return t
end

-- Tooltip colours. The game's tooltip is always dark, so on the notebook skin (whose palette is
-- dark ink for paper) tooltips use light parchment colours instead.
local TIP_LIGHT = { amber = { 1, 0.82, 0.38 }, text = { 0.96, 0.92, 0.84 }, dim = { 0.78, 0.72, 0.62 } }
function ns.TipColor(name, wrap)
    local c = (ns.Paper and ns.Paper()) and TIP_LIGHT[name] or T[name] or TIP_LIGHT.text
    return c[1], c[2], c[3], wrap
end

function W.Tip(owner, title, body, extra)
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(type(title) == "function" and title() or title, ns.TipColor("amber"))
        local b = type(body) == "function" and body() or body
        if b then GameTooltip:AddLine(b, ns.TipColor("text", true)) end
        if extra then GameTooltip:AddLine(extra, ns.TipColor("dim", true)) end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function W.Panel(parent, c, edge)
    local f = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = W.WHITE, edgeFile = W.WHITE, edgeSize = 1 })
        f:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
        local e = edge or T.edge
        f:SetBackdropBorderColor(e[1], e[2], e[3], e[4] or 1)
    else
        local bg = W.Fill(f, c); bg:SetAllPoints()
    end
    return f
end

function W.Window(parent)
    local f = W.Panel(parent, T.bg)
    if ns.themeId == "forever" and BackdropTemplateMixin then
        local created, rim = pcall(CreateFrame, "Frame", nil, f, "BackdropTemplate")
        if created and rim then
            local applied = pcall(rim.SetBackdrop, rim, {
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                edgeSize = 11,
                tileEdge = true,
            })
            if applied then
                rim:SetPoint("TOPLEFT", f, "TOPLEFT", -4, 4)
                rim:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 4, -4)
                rim:SetFrameLevel((f:GetFrameLevel() or 0) + 6)
            else
                rim:Hide()
            end
        end
    end
    return f
end

function W.FlatButton(parent, label, w, h, tipTitle, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = W.Fill(b, T.tile); b.bg:SetAllPoints()
    local journal = ns.JournalSkin()
    local trim = journal and W.JOURNAL.trim or T.amber
    b.edge = W.Fill(b, trim, "BORDER"); b.edge:SetPoint("BOTTOMLEFT"); b.edge:SetPoint("BOTTOMRIGHT"); b.edge:SetHeight(1); b.edge:SetAlpha(0.5)
    b.text = W.Text(b, 11, T.text); b.text:SetPoint("CENTER"); b.text:SetText(label)
    local idle = journal and W.JOURNAL.base or T.tile
    if journal then W.Color(b.bg, idle) end
    b:SetScript("OnEnter", function() W.Color(b.bg, T.tileHi); b.edge:SetAlpha(1) end)
    b:SetScript("OnLeave", function() W.Color(b.bg, idle); b.edge:SetAlpha(0.5) end)
    if tip then W.Tip(b, tipTitle or label, tip) end
    return b
end

-- Segmented toggle: options = { {id, label, tip}, ... }
function W.Segmented(parent, options, onPick)
    local f = W.Panel(parent, T.bg)
    local journal = ns.JournalSkin()
    local trim = journal and W.JOURNAL.trim or T.amber
    f.buttons = {}
    local x = 1
    for i, o in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b.text = W.Text(b, 11, T.dim); b.text:SetPoint("CENTER"); b.text:SetText(o.label)
        local w = math.max(56, b.text:GetStringWidth() + 20)
        b:SetSize(w, 22); b:SetPoint("LEFT", x, 0); x = x + w
        b.bg = W.Fill(b, T.tileHi); b.bg:SetAllPoints()
        b.bar = W.Fill(b, trim, "ARTWORK"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT"); b.bar:SetHeight(2)
        b.id = o.id
        b:SetScript("OnClick", function() onPick(o.id) end)
        W.Tip(b, o.label, o.tip)
        f.buttons[i] = b
    end
    f:SetSize(x + 1, 24)
    function f:Select(id)
        for _, b in ipairs(self.buttons) do
            local on = b.id == id
            b.bg:SetShown(on); b.bar:SetShown(on)
            local c = on and (journal and W.JOURNAL.gold or T.amber) or T.dim
            b.text:SetTextColor(c[1], c[2], c[3])
        end
    end
    return f
end

-- ------------------------------------------------------------ card
-- Card titles are upper case, except in the Forever Journal skin.
function ns.CardTitle(s)
    if ns.Framed and ns.Framed() then return tostring(s or "") end -- the framed tomes use title case
    if ns.Paper and ns.Paper() then return W.SmallCaps(s) end
    return ns.JournalSkin() and s or tostring(s):upper()
end

function W.Card(parent, title, icon, x, y, w, h, tip)
    local f = W.Panel(parent, T.tile)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(27)
    local journal = ns.JournalSkin()
    if journal then
        local banner = W.Fill(head, W.JOURNAL.base)
        banner:SetAllPoints()
        W.Shade(banner, W.JOURNAL.base, W.JOURNAL.top)
    end
    local rule = W.Line(head); rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)
    local ic = W.Icon(head, icon or "star", 14, journal and W.JOURNAL.gold or nil)
    ic:SetPoint("LEFT", 9, 0)
    local book = ns.Paper and ns.Paper()
    f.title = W.Text(head, book and 12 or (journal and 13 or 12), journal and W.JOURNAL.gold or T.text)
    f.title:SetPoint("LEFT", ic, "RIGHT", 8, 0)
    f.title:SetText(ns.CardTitle(title))
    if book then W.Bold(f.title) end
    if tip then head:EnableMouse(true); W.Tip(head, title, tip) end
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", 10, -36)
    f.body:SetSize(w - 20, h - 44)
    f.bw, f.bh = w - 20, h - 44
    return f
end

function W.Legend(parent, items, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(10, 14)
    f.items = {}
    for i = 1, 8 do
        local sw = W.Fill(f, T.amber, "ARTWORK"); sw:SetSize(8, 8)
        local tx = W.Text(f, size or 10, T.dim)
        f.items[i] = { sw = sw, tx = tx }
        sw:Hide(); tx:Hide()
    end
    function f:Set(list)
        local x = 0
        for i, it in ipairs(self.items) do
            local d = list[i]
            if d then
                it.sw:Show(); it.tx:Show()
                W.Color(it.sw, d[2])
                it.sw:ClearAllPoints(); it.sw:SetPoint("LEFT", self, "LEFT", x, 0)
                it.tx:ClearAllPoints(); it.tx:SetPoint("LEFT", it.sw, "RIGHT", 4, 0)
                it.tx:SetText(d[1])
                x = x + 16 + it.tx:GetStringWidth() + 10
            else
                it.sw:Hide(); it.tx:Hide()
            end
        end
    end
    if items then f:Set(items) end
    return f
end

-- ------------------------------------------------------------ odometer KPI
local DIGITS = 8
function W.Odometer(parent, x, y, w, h, label, icon, tip, allowFormatted)
    local f = W.Panel(parent, T.tile)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
    local journal = ns.JournalSkin()
    local top = W.Fill(f, journal and W.JOURNAL.trim or T.amber, "ARTWORK")
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(journal and 2 or 3)
    f.label = W.Text(f, 10, T.dim); f.label:SetPoint("TOPLEFT", 12, -10)
    f.icon = W.Icon(f, icon or "star", 26, journal and W.JOURNAL.gold or nil)
    f.icon:SetPoint("RIGHT", -14, -2)
    local number
    if journal then
        local wash = W.Fill(f, W.JOURNAL.base)
        wash:SetPoint("TOPLEFT", 1, -2); wash:SetPoint("BOTTOMRIGHT", -1, 1)
        W.Shade(wash, W.JOURNAL.base, W.JOURNAL.top)
        number = W.Text(f, 23, T.amber, W.NUM, "LEFT")
        if ns.Paper() then W.Bold(number, T.amber) end
        number:SetPoint("TOPLEFT", 12, -23)
        number:SetPoint("RIGHT", f.icon, "LEFT", -6, 0)
    else
        f.cells = {}
        for i = 1, DIGITS do
            local cell = CreateFrame("Frame", nil, f)
            cell:SetSize(15, 24)
            cell:SetPoint("TOPLEFT", 12 + (i - 1) * 17, -26)
            local bg = W.Fill(cell, T.bg); bg:SetAllPoints()
            local shine = W.Fill(cell, T.tileHi, "BORDER"); shine:SetPoint("TOPLEFT"); shine:SetPoint("TOPRIGHT"); shine:SetHeight(12)
            local seam = W.Fill(cell, T.bg, "ARTWORK"); seam:SetPoint("LEFT"); seam:SetPoint("RIGHT"); seam:SetHeight(1)
            cell.d = W.Text(cell, 17, T.amber, W.NUM); cell.d:SetPoint("CENTER", 0, 0)
            f.cells[i] = cell
        end
    end
    local formatted = number
    if allowFormatted then
        f.label:SetWidth(w - 24)
        f.label:SetJustifyH("LEFT")
        if not formatted then
            formatted = W.Text(f, 22, T.amber, W.NUM, "LEFT")
            formatted:SetPoint("TOPLEFT", 12, -24)
            formatted:SetPoint("RIGHT", f.icon, "LEFT", -6, 0)
            formatted:Hide()
        end
    end
    local formattedMode = false
    local configuredLabel, configuredIcon
    f.sub = W.Text(f, 10, ns.THEME.text); f.sub:SetPoint("BOTTOMLEFT", 12, 7); f.sub:SetPoint("RIGHT", f.icon, "LEFT", -6, 0)
    f:EnableMouse(true)
    f.tipTitle, f.tipBody = label, tip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(self.tipTitle, ns.TipColor("amber"))
        if self.exact then GameTooltip:AddLine(self.exact, ns.TipColor("text")) end
        if self.tipBody then GameTooltip:AddLine(self.tipBody, ns.TipColor("dim", true)) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Configure(lbl, ic, tp)
        if configuredLabel ~= lbl then self.label:SetText(lbl:upper()); configuredLabel = lbl end
        if configuredIcon ~= ic then self.icon:SetTexture(W.MEDIA .. "icons\\" .. ic); configuredIcon = ic end
        self.tipTitle, self.tipBody = lbl, tp
    end
    function f:SetValue(v, sub, exact)
        v = math.max(0, math.floor((v or 0) + 0.5))
        if number then
            if formattedMode then number:SetFont(W.NUM, 23, "") end
            number:SetText(ns.FormatInt(v))
        else
            if formattedMode then formatted:Hide() end
            local s = tostring(v)
            if #s > DIGITS then s = string.rep("9", DIGITS) end
            s = string.rep("0", DIGITS - #s) .. s
            local leading = true
            for i = 1, DIGITS do
                local ch = s:sub(i, i)
                if ch ~= "0" or i == DIGITS then leading = false end
                local cell = self.cells[i]
                if formattedMode then cell:Show() end
                cell.d:SetText(ch)
                if leading then cell.d:SetTextColor(T.dim[1], T.dim[2], T.dim[3], 0.12)
                else cell.d:SetTextColor(T.amber[1], T.amber[2], T.amber[3], 1) end
            end
        end
        formattedMode = false
        self.sub:SetText(sub or "")
        self.exact = exact
    end
    if allowFormatted then
        function f:SetFormatted(text, sub)
            if not number and not formattedMode then
                for _, cell in ipairs(self.cells) do cell:Hide() end
            end
            if not formattedMode or self.exact ~= text then
                formatted:SetFont(W.NUM, 22, "")
                formatted:SetText(text)
                if formatted:GetStringWidth() > w - 60 then formatted:SetFont(W.NUM, 16, "") end
                formatted:Show()
            end
            formattedMode = true
            self.sub:SetText(sub or "")
            self.exact = text
        end
    end
    f:Configure(label, icon or "star", tip)
    return f
end

-- ------------------------------------------------------------ tick ring
-- A ring drawn from rotated tick marks. parts = { {value, color}, ... }
function W.TickRing(parent, size, n, len, thick)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f.ticks = {}
    local r = size / 2 - len / 2
    for i = 1, n do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture(W.WHITE)
        t:SetSize(thick, len)
        local a = (i - 0.5) / n * 2 * math.pi
        t:SetPoint("CENTER", f, "CENTER", math.sin(a) * r, math.cos(a) * r)
        if t.SetRotation then t:SetRotation(-a) end
        f.ticks[i] = t
    end
    f.big = W.Text(f, math.floor(size / 6.5), T.text, W.NUM); f.big:SetPoint("CENTER", 0, 5)
    f.small = W.Text(f, 10, T.dim); f.small:SetPoint("TOP", f.big, "BOTTOM", 0, -2)
    function f:SetParts(parts, big, small)
        local total = 0
        for _, p in ipairs(parts) do total = total + math.max(0, p[1]) end
        local idx, acc = 1, 0
        for i = 1, n do
            local frac = (i - 0.5) / n
            local col = W.C.empty
            if total > 0 then
                while idx <= #parts and frac > (acc + math.max(0, parts[idx][1])) / total do
                    acc = acc + math.max(0, parts[idx][1]); idx = idx + 1
                end
                if idx <= #parts then col = parts[idx][2] end
            end
            W.Color(self.ticks[i], col)
        end
        self.big:SetText(big or "")
        self.small:SetText(total > 0 and (small or "") or "nothing yet")
    end
    function f:SetPercent(pct, color, big, small)
        pct = math.max(0, math.min(100, pct or 0))
        self:SetParts({ { pct, color }, { 100 - pct, W.C.empty } }, big, small)
    end
    return f
end

-- Ring + legend in one card body
function W.RingWithLegend(body, bw, bh)
    -- a slightly smaller ring leaves room for labels like "Quests" and "Vendor" beside coin values
    local size = math.floor(math.min(bh, bw * 0.40, 150))
    local ring = W.TickRing(body, size, 72, math.floor(size / 9), 3)
    ring:SetPoint("RIGHT", body, "RIGHT", -6, 0)
    local rows = {}
    local step = math.min(21, math.floor((bh - 8) / 7))
    for i = 1, 7 do
        local sw = W.Fill(body, T.amber, "ARTWORK"); sw:SetSize(9, 9)
        sw:SetPoint("TOPLEFT", 2, -6 - (i - 1) * step)
        local val = W.Text(body, 11, T.amber, W.NUM, "RIGHT"); val:SetPoint("RIGHT", ring, "LEFT", -6, 0); val:SetPoint("TOP", sw, "TOP", 0, 2)
        local tx = W.Text(body, 11, T.text); tx:SetPoint("LEFT", sw, "RIGHT", 6, 0); tx:SetPoint("RIGHT", val, "LEFT", -6, 0)
        tx:SetJustifyH("LEFT"); tx:SetWordWrap(false)
        rows[i] = { sw = sw, tx = tx, val = val }
    end
    local o = { ring = ring }
    function o:Set(parts, big, small, fmt)
        for i, r in ipairs(rows) do
            local p = parts[i]
            if p then
                r.sw:Show(); r.tx:Show(); r.val:Show()
                W.Color(r.sw, p[3])
                r.tx:SetText(p[1])
                r.val:SetText((fmt or ns.FormatInt)(p[2]))
                r.val:SetWidth(0); r.val:SetWidth(math.ceil(r.val:GetStringWidth()) + 1)
                r.tx:SetText(p[1]) -- again, now that the value's width is known: a long label shrinks to fit
            else
                r.sw:Hide(); r.tx:Hide(); r.val:Hide()
            end
        end
        local rp = {}
        for i, p in ipairs(parts) do rp[i] = { p[2], p[3] } end
        ring:SetParts(rp, big, small)
    end
    return o
end

-- ------------------------------------------------------------ horizontal bar list
function W.BarList(body, bw, bh, rowsN, labelW, valueW)
    rowsN = rowsN or math.floor(bh / 22)
    labelW, valueW = labelW or math.floor(bw * 0.36), valueW or 70
    local rows = {}
    local rh = math.floor(bh / rowsN)
    for i = 1, rowsN do
        local y = -(i - 1) * rh
        local lab = W.Text(body, 12, T.text, nil, "LEFT"); lab:SetPoint("TOPLEFT", 0, y - (rh - 12) / 2); lab:SetWidth(labelW - 6)
        local tw = math.max(1, bw - labelW - valueW - 8)
        local track = W.Fill(body, T.bg, "BORDER"); track:SetPoint("TOPLEFT", labelW, y - (rh - 6) / 2); track:SetSize(tw, 6)
        local bar = W.Fill(body, T.amber, "ARTWORK"); bar:SetPoint("LEFT", track, "LEFT"); bar:SetHeight(6)
        local val = W.Text(body, 12, T.amber, W.NUM, "RIGHT"); val:SetPoint("TOPRIGHT", 0, y - (rh - 12) / 2); val:SetWidth(valueW)
        rows[i] = { lab = lab, track = track, bar = bar, val = val, tw = tw, nobar = tw < 20 }
    end
    local empty = W.Text(body, 11, T.dim); empty:SetPoint("CENTER"); empty:SetText("Nothing recorded yet")
    local o = {}
    function o:Set(list, fmt, color)
        local maxv = 0
        for _, e in ipairs(list) do if e[2] > maxv then maxv = e[2] end end
        empty:SetShown(#list == 0)
        for i, r in ipairs(rows) do
            local e = list[i]
            local show = e ~= nil
            r.lab:SetShown(show); r.track:SetShown(show and not r.nobar); r.bar:SetShown(show and not r.nobar); r.val:SetShown(show)
            if e then
                r.lab:SetText(tostring(e[1]))
                r.val:SetText((fmt or ns.FormatInt)(e[2]))
                r.bar:SetWidth(math.max(1, r.tw * (maxv > 0 and e[2] / maxv or 0)))
                W.Color(r.bar, e[3] or color or T.amber)
            end
        end
    end
    return o
end

-- Mirrored bars: left value | left bar | label | right bar | right value
function W.Mirror(body, bw, bh, rowsN, leftColor, rightColor)
    local rows = {}
    local rh = math.floor(bh / rowsN)
    local mid = bw / 2
    local labelW = 110
    local barMax = mid - labelW / 2 - 44
    for i = 1, rowsN do
        local cy = -(i - 1) * rh - rh / 2
        local lab = W.Text(body, 11, T.text); lab:SetPoint("CENTER", body, "TOPLEFT", mid, cy)
        local lb = W.Fill(body, leftColor, "ARTWORK"); lb:SetHeight(6); lb:SetPoint("RIGHT", body, "TOPLEFT", mid - labelW / 2, cy)
        local rb = W.Fill(body, rightColor, "ARTWORK"); rb:SetHeight(6); rb:SetPoint("LEFT", body, "TOPLEFT", mid + labelW / 2, cy)
        local lv = W.Text(body, 10, T.dim, W.NUM, "RIGHT"); lv:SetPoint("RIGHT", lb, "LEFT", -4, 0)
        local rv = W.Text(body, 10, T.dim, W.NUM, "LEFT"); rv:SetPoint("LEFT", rb, "RIGHT", 4, 0)
        rows[i] = { lab = lab, lb = lb, rb = rb, lv = lv, rv = rv }
    end
    local empty = W.Text(body, 11, T.dim); empty:SetPoint("CENTER"); empty:SetText("Nothing recorded yet")
    local o = {}
    function o:Set(list)
        local ml, mr = 0, 0
        for _, e in ipairs(list) do ml = math.max(ml, e[2]); mr = math.max(mr, e[3]) end
        empty:SetShown(#list == 0)
        for i, r in ipairs(rows) do
            local e = list[i]
            for _, k in ipairs({ "lab", "lb", "rb", "lv", "rv" }) do r[k]:SetShown(e ~= nil) end
            if e then
                r.lab:SetText(e[1])
                r.lb:SetWidth(math.max(1, barMax * (ml > 0 and e[2] / ml or 0)))
                r.rb:SetWidth(math.max(1, barMax * (mr > 0 and e[3] / mr or 0)))
                r.lv:SetText(ns.FormatInt(e[2])); r.rv:SetText(ns.FormatInt(e[3]))
            end
        end
    end
    return o
end

-- ------------------------------------------------------------ column chart
-- mode: "single" | "signed" | "stack" | "group"
function W.Columns(parent, bw, bh, n, mode, series)
    series = series or 1
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    body:SetSize(bw, bh)
    local axisH = 14
    local ch = bh - axisH
    local slot = bw / n
    local barW = math.max(2, math.floor(slot * (mode == "group" and 0.8 or 0.6)))
    local base = W.Line(body); base:SetPoint("TOPLEFT", 0, -(mode == "signed" and ch / 2 or ch)); base:SetSize(bw, 1)
    local bars = {}
    for i = 1, n do
        bars[i] = {}
        for s = 1, series do
            local t = W.Fill(body, T.amber, "ARTWORK")
            bars[i][s] = t
        end
    end
    local axis = {}
    for j = 1, 3 do axis[j] = W.Text(body, 9, T.dim) end
    axis[1]:SetPoint("BOTTOMLEFT", 0, 0)
    axis[2]:SetPoint("BOTTOM", body, "BOTTOMLEFT", bw / 2, 0)
    axis[3]:SetPoint("BOTTOMRIGHT", 0, 0)
    local hover = CreateFrame("Frame", nil, body)
    hover:SetAllPoints()
    hover:EnableMouse(true)
    local o = { values = {}, labels = {} }
    hover:SetScript("OnUpdate", nil)
    hover:SetScript("OnEnter", function(self)
        self:SetScript("OnUpdate", function()
            local x = GetCursorPosition() / self:GetEffectiveScale() - self:GetLeft()
            local i = math.floor(x / slot) + 1
            if i < 1 or i > n or not o.values[i] then return end
            if o.hoverI == i then return end
            o.hoverI = i
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine(o.labels[i] or "", ns.TipColor("amber"))
            for s = 1, series do
                local name = o.seriesNames and o.seriesNames[s] or ""
                local lr, lg, lb = ns.TipColor("text")
                GameTooltip:AddDoubleLine(name, (o.fmt or ns.FormatInt)(o.values[i][s] or 0), lr, lg, lb, ns.TipColor("amber"))
            end
            GameTooltip:Show()
        end)
    end)
    hover:SetScript("OnLeave", function(self) self:SetScript("OnUpdate", nil); o.hoverI = nil; GameTooltip:Hide() end)

    -- values[i] = { v1, v2, ... }; colors = { c1, c2, ... }
    local emptyTx = W.Text(body, 11, T.dim); emptyTx:SetPoint("CENTER", 0, axisH / 2); emptyTx:SetText("Nothing recorded yet")
    function o:Set(values, colors, labels, axisText, fmt, seriesNames, highlightLast)
        self.values, self.labels, self.fmt, self.seriesNames = values, labels or {}, fmt, seriesNames
        local any = false
        for i = 1, n do for k = 1, series do if ((values[i] or {})[k] or 0) ~= 0 then any = true end end end
        emptyTx:SetShown(not any)
        local maxv = 0
        for i = 1, n do
            local v = values[i] or {}
            if mode == "stack" then
                local s = 0
                for k = 1, series do s = s + math.max(0, v[k] or 0) end
                maxv = math.max(maxv, s)
            else
                for k = 1, series do maxv = math.max(maxv, math.abs(v[k] or 0)) end
            end
        end
        for i = 1, n do
            local v = values[i] or {}
            local x0 = (i - 1) * slot + (slot - barW) / 2
            local stackY = 0
            for k = 1, series do
                local t = bars[i][k]
                local val = v[k] or 0
                local col = colors[k] or T.amber
                local hgt
                t:ClearAllPoints()
                if mode == "signed" then
                    hgt = maxv > 0 and math.abs(val) / maxv * (ch / 2 - 2) or 0
                    col = val < 0 and W.C.rust or col
                    if val >= 0 then t:SetPoint("BOTTOMLEFT", body, "TOPLEFT", x0, -ch / 2)
                    else t:SetPoint("TOPLEFT", body, "TOPLEFT", x0, -ch / 2) end
                    t:SetWidth(barW)
                elseif mode == "group" then
                    local gw = math.max(2, math.floor(barW / series) - 1)
                    hgt = maxv > 0 and math.max(0, val) / maxv * (ch - 4) or 0
                    t:SetPoint("BOTTOMLEFT", body, "TOPLEFT", x0 + (k - 1) * (gw + 1), -ch)
                    t:SetWidth(gw)
                else -- single / stack
                    hgt = maxv > 0 and math.max(0, val) / maxv * (ch - 4) or 0
                    t:SetPoint("BOTTOMLEFT", body, "TOPLEFT", x0, -ch + stackY)
                    t:SetWidth(barW)
                    if mode == "stack" then stackY = stackY + hgt end
                end
                t:SetHeight(math.max(hgt, 0.01))
                t:SetShown(hgt >= 0.5)
                local alpha = (highlightLast and i ~= n) and 0.65 or 1
                W.Color(t, col, alpha)
            end
        end
        for j = 1, 3 do axis[j]:SetText(axisText and axisText[j] or "") end
    end
    return o
end

-- Dot matrix: cols x rows of dots, filled from bottom by value
function W.Dots(body, bw, bh, cols, rowsN)
    local axisH = 14
    local dx, dy = bw / cols, (bh - axisH) / rowsN
    local d = math.min(dx, dy) * 0.62
    local dots = {}
    for c = 1, cols do
        dots[c] = {}
        for r = 1, rowsN do
            local t = body:CreateTexture(nil, "ARTWORK")
            t:SetTexture(W.MEDIA .. "dot")
            t:SetSize(d, d)
            t:SetPoint("CENTER", body, "TOPLEFT", (c - 0.5) * dx, -(bh - axisH) + (r - 0.5) * dy)
            dots[c][r] = t
        end
    end
    local a1 = W.Text(body, 9, T.dim); a1:SetPoint("BOTTOMLEFT", 0, 0)
    local a2 = W.Text(body, 9, T.dim); a2:SetPoint("BOTTOM", body, "BOTTOMLEFT", bw / 2, 0)
    local a3 = W.Text(body, 9, T.dim); a3:SetPoint("BOTTOMRIGHT", 0, 0)
    local o = {}
    function o:Set(values, axisText)
        local maxv = 0
        for c = 1, cols do maxv = math.max(maxv, values[c] or 0) end
        for c = 1, cols do
            local lit = maxv > 0 and math.floor((values[c] or 0) / maxv * rowsN + 0.5) or 0
            if (values[c] or 0) > 0 and lit == 0 then lit = 1 end
            for r = 1, rowsN do
                local col = r <= lit and T.amber or T.tileHi
                dots[c][r]:SetVertexColor(col[1], col[2], col[3], 1)
            end
        end
        a1:SetText(axisText[1]); a2:SetText(axisText[2]); a3:SetText(axisText[3])
    end
    return o
end

-- ------------------------------------------------------------ grid table
-- cols = { {title, width, kind = "text"|"num"|"dim"|"bar"} }; last column takes the rest.
function W.Table(body, bw, bh, cols, onClick, emptyText)
    local RH, HH = 22, 22
    local visible = math.floor((bh - HH) / RH)
    local f = CreateFrame("Frame", nil, body)
    f:SetSize(bw, bh)
    f:SetPoint("TOPLEFT")
    local sbW = 4
    local width = bw - sbW - 4
    -- column x positions
    local xs, x = {}, 0
    for i, c in ipairs(cols) do
        xs[i] = x
        c.w = (i == #cols) and (width - x) or c[2]
        x = x + c.w
    end
    local book = ns.Paper and ns.Paper()
    local head = W.Fill(f, book and W.JOURNAL.base or { 0x1d / 255, 0x1f / 255, 0x23 / 255, 1 }, "BACKGROUND", book and 0.55 or nil)
    head:SetPoint("TOPLEFT"); head:SetSize(width, HH)
    f.heads = {}
    for i, c in ipairs(cols) do
        local h = W.Text(f, 10, book and T.text or T.dim, nil, (c.kind == "num" or c.kind == "dim") and "RIGHT" or "LEFT")
        local padL = c.w < 50 and 3 or 8
        h:SetPoint("TOPLEFT", xs[i] + padL, -6); h:SetWidth(c.w - padL * 2)
        if book then W.Bold(h) end
        h:SetText(c[1])
        f.heads[i] = h
    end
    local gridH = HH + visible * RH
    -- grid lines
    for i = 1, #cols + 1 do
        local l = W.Line(f, T.edge, "ARTWORK")
        if book then l:SetAlpha(0.22) end
        l:SetPoint("TOPLEFT", (i <= #cols and xs[i] or width) - (i > #cols and 1 or 0), 0)
        l:SetSize(1, gridH)
    end
    for r = 0, visible + 1 do
        local l = W.Line(f, T.edge, "ARTWORK")
        if book then l:SetAlpha(0.22) end
        l:SetPoint("TOPLEFT", 0, -(r == 0 and 0 or (HH + (r - 1) * RH)))
        l:SetSize(width, 1)
    end
    f.rows = {}
    for r = 1, visible do
        local row = CreateFrame("Button", nil, f)
        row:SetPoint("TOPLEFT", 0, -(HH + (r - 1) * RH))
        row:SetSize(width, RH)
        row.zebra = W.Fill(row, book and T.text or { 0x1f / 255, 0x22 / 255, 0x26 / 255, 1 }, "BACKGROUND", book and 0.05 or nil)
        row.zebra:SetAllPoints()
        row.hl = W.Fill(row, T.tileHi, "BACKGROUND"); row.hl:SetAllPoints(); row.hl:Hide()
        row.cells = {}
        for i, c in ipairs(cols) do
            if c.kind == "bar" then
                local track = W.Fill(row, T.bg, "BORDER"); track:SetPoint("LEFT", xs[i] + 8, 0); track:SetSize(c.w - 16, 6)
                local bar = W.Fill(row, T.amber, "ARTWORK"); bar:SetPoint("LEFT", track, "LEFT"); bar:SetHeight(6)
                row.cells[i] = { bar = bar, track = track, w = c.w - 16 }
            else
                local font = (c.kind == "num" or c.kind == "dim") and W.NUM or W.FONT
                local col = c.kind == "num" and T.amber or (c.kind == "dim" and T.dim or T.text)
                local fs = W.Text(row, c.kind == "text" and 12 or 13, col, font, (c.kind == "num" or c.kind == "dim") and "RIGHT" or "LEFT")
                if book and c.kind == "num" then W.Bold(fs, T.amber) end
                local padL = c.w < 50 and 3 or 8
                fs:SetPoint("LEFT", xs[i] + padL, 0); fs:SetWidth(c.w - padL * 2)
                if book then fs:SetWordWrap(false) end -- one line per cell; long text shrinks to fit
                row.cells[i] = fs
            end
        end
        -- section heading: a rule under ink-coloured capitals, spanning the row
        row.rule = W.Fill(row, T.amber, "ARTWORK", 0.55); row.rule:SetPoint("BOTTOMLEFT", 4, 2); row.rule:SetPoint("BOTTOMRIGHT", -4, 2); row.rule:SetHeight(1); row.rule:Hide()
        row.heading = W.Text(row, 11, T.amber, nil, "LEFT"); row.heading:SetPoint("LEFT", 8, 0); row.heading:SetWidth(width - 16); row.heading:Hide()
        if book then W.Bold(row.heading, T.amber) end
        row:SetScript("OnEnter", function(self)
            local d = self.data
            if d and d.header then return end
            self.hl:Show()
            if not d or not (d.tip or d.what or d.tipTitle) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(d.tipTitle or d[1], ns.TipColor("amber"))
            if d.tip then GameTooltip:AddLine(d.tip, ns.TipColor("text", true)) end
            if d.what then GameTooltip:AddLine("Source: " .. d.what, ns.TipColor("dim", true)) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self) if onClick and self.data and not self.data.header then onClick(self.data) end end)
        f.rows[r] = row
    end
    local sb = W.Fill(f, T.bg, "BORDER"); sb:SetPoint("TOPRIGHT", 0, -HH); sb:SetSize(sbW, visible * RH)
    local thumb = W.Fill(f, T.amber, "ARTWORK"); thumb:SetWidth(sbW)
    local empty = W.Text(f, 11, T.dim); empty:SetPoint("TOP", 0, -HH - 12); empty:SetText(emptyText or "Nothing recorded yet")
    f.offset = 0
    f.data = {}
    function f:Render()
        local n = #self.data
        self.offset = math.max(0, math.min(self.offset, n - visible))
        for r = 1, visible do
            local row = self.rows[r]
            local d = self.data[r + self.offset]
            row.data = d
            local head = d and d.header
            row.zebra:SetShown(not head and ((r + self.offset) % 2) == 0)
            row.rule:SetShown(head and true or false)
            row.heading:SetShown(head and true or false)
            if head then row.heading:SetText((W.SmallCaps or string.upper)(d[1])) end
            for i, c in ipairs(cols) do
                local cell = row.cells[i]
                if head then
                    if c.kind == "bar" then cell.track:Hide(); cell.bar:Hide() else cell:SetText("") end
                elseif c.kind == "bar" then
                    local v = d and d[i] or nil
                    cell.track:SetShown(v ~= nil); cell.bar:SetShown(v ~= nil)
                    if v then cell.bar:SetWidth(math.max(1, cell.w * math.max(0, math.min(1, v)))) end
                else
                    cell:SetText(d and d[i] ~= nil and tostring(d[i]) or "")
                    if book and cell.SetShadowOffset then
                        if d and d.head and i == 2 then W.Bold(cell, T.amber) elseif c.kind ~= "num" then cell:SetShadowOffset(0, 0) end
                    end
                    if d and d.color and i == 1 then cell:SetTextColor(d.color[1], d.color[2], d.color[3])
                    elseif i == 1 and c.kind == "text" then cell:SetTextColor(T.text[1], T.text[2], T.text[3]) end
                end
            end
        end
        empty:SetShown(n == 0)
        if n > visible then
            sb:Show(); thumb:Show()
            local th = math.max(16, visible * RH * visible / n)
            thumb:SetHeight(th)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", sb, "TOPRIGHT", 0, -(visible * RH - th) * (self.offset / (n - visible)))
        else
            sb:Hide(); thumb:Hide()
        end
        if self.onScroll then pcall(self.onScroll, self) end
    end
    -- Scroll so data row i is at the top (section tabs use this).
    function f:ScrollTo(i)
        self.offset = math.max(0, (i or 1) - 1)
        self:Render()
    end
    -- Scroll so data row i is visible, a little below the top.
    function f:Reveal(i)
        if not i then return end
        if i <= self.offset or i > self.offset + visible then self.offset = math.max(0, i - 3) end
        self:Render()
    end
    f.visible = visible
    function f:SetData(data, keepOffset)
        self.data = data
        if not keepOffset then self.offset = 0 end
        self:Render()
    end
    function f:SetHeader(i, text) self.heads[i]:SetText(text) end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = self.offset - delta * 3
        self:Render()
    end)
    return f
end

-- Shrink a FontString one point at a time (down to 9) until its text fits its width,
-- instead of letting the game cut it with "...".
function W.FitText(fs, text, size)
    if not fs or not fs.GetStringWidth or not fs.GetWidth then return end
    local ok, w = pcall(fs.GetWidth, fs)
    if not ok or type(w) ~= "number" or w <= 0 then return end
    local font = (fs.GetFont and select(1, fs:GetFont())) or W.FONT
    size = size or (fs.GetFont and select(2, fs:GetFont())) or 12
    if type(size) ~= "number" then return end
    if type(rawget(fs, "fitBase")) ~= "number" then fs.fitBase = size end
    for s = fs.fitBase, 9, -0.5 do
        pcall(fs.SetFont, fs, font, s, "")
        if text then fs:SetText(text) end
        local sw = fs:GetStringWidth()
        if type(sw) ~= "number" or sw <= w then break end
    end
end

-- Called once the accent colour is known (after ADDON_LOADED).
function W.Init()
    if ns.accent2 then W.C.amber2 = ns.accent2 end
end

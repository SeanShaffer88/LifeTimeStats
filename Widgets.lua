-- LifeTimeStats - UI building blocks (Odometer theme)
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local ADDON, ns = ...

local T = ns.THEME
local W = {}
ns.W = W

W.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
W.WHITE = "Interface\\Buttons\\WHITE8x8"
W.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
W.NUM = "Fonts\\ARIALN.TTF"

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

function W.Text(parent, size, c, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or W.FONT, size or 12, "")
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

function W.Tip(owner, title, body, extra)
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(type(title) == "function" and title() or title, T.amber[1], T.amber[2], T.amber[3])
        local b = type(body) == "function" and body() or body
        if b then GameTooltip:AddLine(b, T.text[1], T.text[2], T.text[3], true) end
        if extra then GameTooltip:AddLine(extra, T.dim[1], T.dim[2], T.dim[3], true) end
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

function W.FlatButton(parent, label, w, h, tipTitle, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.bg = W.Fill(b, T.tile); b.bg:SetAllPoints()
    b.edge = W.Fill(b, T.amber, "BORDER"); b.edge:SetPoint("BOTTOMLEFT"); b.edge:SetPoint("BOTTOMRIGHT"); b.edge:SetHeight(1); b.edge:SetAlpha(0.5)
    b.text = W.Text(b, 11, T.text); b.text:SetPoint("CENTER"); b.text:SetText(label)
    b:SetScript("OnEnter", function() W.Color(b.bg, T.tileHi); b.edge:SetAlpha(1) end)
    b:SetScript("OnLeave", function() W.Color(b.bg, T.tile); b.edge:SetAlpha(0.5) end)
    if tip then W.Tip(b, tipTitle or label, tip) end
    return b
end

-- Segmented toggle: options = { {id, label, tip}, ... }
function W.Segmented(parent, options, onPick)
    local f = W.Panel(parent, T.bg)
    f.buttons = {}
    local x = 1
    for i, o in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b.text = W.Text(b, 11, T.dim); b.text:SetPoint("CENTER"); b.text:SetText(o.label)
        local w = math.max(56, b.text:GetStringWidth() + 20)
        b:SetSize(w, 22); b:SetPoint("LEFT", x, 0); x = x + w
        b.bg = W.Fill(b, T.tileHi); b.bg:SetAllPoints()
        b.bar = W.Fill(b, T.amber, "ARTWORK"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT"); b.bar:SetHeight(2)
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
            local c = on and T.amber or T.dim
            b.text:SetTextColor(c[1], c[2], c[3])
        end
    end
    return f
end

-- ------------------------------------------------------------ card
function W.Card(parent, title, icon, x, y, w, h, tip)
    local f = W.Panel(parent, T.tile)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(27)
    local rule = W.Line(head); rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)
    local ic = W.Icon(head, icon or "star", 14)
    ic:SetPoint("LEFT", 9, 0)
    f.title = W.Text(head, 12, T.text); f.title:SetPoint("LEFT", ic, "RIGHT", 8, 0)
    f.title:SetText(title:upper())
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
function W.Odometer(parent, x, y, w, h, label, icon, tip)
    local f = W.Panel(parent, T.tile)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
    local top = W.Fill(f, T.amber, "ARTWORK"); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(3)
    f.label = W.Text(f, 10, T.dim); f.label:SetPoint("TOPLEFT", 12, -10)
    f.icon = W.Icon(f, icon or "star", 26); f.icon:SetPoint("RIGHT", -14, -2)
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
    f.sub = W.Text(f, 10, ns.THEME.text); f.sub:SetPoint("BOTTOMLEFT", 12, 7); f.sub:SetPoint("RIGHT", f.icon, "LEFT", -6, 0)
    f:EnableMouse(true)
    f.tipTitle, f.tipBody = label, tip
    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(self.tipTitle, T.amber[1], T.amber[2], T.amber[3])
        if self.exact then GameTooltip:AddLine(self.exact, T.text[1], T.text[2], T.text[3]) end
        if self.tipBody then GameTooltip:AddLine(self.tipBody, T.dim[1], T.dim[2], T.dim[3], true) end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Configure(lbl, ic, tp)
        self.label:SetText(lbl:upper()); self.tipTitle = lbl; self.tipBody = tp
        self.icon:SetTexture(W.MEDIA .. "icons\\" .. ic)
    end
    function f:SetValue(v, sub, exact)
        v = math.max(0, math.floor((v or 0) + 0.5))
        local s = tostring(v)
        if #s > DIGITS then s = string.rep("9", DIGITS) end
        s = string.rep("0", DIGITS - #s) .. s
        local leading = true
        for i = 1, DIGITS do
            local ch = s:sub(i, i)
            if ch ~= "0" or i == DIGITS then leading = false end
            local cell = self.cells[i]
            cell.d:SetText(ch)
            if leading then cell.d:SetTextColor(T.dim[1], T.dim[2], T.dim[3], 0.12)
            else cell.d:SetTextColor(T.amber[1], T.amber[2], T.amber[3], 1) end
        end
        self.sub:SetText(sub or "")
        self.exact = exact
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
    local size = math.floor(math.min(bh, bw * 0.5, 150))
    local ring = W.TickRing(body, size, 72, math.floor(size / 9), 3)
    ring:SetPoint("RIGHT", body, "RIGHT", -6, 0)
    local rows = {}
    local step = math.min(21, math.floor((bh - 8) / 7))
    for i = 1, 7 do
        local sw = W.Fill(body, T.amber, "ARTWORK"); sw:SetSize(9, 9)
        sw:SetPoint("TOPLEFT", 2, -6 - (i - 1) * step)
        local tx = W.Text(body, 11, T.text); tx:SetPoint("LEFT", sw, "RIGHT", 6, 0)
        local val = W.Text(body, 12, T.amber, W.NUM, "RIGHT"); val:SetPoint("RIGHT", ring, "LEFT", -10, 0); val:SetPoint("TOP", sw, "TOP", 0, 2)
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
            GameTooltip:AddLine(o.labels[i] or "", T.amber[1], T.amber[2], T.amber[3])
            for s = 1, series do
                local name = o.seriesNames and o.seriesNames[s] or ""
                GameTooltip:AddDoubleLine(name, (o.fmt or ns.FormatInt)(o.values[i][s] or 0), T.text[1], T.text[2], T.text[3], T.amber[1], T.amber[2], T.amber[3])
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
function W.Table(body, bw, bh, cols, onClick)
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
    local head = W.Fill(f, { 0x1d / 255, 0x1f / 255, 0x23 / 255, 1 }, "BACKGROUND")
    head:SetPoint("TOPLEFT"); head:SetSize(width, HH)
    f.heads = {}
    for i, c in ipairs(cols) do
        local h = W.Text(f, 10, T.dim, nil, (c.kind == "num" or c.kind == "dim") and "RIGHT" or "LEFT")
        h:SetPoint("TOPLEFT", xs[i] + 8, -6); h:SetWidth(c.w - 16)
        h:SetText(c[1])
        f.heads[i] = h
    end
    local gridH = HH + visible * RH
    -- grid lines
    for i = 1, #cols + 1 do
        local l = W.Line(f, T.edge, "ARTWORK")
        l:SetPoint("TOPLEFT", (i <= #cols and xs[i] or width) - (i > #cols and 1 or 0), 0)
        l:SetSize(1, gridH)
    end
    for r = 0, visible + 1 do
        local l = W.Line(f, T.edge, "ARTWORK")
        l:SetPoint("TOPLEFT", 0, -(r == 0 and 0 or (HH + (r - 1) * RH)))
        l:SetSize(width, 1)
    end
    f.rows = {}
    for r = 1, visible do
        local row = CreateFrame("Button", nil, f)
        row:SetPoint("TOPLEFT", 0, -(HH + (r - 1) * RH))
        row:SetSize(width, RH)
        row.zebra = W.Fill(row, { 0x1f / 255, 0x22 / 255, 0x26 / 255, 1 }, "BACKGROUND")
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
                fs:SetPoint("LEFT", xs[i] + 8, 0); fs:SetWidth(c.w - 16)
                row.cells[i] = fs
            end
        end
        row:SetScript("OnEnter", function(self)
            self.hl:Show()
            local d = self.data
            if not d or not (d.tip or d.what or d.tipTitle) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(d.tipTitle or d[1], T.amber[1], T.amber[2], T.amber[3])
            if d.tip then GameTooltip:AddLine(d.tip, T.text[1], T.text[2], T.text[3], true) end
            if d.what then GameTooltip:AddLine("Source: " .. d.what, T.dim[1], T.dim[2], T.dim[3], true) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self) self.hl:Hide(); GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self) if onClick and self.data then onClick(self.data) end end)
        f.rows[r] = row
    end
    local sb = W.Fill(f, T.bg, "BORDER"); sb:SetPoint("TOPRIGHT", 0, -HH); sb:SetSize(sbW, visible * RH)
    local thumb = W.Fill(f, T.amber, "ARTWORK"); thumb:SetWidth(sbW)
    local empty = W.Text(f, 11, T.dim); empty:SetPoint("TOP", 0, -HH - 12); empty:SetText("Nothing recorded yet")
    f.offset = 0
    f.data = {}
    function f:Render()
        local n = #self.data
        self.offset = math.max(0, math.min(self.offset, n - visible))
        for r = 1, visible do
            local row = self.rows[r]
            local d = self.data[r + self.offset]
            row.data = d
            row.zebra:SetShown(((r + self.offset) % 2) == 0)
            for i, c in ipairs(cols) do
                local cell = row.cells[i]
                if c.kind == "bar" then
                    local v = d and d[i] or nil
                    cell.track:SetShown(v ~= nil); cell.bar:SetShown(v ~= nil)
                    if v then cell.bar:SetWidth(math.max(1, cell.w * math.max(0, math.min(1, v)))) end
                else
                    cell:SetText(d and d[i] ~= nil and tostring(d[i]) or "")
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
    end
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

-- Called once the accent colour is known (after ADDON_LOADED).
function W.Init()
    if ns.accent2 then W.C.amber2 = ns.accent2 end
end

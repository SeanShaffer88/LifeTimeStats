-- LifeTimeStats - text backup / restore
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
-- Format: "LTS2|<checksum>|" then "section.key=value" (flat) or "section.group.key=value"
-- (nested) entries joined by ";". Values are numbers, or text written as "s:<escaped>".
-- Importing only ever stores numbers and plain text, so it can never run code.
local _, ns = ...

local FLAT = { "c", "r", "f", "fw", "fd", "first", "firstd", "ach", "achr" }
local NESTED = { "t", "u", "days" }
local IS_FLAT, IS_NESTED = {}, {}
for _, k in ipairs(FLAT) do IS_FLAT[k] = true end
for _, k in ipairs(NESTED) do IS_NESTED[k] = true end

local function Esc(s)
    return (tostring(s):gsub("[%%;=%.|:%s]", function(ch) return string.format("%%%02X", ch:byte()) end))
end
local function Unesc(s)
    return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function Checksum(s)
    local sum = 0
    for i = 1, #s do sum = (sum * 31 + s:byte(i)) % 16777213 end
    return string.format("%06x", sum)
end

local function Val(v)
    if type(v) == "boolean" then return v and "1" or "0" end
    if type(v) == "string" then return "s:" .. Esc(v) end
    if v == math.floor(v) then return string.format("%d", v) end
    return string.format("%.3f", v)
end

local function SortedKeys(t)
    local keys = {}
    for k, v in pairs(t) do
        local tv = type(v)
        if tv == "number" or tv == "string" or tv == "boolean" or tv == "table" then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

function ns.Serialize(rec)
    local parts = {}
    for _, sec in ipairs(FLAT) do
        local t = rec[sec] or {}
        for _, k in ipairs(SortedKeys(t)) do
            if type(t[k]) ~= "table" then parts[#parts + 1] = sec .. "." .. Esc(k) .. "=" .. Val(t[k]) end
        end
    end
    for _, sec in ipairs(NESTED) do
        local t = rec[sec] or {}
        for _, g in ipairs(SortedKeys(t)) do
            local inner = t[g]
            if type(inner) == "table" then
                for _, k in ipairs(SortedKeys(inner)) do
                    if type(inner[k]) ~= "table" then
                        parts[#parts + 1] = sec .. "." .. Esc(g) .. "." .. Esc(k) .. "=" .. Val(inner[k])
                    end
                end
            end
        end
    end
    local body = table.concat(parts, ";")
    return "LTS2|" .. Checksum(body) .. "|" .. body
end

local function ParseValue(raw)
    if raw:sub(1, 2) == "s:" then return Unesc(raw:sub(3)) end
    if not raw:match("^%-?%d+%.?%d*$") then return nil end
    local n = tonumber(raw)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

-- Returns a record-like table, entry count — or nil, error.
function ns.Deserialize(str)
    if type(str) ~= "string" then return nil, "empty" end
    str = str:gsub("%s", "")
    local head, sum, body = str:match("^(LTS%d+)|(%x+)|(.*)$")
    if head ~= "LTS1" and head ~= "LTS2" then return nil, "not a LifeTimeStats backup" end
    if Checksum(body) ~= sum then return nil, "checksum mismatch (text was cut off or edited)" end
    local out = {}
    for _, k in ipairs(FLAT) do out[k] = {} end
    for _, k in ipairs(NESTED) do out[k] = {} end
    local n = 0
    for entry in body:gmatch("[^;]+") do
        local path, raw = entry:match("^([^=]+)=(.+)$")
        if not path then return nil, "malformed entry" end
        local val = ParseValue(raw)
        if val == nil then return nil, "malformed value" end
        local a, b, c = path:match("^([^%.]+)%.([^%.]+)%.?([^%.]*)$")
        if IS_FLAT[a] and c == "" then
            out[a][Unesc(b)] = val
        elseif IS_NESTED[a] and c ~= "" then
            local g = Unesc(b)
            out[a][g] = out[a][g] or {}
            out[a][g][Unesc(c)] = val
        else
            return nil, "malformed entry"
        end
        n = n + 1
    end
    -- Unique sets are stored as 1/true.
    for set, t in pairs(out.u) do for k, v in pairs(t) do t[k] = (v ~= 0) or nil end end
    return out, n
end

-- Restore never lowers anything: counters/records/tallies keep the larger number,
-- unique sets are unioned, fastest times keep the smaller time, firsts keep the earliest.
function ns.MergeMax(dst, src)
    ns.EnsureRecord(dst)
    local changed = 0
    for k, v in pairs(src.c or {}) do
        if type(v) == "number" and v > (dst.c[k] or 0) then dst.c[k] = v; changed = changed + 1 end
    end
    for k, v in pairs(src.r or {}) do
        if type(v) == "number" then
            if v > (dst.r[k] or 0) then
                dst.r[k] = v
                dst.r[k .. "_what"] = src.r[k .. "_what"]
                changed = changed + 1
            end
        end
    end
    for tn, t in pairs(src.t or {}) do
        dst.t[tn] = dst.t[tn] or {}
        for k, v in pairs(t) do
            if type(v) == "number" and v > (dst.t[tn][k] or 0) then dst.t[tn][k] = v; changed = changed + 1 end
        end
    end
    for set, t in pairs(src.u or {}) do
        dst.u[set] = dst.u[set] or {}
        for k in pairs(t) do
            if not dst.u[set][k] then dst.u[set][k] = true; changed = changed + 1 end
        end
    end
    for k, v in pairs(src.f or {}) do
        if type(v) == "number" and (not dst.f[k] or v < dst.f[k]) then
            dst.f[k], dst.fw[k], dst.fd[k] = v, (src.fw or {})[k], (src.fd or {})[k]
            changed = changed + 1
        end
    end
    for k, when in pairs(src.firstd or {}) do
        if type(when) == "number" and (not dst.firstd[k] or when < dst.firstd[k]) then
            dst.firstd[k], dst.first[k] = when, (src.first or {})[k]
            changed = changed + 1
        end
    end
    for k, when in pairs(src.ach or {}) do
        if type(when) == "number" and (not dst.ach[k] or when < dst.ach[k]) then
            dst.ach[k] = when
            dst.achr[k] = (src.achr or {})[k] and true or nil
            changed = changed + 1
        end
    end
    for d, day in pairs(src.days or {}) do
        dst.days[d] = dst.days[d] or {}
        for k, v in pairs(day) do
            if type(v) == "number" and v > (dst.days[d][k] or 0) then dst.days[d][k] = v end
        end
    end
    ns.EnsureRecord(dst) -- recount unique sets
    return changed
end

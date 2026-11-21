-- Bounded collection completeness and retained-window descriptions.
local _, ns = ...
local Retention = {}
ns.Retention = Retention
local MAX_COLLECTIONS = 256
local histories = {
    days = { limit = 40, date = "day", description = "Earlier daily totals are preserved in monthly rollups." },
    sessionlog = { limit = 300, date = "s" }, rh = { limit = 200, date = "at" },
    journal = { limit = 600, date = 1 }, runlog = { limit = 200, date = "s" },
    items = { limit = 1000, date = "t" }, quests = { limit = 1000, date = "t" },
    deathlog = { limit = 500, date = "t" },
}
Retention.Histories = histories

local function Plain(value)
    return type(value) == "table" and not ns.IsSecret(value) and getmetatable(value) == nil
end
local function Key(value)
    return type(value) == "string" and not ns.IsSecret(value) and #value > 0 and #value <= 96
        and value:match("^[%w_]+$") ~= nil
end

function Retention.ValidateSaved(value)
    if value == nil then return {} end
    if not Plain(value) then return nil, "invalid retention flags" end
    local clean = {}
    for kind, entries in pairs(value) do
        if kind ~= "u" and kind ~= "t" and kind ~= "h" then return nil, "unknown retention kind" end
        if not Plain(entries) then return nil, "invalid retention bucket" end
        local out, count = {}, 0
        for name, flag in pairs(entries) do
            count = count + 1
            if count > MAX_COLLECTIONS or not Key(name) or (flag ~= "omitted" and flag ~= "unknown") then return nil, "invalid retention flag" end
            if kind == "h" and not histories[name] then return nil, "unknown history" end
            out[name] = flag
        end
        clean[kind] = out
    end
    return clean
end

function Retention.Mark(record, kind, name, flag)
    if not record or not Key(name) or (kind ~= "u" and kind ~= "t" and kind ~= "h") then return end
    record.retention = record.retention or {}
    local flags = record.retention[kind]
    if not flags then flags = {}; record.retention[kind] = flags end
    if flags[name] == "omitted" then return end
    if flags[name] == nil then
        local count = 0; for _ in pairs(flags) do count = count + 1 end
        if count >= MAX_COLLECTIONS then return end
    end
    flags[name] = flag or "omitted"
end

function Retention.Repair(record)
    record.retention = Retention.ValidateSaved(record.retention) or {}
    for name, entries in pairs(record.u or {}) do
        if type(entries) == "table" then
            local keys = {}; for key in pairs(entries) do keys[#keys + 1] = key end
            if #keys >= ns.UNIQUE_CAP and not (record.retention.u and record.retention.u[name]) then
                -- Visibility only: legacy oversized sets and their totals remain intact.
                Retention.Mark(record, "u", name, "unknown")
            end
        end
    end
    for name, entries in pairs(record.t or {}) do
        local n = 0; for _ in pairs(type(entries) == "table" and entries or {}) do n = n + 1 end
        if n >= 400 and not (record.retention.t and record.retention.t[name]) then Retention.Mark(record, "t", name, "unknown") end
    end
end

local function Count(bucket)
    local n = 0; for _ in pairs(type(bucket) == "table" and bucket or {}) do n = n + 1 end
    return n
end

function Retention.Collection(record, kind, name)
    local bucket = record and record[kind] and record[kind][name]
    local kept, limit = Count(bucket), kind == "u" and (ns.UNIQUE_CAP or 20000) or 400
    local flag = record and record.retention and record.retention[kind] and record.retention[kind][name]
    if not flag and kept >= limit then flag = "unknown" end
    local text = kept .. "/" .. limit .. " retained"
    if flag == "omitted" then text = text .. "; new identities or labels were omitted."
    elseif flag then text = text .. "; cap reached, earlier omission history unknown."
    else text = text .. "; within the stored collection limit." end
    if kind == "t" then text = text .. " Ranking covers retained labels." end
    return { kept = kept, limit = limit, completeness = flag and "partial" or "retained",
        omitted = flag == "omitted", historicalUnknown = flag == "unknown",
        atLeast = kind == "u" and flag ~= nil, text = text }
end

function Retention.History(record, name)
    local descriptor = histories[name]
    if not descriptor then return nil end
    local entries = record and record[name] or {}
    local count, oldest, newest = 0, nil, nil
    for key, entry in pairs(type(entries) == "table" and entries or {}) do
        count = count + 1
        local stamp = descriptor.date == "day" and key or (type(entry) == "table" and entry[descriptor.date])
        if not ns.IsSecret(stamp) and ((descriptor.date == "day" and type(stamp) == "string")
            or (descriptor.date ~= "day" and type(stamp) == "number" and not ns.BadNumber(stamp) and stamp >= 0 and stamp <= 4102444800)) then
            if not oldest or stamp < oldest then oldest = stamp end
            if not newest or stamp > newest then newest = stamp end
        end
    end
    local flag = record and record.retention and record.retention.h and record.retention.h[name]
    local text = count .. "/" .. descriptor.limit .. " retained " .. name
    if oldest then
        local format = function(stamp) return type(stamp) == "number" and date("%b %d, %Y", stamp) or tostring(stamp) end
        text = text .. "; " .. format(oldest) .. " to " .. format(newest)
    end
    text = text .. ". " .. (descriptor.description or "This is a rolling retained window.")
    if flag == "omitted" then text = text .. " Earlier rows are unavailable."
    elseif flag or count >= descriptor.limit then text = text .. " At the storage limit; earlier omission history is unknown." end
    return { kept = count, limit = descriptor.limit, oldest = oldest, newest = newest, text = text, partial = flag ~= nil or count >= descriptor.limit }
end

function Retention.ForStat(stat, record)
    if stat.set then return Retention.Collection(record, "u", stat.set) end
    if stat.label2 or stat.id then return Retention.Collection(record, "t", stat.label2 or stat.id) end
    return Retention.History(record, stat.rec and "rh" or "days")
end

function Retention.Report(record)
    local lines = { "Retained data windows", "Lifetime aggregate counters are separate from retained identities, labels and histories." }
    for _, name in ipairs({ "days", "sessionlog", "rh", "journal", "runlog", "items", "quests", "deathlog" }) do
        lines[#lines + 1] = Retention.History(record, name).text
    end
    for kind, entries in pairs(record.retention or {}) do
        if kind ~= "h" then for name in pairs(entries) do lines[#lines + 1] = name .. ": " .. Retention.Collection(record, kind, name).text end end
    end
    return lines
end

function Retention.MergeFlags(destination, source)
    for kind, entries in pairs(source and source.retention or {}) do
        for name, flag in pairs(entries) do Retention.Mark(destination, kind, name, flag) end
    end
end

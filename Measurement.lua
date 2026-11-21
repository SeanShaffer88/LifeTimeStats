-- Measurement provenance and availability are distinct from numeric counters.
-- New metadata starts now; earlier totals never acquire invented source history.
local _, ns = ...
local Measurement = {}
ns.Measurement = Measurement
local catalog = ns.MeasurementCatalog
local MAX_TRANSITIONS = 8
local catalogEntries
local definitions = setmetatable({}, { __mode = "k" })
local families = {
    sampled = "Bounded movement, elapsed-time, state and fall observations; long gaps may be capped.",
    combat = "Combat log when permitted; otherwise readable combat text, health deltas and the client damage meter, by field.",
    kills = "Engaged-unit deaths and matching experience or honor messages, or combat-log kills when permitted.",
    economy = "Readable money changes, transaction context and matching loot/mail/vendor messages.",
    progress = "Quest, experience and level events, readable server totals and matching localized chat.",
    inventory = "Readable bag, item, equipment and collection APIs plus matching inventory events.",
    profession = "Successful gathering/crafting casts, skill events and matching skill/loot messages.",
    social = "Registered social/chat/group events, explicit UI hooks and sampled group observations.",
    spells = "Successful spellcast/form events and readable spell or power APIs.",
    world = "Zone/travel events, readable world APIs and bounded location/state observations.",
    milestones = "Recorded maxima, minima or first observations from the owning tracker; provider identifies the formula.",
    deaths = "Death/resurrection events, readable health changes and delayed client death-recap data.",
    life = "Registered life/activity events, explicit hooks and readable periodic character-state observations.",
    collections = "Retained identities or labels admitted by the owning event/API tracker.",
}
Measurement.Families = families
Measurement.TRANSITION_CAP = MAX_TRANSITIONS

local function Plain(value)
    return type(value) == "table" and not ns.IsSecret(value) and getmetatable(value) == nil
end
local function Timestamp(value)
    return not ns.IsSecret(value) and type(value) == "number" and value >= 0
        and value < math.huge and value == value and value <= 4133980800
end

local function Identity(stat, category)
    if category == "uniques" then return "unique:" .. stat.set end
    if category == "lists" then return "tally:" .. stat.id end
    if category == "firsts" then return "first:" .. stat.key end
    if category == "fastest" then return "fastest:" .. stat.key end
    if stat.label2 then return category .. ":top:" .. stat.label2 end
    if stat.get then return category .. ":computed:" .. stat.label end
    return category .. (stat.rec and ":record:" or ":counter:") .. (stat.rec or stat.key)
end

function Measurement.Catalog()
    local result = {}
    local function Add(stat, category)
        local id = Identity(stat, category)
        local reviewed = catalog[id]
        local definition = reviewed and {
            id = id, family = reviewed.family, quality = reviewed.quality, provider = reviewed.provider,
            source = families[reviewed.family], inputs = reviewed.inputs or stat.measurementInputs,
            computedPolicy = stat.get and (reviewed.computedPolicy or (stat.measurementInputs and "inputs") or "unknown-provider"),
            calculation = reviewed.calculation or stat.measurementCalculation or stat.tip
                or (stat.get and ("Reviewed computed provider " .. id) or (stat.rec and "Recorded maximum." or "Accumulated readable observations.")),
            availabilityPolicy = "registered-readable-feed", coveragePolicy = "since-recorded-provenance",
            category = category, key = stat.naKey or stat.key or stat.rec,
        }
        if definition then
            local key = definition.key or ""
            if key:match("^max_") and (category == "character" or key == "max_health" or key == "max_crit_pct" or key == "max_healpower") then
                definition.source = "Readable character API snapshots; records retain the highest observed value."
            elseif key == "casts" or key == "casts_success" then
                definition.source = "Successful player spellcast events; independent of combat-log access."
            end
            definitions[stat] = definition
        end
        result[#result + 1] = { stat = stat, id = id, definition = definition }
    end
    for category, list in pairs(ns.STATS) do for _, stat in ipairs(list) do Add(stat, category) end end
    for _, pair in ipairs({ { "uniques", ns.UNIQUES }, { "lists", ns.LISTS },
        { "fastest", ns.FASTEST }, { "firsts", ns.FIRSTS } }) do
        for _, stat in ipairs(pair[2] or {}) do Add(stat, pair[1]) end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    catalogEntries = result
    return result
end

function Measurement.Definition(stat)
    if not stat then return nil end
    if definitions[stat] then return definitions[stat] end
    if not catalogEntries then Measurement.Catalog() end
    if definitions[stat] then return definitions[stat] end
    for _, entry in ipairs(catalogEntries) do
        if (stat.key and entry.stat.key == stat.key) or (stat.rec and entry.stat.rec == stat.rec) then return entry.definition end
    end
end

local function Current(definition, stat)
    if stat.get then
        if definition.computedPolicy ~= "inputs" or not definition.inputs or #definition.inputs == 0 then
            return "unknown", "The named computed provider's current input coverage is not verified."
        end
        local unknown = false
        for _, input in ipairs(definition.inputs) do
            local kind, key = input:match("^(%a):(.+)$")
            if kind == "c" or kind == "r" then
                local state = Current({ key = key }, {})
                if state == "unavailable" then return "unavailable", "A required computed input is unavailable: " .. key end
                if state ~= "available" then unknown = true end
            elseif kind ~= "u" and kind ~= "t" and kind ~= "h" then unknown = true end
        end
        if unknown then return "unknown", "Current coverage of one or more computed inputs is unverified." end
    end
    local key = definition.key
    if key == "max_health" then
        local ok, value = pcall(function() return UnitHealthMax("player") end)
        if not ok or ns.IsSecret(value) or ns.BadNumber(value) then return "unavailable", "Maximum-health API is unreadable." end
        return "available"
    end
    local src, settings = ns.src or {}, ns.settings or {}
    if stat.expandedSource and (src[stat.expandedSource .. "Hidden"] or 0) > 0
        and not src[stat.expandedSource] then return "unavailable", "The sampled input is restricted." end
    if key and ns.CombatLogRestricted() then
        local combatText = key == "hits" or key == "crits" or key == "hits_taken" or key == "crits_taken"
            or key == "in_dodge" or key == "in_parry" or key == "in_block" or key == "in_miss"
        if combatText then
            if ns.eventStatus.UNIT_COMBAT == "rejected" then return "unavailable", "Client rejected combat text events." end
            if (src.ucPlayer or 0) == 0 and (src.ucTarget or 0) == 0 then
                return "unknown", "Combat text is registered; readable hit/avoidance flags have not been established."
            end
        end
        local meter = src.dmReadable or settings.dmReadable
        if ns.DM_KEYS and ns.DM_KEYS[key] then
            if meter then return "available" end
            if key == "dmg_done" and (src.amountReadable or not settings.amountsSecret) then
                return "available", "Readable outgoing combat text is the fallback; client-meter coverage is not established."
            end
            if C_DamageMeter then return "unknown", "Client meter exists but readable coverage has not been established." end
            return "unavailable", "Client damage meter is unavailable and this field has no readable fallback."
        end
        if ns.CLEU_ONLY and ns.CLEU_ONLY[key] and not (ns.DM_KEYS and ns.DM_KEYS[key] and meter) then
            return "unavailable", "This field requires the restricted combat log."
        end
        if ns.AMOUNT_KEYS and ns.AMOUNT_KEYS[key] and settings.amountsSecret and not src.amountReadable then
            return "unavailable", "Combat amount input is restricted."
        end
        if ns.HEALTH_KEYS and ns.HEALTH_KEYS[key] and settings.healthSecret and settings.amountsSecret then
            return "unavailable", "Health and combat amount inputs are restricted."
        end
    end
    if key and (key:match("^dist_") or key == "max_speed") and type(GetUnitSpeed) ~= "function"
        and type(UnitPosition) ~= "function" then return "unavailable", "Movement APIs are unavailable." end
    if definition.family == "spells" and ns.eventStatus.UNIT_SPELLCAST_SUCCEEDED == "rejected" then
        return "unavailable", "The client rejected the spellcast event."
    end
    return "available"
end

function Measurement.ValidateSaved(value)
    if value == nil then return {} end
    if not Plain(value) then return nil, "invalid measurement metadata" end
    local out, count = {}, 0
    for key, item in pairs(value) do
        if key == "started" then if not Timestamp(item) then return nil, "invalid observation start" end; out.started = item
        elseif key == "historicalUnknown" then if type(item) ~= "boolean" then return nil, "invalid historical status" end; out.historicalUnknown = item
        elseif key == "families" then
            if not Plain(item) then return nil, "invalid source families" end
            out.families = {}
            for family, record in pairs(item) do
                count = count + 1
                if count > 14 or not families[family] or not Plain(record) then return nil, "unknown source family" end
                local copied = {}
                for field, entry in pairs(record) do
                    if field == "capped" then if type(entry) ~= "boolean" then return nil, "invalid transition cap" end; copied.capped = entry
                    elseif field == "transitions" then
                        if not Plain(entry) or #entry > MAX_TRANSITIONS then return nil, "invalid source transitions" end
                        copied.transitions = {}
                        local n = 0
                        for index, transition in pairs(entry) do
                            n = n + 1
                            if type(index) ~= "number" or index < 1 or index > #entry or index ~= math.floor(index)
                                or not Plain(transition) or not Timestamp(transition.at)
                                or (transition.state ~= "available" and transition.state ~= "unavailable" and transition.state ~= "unknown") then
                                return nil, "invalid source transition"
                            end
                            for k in pairs(transition) do if k ~= "at" and k ~= "state" then return nil, "unknown transition field" end end
                            copied.transitions[index] = { at = transition.at, state = transition.state }
                        end
                        if n ~= #entry then return nil, "sparse source transitions" end
                    else return nil, "unknown source record field" end
                end
                out.families[family] = copied
            end
        else return nil, "unknown measurement field" end
    end
    return out
end

function Measurement.Initialize(record, isNew)
    local clean = Measurement.ValidateSaved(record.measurement)
    if not clean or not clean.started then
        clean = { started = time(), historicalUnknown = not isNew, families = {} }
    end
    clean.families = clean.families or {}
    record.measurement = clean
end

local function Capture()
    if not ns.char then return end
    local metadata = ns.char.measurement
    if not metadata or not metadata.started then return end
    for family in pairs(families) do
        local state = "available"
        if family == "combat" and ns.CombatLogRestricted() then
            state = C_DamageMeter and "available" or "unknown"
        end
        local record = metadata.families[family]
        if not record then record = { transitions = {} }; metadata.families[family] = record end
        local transitions = record.transitions
        local last = transitions[#transitions]
        if not last or last.state ~= state then
            transitions[#transitions + 1] = { at = time(), state = state }
            if #transitions > MAX_TRANSITIONS then table.remove(transitions, 1); record.capped = true end
        end
    end
end

function Measurement.Resolve(stat, view, context)
    local definition = Measurement.Definition(stat)
    if not definition then return { availability = "unknown", quality = "historical-unknown", source = "Definition has no reviewed measurement policy." } end
    context = context or {}
    if not view then return { availability = "unknown", quality = "historical-unknown", source = definition.source, definition = definition } end
    local current, reason = Current(definition, stat)
    local function Value()
        if definition.category == "uniques" then return (view.un or {})[stat.set] or 0 end
        if definition.category == "fastest" then local v = (view.f or {})[stat.key]; return type(v) == "table" and v.v or v end
        if definition.category == "firsts" then return (view.firstd or {})[stat.key] end
        if definition.category == "lists" then
            if stat.count then return stat.count(view) end
            local n = 0; for _ in pairs((view.t or {})[stat.id] or {}) do n = n + 1 end; return n
        end
        return ns.StatValue(stat, view)
    end
    local ok, numeric = pcall(Value)
    if not ok or ns.IsSecret(numeric) or ns.BadNumber(numeric) then numeric = nil end
    if stat.rec and (not view.r or view.r[stat.rec] == nil) then numeric = nil; reason = "No record has been retained yet." end
    local metadata = view.measurement
    local session = view == ns.session or context.scope == "session"
    local legacy = not session and (not metadata or metadata.historicalUnknown ~= false)
    local availability = current
    if current == "unavailable" and numeric and (numeric ~= 0 or (stat.rec and view.r and view.r[stat.rec] ~= nil)) and not session then availability = "unknown" end
    if numeric == nil then availability = "unknown" end
    local result = { definition = definition, availability = availability, currentAvailability = current,
        quality = legacy and "historical-unknown" or definition.quality, source = definition.source,
        calculation = definition.calculation, reason = reason, historicalUnknown = legacy,
        started = session and Timestamp(view.wallStart) and view.wallStart or (metadata and metadata.started), untilAt = time(),
        sessionCharacter = session and (ns.char and ns.char.meta.name), value = numeric,
        retention = ns.Retention and ns.Retention.ForStat(stat, view) or nil }
    if context.scope == "account" then
        local states, count = {}, 0
        for _, member in pairs(ns.db and ns.db.chars or {}) do
            if ns.ValidRecord(member) then
                local state = Measurement.Resolve(stat, member)
                states[state.availability .. ":" .. state.quality] = true
                count = count + 1
            end
        end
        local kinds = 0; for _ in pairs(states) do kinds = kinds + 1 end
        result.availability = kinds > 1 and "mixed" or (count == 0 and "unknown" or availability)
        result.quality = "historical-unknown"
    end
    return result
end

function Measurement.Text(status)
    local text = status.availability .. " · " .. status.quality .. "\n" .. status.source
    if status.currentAvailability and status.currentAvailability ~= status.availability then text = text .. "\nCurrent feed: " .. status.currentAvailability end
    if status.calculation then text = text .. "\nCalculation: " .. status.calculation end
    if status.reason then text = text .. "\n" .. status.reason end
    if status.historicalUnknown then text = text .. "\nEarlier historical source coverage is unknown." end
    if status.started then text = text .. "\nProvenance since " .. date("%b %d, %Y", status.started) end
    if status.sessionCharacter then text = text .. "\nSession belongs to " .. status.sessionCharacter .. "." end
    if status.retention and status.retention.text then text = text .. "\n" .. status.retention.text end
    return text
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED" }) do ns.On(event, Capture) end

-- Fixed two-line header; the complete report remains available through Text.
function Measurement.Summary(status)
    local second = status.currentAvailability and status.currentAvailability ~= status.availability and ("Current feed: " .. status.currentAvailability)
        or (status.historicalUnknown and "Earlier source coverage unknown") or "Source, formula and retained window in details"
    return status.availability .. " · " .. status.quality .. "\n" .. second
end

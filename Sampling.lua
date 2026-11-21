-- One frame entry point for bounded, independently guarded periodic observations.
local _, ns = ...
local Sampling = {}
ns.Sampling = Sampling
local tasks, byID, falls = {}, {}, {}
local frame = CreateFrame("Frame")
local running, falling, taxiActive = false, false, false
local taxiObserver
local counts = { frames = 0, tasks = 0, fall = 0 }

function Sampling.Register(id, period, callback)
    assert(type(id) == "string" and type(period) == "number" and period > 0 and type(callback) == "function")
    local old = byID[id]
    if old then old.callback, old.period = callback, period; return end
    local task = { id = id, period = period, callback = callback, elapsed = 0, enabled = true }
    tasks[#tasks + 1], byID[id] = task, task
end

function Sampling.Unregister(id)
    local task = byID[id]
    if not task then return end
    byID[id] = nil
    for i, item in ipairs(tasks) do if item == task then table.remove(tasks, i); break end end
end

function Sampling.ObserveFalls(id, callback, reset)
    assert(type(id) == "string" and type(callback) == "function")
    falls[id] = { callback = callback, reset = reset }
end

function Sampling.ObserveTaxi(callback, reset)
    assert(type(callback) == "function")
    taxiObserver = { callback = callback, reset = reset }
end
local function ResetTaxi()
    taxiActive = false
    if taxiObserver and taxiObserver.reset then
        local ok, err = pcall(taxiObserver.reset)
        if not ok then ns.LogError("sample:taxi-reset", err) end
    end
end
local function ObserveTaxi()
    local ok, value = pcall(UnitOnTaxi, "player")
    if not ok or ns.IsSecret(value) then ResetTaxi(); return end
    local active = value == true
    if taxiObserver and (active or taxiActive) then
        local success, err = pcall(taxiObserver.callback)
        if not success then ns.LogError("sample:taxi", err) end
    end
    taxiActive = active
end
local function ResetFall()
    falling = false
    for id, observer in pairs(falls) do
        if observer.reset then
            local ok, err = pcall(observer.reset)
            if not ok then ns.LogError("sample:fall-reset:" .. id, err) end
        end
    end
end

local function ObserveFall()
    -- A shared cheap probe preserves short-fall onset fidelity without a
    -- separate idle frame callback. Health and airtime work runs only in flight.
    local ok, value = pcall(IsFalling)
    if not ok or ns.IsSecret(value) then
        ResetFall()
        return
    end
    local active = value == true
    if active or falling then
        for id, observer in pairs(falls) do
            counts.fall = counts.fall + 1
            local success, err = pcall(observer.callback)
            if not success then ns.LogError("sample:fall:" .. id, err) end
        end
    end
    falling = active
end

local function Update(_, elapsed)
    if not ns.char then ResetFall(); ResetTaxi(); return end
    if ns.IsSecret(elapsed) or ns.BadNumber(elapsed) or elapsed < 0 then return end
    counts.frames = counts.frames + 1
    ObserveFall()
    ObserveTaxi()
    for _, task in ipairs(tasks) do
        if task.enabled then
            task.elapsed = task.elapsed + elapsed
            if task.elapsed >= task.period then
                local dt = task.elapsed
                task.elapsed = 0
                counts.tasks = counts.tasks + 1
                local ok, err = pcall(task.callback, nil, dt)
                if not ok then ns.LogError("sample:" .. task.id, err) end
            end
        end
    end
end

function Sampling.Start()
    if running or not ns.char then return end
    running = true
    frame:SetScript("OnUpdate", Update)
end

function Sampling.Stop()
    running = false
    ResetFall()
    ResetTaxi()
    frame:SetScript("OnUpdate", nil)
    for _, task in ipairs(tasks) do task.elapsed = 0 end
end

function Sampling.Status()
    return { running = running, falling = falling, frames = counts.frames,
        taskCalls = counts.tasks, fallCalls = counts.fall, registered = #tasks }
end

ns.On("ADDON_LOADED", function(_, name)
    if name == ns.ADDON_NAME or name == "LifeTimeStats" then Sampling.Start() end
end)
ns.On("PLAYER_ENTERING_WORLD", function() ResetFall(); ResetTaxi(); Sampling.Start() end)
ns.On("PLAYER_LEAVING_WORLD", Sampling.Stop)
ns.On("PLAYER_LOGOUT", Sampling.Stop)

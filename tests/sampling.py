"""Coordinated observation contracts against the real Lua modules and mock APIs."""
from pathlib import Path
from lupa import lua51
ROOT = Path(__file__).resolve().parent.parent
lua = lua51.LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
lua.execute("ns = {}")
for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
    if name.strip().endswith(".lua"):
        lua.execute((ROOT / name.strip()).read_text(encoding="utf-8"), "LifeTimeStats", lua.globals().ns)
lua.execute(r'''
local checks = 0
local function check(condition, message)
  checks = checks + 1
  assert(condition, message)
end
local function fire(event, ...) ns.frame.scripts.OnEvent(ns.frame, event, ...) end
local function update(elapsed)
  NOW = NOW + elapsed
  for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, elapsed) end end
end
check(not ns.Sampling.Status().running, "loading modules must not start observations")
fire("ADDON_LOADED", "LifeTimeStats")
fire("PLAYER_ENTERING_WORLD", true, false)
check(ns.Sampling.Status().running, "character initialization starts the dispatcher")
local falls = ns.Sampling.Status().fallCalls
for i = 1, 100 do update(0.01) end
check(ns.Sampling.Status().fallCalls == falls, "idle frames never call heavy fall observers")
local before = ns.char.c.airtime or 0
state.falling = true
for i = 1, 18 do update(1/60) end
state.falling = false
update(1/60)
check(math.abs((ns.char.c.airtime or 0) - before - 0.3) < 0.000001, "short falls preserve frame-level airtime")
local total = ns.char.c.airtime
state.falling = true; update(0.02)
fire("PLAYER_LEAVING_WORLD")
check(not ns.Sampling.Status().running and not ns.Sampling.Status().falling, "world leave resets the observer")
NOW = NOW + 30; state.falling = false
fire("PLAYER_ENTERING_WORLD", false, false); update(0.02)
check(ns.char.c.airtime == total, "world reentry cannot record a phantom long fall")
state.falling = true; update(0.02)
local original = IsFalling
IsFalling = function() error("restricted falling input") end
update(0.02)
IsFalling = original
state.falling = false; update(0.02)
check(ns.char.c.airtime == total and not ns.Sampling.Status().falling, "failed input resets both observer domains")
local called = 0
ns.Sampling.Register("audit-error", 0.25, function() error("intentional sample error") end)
ns.Sampling.Register("audit-other", 0.25, function(_, elapsed) called = called + elapsed end)
local errors = #ns.errors
update(0.5)
check(called == 0.5 and #ns.errors == errors + 1, "one task failure cannot block other tracking")
ns.Sampling.Unregister("audit-error")
ns.Sampling.Unregister("audit-other")
table.remove(ns.errors)
local baseline = ns.Sampling.Status().registered
for i=1,100 do ns.Sampling.Register("audit-reused", 1, function() end); ns.Sampling.Unregister("audit-reused") end
check(ns.Sampling.Status().registered == baseline, "register/unregister reuse does not leak tasks")
state.taxi=true
for i=1,318 do update(1/60) end
state.taxi=false; update(1/60)
check(math.abs(ns.char.r.flight_long - 5.3) < 0.000001, "flight endpoints retain frame fidelity")
state.taxi=true;update(0.1);fire("PLAYER_LEAVING_WORLD");state.taxi=false;fire("PLAYER_ENTERING_WORLD",false,false);update(0.1)
check(math.abs(ns.char.r.flight_long - 5.3) < 0.000001, "world transition resets flight duration")
local online = ns.char.c.time_online or 0
local distance = ns.char.c.dist_total or 0
state.speed = 7
update(3600)
check((ns.char.c.time_online or 0) - online <= 120, "suspended time remains capped")
check((ns.char.c.dist_total or 0) == distance, "suspension cannot add movement")
fire("PLAYER_LOGOUT")
check(not ns.Sampling.Status().running, "logout stops the dispatcher")
print("SAMPLING PASS: " .. checks .. " assertions")
''')

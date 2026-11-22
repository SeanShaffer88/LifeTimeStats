"""Offline regression tests for the standalone login recap and its preferences."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parents[1]


def runtime():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
    lua.execute("""
        ns = {}; chunks = {}
        local make = CreateFrame
        function CreateFrame(kind, name, parent, template)
            local frame = make(kind, name, parent, template)
            frame.testName, frame.testParent, frame.testKind = name, parent, kind
            function frame:SetChecked(value) self.testChecked = value and true or false end
            function frame:GetChecked() return self.testChecked or false end
            function frame:SetScale(value) self.testScale = value end
            if name then _G[name] = frame end
            return frame
        end
        function eq(actual, expected, label)
            assert(actual == expected, label .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
        end
        function fire(event, ...)
            local frame = ns.frame
            frame.scripts.OnEvent(frame, event, ...)
        end
        function advance(seconds) NOW = NOW + seconds; RunTimers() end
    """)
    for name in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
        name = name.strip()
        if name.endswith(".lua"):
            chunk = lua.eval("function(s,n) return assert(loadstring(s,n)) end")(
                (ROOT / name).read_text(encoding="utf-8"), name
            )
            lua.globals().chunks[len(lua.globals().chunks) + 1] = chunk
            chunk("LifeTimeStats", lua.globals().ns)
    lua.execute("""
        fire("ADDON_LOADED", "LifeTimeStats")
        timers = {}
        previous = { c = { kills_npc = 12, quests_done = 2 }, elapsed = 600, at = time() }
        LifeTimeStatsCharDB.lastSession = previous
    """)
    return lua


CASES = {
    "login delay and standalone routing": """
        local calls, oldCalls = 0, 0
        ns.ShowLoginRecap = function() calls = calls + 1 end
        ns.ShowSessionSummary = function() oldCalls = oldCalls + 1 end
        fire("PLAYER_ENTERING_WORLD", true, false)
        advance(3.9)
        eq(calls, 0, "no early popup")
        advance(0.1)
        eq(calls, 1, "ten minute session opens recap at four seconds")
        eq(oldCalls, 0, "automatic login uses standalone recap")
        fire("PLAYER_ENTERING_WORLD", true, false)
        fire("PLAYER_ENTERING_WORLD", true, false)
        advance(4)
        eq(calls, 2, "duplicate pending world entries show one recap")
    """,
    "eligibility and malformed saved elapsed": """
        local calls = 0
        ns.ShowLoginRecap = function() calls = calls + 1 end
        for _, elapsed in ipairs({599, -1, "600", math.huge, 0/0}) do
            timers = {}; previous.elapsed = elapsed
            fire("PLAYER_ENTERING_WORLD", true, false); advance(4)
        end
        previous.elapsed = nil
        fire("PLAYER_ENTERING_WORLD", true, false); advance(4)
        previous.elapsed = 600
        fire("PLAYER_ENTERING_WORLD", false, true); advance(4)
        ns.settings.recapWindow = false
        fire("PLAYER_ENTERING_WORLD", true, false); advance(4)
        eq(calls, 0, "ineligible sessions do not open recap")
        eq(#ns.errors, 0, "malformed elapsed has no handler error")
    """,
    "pending recap cancellation": """
        local calls = 0
        ns.ShowLoginRecap = function() calls = calls + 1 end
        fire("PLAYER_ENTERING_WORLD", true, false)
        ns.settings.recapWindow = false; advance(4)
        ns.settings.recapWindow = true
        fire("PLAYER_ENTERING_WORLD", true, false)
        ns.charKey = "Other-Realm"; advance(4)
        ns.charKey = "Original-Realm"
        fire("PLAYER_ENTERING_WORLD", true, false)
        ns.char = ns.NewCharRecord(); advance(4)
        fire("PLAYER_ENTERING_WORLD", true, false)
        LifeTimeStatsCharDB.lastSession = { c = {}, elapsed = 900 }; advance(4)
        fire("PLAYER_ENTERING_WORLD", true, false)
        LifeTimeStatsCharDB.lastSession.elapsed = 599; advance(4)
        eq(calls, 0, "changed settings, character or saved session cancels pending popup")
    """,
    "optional timer and renderer failures": """
        local calls = 0
        C_Timer.After = nil
        ns.ShowLoginRecap = function() calls = calls + 1 end
        fire("PLAYER_ENTERING_WORLD", true, false)
        eq(calls, 0, "missing timer skips recap")
        for _, message in ipairs(ns.errors) do
            assert(not message:find("login:recap-window", 1, true), "missing timer does not fail recap")
        end
        ns.errors = {}
        C_Timer.After = function(delay, fn) timers[#timers + 1] = {t = NOW + delay, f = fn} end
        ns.ShowLoginRecap = function() error("expected recap render failure") end
        fire("PLAYER_ENTERING_WORLD", true, false)
        advance(4)
        eq(#ns.errors, 1, "renderer error recorded once")
        assert(ns.errors[1]:find("login:recap-window", 1, true), "error identifies login recap")
    """,
    "standalone UI and opt-out": """
        assert(type(ns.ShowLoginRecap) == "function", "ShowLoginRecap API missing")
        eq(ns.ShowLoginRecap(), true, "open login recap")
        local popup = assert(ns.loginRecap, "standalone recap frame exposed")
        eq(popup.testParent, UIParent, "standalone parent")
        eq(_G.LifeTimeStatsWindow, nil, "main window stays unopened")
        eq(popup:IsShown(), true, "popup shown")
        local registered = false
        for _, name in ipairs(UISpecialFrames) do if name == "LifeTimeStatsLoginRecap" then registered = true end end
        eq(registered, true, "Escape registration")
        local chat = ns.settings.recap
        popup.optOut:SetChecked(true); popup.optOut.scripts.OnClick(popup.optOut)
        eq(ns.settings.recapWindow, false, "checkbox immediately opts out")
        eq(ns.settings.recap, chat, "popup opt-out preserves chat preference")
        popup.optOut:SetChecked(false); popup.optOut.scripts.OnClick(popup.optOut)
        eq(ns.settings.recapWindow, true, "unchecked permits next recap")
        popup.continue.scripts.OnClick(popup.continue)
        eq(popup:IsShown(), false, "Continue dismisses")
        eq(ns.settings.recapWindow, true, "Continue preserves preference")
        ns.settings.recapWindow = false
        ns.ShowLoginRecap()
        eq(popup.optOut:GetChecked(), true, "opening resynchronizes checkbox")
        popup.journal.scripts.OnClick(popup.journal)
        assert(_G.LifeTimeStatsWindow and _G.LifeTimeStatsWindow:IsShown(), "explicit Journal action opens main window")
        local summaries = 0
        ns.ShowSessionClosing = function() summaries = summaries + 1 end
        ns.ShowSessionSummary(true)
        eq(summaries, 1, "manual summary remains available after opting out")
    """,
    "opt-out persists through save and addon reload": """
        assert(type(ns.ShowLoginRecap) == "function", "ShowLoginRecap API missing")
        ns.ShowLoginRecap()
        ns.loginRecap.optOut:SetChecked(true)
        ns.loginRecap.optOut.scripts.OnClick(ns.loginRecap.optOut)
        local chat = ns.settings.recap
        ns.Save()
        ns = {}
        for _, chunk in ipairs(chunks) do chunk("LifeTimeStats", ns) end
        fire("ADDON_LOADED", "LifeTimeStats")
        eq(ns.settings.recapWindow, false, "opt-out survives reload")
        eq(ns.settings.recap, chat, "chat preference survives independently")
    """,
    "small-screen fit and immutable displayed contents": """
        assert(type(ns.ShowLoginRecap) == "function", "ShowLoginRecap API missing")
        function UIParent:GetWidth() return 320 end
        function UIParent:GetHeight() return 400 end
        ns.settings.window.scale = 1.5
        previous.closing = {
            zones = { "Durotar |cffff0000 literal " .. string.rep("long zone ", 12) },
            bosses = { "A saved boss" }, notes = 2, complete = true,
        }
        previous.highlights = { "New best |Hspell:123|hrecord|h" }
        assert(ns.ShowLoginRecap())
        local popup = ns.loginRecap
        assert(popup.testScale * 532 <= 320, "popup fits available width")
        assert(popup.testScale * 528 <= 400, "popup fits available height")
        eq(ns.settings.window.scale, 1.5, "fit preserves saved main-window scale")
        local count = popup.counts[2]:GetText()
        local zone, highlight = popup.sections[1].full, popup.sections[3].full
        assert(zone:find("||cffff0000", 1, true), "saved zone markup is escaped literally")
        assert(highlight:find("||Hspell:123", 1, true), "saved record markup is escaped literally")
        previous.c.kills_npc = 999
        previous.closing.zones[1] = "Changed zone"
        previous.highlights[1] = "Changed record"
        eq(popup.counts[2]:GetText(), count, "displayed totals are a snapshot")
        eq(popup.sections[1].full, zone, "zone tooltip remains a snapshot")
        eq(popup.sections[3].full, highlight, "record tooltip remains a snapshot")
        local before = popup
        assert(ns.ShowLoginRecap())
        eq(ns.loginRecap, before, "repeat show reuses standalone frame")
        local registrations = 0
        for _, name in ipairs(UISpecialFrames) do if name == "LifeTimeStatsLoginRecap" then registrations = registrations + 1 end end
        eq(registrations, 1, "repeat show keeps one Escape registration")
        eq(_G.LifeTimeStatsWindow, nil, "small-screen popup stays independent of main")
    """,
    "portable and older preference backups": """
        ns.settings.recapWindow = false
        local text = ns.SerializePreferences()
        local values = assert(ns.DeserializePreferences(text))
        eq(values.recapWindow, false, "new preference format retains opt-out")
        ns.settings.recapWindow = true
        local preview = assert(ns.ReadPreferencesBackup(text))
        assert(preview.apply())
        eq(ns.settings.recapWindow, false, "new preference restore applies popup flag")
        local body, sum = "recap=true", 0
        for i = 1, #body do sum = (sum * 31 + body:byte(i)) % 16777213 end
        local old = "LTSP1|" .. string.format("%06x", sum) .. "|" .. body
        local legacy = assert(ns.ReadPreferencesBackup(old))
        assert(legacy.apply())
        eq(ns.settings.recapWindow, false, "old preferences preserve popup flag")
        ns.settings.recapWindow = nil
        local oldTwo = ns.SerializePreferences()
        eq(oldTwo:sub(1, 6), "LTSP2|", "portable preference format remains LTSP2")
        ns.settings.recapWindow = false
        local oldTwoPreview = assert(ns.ReadPreferencesBackup(oldTwo))
        assert(oldTwoPreview.apply())
        eq(ns.settings.recapWindow, false, "older LTSP2 without popup flag preserves current choice")
    """,
    "independent settings controls": """
        local controls, text = {}, ns.W.Text
        ns.W.Text = function(parent, ...)
            local value = text(parent, ...)
            local setText = value.SetText
            value.SetText = function(self, label)
                controls[label] = parent
                setText(self, label)
            end
            return value
        end
        ns.CreateOptions()
        local chat = assert(controls["Login recap in chat"], "chat setting exists")
        local popup = assert(controls["Session window at login"], "popup setting exists")
        ns.settings.recap, ns.settings.recapWindow = true, true
        chat.scripts.OnClick(chat)
        eq(ns.settings.recap, false, "chat toggle changes chat")
        eq(ns.settings.recapWindow, true, "chat toggle preserves popup")
        popup.scripts.OnClick(popup)
        eq(ns.settings.recapWindow, false, "popup toggle changes popup")
        eq(ns.settings.recap, false, "popup toggle preserves chat")
    """,
}

failures = []
for name, case in CASES.items():
    try:
        runtime().execute(case)
        print(f"PASS {name}")
    except Exception as exc:
        failures.append(name)
        print(f"FAIL {name}: {exc}")
if failures:
    raise SystemExit(f"LOGIN RECAP FAIL: {len(failures)} of {len(CASES)} cases")
print(f"LOGIN RECAP PASS: {len(CASES)} cases")

"""Offline regressions for Journal search, favorites, chapters and restore recovery."""

from pathlib import Path

from lupa import lua51

ROOT = Path(__file__).resolve().parents[1]


def runtime():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((ROOT / "tests/harness.lua").read_text(encoding="utf-8"))
    lua.execute("""
        ns = {}
        local make = CreateFrame
        function CreateFrame(kind, name, parent, template)
            local frame = make(kind, name, parent, template)
            frame.testParent, frame.testKind = parent, kind
            return frame
        end
    """)
    for line in (ROOT / "LifeTimeStats.toc").read_text(encoding="utf-8").splitlines():
        name = line.strip()
        if name.endswith(".lua"):
            chunk = lua.eval("function(s,n) return assert(loadstring(s,n)) end")(
                (ROOT / name).read_text(encoding="utf-8"), name
            )
            chunk("LifeTimeStats", lua.globals().ns)
    lua.execute("""
        function fire(event, ...)
            local frame = ns.frame
            frame.scripts.OnEvent(frame, event, ...)
        end
        function eq(actual, expected, why)
            assert(actual == expected, why .. ": got " .. tostring(actual) .. ", expected " .. tostring(expected))
        end
        function pump()
            for i = 1, 200 do
                if #timers == 0 then return end
                NOW = NOW + 10
                RunTimers()
            end
            error("asynchronous operation did not finish")
        end
        fire("ADDON_LOADED", "LifeTimeStats")
        fire("PLAYER_LOGIN")
        fire("PLAYER_ENTERING_WORLD", true, false)
        NOW = NOW + 10
        RunTimers()
    """)
    return lua


CASES = {
    "literal Journal search": r"""
        assert(type(ns.FilterJournal) == "function", "FilterJournal API missing")
        local first = { time(), "Defeated [Rare] beast", 10, kind = "boss", zone = "Durotar", note = "Secret map clue" }
        local second = { time(), "A quiet day", 10, kind = "first", zone = "Mulgore" }
        local entries = { first, second }
        eq(#ns.FilterJournal(entries, { text = "[rare]" }), 1, "search is literal and ignores case")
        eq(#ns.FilterJournal(entries, { text = "SECRET MAP" }), 1, "search includes local notes")
        eq(#ns.FilterJournal(entries, { text = "Durotar" }), 1, "search includes zone")
        eq(#ns.FilterJournal(entries, { text = "clue", kind = "first" }), 0, "search intersects type")
        eq(#ns.FilterJournal(entries, { zone = "mulg", text = "quiet" }), 1, "search intersects zone")
        first.note = "A revised private annotation"
        eq(#ns.FilterJournal(entries, { text = "SECRET MAP" }), 0, "changed note invalidates previous search match")
        eq(#ns.FilterJournal(entries, { text = "revised" }), 1, "changed note becomes searchable")
        eq(first[2], "Defeated [Rare] beast", "search preserves saved entry")
        eq(entries[1], first, "filter preserves original entry references")
    """,
    "Journal favorites and stale entries": r"""
        assert(type(ns.SetJournalFavorite) == "function", "SetJournalFavorite API missing")
        local entry = { time(), "Secret favorite event", 10, kind = "first", zone = "Durotar" }
        ns.char.journal = { entry }
        eq(ns.SetJournalFavorite(entry, true), true, "favorite current entry")
        eq(ns.JournalFavorite(entry), true, "favorite persists")
        eq(#ns.FilterJournal(ns.char.journal, { favoritesOnly = true }), 1, "favorite filter")
        eq(ns.SetJournalFavorite(entry, false), true, "unfavorite current entry")
        eq(#ns.FilterJournal(ns.char.journal, { favoritesOnly = true }), 0, "unfavorite removes match")
        ns.char.journal = {}
        eq(ns.SetJournalFavorite(entry, true), false, "stale entry rejected")
        eq(entry.favorite == true, false, "stale entry has no mutation")
        ns.char.journal = { entry }
        assert(not ns.Serialize(ns.char):find("Secret favorite event", 1, true), "stats backup excludes Journal text")
        assert(not ns.ShareText("summary"):find("Secret favorite event", 1, true), "chat summary excludes Journal text")
    """,
    "chapter introduction and retained summary": r"""
        assert(type(ns.JournalChapterSummary) == "function", "JournalChapterSummary API missing")
        local id = assert(ns.CreateJournalChapter("The Barrens"))
        eq(ns.SetJournalChapterIntro(id, "An introduction to this journey."), true, "save chapter introduction")
        local one = { time() - 60, "First arrival", 10, kind = "first", zone = "Barrens", note = "Private note", chapter = id, favorite = true }
        local two = { time(), "Defeated a boss", 11, kind = "boss", zone = "Barrens", chapter = id }
        ns.char.journal = { one, two }
        local summary = assert(ns.JournalChapterSummary(id, ns.char))
        eq(summary.id, id, "summary chapter identity")
        eq(summary.intro, "An introduction to this journey.", "summary introduction")
        eq(summary.count, 2, "retained entry count")
        eq(summary.notes, 1, "annotated entry count")
        eq(summary.favorites, 1, "favorite entry count")
        eq(summary.first, one[1], "earliest retained entry")
        eq(summary.last, two[1], "latest retained entry")
        eq(summary.retainedOnly, false, "complete small Journal has no omission flag")
        local old = summary.intro
        eq(ns.SetJournalChapterIntro("chapter:9999", "discarded"), false, "missing chapter rejected")
        eq(ns.JournalChapterSummary(id, ns.char).intro, old, "rejected update preserves introduction")
        local text = assert(ns.SerializeFullBackup())
        local snapshot = assert(ns.DeserializeFullBackup(text))
        eq(snapshot.record.chapters[1].intro, old, "full backup retains introduction")
        eq(snapshot.record.journal[1].favorite, true, "full backup retains favorite")
    """,
    "saved session comparison": r"""
        assert(type(ns.CompareSavedSessions) == "function", "CompareSavedSessions API missing")
        local left = { id = 200, s = time()-4000, d = 3600, afk = 1800, k = 20, q = 2, de = 1, xp = 1000, dmg = 4000 }
        local right = { id = 201, s = time()-2000, d = 1800, afk = 0, k = 40, q = 4, de = 0, xp = 3000, dmg = 8000 }
        ns.char.sessionlog = { left, right }
        local result = assert(ns.CompareSavedSessions(left, right))
        eq(result.retainedOnly, false, "complete small session history has no omission flag")
        eq(result.left, left, "left retained row")
        eq(result.right, right, "right retained row")
        local kill
        for _, row in ipairs(result.rows) do if row.key == "k" then kill = row end end
        assert(kill, "comparison includes kills")
        eq(kill.left, 20, "left kills")
        eq(kill.right, 40, "right kills")
        eq(kill.leftRate, 20, "left saved-play-hour rate")
        eq(kill.rightRate, 80, "right saved-play-hour rate")
        ns.char.sessionlog = { right }
        eq(ns.CompareSavedSessions(left, right), nil, "evicted session rejected")
        eq(left.k, 20, "comparison preserves original session")
        right.d, right.afk = 0, 0
        local zero = assert(ns.CompareSavedSessions(right, right))
        for _, row in ipairs(zero.rows) do
            assert(row.leftRate == nil or row.leftRate == row.leftRate and row.leftRate ~= math.huge, "zero-duration rate is finite")
        end
    """,
    "portable Dashboard preferences": r"""
        assert(type(ns.ReadPreferencesBackup) == "function", "ReadPreferencesBackup API missing")
        ns.settings.dashboardPins = { "computed:steps", "counter:quests_done" }
        assert(ns.SaveDashboardLayout("Travel plans"))
        local text = assert(ns.SerializePreferences())
        eq(text:sub(1, 6), "LTSP2|", "new preferences format")
        local values = assert(ns.DeserializePreferences(text))
        assert(type(values.dashboard) == "table", "new preferences retain Dashboard")
        ns.settings.dashboardPins = {}
        ns.settings.dashboardLayouts = {}
        ns.settings.dashboardLayout = nil
        local preview, why = ns.ReadPreferencesBackup(text)
        assert(preview, why)
        eq(#ns.settings.dashboardPins, 0, "preferences preview has no writes")
        assert(type(preview.changes) == "table", "preview explains changes")
        eq(preview.apply(), true, "apply preferences")
        eq(#ns.settings.dashboardPins, 2, "portable pins restored")
        eq(#ns.DashboardLayouts(), 4, "portable custom layout restored")
        eq(preview.apply(), false, "preferences preview is single use")
        local stale = assert(ns.ReadPreferencesBackup(text))
        ns.settings.recap = not ns.settings.recap
        local changedRecap = ns.settings.recap
        eq(stale.apply(), false, "changed settings invalidate preferences preview")
        eq(ns.settings.recap, changedRecap, "stale preferences preview has no partial writes")
        eq(ns.DeserializePreferences(text .. "broken"), nil, "bad checksum rejected")
        local function checksum(body)
            local value = 0
            for i = 1, #body do value = (value * 31 + body:byte(i)) % 16777213 end
            return string.format("%06x", value)
        end
        local body = "recap=false"
        local legacy = assert(ns.DeserializePreferences("LTSP1|" .. checksum(body) .. "|" .. body))
        eq(legacy.recap, false, "legacy preferences accepted")
        eq(legacy.dashboard, nil, "legacy preferences preserve existing Dashboard")
    """,
    "restore safety copy": r"""
        assert(type(ns.GetRestoreSafety) == "function", "GetRestoreSafety API missing")
        local function fullRestore(text)
            local preview, why
            ns.ReadFullBackup(text, function(value, err) preview, why = value, err end)
            pump()
            assert(preview, why)
            local ok, reason = preview.apply()
            assert(ok, reason)
        end
        ns.char.c.jumps = 20
        local old = assert(ns.SerializeFullBackup())
        ns.char.c.jumps = 100
        fullRestore(old)
        eq(ns.char.c.jumps, 20, "replacement applied")
        assert(ns.GetRestoreSafety(), "successful replacement captures safety copy")
        local recovery, why
        ns.ReadRestoreSafety(function(value, err) recovery, why = value, err end)
        pump()
        assert(recovery, why)
        eq(ns.char.c.jumps, 20, "recovery preview has no writes")
        assert(recovery.apply())
        eq(ns.char.c.jumps, 100, "safety recovery restores pre-replacement state")
        eq(recovery.apply(), false, "recovery preview is single use")
        local reverse
        ns.ReadRestoreSafety(function(value) reverse = value end)
        pump()
        assert(reverse and reverse.apply())
        eq(ns.char.c.jumps, 20, "second recovery reverses the prior recovery")
        local before = ns.GetRestoreSafety()
        local failed
        ns.ReadFullBackup(old .. "broken", function(value) failed = value end)
        pump()
        eq(failed, nil, "invalid restore has no preview")
        eq(ns.char.c.jumps, 20, "invalid restore preserves current record")
        local after = ns.GetRestoreSafety()
        eq(after.text, before.text, "invalid restore preserves safety text")
        eq(after.savedAt, before.savedAt, "invalid restore preserves safety date")
        eq(after.character, before.character, "invalid restore preserves safety identity")
        local valid
        ns.ReadFullBackup(old, function(value) valid = value end)
        pump()
        assert(valid, "prepare a valid replacement before failed safety capture")
        local serialize = ns.SerializeFullBackup
        ns.SerializeFullBackup = function() return nil, "forced safety capture failure" end
        local ok = valid.apply()
        ns.SerializeFullBackup = serialize
        eq(ok, false, "failed safety capture rejects replacement")
        eq(ns.char.c.jumps, 20, "failed safety capture preserves character")
        eq(ns.GetRestoreSafety().text, before.text, "failed safety capture preserves prior safety")
    """,
    "localized search and private prose": r"""
        C_Intl = { ToLower = function(text) return (text:gsub("Ä", "ä")):lower() end }
        local id = assert(ns.CreateJournalChapter("Private chapter"))
        assert(ns.SetJournalChapterIntro(id, "PRIVATE INTRO MARKER"))
        local entry = { time(), "ÄVENTURE [literal]", 10, zone = "ÄSHENVALE", note = "PRIVATE NOTE MARKER", chapter = id }
        ns.char.journal = { entry }
        eq(#ns.FilterJournal(ns.char.journal, { text = "äventure" }), 1, "localized text case folding")
        eq(#ns.FilterJournal(ns.char.journal, { zone = "äshen" }), 1, "localized zone case folding")
        for topic in pairs(ns.SHARE_TOPICS) do
            local text = ns.ShareText(topic)
            assert(not text:find("PRIVATE NOTE MARKER", 1, true), "chat excludes notes: " .. topic)
            assert(not text:find("PRIVATE INTRO MARKER", 1, true), "chat excludes introduction: " .. topic)
        end
        for _, text in ipairs({ assert(ns.Serialize(ns.char)), assert(ns.SerializePreferences()) }) do
            assert(not text:find("PRIVATE NOTE MARKER", 1, true), "portable stats/preferences exclude notes")
            assert(not text:find("PRIVATE INTRO MARKER", 1, true), "portable stats/preferences exclude intros")
        end
        C_Intl.ToLower = function() error("unavailable locale service") end
        eq(#ns.FilterJournal(ns.char.journal, { text = "literal" }), 1, "locale failure has readable ASCII fallback")
    """,
    "preference adversarial boundaries": r"""
        -- Independent tiny encoder builds checksum-valid malformed inputs, so
        -- rejection must come from schema validation rather than checksum failure.
        local function encode(value)
            if type(value) == "table" then
                local parts, count = {}, 0
                for key, item in pairs(value) do count = count + 1; parts[#parts+1] = encode(key) .. encode(item) end
                return "m" .. count .. ":" .. table.concat(parts)
            elseif type(value) == "string" then
                local escaped = value:gsub("[|%z\1-\32\127-\255%%]", function(byte) return string.format("%%%02X", byte:byte()) end)
                return "s" .. #escaped .. ":" .. escaped
            elseif type(value) == "number" then return "n" .. value .. ";"
            else return value and "t" or "f" end
        end
        local function pack(value)
            local body, a, b = encode(value), 1, 0
            for i = 1, #body do a = (a + body:byte(i)) % 65521; b = (b + a) % 65521 end
            return "LTSP2|" .. string.format("%04x%04x", b, a) .. "|" .. body
        end
        local function valid()
            return { preferences = { recap = false }, dashboard = { pins = { "computed:steps" }, layouts = {} } }
        end
        assert(ns.DeserializePreferences(pack(valid())), "independent valid LTSP2 fixture")
        local mutations = {
            function(v) v.privateNote = "unexpected" end,
            function(v) v.preferences.screenshot = true end,
            function(v) v.dashboard.pins = { [2] = "computed:steps" } end,
            function(v) v.dashboard.pins = { "computed:steps", "computed:steps" } end,
            function(v) v.dashboard.pins = { "counter:made_up" } end,
            function(v) v.dashboard.pins = { "computed:steps", "computed:kills", "counter:deaths", "counter:jumps", "counter:quests_done" } end,
            function(v) v.dashboard.layouts = { {id="layout:1",name="One",pins={}}, {id="layout:1",name="Two",pins={}} } end,
            function(v) v.dashboard.layouts = { {id="layout:1",name="Same",pins={}}, {id="layout:2",name="same",pins={}} } end,
            function(v) v.dashboard.layouts = { {id="layout:1",name=string.rep("a",41),pins={}} } end,
            function(v) v.dashboard.layouts = {}; for i=1,13 do v.dashboard.layouts[i]={id="layout:"..i,name="Saved "..i,pins={}} end end,
            function(v) v.dashboard.selected = "layout:999" end,
            function(v) v.dashboard.selected = "combat" end,
            function(v) v.dashboard.layouts = { {id="layout:01",name="Not canonical",pins={}} } end,
        }
        local originalRecap = ns.settings.recap
        for i, mutate in ipairs(mutations) do
            local value = valid(); mutate(value)
            eq(ns.ReadPreferencesBackup(pack(value)), nil, "malformed preference rejected " .. i)
            eq(ns.settings.recap, originalRecap, "rejected preference leaves settings unchanged " .. i)
        end
        local value = valid()
        value.dashboard.layouts = { {id="layout:1",name="Private snapshot",pins={"computed:steps"}} }
        value.dashboard.selected = "layout:1"
        local text = pack(value)
        local decoded = assert(ns.DeserializePreferences(text))
        local preview = assert(ns.ReadPreferencesBackup(text))
        decoded.dashboard.pins[1] = "counter:deaths"
        decoded.dashboard.layouts[1].name = "Injected"
        for _, change in ipairs(preview.changes) do change.value = "Injected"; change.before = "Injected" end
        assert(preview.apply())
        eq(ns.settings.dashboardPins[1], "computed:steps", "detached decode cannot mutate staged pins")
        eq(ns.settings.dashboardLayouts[1].name, "Private snapshot", "public changes cannot mutate staged layout")
        local stale = assert(ns.ReadPreferencesBackup(text))
        ns.settings.dashboardLayouts[1].pins[1] = "counter:deaths"
        eq(stale.apply(), false, "nested settings edit invalidates preview")
        eq(ns.settings.dashboardLayouts[1].pins[1], "counter:deaths", "stale apply preserves nested edit")
        local swapped = assert(ns.ReadPreferencesBackup(text))
        local previous = ns.settings
        ns.settings = {}
        eq(swapped.apply(), false, "settings-object change invalidates preview")
        eq(next(ns.settings), nil, "changed settings object receives no writes")
        ns.settings = previous
    """,
    "recovery character and capture failures": r"""
        local original = assert(ns.SerializeFullBackup())
        local preview
        ns.ReadFullBackup(original, function(value) preview = value end); pump(); assert(preview)
        local previousSafety = LifeTimeStatsCharDB.restoreSafety
        local before = ns.char.c.jumps
        local savedKey = ns.charKey
        ns.charKey = "Different-Character"
        eq(preview.apply(), false, "changed character rejects full replacement")
        eq(ns.char.c.jumps, before, "changed character preserves record")
        eq(LifeTimeStatsCharDB.restoreSafety, previousSafety, "changed character preserves safety")
        ns.charKey = savedKey
        ns.ReadFullBackup(original, function(value) preview = value end); pump(); assert(preview)
        local serialize = ns.SerializeFullBackup
        ns.SerializeFullBackup = function() error("forced capture exception") end
        eq(preview.apply(), false, "capture exception rejects replacement")
        ns.SerializeFullBackup = serialize
        eq(ns.char.c.jumps, before, "capture exception preserves record")
        eq(LifeTimeStatsCharDB.restoreSafety, previousSafety, "capture exception preserves safety")
    """,
    "Journal workbook UI interactions": r"""
        local function click(button) assert(button, "button exists"); button:GetScript("OnClick")(button) end
        local function button(label, parent)
            for i = #frames, 1, -1 do
                local frame, text = frames[i], rawget(frames[i], "text")
                if type(text) == "table" and text:GetText() == label and (not parent or frame.testParent == parent) then return frame end
            end
        end
        local id = assert(ns.CreateJournalChapter("UI chapter"))
        local one = {time()-1, "Ordinary event", 10, note="search clue", chapter=id}
        local two = {time(), "Highlighted event", 10, favorite=true, chapter=id}
        ns.char.journal = {one,two}
        ns.OpenPage("journal")
        local feed
        for _, frame in ipairs(frames) do if rawget(frame,"SetEntries") then feed=frame end end
        assert(feed, "Journal feed is visible")
        feed.textSearch:SetText("clue"); feed.textSearch:GetScript("OnTextChanged")(feed.textSearch)
        eq(feed.rows[1].entry, one, "typing text filters visible entry")
        assert(ns.SetJournalNote(one,"changed")); ns.RefreshWindow()
        eq(#feed.entries,0,"note edit removes stale visible search result")
        feed.textSearch:SetText(""); feed.textSearch:GetScript("OnTextChanged")(feed.textSearch)
        click(button("Highlights",feed))
        eq(feed.rows[1].entry,two,"Highlights click filters visible entries")
        assert(ns.SetJournalFavorite(two,false)); ns.RefreshWindow()
        eq(#feed.entries,0,"unfavorite invalidates visible Highlights")
        click(button("Chapters…",feed))
        local chapterRow
        for _, frame in ipairs(frames) do local data=rawget(frame,"data"); if type(data)=="table" and data.id==id then chapterRow=frame end end
        click(chapterRow); click(button("Chapter page"))
        local intro
        for _, frame in ipairs(frames) do
            if frame.testKind=="EditBox" and frame:GetScript("OnCursorChanged") and frame:GetScript("OnTextChanged") then intro=frame end
        end
        assert(intro,"chapter intro supplies scrolling edit box")
        intro:SetText("UI private introduction"); intro:GetScript("OnTextChanged")(intro)
        click(button("Save introduction"))
        eq(ns.JournalChapterSummary(id).intro,"UI private introduction","chapter page saves introduction")
        ns.ShowPage("journal")
        local a,b,c={s=time()-30,d=10,k=1},{s=time()-20,d=10,k=2},{s=time()-10,d=10,k=3}
        ns.char.sessionlog={a,b,c}
        local compare, selected = ns.CompareSavedSessions
        ns.CompareSavedSessions=function(left,right) selected=left; return compare(left,right) end
        ns.ShowSessionComparison()
        local firstChoice
        for _, frame in ipairs(frames) do
            local items=rawget(frame,"items")
            if type(items)=="table" and items[1] and items[1].id==3 and frame.selected==2 then firstChoice=frame end
        end
        assert(firstChoice,"comparison selector opened")
        table.remove(ns.char.sessionlog,1)
        click(button("›",firstChoice))
        eq(selected,a,"selector preserves original row despite retention shift")
        eq(compare(a,c),nil,"evicted selected row rejected")
        ns.CompareSavedSessions=compare
        ns.ShowPage("journal")
        ns.char.c.jumps=11
        local old=assert(ns.SerializeFullBackup())
        ns.char.c.jumps=99
        local replacement
        ns.ReadFullBackup(old,function(value) replacement=value end); pump(); assert(replacement.apply())
        ns.ShowImport()
        click(button("Recover previous data")); pump()
        eq(ns.char.c.jumps,11,"recovery button opens preview without replacement")
        click(button("Restore recovery")); pump()
        eq(ns.char.c.jumps,99,"explicit recovery confirmation applies safety copy")
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
    raise SystemExit(f"JOURNAL WORKBOOK FAIL: {len(failures)} of {len(CASES)} cases")
print(f"JOURNAL WORKBOOK PASS: {len(CASES)} cases")

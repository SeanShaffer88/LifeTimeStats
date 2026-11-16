-- LifeTimeStats - interface habits: map pins, /who, bag sorting, camera and minimap zooms, windows
-- Copyright (C) 2026 Malikor. Licensed under GPL-3.0-or-later (see LICENSE).
local _, ns = ...
local Add, On = ns.Add, ns.On

-- { namespace or nil, function, counter, label, tip }. Each is a secure post-hook that only
-- counts the call; arguments are never read. Missing functions are skipped.
ns.HABITS = {
    { "C_Map", "SetUserWaypoint", "map_pins", "Map pins placed", "Waypoints you dropped on the world map." },
    { "C_Map", "ClearUserWaypoint", "map_pins_cleared", "Map pins removed" },
    { "C_FriendList", "SendWho", "who_searches", "/who searches" },
    { "C_FriendList", "DelIgnore", "unignored", "Players unignored" },
    { "C_Container", "SortBags", "bags_sorted", "Bags sorted", "The bag clean-up button." },
    { "C_MerchantFrame", "SellAllJunkItems", "junk_sales", "Sell all junk clicks" },
    { "C_Minimap", "SetTracking", "tracking_changes", "Minimap tracking changed", "Switching between Find Herbs, Find Minerals, Track Beasts and the like." },
    { nil, "CreateMacro", "macros_created", "Macros created" },
    { nil, "ToggleRun", "walk_toggles", "Walk/run toggles" },
    { nil, "CameraZoomIn", "camera_zoom_in", "Camera zoomed in", "Mouse-wheel and key zoom steps." },
    { nil, "CameraZoomOut", "camera_zoom_out", "Camera zoomed out", "Mouse-wheel and key zoom steps." },
    { nil, "Minimap_ZoomIn", "minimap_zoom_in", "Minimap zoomed in" },
    { nil, "Minimap_ZoomOut", "minimap_zoom_out", "Minimap zoomed out" },
    { nil, "ToggleMinimap", "minimap_toggles", "Minimap shown or hidden" },
    { nil, "ToggleGameMenu", "game_menu_opens", "Game menu opened", "Escape menu, including when Escape closes other windows first." },
    { nil, "ToggleCalendar", "calendar_opens", "Calendar opened" },
    { nil, "ToggleCollectionsJournal", "collections_opens", "Collections opened" },
    { nil, "ToggleAchievementFrame", "achievement_opens", "Achievements window opened" },
    { nil, "ToggleGuildFrame", "guild_opens", "Guild window opened" },
    { nil, "ToggleChannelFrame", "channels_opens", "Chat channels window opened" },
    { nil, "ToggleHelpFrame", "help_opens", "Customer support opened" },
}

local installed = false
function ns.InstallHabits()
    if installed then return end
    installed = true
    for _, h in ipairs(ns.HABITS) do
        local tblName, fnName, key = h[1], h[2], h[3]
        local tbl = tblName and _G[tblName]
        local fn = function() Add(key) end
        if tblName then
            if type(tbl) == "table" and type(tbl[fnName]) == "function" then pcall(hooksecurefunc, tbl, fnName, fn) end
        elseif type(_G[fnName]) == "function" then
            pcall(hooksecurefunc, fnName, fn)
        end
    end
end
On("PLAYER_LOGIN", function() ns.InstallHabits() end)

-- ------------------------------------------------------------ catalog
for _, h in ipairs(ns.HABITS) do
    table.insert(ns.STATS.social, { label = h[4], fmt = "int", key = h[3], tip = h[5] })
end
table.insert(ns.STATS.social, { label = "Camera zoom steps", fmt = "int", tip = "In and out together.",
    get = function(v) local c = v.c or {} return (c.camera_zoom_in or 0) + (c.camera_zoom_out or 0) end })
ns.HABITS_STAT_COUNT = #ns.HABITS + 1

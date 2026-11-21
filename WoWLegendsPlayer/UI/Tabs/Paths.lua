-- WoWLegendsPlayer/UI/Tabs/Paths.lua
-- The launcher's "Paths" entry. Not a tab of its own: a click opens the Paths
-- window (UI/PathsFrame.lua), which lives beside this panel, not inside it.

local addonName, WLP = ...

WLP.RegisterTab({
    id = "paths",
    label = "Paths",
    wl = true,
    action = function()
        if WLP.Paths and WLP.Paths.UI then WLP.Paths.UI.Open() end
    end,
})

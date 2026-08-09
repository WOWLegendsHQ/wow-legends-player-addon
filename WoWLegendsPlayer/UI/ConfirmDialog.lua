-- WoWLegendsPlayer/UI/ConfirmDialog.lua
-- Confirm popups. One generic popup for every danger=true command, plus a
-- louder dedicated popup for the irreversible Hardcore opt-in.

local addonName, WLP = ...

StaticPopupDialogs["WLP_CONFIRM_CMD"] = {
    text = "|cffffc94dWoW Legends|r\n\nRun this command?\n\n|cffffd100%s|r",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self)
        local line = self.data
        if line and line ~= "" then WLP._ExecuteRaw(line) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,   -- avoid UIParent taint on 3.3.5a
    showAlert = true,
}

-- Break camp is destructive and the server itself is two-step: the button has
-- already sent `.camp leave` (which prints the server's own warning); accepting
-- here sends the `confirm` form that actually destroys the camp + all props.
StaticPopupDialogs["WLP_CONFIRM_CAMP_LEAVE"] = {
    text = "|cffff4444Break camp?|r\n\nThis destroys your Warband Camp and EVERYTHING placed in it. "
        .. "It cannot be undone, and the camp belongs to your whole account.\n\nReally break it?",
    button1 = "Yes, break camp",
    button2 = CANCEL,
    OnAccept = function()
        WLP._ExecuteRaw(".camp leave confirm")
        if WLP.Warband then WLP.Warband.Probe(2) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

-- Hardcore is permadeath and irreversible — spell that out before sending.
-- The server still requires the player to confirm in-game (run .hardcore on
-- twice within 30s), so this popup is the addon's own first gate.
StaticPopupDialogs["WLP_CONFIRM_HARDCORE"] = {
    text = "|cffff4444HARDCORE - PERMADEATH|r\n\nThis opts |cffffffff%s|r into Hardcore.\n\n"
        .. "If this character dies, it is gone |cffff4444forever|r. This cannot be undone, and only works at level 1.\n\n"
        .. "The server will ask you to confirm again in-game (run it twice within 30s).\n\nArm the Hardcore opt-in?",
    button1 = "Yes, make me Hardcore",
    button2 = CANCEL,
    OnAccept = function(self)
        if self.data and self.data ~= "" then WLP._ExecuteRaw(self.data) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    showAlert = true,
}

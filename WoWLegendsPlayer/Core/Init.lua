-- WoWLegendsPlayer/Core/Init.lua
-- Addon namespace, defaults, event wiring, slash commands, C_Timer shim.
--
-- WoW Legends Player panel — WotLK 3.3.5a (AzerothCore Playerbot branch).
-- Every file receives the addon name and the shared private table via `...`:
--     local addonName, WLP = ...
-- so there is exactly one shared table and no reliance on a global. We also
-- mirror it to _G.WLP so it can be poked from /script for debugging.

local addonName, WLP = ...
_G.WLP = WLP

WLP.name    = "WoW Legends Player"
WLP.short   = "WLP"
WLP.version = GetAddOnMetadata(addonName, "Version") or "0.1.0"

-- Persisted defaults (deep-merged into the SavedVariable on load).
WLP.defaults = {
    frame   = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0, shown = false },
    button  = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -28, y = -120 },
    favorites = {},
    history   = {},
    inputs    = {},
    activeTab = 1,
    subTabs   = {},          -- per-tab remembered sub-tab index, keyed by tab id
    botScope  = "all",       -- where $ bot orders go: "all" (party/raid) or "whisper"
    minimap   = { hide = false },
    confirmDanger = true,     -- show confirm popup for danger commands
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
WLP.CopyDefaults = copyDefaults

-- ─── Login-handler registry ───────────────────────────────────────────────
-- Each module appends a function via WLP.AddLogin(); on PLAYER_LOGIN we run
-- each in sequence wrapped in pcall, so a failure in one (e.g. a tab builder)
-- never blocks the others (e.g. the toggle button).
WLP._loginHandlers = {}
function WLP.AddLogin(fn) table.insert(WLP._loginHandlers, fn) end

-- ─── C_Timer.After shim ────────────────────────────────────────────────────
-- 3.3.5a has no C_Timer. A single shared OnUpdate ticker drains a queue of
-- delayed callbacks — good enough for the short, low-volume delays we use.
do
    local queue = {}
    local ticker = CreateFrame("Frame")
    ticker:Hide()
    ticker:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        for i = #queue, 1, -1 do
            if now >= queue[i].at then
                local fn = queue[i].fn
                table.remove(queue, i)
                local ok, err = pcall(fn)
                if not ok then
                    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555WLP timer error:|r " .. tostring(err))
                end
            end
        end
        if #queue == 0 then self:Hide() end
    end)
    -- WLP.After(delay, fn) — run fn after `delay` seconds.
    function WLP.After(delay, fn)
        table.insert(queue, { at = GetTime() + (delay or 0), fn = fn })
        ticker:Show()
    end
end

-- ─── Event wiring ──────────────────────────────────────────────────────────
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        WoWLegendsPlayer_DB = WoWLegendsPlayer_DB or {}
        copyDefaults(WLP.defaults, WoWLegendsPlayer_DB)
        WLP.db = WoWLegendsPlayer_DB
    elseif event == "PLAYER_LOGIN" then
        for i, fn in ipairs(WLP._loginHandlers or {}) do
            local ok, err = pcall(fn)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555WLP login handler #" .. i .. " error:|r " .. tostring(err))
            end
        end
    end
end)

-- ─── Slash commands ────────────────────────────────────────────────────────
SLASH_WLP1 = "/wlp"
SLASH_WLP2 = "/wlplayer"
SLASH_WLP3 = "/bots"
SlashCmdList["WLP"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lcmd = msg:lower()

    if lcmd == "reset" then
        WLP.db.frame, WLP.db.button = nil, nil
        copyDefaults(WLP.defaults, WLP.db)
        if WLP.RestoreMainFramePosition then WLP.RestoreMainFramePosition() end
        if WLP.RestoreButtonPosition then WLP.RestoreButtonPosition() end
        WLP.Print("positions reset.")
    elseif lcmd == "show" then
        if WoWLegendsPlayer_MainFrame then WoWLegendsPlayer_MainFrame:Show() end
    elseif lcmd == "hide" then
        if WoWLegendsPlayer_MainFrame then WoWLegendsPlayer_MainFrame:Hide() end
    elseif lcmd == "debug" then
        WLP.DumpDebug()
    else
        if WLP.Toggle then WLP.Toggle() end
    end
end

-- Module load-status dump for troubleshooting (/wlp debug).
function WLP.DumpDebug()
    local c = WLP.colors
    local function pp(label, val) DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. ": " .. tostring(val)) end
    DEFAULT_CHAT_FRAME:AddMessage(c.accent .. WLP.name .. " debug" .. c.reset .. "  v" .. WLP.version)
    pp("MainFrame", WoWLegendsPlayer_MainFrame)
    pp("ToggleButton", WoWLegendsPlayer_ToggleButton)
    pp("tabs registered", WLP.tabs and #WLP.tabs or 0)
    if WLP._mainFrameLoadError then pp("MainFrame load error", WLP._mainFrameLoadError) end
    DEFAULT_CHAT_FRAME:AddMessage("  modules:")
    for _, m in ipairs({
        { "Util",          WLP.colors },
        { "SavedVars",     WLP.PushHistory },
        { "CommandRunner", WLP.RunCommand },
        { "Specs",         WLP.Specs },
        { "ConfirmDialog", StaticPopupDialogs and StaticPopupDialogs["WLP_CONFIRM_CMD"] },
        { "Widgets",       WLP.CreateCommandRow },
        { "MainFrame",     WLP.RegisterTab },
        { "ToggleButton",  WLP.Toggle },
    }) do
        pp("    " .. m[1], m[2] and (c.good .. "ok" .. c.reset) or (c.danger .. "MISSING" .. c.reset))
    end
end

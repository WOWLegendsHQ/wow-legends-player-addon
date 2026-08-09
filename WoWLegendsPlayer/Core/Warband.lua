-- WoWLegendsPlayer/Core/Warband.lua
-- Warband Camp state: parse the server's CHAT_MSG_SYSTEM replies to `.camp`
-- commands into a small session-cached state table the tab renders from.
-- Response strings are the literal shipped v1.5.0 ones (see
-- handoffs/2026-08-09_addon_warband_tab.md); we strip |cffxxxxxx..|r color
-- codes first and match loosely, exactly as that spec asks.
--
-- Feature gating: the module ships OFF. We probe once at login with a silent
-- `.camp` (bypasses command history) — "Warband Camps are not enabled on this
-- realm." marks the tab disabled for the session.

local addonName, WLP = ...

local W = {
    probed  = false,   -- have we heard ANY .camp status yet this session
    enabled = nil,     -- false only after the literal not-enabled line
    hasCamp = nil,
    zone    = nil,
    count   = nil,     -- props placed
    cap     = nil,     -- prop cap; nil = unlimited (MaxProps=0) or unknown
}
WLP.Warband = W

-- UI refresh hooks (the tab registers one).
local callbacks = {}
function W.OnChange(fn) table.insert(callbacks, fn) end
local function notify()
    for _, fn in ipairs(callbacks) do pcall(fn) end
end

local function strip(msg)
    return (msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Silent probe (no history entry). Delay lets claim/leave settle server-side.
function W.Probe(delay)
    WLP.After(delay or 0, function() SendChatMessage(".camp", "SAY") end)
end

-- Parse one system line. Returns true if it was a Warband line.
-- NOTE: the "N of M" status form MUST be tried before the unlimited form —
-- "with (%d+) things set up" would otherwise swallow "with 12 of 200 things
-- set up" and mis-capture the zone.
function W.ParseSystem(msg)
    if type(msg) ~= "string" then return false end
    msg = strip(msg)

    if msg:find("Warband Camps are not enabled", 1, true) then
        W.probed, W.enabled = true, false
        notify(); return true
    end
    if msg:find("You have no Warband Camp yet", 1, true) then
        W.probed, W.enabled, W.hasCamp = true, true, false
        W.zone, W.count, W.cap = nil, nil, nil
        notify(); return true
    end

    local zone, n, m = msg:match("Your Warband Camp is in (.-), with (%d+) of (%d+) things set up")
    if zone then
        W.probed, W.enabled, W.hasCamp = true, true, true
        W.zone, W.count, W.cap = zone, tonumber(n), tonumber(m)
        notify(); return true
    end
    local zone2, n2 = msg:match("Your Warband Camp is in (.-), with (%d+) things set up")
    if zone2 then
        W.probed, W.enabled, W.hasCamp = true, true, true
        W.zone, W.count, W.cap = zone2, tonumber(n2), nil
        notify(); return true
    end

    -- Place success: "<Label> set up (N of M)." / "<Label> set up (N so far)."
    local pn, pm = msg:match("set up %((%d+) of (%d+)%)")
    if pn then
        W.enabled, W.hasCamp = true, true
        W.count, W.cap = tonumber(pn), tonumber(pm)
        notify(); return true
    end
    local ps = msg:match("set up %((%d+) so far%)")
    if ps then
        W.enabled, W.hasCamp = true, true
        W.count = tonumber(ps)          -- cap unchanged (unlimited realms)
        notify(); return true
    end

    -- Cap reached: "Your camp is full (N things)."
    local full = msg:match("Your camp is full %((%d+) things%)")
    if full then
        W.enabled, W.hasCamp = true, true
        W.count = tonumber(full)
        if W.cap == nil then W.cap = tonumber(full) end
        notify(); return true
    end

    -- Claim success: "This ground is yours. Your Warband Camp is founded ..."
    if msg:find("This ground is yours", 1, true) then
        W.enabled, W.hasCamp = true, true
        W.Probe(2)                      -- fetch zone + counts
        notify(); return true
    end

    return false
end

-- ─── Wiring ────────────────────────────────────────────────────────────────
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_SYSTEM")
listener:SetScript("OnEvent", function(_, _, msg) W.ParseSystem(msg) end)

-- One probe per session, shortly after login so the world is settled.
WLP.AddLogin(function() W.Probe(5) end)

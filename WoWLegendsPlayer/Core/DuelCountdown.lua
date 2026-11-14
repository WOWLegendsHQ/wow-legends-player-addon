-- WoWLegendsPlayer/Core/DuelCountdown.lua
-- Duel Master practice duels (Gurubashi Arena): a big centre-screen countdown.
--
-- The server whispers the player to themself on the hidden addon channel,
-- prefix "WLDUEL", fields tab-separated (wowlegends_duelmaster.cpp, AddonMsg):
--   C <seconds left> <opponent> <spec>   once a second, 20 down to 1
--   F                                    the fight starts
--   E <W|L|-> <opponent>                 the duel is over: won / lost / no result
-- Without the addon the server's own yellow centre text still covers 20/15/10/
-- 5/4 and "FIGHT!", so this is an upgrade, not a dependency.
--
-- Text only - no box, no buttons (nothing here needs a click). It sits above
-- the screen centre so the client's own 3-2-1 duel countdown, which overlaps
-- our last three seconds, is not drawn on top of it.

local addonName, WLP = ...

local DC = {}
WLP.DuelCountdown = DC

local PREFIX = "WLDUEL"
local STALE_AFTER = 3        -- no countdown tick for this long = the duel was called off
local FIGHT_HOLD, RESULT_HOLD, FADE = 1.2, 3.5, 0.8

local f = CreateFrame("Frame", "WoWLegendsPlayer_DuelCountdown", UIParent)
f:SetWidth(600)
f:SetHeight(160)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
f:SetFrameStrata("HIGH")
f:Hide()

local big = f:CreateFontString(nil, "OVERLAY")
big:SetFont("Fonts\\FRIZQT__.TTF", 64, "THICKOUTLINE")
big:SetPoint("TOP", f, "TOP", 0, 0)
big:SetJustifyH("CENTER")

local sub = f:CreateFontString(nil, "OVERLAY")
sub:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
sub:SetPoint("TOP", big, "BOTTOM", 0, -6)
sub:SetJustifyH("CENTER")

DC.frame, DC.big, DC.sub = f, big, sub

-- state: "count" (ticking), "fight" (FIGHT! flash), "result", or nil
local state, holdUntil, lastTick = nil, 0, 0

local function show(bigText, r, g, b, subText)
    big:SetText(bigText)
    big:SetTextColor(r, g, b)
    sub:SetText(subText or "")
    f:SetAlpha(1)
    f:Show()
end

local function hide()
    state = nil
    f:Hide()
end

f:SetScript("OnUpdate", function(self)
    local now = GetTime()
    if state == "count" then
        if now - lastTick > STALE_AFTER then hide() end
    elseif state == "fight" or state == "result" then
        if now >= holdUntil + FADE then
            hide()
        elseif now >= holdUntil then
            self:SetAlpha(1 - (now - holdUntil) / FADE)
        end
    end
end)

-- One parsed message. Returns true when it was ours and understood.
function DC.Handle(message)
    if type(message) ~= "string" then return false end
    local fields = {}
    for part in (message .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = part end
    local kind = fields[1]

    if kind == "C" then
        local n = tonumber(fields[2])
        if not n then return false end
        local opp, spec = fields[3] or "", fields[4] or ""
        local vs = (opp ~= "") and ("vs " .. opp .. ((spec ~= "") and (" (" .. spec .. ")") or "")) or ""
        -- White while there is time, gold for the last five.
        if n <= 5 then show(tostring(n), 1, 0.82, 0, vs) else show(tostring(n), 1, 1, 1, vs) end
        state, lastTick = "count", GetTime()
        return true
    elseif kind == "F" then
        show("FIGHT!", 1, 0.25, 0.1, "")
        state, holdUntil = "fight", GetTime() + FIGHT_HOLD
        return true
    elseif kind == "E" then
        local res, opp = fields[2], fields[3] or ""
        if res == "W" then
            show("Victory", 0.25, 1, 0.25, (opp ~= "") and ("you beat " .. opp) or "")
        elseif res == "L" then
            show("Defeat", 1, 0.25, 0.25, (opp ~= "") and (opp .. " won this one") or "")
        else
            show("No result", 0.7, 0.7, 0.7, "")
        end
        state, holdUntil = "result", GetTime() + RESULT_HOLD
        return true
    end
    return false
end

-- Only our own server's whisper-to-self counts: anyone could whisper an
-- addon message with this prefix, and nobody else gets to put text there.
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") then return end
    local ok, err = pcall(DC.Handle, message)
    if not ok and WLP.Warn then WLP.Warn("duel countdown: " .. tostring(err)) end
end)

-- WoWLegendsPlayer/UI/PathsAlerts.lua
-- Two small companions of the Paths window:
--   * toasts in the 3.3.5a achievement-alert style, with its sound: a boss
--     credited, a stage cleared, a Path walked, a Path forsaken. They come
--     from comparing a push with the set before it (Core/Paths.lua, P.Diff).
--   * an optional one-line tracker under the quest tracker (WatchFrame) for
--     the Path being walked; off by default, toggled in the window.

local addonName, WLP = ...
local P = WLP.Paths
local UI = P.UI
local ACH = "Interface\\AchievementFrame\\"

-- ─── Toast ──────────────────────────────────────────────────────────────────
local toast = CreateFrame("Button", "WoWLegendsPlayer_PathsToast", UIParent)
toast:SetSize(300, 88)
toast:SetFrameStrata("DIALOG")
toast:RegisterForClicks("LeftButtonUp")
toast:Hide()

local bg = toast:CreateTexture(nil, "BACKGROUND")
bg:SetTexture(ACH .. "UI-Achievement-Alert-Background")
bg:SetTexCoord(0, 0.605, 0, 0.703)
bg:SetAllPoints(toast)

local topText = toast:CreateFontString(nil, "ARTWORK", "GameFontBlackTiny")
topText:SetSize(200, 12)
topText:SetPoint("TOP", toast, "TOP", 7, -23)

local nameText = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
nameText:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 72, 36)
nameText:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -60, 36)
nameText:SetHeight(16)

local iconHolder = CreateFrame("Frame", nil, toast)
iconHolder:SetSize(124, 124)
iconHolder:SetPoint("TOPLEFT", toast, "TOPLEFT", -26, 16)
local iconTex = iconHolder:CreateTexture(nil, "ARTWORK")
iconTex:SetSize(50, 50)
iconTex:SetPoint("CENTER", iconHolder, "CENTER", 0, 3)
local iconFrame = iconHolder:CreateTexture(nil, "OVERLAY")
iconFrame:SetTexture(ACH .. "UI-Achievement-IconFrame")
iconFrame:SetTexCoord(0, 0.5625, 0, 0.5625)
iconFrame:SetSize(72, 72)
iconFrame:SetPoint("CENTER", iconHolder, "CENTER", -1, 2)

local shield = toast:CreateTexture(nil, "BORDER")
shield:SetTexture(ACH .. "UI-Achievement-Shields-NoPoints")
shield:SetTexCoord(0, 0.5, 0, 0.9)
shield:SetSize(52, 48)
shield:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -9, -19)

local glow = toast:CreateTexture(nil, "OVERLAY")
glow:SetTexture(ACH .. "UI-Achievement-Alert-Glow")
glow:SetTexCoord(0, 0.78125, 0, 0.66796875)
glow:SetBlendMode("ADD")
glow:SetSize(400, 171)
glow:SetPoint("CENTER", toast, "CENTER")

local shine = toast:CreateTexture(nil, "OVERLAY")
shine:SetTexture(ACH .. "UI-Achievement-Alert-Glow")
shine:SetTexCoord(0.78125, 0.912109375, 0, 0.28125)
shine:SetBlendMode("ADD")
shine:SetSize(67, 72)

local queue = {}
local shownAt, showing
local HOLD, FADE = 4.05, 1.5

local function placeToast()
    toast:ClearAllPoints()
    for i = 2, 1, -1 do
        local a = _G["AchievementAlertFrame" .. i]
        if a and a:IsShown() then
            toast:SetPoint("BOTTOM", a, "TOP", 0, 10)
            return
        end
    end
    toast:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 128)
end

local function textsFor(ev)
    local p = ev.path
    if ev.kind == "goal" then
        return p.name, ev.goal.label .. " defeated", "Interface\\Icons\\" .. ev.goal.icon, false
    elseif ev.kind == "stage" then
        local s = ev.stage.name
        s = s:sub(1, 1):upper() .. s:sub(2)
        local top = (ev.stage.gate or 0) > 0 and ("Stage cleared - XP gate " .. ev.stage.gate .. " lifted") or "Stage cleared"
        return top, s, UI.IconOf(p), false
    elseif ev.kind == "done" then
        return "Path walked", p.name, UI.IconOf(p), false
    elseif ev.kind == "forsaken" then
        return "Path forsaken", p.name, UI.IconOf(p), true
    end
end

local function showNext()
    local ev = table.remove(queue, 1)
    if not ev then showing = nil; toast:Hide(); return end
    local top, name, tex, grey = textsFor(ev)
    topText:SetText(top)
    nameText:SetText(name)
    iconTex:SetTexture(tex)
    iconTex:SetDesaturated(grey and true or false)
    toast.key = ev.path.key
    showing, shownAt = ev, GetTime()
    placeToast()
    toast:SetAlpha(0)
    glow:SetAlpha(0)
    shine:SetAlpha(0)
    toast:Show()
    PlaySound("AchievementSound")
end

toast:SetScript("OnUpdate", function(self)
    if not showing then return end
    local t = GetTime() - shownAt
    -- in: 0.2 s; glow flashes; the shine sweeps across
    self:SetAlpha(math.min(1, t / 0.2))
    if t < 0.2 then glow:SetAlpha(t / 0.2)
    elseif t < 0.7 then glow:SetAlpha(1 - (t - 0.2) / 0.5)
    else glow:SetAlpha(0) end
    shine:ClearAllPoints()
    if t < 0.2 then
        shine:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 8)
        shine:SetAlpha(t / 0.2)
    elseif t < 1.05 then
        shine:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 240 * (t - 0.2) / 0.85, 8)
        shine:SetAlpha(t < 0.55 and 1 or math.max(0, 1 - (t - 0.55) / 0.5))
    else
        shine:SetAlpha(0)
    end
    -- hold while the mouse is on it, then fade out
    if MouseIsOver(self) and t > 0.2 then
        shownAt = GetTime() - 0.2
        self:SetAlpha(1)
        return
    end
    if t > HOLD then
        local a = 1 - (t - HOLD) / FADE
        if a <= 0 then showNext() else self:SetAlpha(a) end
    end
end)

toast:SetScript("OnClick", function(self)
    if UI and self.key then UI.Open(self.key) end
end)

function UI.Toast(ev)
    queue[#queue + 1] = ev
    if not showing then showNext() end
end

-- ─── Tracker ────────────────────────────────────────────────────────────────
local tracker = CreateFrame("Button", "WoWLegendsPlayer_PathsTracker", UIParent)
tracker:SetSize(196, 16)
tracker:SetFrameStrata("LOW")
tracker:RegisterForClicks("LeftButtonUp")
tracker:Hide()
local trIcon = tracker:CreateTexture(nil, "ARTWORK")
trIcon:SetSize(14, 14)
trIcon:SetPoint("LEFT", tracker, "LEFT", 0, 0)
trIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local trText = tracker:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
trText:SetPoint("LEFT", trIcon, "RIGHT", 4, 0)
local TEXT_MAX = 150
trText:SetWidth(TEXT_MAX)
trText:SetHeight(14)
trText:SetJustifyH("LEFT")

-- frames the line steps below when they cover it: the client UI's raid and
-- battlefront bars, and this addon's own launcher (it defaults to this corner)
local BARS = { "WLUI_TownRaidBar", "WLUI_BattlefrontBar", "WoWLegendsPlayer_ToggleButton" }

-- The quest tracker shrinks to nothing when it is empty or collapsed, so the
-- line takes its column from the tracker's right edge and its full width.
local function placeTracker()
    tracker:ClearAllPoints()
    local wf = WatchFrame
    local width = WATCHFRAME_EXPANDEDWIDTH or 204
    if wf and wf:IsShown() then
        local y = -8
        if WatchFrameHeader and WatchFrameHeader:IsShown() then
            if not wf.collapsed and WatchFrameLines and WatchFrameLines:IsShown() and (wf.nextOffset or 0) < 0 then
                y = -30 + wf.nextOffset + 2      -- WatchFrameLines sits 30 below the top
            else
                y = -28                          -- under the "Objectives" header
            end
        end
        tracker:SetPoint("TOPLEFT", wf, "TOPRIGHT", -width, y)
    else
        tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -30, -230)
    end
    -- below our raid / battlefront bars when one shows where the line would be
    local l, t = tracker:GetLeft(), tracker:GetTop()
    if not l or not t then return end
    local r, b = l + tracker:GetWidth(), t - tracker:GetHeight()
    for _, n in ipairs(BARS) do
        local bar = _G[n]
        if bar and bar:IsShown() and bar:GetLeft() then
            if bar:GetLeft() < r and bar:GetRight() > l and bar:GetBottom() < t and bar:GetTop() > b then
                tracker:ClearAllPoints()
                tracker:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, bar:GetBottom() - 6)
                t = bar:GetBottom() - 6
                b = t - tracker:GetHeight()
            end
        end
    end
end

-- the Path the line follows: the one chosen in the window if it is being
-- walked, else the first being walked (Paths before the trial)
local function followed()
    local set = P.data
    if not set then return nil end
    local sel = WLP.db and WLP.db.pathsSelected
    if sel and set.byKey[sel] and set.byKey[sel].status == "active" then return set.byKey[sel] end
    for _, kind in ipairs({ "path", "trial" }) do
        for _, p in ipairs(set.list) do
            if p.status == "active" and (p.kind == kind or (kind == "path" and p.kind ~= "trial")) then return p end
        end
    end
end

-- short = without the next goal's name, for when the full line will not fit
function UI.TrackerText(p, short)
    local steps, done, nextLabel, counted = 0, 0, nil, nil
    for _, g in ipairs(p.goals) do
        if g.need == 1 then
            steps = steps + 1
            if g.done then done = done + 1 elseif not nextLabel then nextLabel = g.label end
        elseif not counted then
            counted = g
        end
    end
    local s = "|cffffd100" .. p.name .. "|r  "
    if steps > 0 then
        s = s .. done .. "/" .. steps
        if nextLabel and not short then s = s .. ", next " .. nextLabel end
    elseif counted then
        local left = counted.need - counted.have
        s = s .. (left == 1 and "1 level left" or (left .. " levels left"))
    end
    if p.key == "slow_burn" then s = s .. ", XP half" end
    return s
end

function UI.RefreshTracker()
    local p = (WLP.db and WLP.db.pathsTracker) and followed() or nil
    if not p then tracker:Hide(); return end
    tracker.key = p.key
    trIcon:SetTexture(UI.IconOf(p))
    -- the screen edge holds minimap-side buttons: keep the line well inside
    tracker.full = UI.TrackerText(p)
    trText:SetWidth(0)
    trText:SetText(tracker.full)
    if trText:GetStringWidth() > TEXT_MAX then trText:SetText(UI.TrackerText(p, true)) end
    trText:SetWidth(TEXT_MAX)
    placeTracker()
    tracker:Show()
end

tracker:SetScript("OnClick", function(self) UI.Open(self.key) end)
tracker:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Paths of Legends", 1, 0.82, 0)
    GameTooltip:AddLine(self.full or "", 1, 1, 1)
    GameTooltip:AddLine("Click to open the Paths window.", 1, 1, 1)
    GameTooltip:AddLine("Turn this line off there, or /wlpaths tracker.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
tracker:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- the bars come and go, the quest tracker grows and shrinks
tracker:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 1 then return end
    self.t = 0
    placeTracker()
end)

if hooksecurefunc then
    if WatchFrame_Update then hooksecurefunc("WatchFrame_Update", function() if tracker:IsShown() then placeTracker() end end) end
    if WatchFrame_Collapse then hooksecurefunc("WatchFrame_Collapse", function() if tracker:IsShown() then placeTracker() end end) end
end

P.OnChange(function(_, events)
    for _, ev in ipairs(events or {}) do UI.Toast(ev) end
    UI.RefreshTracker()
end)

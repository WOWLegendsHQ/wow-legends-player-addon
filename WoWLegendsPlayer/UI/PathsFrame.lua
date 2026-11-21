-- WoWLegendsPlayer/UI/PathsFrame.lua
-- The Paths window, in the style of the 3.3.5a Achievement frame: the Paths
-- on the left, the chosen one on parchment on the right. Opens from the
-- launcher's "Paths" entry, /wlpaths, and by itself beside the Herald of the
-- Fallen's gossip. Swearing stays in the gossip - this window only shows.
-- Data: Core/Paths.lua. Toasts and the tracker line: UI/PathsAlerts.lua.

local addonName, WLP = ...
local P = WLP.Paths
local UI = {}
P.UI = UI

local W, H = 560, 420
local LIST_W = 176
local TOP_Y = -48              -- where the list and the parchment start
local CW = 306                 -- the parchment's text width
local ACH = "Interface\\AchievementFrame\\"
local FONT = "Fonts\\FRIZQT__.TTF"     -- 3.3.5a ships no italic face

-- ink on parchment
local INK   = { 0.18, 0.11, 0.03 }
local SOFT  = { 0.36, 0.26, 0.14 }
local GREEN = { 0.04, 0.38, 0.04 }
local RED   = { 0.55, 0.06, 0.02 }
local GOLD  = { 0.42, 0.22, 0.00 }

-- badges on the dark list buttons: text, r, g, b
local function badgeOf(p)
    if p.status == "active" then return "Sworn", 1, 0.82, 0 end
    if p.status == "done" then return "Walked", 0.35, 1, 0.35 end
    if p.status == "forsaken" then return "Forsaken", 0.85, 0.45, 0.35 end
    if p.status == "fallen" then return "Fallen", 1, 0.3, 0.3 end
    if p.canSwear then return "Can swear", 1, 1, 1 end
    return "Out of reach", 0.6, 0.6, 0.6
end
UI.BadgeOf = badgeOf

local function day(t)
    if not t or t <= 0 then return nil end
    return (date("%d %b %Y", t):gsub("^0", ""))
end

-- the icon of a Path: its own, else its keepsake's
function UI.IconOf(p)
    if p.icon and p.icon ~= "" then return "Interface\\Icons\\" .. p.icon end
    if p.trophy and p.trophy > 0 then
        local tex = GetItemIcon and GetItemIcon(p.trophy)
        if not tex then tex = select(10, GetItemInfo(p.trophy)) end
        if tex then return tex end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function icon(name)
    if not name or name == "" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    return "Interface\\Icons\\" .. name
end

-- ─── The frame ──────────────────────────────────────────────────────────────
local f = CreateFrame("Frame", "WoWLegendsPlayer_PathsFrame", UIParent)
f:SetSize(W, H)
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:SetMovable(true)
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:Hide()
f:SetBackdrop({
    bgFile = "Interface\\TutorialFrame\\TutorialFrameBackground",
    edgeFile = ACH .. "UI-Achievement-WoodBorder", tile = true, tileSize = 32, edgeSize = 64,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
})
UI.frame = f
if UISpecialFrames then table.insert(UISpecialFrames, "WoWLegendsPlayer_PathsFrame") end

do  -- wood corners, as the Achievement frame
    local corners = {
        { "TOPLEFT", 4, -2, 0, 1, 0, 1 }, { "TOPRIGHT", -4, -2, 1, 0, 0, 1 },
        { "BOTTOMLEFT", 4, 3, 0, 1, 1, 0 }, { "BOTTOMRIGHT", -4, 3, 1, 0, 1, 0 },
    }
    for _, c in ipairs(corners) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ACH .. "UI-Achievement-WoodBorder-Corner")
        t:SetSize(64, 64)
        t:SetPoint(c[1], f, c[1], c[2], c[3])
        t:SetTexCoord(c[4], c[5], c[6], c[7])
    end
end

-- title bar
local titleBar = f:CreateTexture(nil, "ARTWORK")
titleBar:SetTexture(ACH .. "UI-Achievement-Title")
titleBar:SetTexCoord(0, 0.9765625, 0, 0.3125)
titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -18)
titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -18)
titleBar:SetHeight(26)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("CENTER", titleBar, "CENTER", 0, 1)
title:SetText("Paths of Legends")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -12)
close:SetScript("OnClick", function() f:Hide() end)

-- ─── Left: the list ─────────────────────────────────────────────────────────
local list = CreateFrame("Frame", nil, f)
list:SetPoint("TOPLEFT", f, "TOPLEFT", 20, TOP_Y)
list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 20)
list:SetWidth(LIST_W)
local listBG = list:CreateTexture(nil, "BACKGROUND")
listBG:SetTexture(ACH .. "UI-Achievement-Parchment")
listBG:SetAllPoints(list)

local function inkText(parent, size, font, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(font or FONT, size or 12)
    fs:SetShadowOffset(0, 0)
    local c = color or INK
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH("LEFT")
    return fs
end

local pathsLabel = inkText(list, 11)
local trialLabel = inkText(list, 11)
pathsLabel:SetText("Paths")
trialLabel:SetText("Trial")

local buttons = {}
local selectedKey

local function makeListButton(i)
    local b = CreateFrame("Button", nil, list)
    b:SetSize(LIST_W - 6, 40)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(ACH .. "UI-Achievement-Category-Background")
    bg:SetTexCoord(0, 0.6640625, 0, 1)
    bg:SetAllPoints(b)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ACH .. "UI-Achievement-Category-Highlight")
    hl:SetTexCoord(0, 0.6640625, 0, 1)
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(b)
    local sel = b:CreateTexture(nil, "ARTWORK")
    sel:SetTexture(ACH .. "UI-Achievement-Category-Highlight")
    sel:SetTexCoord(0, 0.6640625, 0, 1)
    sel:SetBlendMode("ADD")
    sel:SetAllPoints(b)
    sel:Hide()
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetSize(22, 22)
    ic:SetPoint("LEFT", b, "LEFT", 9, 0)
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local name = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", ic, "TOPRIGHT", 6, 4)
    name:SetWidth(LIST_W - 50)
    name:SetJustifyH("LEFT")
    local badge = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    badge:SetWidth(LIST_W - 50)
    badge:SetJustifyH("LEFT")
    b.sel, b.icon, b.name, b.badge = sel, ic, name, badge
    b:SetScript("OnClick", function(self)
        if self.key then
            selectedKey = self.key
            if WLP.db then WLP.db.pathsSelected = self.key end
            PlaySound("igMainMenuOptionCheckBoxOn")
            UI.Render()
        end
    end)
    buttons[i] = b
    return b
end

-- tracker toggle
local track = CreateFrame("CheckButton", "WoWLegendsPlayer_PathsTrack", list, "UICheckButtonTemplate")
track:SetSize(22, 22)
track:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 6, 6)
local trackLabel = inkText(list, 11)
trackLabel:SetPoint("LEFT", track, "RIGHT", 2, 1)
trackLabel:SetText("Show on screen")
track:SetScript("OnClick", function(self)
    local on = self:GetChecked() and true or false
    if WLP.db then WLP.db.pathsTracker = on end
    if UI.RefreshTracker then UI.RefreshTracker() end
end)
track:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show on screen", 1, 0.82, 0)
    GameTooltip:AddLine("One line under your quest tracker with the", 1, 1, 1)
    GameTooltip:AddLine("Path you are walking. Off by default.", 1, 1, 1)
    GameTooltip:Show()
end)
track:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ─── Right: the parchment ───────────────────────────────────────────────────
local detail = CreateFrame("Frame", nil, f)
detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, 0)
detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)
do  -- the quest log's parchment, in its four pieces
    local tl = detail:CreateTexture(nil, "BACKGROUND")
    tl:SetTexture("Interface\\QuestFrame\\UI-QuestDetails-TopLeft")
    tl:SetTexCoord(0.078125, 1.0, 0.2890625, 1.0)
    local tr = detail:CreateTexture(nil, "BACKGROUND")
    tr:SetTexture("Interface\\QuestFrame\\UI-QuestDetails-TopRight")
    tr:SetTexCoord(0.0, 0.5, 0.2890625, 1.0)
    -- the bottom pieces stop at the torn edge: below it the quest frame's
    -- black button bar is part of the same texture
    local bl = detail:CreateTexture(nil, "BACKGROUND")
    bl:SetTexture("Interface\\QuestFrame\\UI-QuestDetails-BotLeft")
    bl:SetTexCoord(0.078125, 1.0, 0, 0.59)
    local br = detail:CreateTexture(nil, "BACKGROUND")
    br:SetTexture("Interface\\QuestFrame\\UI-QuestDetails-BotRight")
    br:SetTexCoord(0.0, 0.5, 0, 0.59)
    -- natural 236+62 x 182+151; stretched in the same proportions. The
    -- parchment's size is fixed by the window's, so it is known up front.
    local w, h = W - 20 - 20 - LIST_W - 6, H + TOP_Y - 20
    local lw, th = math.floor(w * 236 / 298), math.floor(h * 182 / 333)
    tl:SetPoint("TOPLEFT", detail, "TOPLEFT"); tl:SetSize(lw, th)
    tr:SetPoint("TOPLEFT", tl, "TOPRIGHT"); tr:SetSize(w - lw, th)
    bl:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); bl:SetSize(lw, h - th)
    br:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); br:SetSize(w - lw, h - th)
end

local scroll = CreateFrame("ScrollFrame", "WoWLegendsPlayer_PathsScroll", detail, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -8)
scroll:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -26, 8)
local child = CreateFrame("Frame", nil, scroll)
child:SetWidth(CW)
child:SetHeight(10)
scroll:SetScrollChild(child)
local scrollBar = _G["WoWLegendsPlayer_PathsScrollScrollBar"]
do  -- the quest log's scroll track behind the bar
    local top = scroll:CreateTexture(nil, "BACKGROUND")
    top:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    top:SetTexCoord(0, 0.484375, 0, 1.0)
    top:SetSize(31, 256)
    top:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 5)
    local bottom = scroll:CreateTexture(nil, "BACKGROUND")
    bottom:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar")
    bottom:SetTexCoord(0.515625, 1.0, 0, 0.4140625)
    bottom:SetSize(31, 106)
    bottom:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", -2, -2)
    scroll.track = { top, bottom }
end

-- ─── Pools: everything on the parchment is reused between renders ──────────
local pools = { fs = {}, tex = {}, iconBtn = {}, bar = {} }
local used = {}

local function resetPools()
    for k, list_ in pairs(pools) do
        for _, o in ipairs(list_) do o:Hide() end
        used[k] = 0
    end
end

local function takeFS(size, font, color)
    used.fs = used.fs + 1
    local fs = pools.fs[used.fs]
    if not fs then
        fs = child:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetShadowOffset(0, 0)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        pools.fs[used.fs] = fs
    end
    fs:SetFont(font or FONT, size or 12)
    local c = color or INK
    fs:SetTextColor(c[1], c[2], c[3])
    fs:ClearAllPoints()
    fs:SetWidth(0)
    fs:SetJustifyH("LEFT")
    fs:Show()
    return fs
end

local function takeTex(layer)
    used.tex = used.tex + 1
    local t = pools.tex[used.tex]
    if not t then
        t = child:CreateTexture(nil, "ARTWORK")
        pools.tex[used.tex] = t
    end
    t:SetDrawLayer(layer or "ARTWORK")
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetDesaturated(false)
    t:SetAlpha(1)
    t:SetBlendMode("BLEND")
    t:ClearAllPoints()
    t:Show()
    return t
end

-- an icon with a tooltip: boss icons, "give up" icons, the keepsake
local function takeIcon(size)
    used.iconBtn = used.iconBtn + 1
    local b = pools.iconBtn[used.iconBtn]
    if not b then
        b = CreateFrame("Button", nil, child)
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetPoint("CENTER", b, "CENTER")
        b.border = b:CreateTexture(nil, "OVERLAY")
        b.border:SetTexture(ACH .. "UI-Achievement-Progressive-IconBorder")
        b.border:SetTexCoord(0, 0.65625, 0, 0.65625)
        b.border:SetPoint("CENTER", b, "CENTER", 2, -2)
        b.check = b:CreateTexture(nil, "OVERLAY")
        b.check:SetTexture(ACH .. "UI-Achievement-Criteria-Check")
        b.check:SetTexCoord(0, 0.625, 0, 1)
        b.check:SetSize(24, 19)
        b.check:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 11, -7)
        b:SetScript("OnEnter", function(self)
            if not self.tip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            self.tip(GameTooltip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pools.iconBtn[used.iconBtn] = b
    end
    b:SetSize(size, size)
    b.tex:SetSize(size, size)
    b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.tex:SetDesaturated(false)
    b.tex:SetVertexColor(1, 1, 1)
    b.border:SetSize(size * 1.45, size * 1.45)
    b.border:Hide()
    b.check:Hide()
    b.tip = nil
    b:ClearAllPoints()
    b:Show()
    return b
end

-- the Achievement frame's progress bar
local function takeBar(width)
    used.bar = used.bar + 1
    local s = pools.bar[used.bar]
    if not s then
        s = CreateFrame("StatusBar", nil, child)
        s:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        s:SetStatusBarColor(0, 0.6, 0)
        local bg = s:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(0, 0, 0, 0.55)
        bg:SetAllPoints(s)
        local l = s:CreateTexture(nil, "OVERLAY")
        l:SetTexture(ACH .. "UI-Achievement-ProgressBar-Border")
        l:SetTexCoord(0, 0.0625, 0, 0.75)
        l:SetWidth(16)
        l:SetPoint("TOPLEFT", s, "TOPLEFT", -6, 5)
        l:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", -6, -5)
        local r = s:CreateTexture(nil, "OVERLAY")
        r:SetTexture(ACH .. "UI-Achievement-ProgressBar-Border")
        r:SetTexCoord(0.812, 0.8745, 0, 0.75)
        r:SetWidth(16)
        r:SetPoint("TOPRIGHT", s, "TOPRIGHT", 6, 5)
        r:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", 6, -5)
        local m = s:CreateTexture(nil, "OVERLAY")
        m:SetTexture(ACH .. "UI-Achievement-ProgressBar-Border")
        m:SetTexCoord(0.0625, 0.812, 0, 0.75)
        m:SetPoint("TOPLEFT", l, "TOPRIGHT")
        m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
        s.text = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.text:SetPoint("CENTER", s, "CENTER", 0, 1)
        s.ticks = {}
        pools.bar[used.bar] = s
    end
    s:SetSize(width, 14)
    for _, t in ipairs(s.ticks) do t:Hide() end
    s:ClearAllPoints()
    s:Show()
    return s
end

local function tickAt(bar, i, x)
    local t = bar.ticks[i]
    if not t then
        t = bar:CreateTexture(nil, "OVERLAY")
        t:SetTexture(1, 1, 1, 0.45)
        t:SetWidth(1)
        bar.ticks[i] = t
    end
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
    t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
    t:Show()
end

-- ─── Rendering ──────────────────────────────────────────────────────────────
local y   -- running offset down the parchment (negative)

local function para(text, size, font, color, indent, gap)
    local fs = takeFS(size, font, color)
    fs:SetWidth(CW - (indent or 0) - 4)
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 0, y)
    fs:SetText(text)
    y = y - fs:GetHeight() - (gap or 6)
    return fs
end

local function heading(text)
    y = y - 4
    local fs = para(text, 13, FONT, INK, 0, 4)
    local line = takeTex("ARTWORK")
    line:SetTexture(SOFT[1], SOFT[2], SOFT[3], 0.45)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y + 2)
    line:SetWidth(CW - 8)
    y = y - 4
    return fs
end

local function goalTip(g, p)
    return function(tt)
        tt:SetText(g.label, 1, 1, 1)
        if g.done then
            tt:AddLine(g.need == 1 and "Defeated" or "Done", 0.3, 1, 0.3)
        else
            tt:AddLine("Not yet", 0.7, 0.7, 0.7)
        end
        if g.gate > 0 then
            tt:AddLine("Experience stops at level " .. g.gate .. " until this", 1, 0.82, 0)
            tt:AddLine("stage of " .. p.name .. " is done.", 1, 0.82, 0)
        end
    end
end

local function renderRoad(p)
    local stages = P.Stages(p)
    if #stages == 0 then return end
    heading("The road")

    -- one-step goals (bosses): an overall bar, then icons grouped by stage
    local steps, stepsDone = 0, 0
    for _, g in ipairs(p.goals) do
        if g.need == 1 then
            steps = steps + 1
            if g.done then stepsDone = stepsDone + 1 end
        end
    end
    local lit = p.status == "active" or p.status == "done"
    if steps > 1 then
        local bar = takeBar(CW - 24)
        if lit then bar:SetStatusBarColor(0, 0.6, 0) else bar:SetStatusBarColor(0.45, 0.45, 0.45) end
        bar:SetPoint("TOPLEFT", child, "TOPLEFT", 10, y - 4)
        bar:SetMinMaxValues(0, steps)
        bar:SetValue(stepsDone)
        bar.text:SetText(stepsDone .. " / " .. steps)
        y = y - 26
    end

    for _, s in ipairs(stages) do
        local oneStep = true
        for _, g in ipairs(s.goals) do if g.need ~= 1 then oneStep = false end end

        if oneStep then
            local label = s.name ~= "" and (s.name:sub(1, 1):upper() .. s.name:sub(2)) or "The road"
            local indent = 0
            if s.done then
                local ck = takeTex("OVERLAY")
                ck:SetTexture(ACH .. "UI-Achievement-Criteria-Check")
                ck:SetTexCoord(0, 0.625, 0, 1)
                ck:SetSize(15, 12)
                ck:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
                indent = 17
            end
            local fs = takeFS(12, FONT, s.done and GREEN or INK)
            fs:SetPoint("TOPLEFT", child, "TOPLEFT", indent, y)
            fs:SetText(label)
            if s.gate > 0 then
                local gate = takeFS(10, FONT, s.done and GREEN or SOFT)
                gate:SetPoint("BOTTOMLEFT", fs, "BOTTOMRIGHT", 8, 0)
                gate:SetText(s.done and ("gate " .. s.gate .. " lifted") or ("XP stops at level " .. s.gate))
            end
            y = y - fs:GetHeight() - 8
            local x, rowH = 14, 0
            for _, g in ipairs(s.goals) do
                if x + 70 > CW then x = 14; y = y - rowH; rowH = 0 end
                local b = takeIcon(34)
                b:SetPoint("TOPLEFT", child, "TOPLEFT", x + 18, y - 4)
                b.tex:SetTexture(icon(g.icon))
                b.border:Show()
                if g.done and lit then
                    b.check:Show()
                else
                    b.tex:SetDesaturated(true)
                    b.tex:SetVertexColor(0.65, 0.65, 0.65)
                end
                b.tip = goalTip(g, p)
                local n = takeFS(10, FONT, g.done and INK or SOFT)
                n:SetWidth(70)
                n:SetJustifyH("CENTER")
                n:SetPoint("TOP", b, "BOTTOM", 0, -5)
                n:SetText(g.label)
                rowH = math.max(rowH, 48 + n:GetHeight())
                x = x + 72
            end
            y = y - rowH - 10
        else
            -- counted goals (levels): a 1..need track with ticks every 10
            for _, g in ipairs(s.goals) do
                para(g.label, 12, FONT, g.done and GREEN or INK, 0, 4)
                local bar = takeBar(CW - 24)
                bar:SetPoint("TOPLEFT", child, "TOPLEFT", 10, y - 4)
                bar:SetMinMaxValues(0, g.need)
                bar:SetValue(math.min(g.have, g.need))
                bar.text:SetText(g.have .. " / " .. g.need)
                if not lit then
                    bar:SetStatusBarColor(0.45, 0.45, 0.45)
                else
                    bar:SetStatusBarColor(0, 0.6, 0)
                end
                local step = (g.need >= 20 and g.need % 10 == 0) and 10 or nil
                if step then
                    local w = CW - 24
                    local i = 0
                    for lv = step, g.need - step, step do
                        i = i + 1
                        tickAt(bar, i, math.floor(w * lv / g.need))
                    end
                    for lv = step, g.need, step do
                        local t = takeFS(9, FONT, SOFT)
                        t:SetPoint("TOP", child, "TOPLEFT", 10 + math.floor(w * lv / g.need), y - 21)
                        t:SetText(tostring(lv))
                    end
                    y = y - 36
                else
                    y = y - 24
                end
                -- what is left counts only on a Path being walked
                local left = g.need - g.have
                local line
                if p.status == "fallen" then
                    line = "This hero has fallen."
                elseif g.done and lit then
                    line = "Done."
                elseif p.status ~= "active" then
                    line = nil
                elseif g.label:lower():find("level") then
                    line = left == 1 and "1 level left" or (left .. " levels left")
                else
                    line = left .. " left"
                end
                if line then para(line, 11, FONT, g.done and GREEN or INK, 10, 4) end
            end
        end
    end

    -- the Slow Burn's one extra line
    if p.key == "slow_burn" and p.status == "active" then
        para("XP: half rate", 12, FONT, GOLD, 10, 4)
    end
end

local function renderReward(p)
    if not p.trophy or p.trophy <= 0 then return end
    heading("Reward")
    local b = takeIcon(32)
    b:SetPoint("TOPLEFT", child, "TOPLEFT", 10, y - 2)
    b.tex:SetTexture(UI.IconOf(p))
    b.tex:SetTexCoord(0, 1, 0, 1)
    if p.status ~= "done" then
        b.tex:SetVertexColor(0.85, 0.85, 0.85)
    end
    local id = p.trophy
    b.tip = function(tt) tt:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0") end
    local name, _, quality = GetItemInfo(id)
    local n = takeFS(12, FONT, INK)
    n:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, -1)
    n:SetWidth(CW - 60)
    if name then
        local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
        -- the brighter quality colours vanish on parchment: darken them
        if c then n:SetTextColor(c.r * 0.55, c.g * 0.55, c.b * 0.55) end
        n:SetText(name)
    else
        n:SetText("A keepsake")
        UI.pendingItem = id
    end
    local note, color = "Yours when the Path is walked.", SOFT
    if p.status == "done" then
        note, color = "Yours: the Path is walked.", GREEN
    elseif p.status == "forsaken" then
        note, color = "Lost: the Path was forsaken.", RED
    end
    local s = takeFS(11, FONT, color)
    s:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -3)
    s:SetWidth(CW - 60)
    s:SetText(note)
    y = y - 44
end

local function renderDetail(set, p)
    resetPools()
    y = -6
    if not p then
        local msg
        if not set then
            local waited = P.askedAt and (GetTime() - P.askedAt) >= 4
            msg = waited and "This realm doesn't support the Paths window yet."
                or "Asking the realm..."
        else
            msg = "No Paths are offered on this realm."
        end
        para(msg, 13, FONT, SOFT, 10, 4)
        child:SetHeight(-y + 8)
        return
    end

    -- name, icon, status
    local b = takeIcon(40)
    b:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -10)
    b.tex:SetTexture(UI.IconOf(p))
    b.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local frame = takeTex("OVERLAY")
    frame:SetTexture(ACH .. "UI-Achievement-IconFrame")
    frame:SetTexCoord(0, 0.5625, 0, 0.5625)
    frame:SetSize(56, 56)
    frame:SetPoint("CENTER", b, "CENTER", -1, 2)
    if p.status ~= "active" and p.status ~= "done" then b.tex:SetDesaturated(true) end
    if p.trophy and p.trophy > 0 and (not p.icon or p.icon == "") then
        local id = p.trophy
        b.tip = function(tt) tt:SetHyperlink("item:" .. id .. ":0:0:0:0:0:0:0") end
    end

    local name = takeFS(17, FONT, INK)
    name:SetPoint("TOPLEFT", child, "TOPLEFT", 62, -10)
    name:SetWidth(CW - 66)
    name:SetText(p.name)

    local text, color
    local when = day(p.sworn)
    if p.status == "active" then
        text, color = when and ("Sworn on " .. when) or "Sworn", GOLD
    elseif p.status == "done" then
        text, color = when and ("Walked - sworn on " .. when) or "Walked", GREEN
    elseif p.status == "forsaken" then
        text, color = when and ("Forsaken - sworn on " .. when) or "Forsaken", RED
    elseif p.status == "fallen" then
        text, color = "Fallen - this hero has died", RED
    elseif p.canSwear then
        text, color = "Not sworn - you can swear it now", INK
    else
        text, color = "Out of reach", SOFT
    end
    local st = takeFS(11, FONT, color)
    st:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    st:SetWidth(CW - 66)
    st:SetText(text)
    y = math.min(-62, -10 - name:GetHeight() - 3 - st:GetHeight() - 10)

    if not p.live then
        para("Switched off on this realm: its limits are lifted, your record is kept.", 11, FONT, RED, 0, 6)
    end

    local creed = P.Text(p, "creed")
    if creed ~= "" then
        para(creed, 12, FONT, SOFT, 4, 8)
    end

    if #p.rules > 0 then
        heading("What you give up")
        for _, r in ipairs(p.rules) do
            local ic = takeIcon(18)
            ic:SetPoint("TOPLEFT", child, "TOPLEFT", 6, y - 1)
            ic.tex:SetTexture(icon(r.icon))
            local fs = takeFS(11, FONT, INK)
            fs:SetWidth(CW - 36)
            fs:SetPoint("TOPLEFT", child, "TOPLEFT", 30, y - 2)
            fs:SetText(r.text)
            y = y - math.max(20, fs:GetHeight() + 6)
        end
    end

    renderRoad(p)
    renderReward(p)

    if p.status == "none" then
        heading(p.canSwear and "Where to swear" or "Why not now")
        local where = set.herald and set.herald.where or ""
        if where ~= "" then para(where, 11, FONT, INK, 0, 4) end
        local offer = P.Text(p, "offer")
        if offer ~= "" and p.canSwear then
            para("Choose: \"" .. offer .. "\"", 11, FONT, SOFT, 0, 4)
        end
        if not p.canSwear and p.reason ~= "" then
            para(p.reason, 11, FONT, RED, 0, 4)
        end
    elseif p.status == "forsaken" then
        heading("Forsaken")
        para("You renounced this Path. It cannot be sworn again.", 11, FONT, INK, 0, 4)
    end

    child:SetHeight(-y + 8)
end

local function setDim(b, dim)
    b:SetAlpha(dim and 0.5 or 1)
end

local function pick(set)
    if not set or #set.list == 0 then return nil end
    if selectedKey and set.byKey[selectedKey] then return set.byKey[selectedKey] end
    local saved = WLP.db and WLP.db.pathsSelected
    if saved and set.byKey[saved] then selectedKey = saved; return set.byKey[saved] end
    for _, p in ipairs(set.list) do
        if p.status == "active" then selectedKey = p.key; return p end
    end
    selectedKey = set.list[1].key
    return set.list[1]
end

function UI.Render()
    local set = P.data
    local p = pick(set)

    -- the list: Paths first, the trial(s) in their own small group
    local paths, trials = {}, {}
    if set then
        for _, q in ipairs(set.list) do
            if q.kind == "trial" then trials[#trials + 1] = q else paths[#paths + 1] = q end
        end
    end
    local yy, i = -6, 0
    local function place(q)
        i = i + 1
        local b = buttons[i] or makeListButton(i)
        b.key = q.key
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", list, "TOPLEFT", 3, yy)
        b.icon:SetTexture(UI.IconOf(q))
        b.icon:SetDesaturated(q.status ~= "active" and q.status ~= "done")
        b.name:SetText(q.name)
        local text, r, g, bl = badgeOf(q)
        if not q.live then text = text .. " - off" end
        b.badge:SetText(text)
        b.badge:SetTextColor(r, g, bl)
        if q.key == selectedKey then b.sel:Show() else b.sel:Hide() end
        setDim(b, not q.live)
        b:Show()
        yy = yy - 41
    end
    pathsLabel:SetPoint("TOPLEFT", list, "TOPLEFT", 8, yy)
    if #paths > 0 then pathsLabel:Show(); yy = yy - 14 else pathsLabel:Hide() end
    for _, q in ipairs(paths) do place(q) end
    if #trials > 0 then
        yy = yy - 6
        trialLabel:ClearAllPoints()
        trialLabel:SetPoint("TOPLEFT", list, "TOPLEFT", 8, yy)
        trialLabel:Show()
        yy = yy - 14
        for _, q in ipairs(trials) do place(q) end
    else
        trialLabel:Hide()
    end
    for j = i + 1, #buttons do buttons[j]:Hide(); buttons[j].key = nil end

    track:SetChecked(WLP.db and WLP.db.pathsTracker)

    renderDetail(set, p)
    scroll:SetVerticalScroll(0)
    if scrollBar then
        local need = child:GetHeight() > scroll:GetHeight() + 1
        if need then scrollBar:Show() else scrollBar:Hide() end
        for _, t in ipairs(scroll.track) do if need then t:Show() else t:Hide() end end
    end
end

-- ─── Open / close / dock beside the Herald ──────────────────────────────────
local docked = false

local function restorePosition()
    WLP.RestoreFramePoint(f, "pathsFrame", { point = "CENTER", relPoint = "CENTER", x = 0, y = 40 })
end

f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    docked = false
    WLP.SaveFramePoint(self, "pathsFrame")
end)

f:SetScript("OnShow", function()
    PlaySound("AchievementMenuOpen")
    P.Ask()
    if not P.data then
        -- an older realm never answers: say so plainly once the ask is 4 s old
        WLP.After(4.2, function() if not P.data and f:IsShown() then UI.Render() end end)
    end
    UI.Render()
end)
f:SetScript("OnHide", function()
    PlaySound("AchievementMenuClose")
    if docked then docked = false; restorePosition() end
end)

function UI.Open(key)
    if key then selectedKey = key end
    if f:IsShown() then UI.Render() else f:Show() end
    f:Raise()
end

function UI.Toggle()
    if f:IsShown() then f:Hide() else UI.Open() end
end

function UI.Dock()
    if f:IsShown() and not docked then return end   -- already open where he put it
    if GossipFrame then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", GossipFrame, "TOPRIGHT", -30, -12)
        docked = true
    end
    -- at the Herald, start on a Path he can swear
    if P.data then
        for _, q in ipairs(P.data.list) do
            if q.status == "none" and q.canSwear then selectedKey = q.key; break end
        end
    end
    UI.Open()
end

-- a push while open: draw it; a keepsake's name may arrive a moment later
P.OnChange(function()
    if f:IsShown() then UI.Render() end
end)

local gossip = CreateFrame("Frame")
gossip:RegisterEvent("GOSSIP_SHOW")
gossip:RegisterEvent("GOSSIP_CLOSED")
gossip:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_SHOW" then
        -- only on a realm that answered: older realms have the Herald too
        if P.data and P.IsHerald("npc") then UI.Dock() end
    elseif event == "GOSSIP_CLOSED" then
        if docked then f:Hide() end
    end
end)

-- the keepsake's name and icon are cached by the client only after a query:
-- a hidden tooltip asks for each one as soon as a set arrives
local scanTip = CreateFrame("GameTooltip", "WoWLegendsPlayer_PathsScanTip", UIParent, "GameTooltipTemplate")
P.OnChange(function(set)
    for _, q in ipairs(set and set.list or {}) do
        if q.trophy and q.trophy > 0 and not GetItemInfo(q.trophy) then
            scanTip:SetOwner(UIParent, "ANCHOR_NONE")
            scanTip:SetHyperlink("item:" .. q.trophy .. ":0:0:0:0:0:0:0")
            scanTip:Hide()
        end
    end
end)
local itemWatch = CreateFrame("Frame")
itemWatch:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t < 0.5 then return end
    self.t = 0
    if UI.pendingItem and f:IsShown() and GetItemInfo(UI.pendingItem) then
        UI.pendingItem = nil
        UI.Render()
    end
end)

WLP.AddLogin(function()
    restorePosition()
end)

-- /wlpaths [tracker]
SLASH_WLPATHS1 = "/wlpaths"
SlashCmdList["WLPATHS"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "tracker" then
        if WLP.db then WLP.db.pathsTracker = not WLP.db.pathsTracker end
        if UI.RefreshTracker then UI.RefreshTracker() end
        WLP.Print("Paths tracker " .. ((WLP.db and WLP.db.pathsTracker) and "on" or "off") .. ".")
    else
        UI.Toggle()
    end
end

-- WoWLegendsPlayer/UI/MainFrame.lua
-- Movable parent window: header, left tab rail ("left menu"), content area
-- (each tab hangs its own "top tabs" inside), and a footer legend.

local addonName, WLP = ...

local FRAME_W, FRAME_H = 900, 560
local HEADER_H = 32
local RAIL_W   = 120
local FOOTER_H = 22

WLP.tabs = {}   -- { id, label, wl, builder, onShow, button, contentFrame }

function WLP.RegisterTab(def) table.insert(WLP.tabs, def) end

local function selectTab(index)
    local tabs = WLP.tabs
    if not tabs[index] then return end
    for i, tab in ipairs(tabs) do
        if tab.button then
            if i == index then
                tab.button.bg:SetTexture(0.10, 0.30, 0.40, 0.95)
                tab.button.sel:Show()
                tab.button.label:SetTextColor(1, 0.82, 0.30)
            else
                tab.button.bg:SetTexture(0, 0, 0, 0)
                tab.button.sel:Hide()
                tab.button.label:SetTextColor(tab.wl and 1 or 0.85, tab.wl and 0.79 or 0.85, tab.wl and 0.30 or 0.88)
            end
        end
        if tab.contentFrame then
            if i == index then tab.contentFrame:Show() else tab.contentFrame:Hide() end
        end
    end
    if tabs[index].onShow then pcall(tabs[index].onShow) end
    if WLP.db then WLP.db.activeTab = index end
end
WLP.SelectTab = selectTab

function WLP.SelectTabById(id)
    for i, tab in ipairs(WLP.tabs) do
        if tab.id == id then selectTab(i); return i end
    end
end

local function buildRail(main)
    local rail = CreateFrame("Frame", nil, main)
    rail:SetPoint("TOPLEFT", main, "TOPLEFT", 6, -HEADER_H - 4)
    rail:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", 6, FOOTER_H + 4)
    rail:SetWidth(RAIL_W)
    WLP.ApplyBackdrop(rail, "inset", 0.5, 0.02, 0.03, 0.05)
    main.rail = rail
    return rail
end

local function buildAllTabs()
    local main = WoWLegendsPlayer_MainFrame
    local rail = main.rail

    local content = CreateFrame("Frame", nil, main)
    content:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
    content:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -8, FOOTER_H + 4)
    main.contentArea = content

    local prev
    for i, tab in ipairs(WLP.tabs) do
        local label = tab.label
        if tab.wl then label = "* " .. label end
        local btn = WLP.MakeFlatButton(rail, RAIL_W - 12, 30, label, { padLeft = 10, font = "GameFontNormal" })
        btn.bg:SetTexture(0, 0, 0, 0)

        -- Left selection accent bar (shown only on the active tab).
        local sel = btn:CreateTexture(nil, "OVERLAY")
        sel:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 0)
        sel:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", -2, 0)
        sel:SetWidth(3)
        sel:SetTexture(1, 0.79, 0.30, 1)
        sel:Hide()
        btn.sel = sel

        if prev then btn:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
        else btn:SetPoint("TOPLEFT", rail, "TOPLEFT", 6, -6) end
        btn:SetID(i)
        btn:SetScript("OnClick", function(self) selectTab(self:GetID()) end)
        tab.button = btn
        prev = btn

        local cf = CreateFrame("Frame", nil, content)
        cf:SetAllPoints(content)
        cf:Hide()
        tab.contentFrame = cf
        if tab.builder then
            local ok, err = pcall(tab.builder, cf)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff5555WLP tab '" .. tostring(tab.label) .. "' build error:|r " .. tostring(err))
            end
        end
    end

    selectTab((WLP.db and WLP.db.activeTab) or 1)
end

function WLP.RestoreMainFramePosition()
    if WoWLegendsPlayer_MainFrame then
        WLP.RestoreFramePoint(WoWLegendsPlayer_MainFrame, "frame", WLP.defaults.frame)
    end
end

local function createMainFrame()
    local f = CreateFrame("Frame", "WoWLegendsPlayer_MainFrame", UIParent)
    f:SetSize(FRAME_W, FRAME_H)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); WLP.SaveFramePoint(self, "frame") end)
    f:SetScript("OnShow", function() if WLP.db and WLP.db.frame then WLP.db.frame.shown = true end end)
    f:SetScript("OnHide", function() if WLP.db and WLP.db.frame then WLP.db.frame.shown = false end end)
    WLP.ApplyBackdrop(f, "panel", 0.95)

    -- Header
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    header:SetHeight(HEADER_H)
    WLP.ApplyBackdrop(header, "inset", 0.6, 0.06, 0.09, 0.12)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 12, 0)
    title:SetText(WLP.colors.brand .. "WoW Legends" .. WLP.colors.reset .. " " ..
        WLP.colors.white .. "Player" .. WLP.colors.reset ..
        "  " .. WLP.colors.muted .. "v" .. WLP.version .. WLP.colors.reset)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", header, "RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Current-target readout — many things fall back to your target (the bot
    -- you whisper an order to, the character you add as a bot, etc.).
    local targetFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetFS:SetPoint("RIGHT", close, "LEFT", -10, 0)
    local function updateTarget()
        local n = UnitName("target")
        if n and n ~= "" then
            targetFS:SetText(WLP.colors.muted .. "Target: " .. WLP.colors.reset .. WLP.colors.accent .. n .. WLP.colors.reset)
        else
            targetFS:SetText(WLP.colors.muted .. "No target" .. WLP.colors.reset)
        end
    end
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", updateTarget)
    f:HookScript("OnShow", updateTarget)
    f.header = header

    -- Footer: command-category legend.
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 4)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    footer:SetHeight(FOOTER_H)
    local legend = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("LEFT", footer, "LEFT", 4, 0)
    legend:SetText(
        WLP.cats.player.color .. WLP.cats.player.name .. WLP.colors.reset .. "   " ..
        WLP.cats.bot.color    .. WLP.cats.bot.name    .. WLP.colors.reset .. "   " ..
        WLP.colors.legend .. "* WoW Legends exclusive" .. WLP.colors.reset)

    f.tabRail = buildRail(f)
    f:Hide()
    return f
end

WLP.AddLogin(function()
    if not WoWLegendsPlayer_MainFrame then createMainFrame() end
    WLP.RestoreMainFramePosition()
    buildAllTabs()
    if WLP.db and WLP.db.frame and WLP.db.frame.shown then WoWLegendsPlayer_MainFrame:Show() end
end)

-- Create the shell early so tab files can reference it; surface load errors.
local ok, err = pcall(createMainFrame)
if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000WLP MainFrame ERROR:|r " .. tostring(err))
    WLP._mainFrameLoadError = tostring(err)
end

-- WoWLegendsPlayer/UI/Tabs/XP.lua
-- ★ Your personal XP rate (PLAYER_COMMANDS.md §5). A 1-10 slider + Apply, plus
-- view / enable / disable / reset rows.

local addonName, WLP = ...

local Rows = {
    { id="xp_view", label="View XP rate", format=".xp view", wl=true, group="XP",
      tooltip="Show your current XP rate and the maximum the server allows (default cap 10)." },
    { id="xp_enable", label="Enable my rate", format=".xp enable", wl=true, group="XP",
      tooltip="Turn your custom XP rate on." },
    { id="xp_disable", label="Disable my rate", format=".xp disable", wl=true, group="XP",
      tooltip="Turn it off - back to the realm's default rate." },
    { id="xp_default", label="Reset to default", format=".xp default", wl=true, group="XP",
      tooltip="Reset your XP rate to the server's configured default." },
}

local function xpBuilder(parent)
    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    info:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    info:SetJustifyH("LEFT")
    info:SetText(WLP.colors.muted ..
        "Set your own leveling pace. 1 = Blizzlike, up to the server's maximum (default 10). "
        .. "Drag the slider and hit Apply; use View to read your current rate and the cap." .. WLP.colors.reset)

    local hdr = WLP.CreateSectionHeader(parent, "Set your XP rate")
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -(8 + info:GetStringHeight() + 14))

    local slider = CreateFrame("Slider", "WoWLegendsPlayer_XPSlider", parent, "OptionsSliderTemplate")
    slider:SetWidth(240)
    slider:SetHeight(18)
    slider:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 8, -22)
    slider:SetMinMaxValues(1, 10)
    slider:SetValueStep(1)
    slider:SetValue(1)
    local sName = slider:GetName()
    if _G[sName .. "Low"]  then _G[sName .. "Low"]:SetText("1x") end
    if _G[sName .. "High"] then _G[sName .. "High"]:SetText("10x") end
    if _G[sName .. "Text"] then _G[sName .. "Text"]:SetText("XP rate: 1x") end
    slider:SetScript("OnValueChanged", function(self)
        local v = math.floor(self:GetValue() + 0.5)
        if _G[self:GetName() .. "Text"] then _G[self:GetName() .. "Text"]:SetText("XP rate: " .. v .. "x") end
    end)

    local apply = WLP.MakeFlatButton(parent, 110, 24, "Apply rate", { justify = "CENTER" })
    apply:SetPoint("LEFT", slider, "RIGHT", 24, 0)
    apply:SetScript("OnClick", function()
        local v = math.floor(slider:GetValue() + 0.5)
        WLP.RunCommand(".xp set " .. v)
    end)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -10)
    hint:SetText("If the server cap is above 10, View shows it - you can also type .xp set <rate> directly.")

    WLP.LayoutRows(parent, Rows, { yTop = 8 + info:GetStringHeight() + 14 + 120, x = 8,
        sectionTitle = "Manage" })
end

WLP.RegisterTab({
    id = "xp", label = "XP Rate", wl = true,
    builder = xpBuilder,
})

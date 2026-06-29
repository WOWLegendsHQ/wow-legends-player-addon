-- WoWLegendsPlayer/UI/ToggleButton.lua
-- Draggable launcher button. Click → toggle panel. SHIFT-drag → reposition.

local addonName, WLP = ...

local SIZE = 32

function WLP.Toggle()
    local f = WoWLegendsPlayer_MainFrame
    if not f then
        WLP.Warn("main frame not created — run /wlp debug.")
        return
    end
    if f:IsShown() then f:Hide() else f:Show(); f:Raise() end
end

local function createToggleButton()
    local b = CreateFrame("Button", "WoWLegendsPlayer_ToggleButton", UIParent)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if icon.SetMask then icon:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", b, "CENTER", 11, -11)

    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    b:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then self:StartMoving(); self.isMoving = true end
    end)
    b:SetScript("OnDragStop", function(self)
        if self.isMoving then
            self:StopMovingOrSizing(); self.isMoving = false
            WLP.SaveFramePoint(self, "button")
        end
    end)
    b:SetScript("OnClick", function() WLP.Toggle() end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("WoW Legends Player", 1, 0.79, 0.30)
        GameTooltip:AddLine("Click to toggle the player panel.", 1, 1, 1)
        GameTooltip:AddLine("Build & command your bot party, set roles,", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("run dungeons, tune XP, Companion, Hardcore.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("SHIFT-drag to move this button.", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("/wlp reset to recenter everything.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:Show()
    return b
end

function WLP.RestoreButtonPosition()
    if WoWLegendsPlayer_ToggleButton then
        WLP.RestoreFramePoint(WoWLegendsPlayer_ToggleButton, "button", WLP.defaults.button)
    end
end

WLP.AddLogin(function()
    if not WoWLegendsPlayer_ToggleButton then createToggleButton() end
    WLP.RestoreButtonPosition()
    if WLP.db and WLP.db.minimap and WLP.db.minimap.hide then
        WoWLegendsPlayer_ToggleButton:Hide()
    end
end)

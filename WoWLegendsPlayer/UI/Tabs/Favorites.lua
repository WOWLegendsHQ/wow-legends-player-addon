-- WoWLegendsPlayer/UI/Tabs/Favorites.lua
-- Your pinned commands. Right-click any command anywhere to pin/unpin it.

local addonName, WLP = ...

WLP.RegisterTab({
    id = "favorites", label = "Favorites",
    builder = function(parent)
        local scroll, content = WLP.CreateScrollContent(parent)

        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOP", content, "TOP", 0, -40)
        empty:SetText("No favorites yet.\nRight-click any command to pin it here.")
        empty:SetJustifyH("CENTER")

        local holder
        local function refresh()
            if holder then holder:Hide(); holder:SetParent(nil); holder = nil end
            local favs = WLP.GetFavorites()
            if #favs == 0 then empty:Show(); content:SetHeight(200); return end
            empty:Hide()
            holder = CreateFrame("Frame", nil, content)
            holder:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            holder:SetWidth(780)
            local used = WLP.LayoutRows(holder, favs, { rowsPerColumn = 16, columnWidth = 380 })
            holder:SetHeight(used)
            content:SetHeight(math.max(used, 200))
        end
        WLP.RefreshFavoritesTab = refresh
        refresh()
    end,
    onShow = function() if WLP.RefreshFavoritesTab then WLP.RefreshFavoritesTab() end end,
})

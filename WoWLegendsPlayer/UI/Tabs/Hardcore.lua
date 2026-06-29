-- WoWLegendsPlayer/UI/Tabs/Hardcore.lua
-- ★ Hardcore (permadeath) + Mak'gora (PLAYER_COMMANDS.md §7). The opt-in is
-- irreversible and level-1 only, so "Enable Hardcore" routes through the loud
-- dedicated confirm (def.hardcore); the server still asks you to confirm again
-- in-game (run it twice within 30s).

local addonName, WLP = ...

local Rows = {
    { id="hc_on", label="Enable Hardcore", format=".hardcore on", wl=true, group="Hardcore", hardcore=true,
      tooltip="Opt this character into PERMADEATH. LEVEL 1 ONLY and irreversible - fall once and the hero is gone for good.\nConfirm by running it TWICE within 30s (or use the Herald of the Fallen NPC). Blocked if realm-wide HC is on, opt-in is disabled, you are not level 1, or you are already hardcore/fallen." },
    { id="hc_status", label="Hardcore status", format=".hardcore status", wl=true, group="Hardcore",
      tooltip="Show your state: FALLEN / ACTIVE (hardcore) / normal." },
    { id="makgora", label="Mak'gora challenge", format=".makgora", wl=true, group="Hardcore", danger=true,
      tooltip="Arm a duel TO THE DEATH with your targeted player. Both must be hardcore, target each other, and both run .makgora; the next normal duel within 30s becomes lethal and the loser falls forever. (Normal duels never kill.)" },
}

local function hardcoreBuilder(parent)
    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    info:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    info:SetJustifyH("LEFT")
    info:SetText(
        WLP.colors.danger .. "Permadeath." .. WLP.colors.reset .. " "
        .. WLP.colors.muted .. "Opt a level-1 character into Hardcore and a single death ends it forever - there is no undo. "
        .. "Hardcore players can also challenge each other to a lethal Mak'gora duel." .. WLP.colors.reset)

    local rowsTop = 8 + info:GetStringHeight() + 16
    local used = WLP.LayoutRows(parent, Rows, { yTop = rowsTop, x = 8,
        sectionTitle = "Hardcore & Mak'gora" })

    local warn = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -(rowsTop + used + 12))
    warn:SetJustifyH("LEFT")
    warn:SetText(WLP.colors.warn ..
        "Enabling Hardcore asks you to confirm here, then the server asks again in-game (run .hardcore on twice within 30s)."
        .. WLP.colors.reset)
end

WLP.RegisterTab({
    id = "hardcore", label = "Hardcore", wl = true,
    builder = hardcoreBuilder,
})

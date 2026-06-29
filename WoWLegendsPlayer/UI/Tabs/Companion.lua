-- WoWLegendsPlayer/UI/Tabs/Companion.lua
-- * Your ONE permanent battle-companion (a bound bot that fights at your side,
-- chats, and remembers you). Source: PLAYER_COMMANDS.md §6 + §8.3.
-- Faction-aware Create row with race/class dropdowns + a name field, exactly
-- like the GM addon's Companion panel.

local addonName, WLP = ...

local function companionBuilder(parent)
    local faction = UnitFactionGroup("player") or "Alliance"
    local raceChoices  = WLP.Specs.races[faction] or WLP.Specs.races.Alliance
    local classChoices = WLP.Specs.classes
    local raceList = table.concat(raceChoices, "  ")

    local rows = {
        { id="comp_show", label="My companion", format=".companion", wl=true, group="Companion",
          tooltip="Show your companion (name, race, class), or how to create one if you have none yet." },
        { id="comp_create", label="Create companion", format=".companion create %s %s %s", wl=true, group="Companion",
          args={ {key="race",placeholder="race",choices=raceChoices,width=110},
                 {key="class",placeholder="class",choices=classChoices,width=100},
                 {key="name",placeholder="name",width=120} },
          tooltip="Claim your ONE permanent battle companion - a bot that fights at your side, chats, and remembers you.\n"
              .. "Your faction (" .. faction .. ") races: " .. raceList
              .. "\nName: 2-12 letters, unique.   e.g.  .companion create " .. (raceChoices[1] or "orc") .. " warrior Grommash" },
        { id="comp_summon", label="Summon companion", format=".companion summon", wl=true, group="Companion",
          tooltip="Recall your companion to your side (auto-joins your group and fights with you)." },
        { id="comp_dismiss", label="Dismiss companion", format=".companion dismiss", wl=true, group="Companion",
          tooltip="Send your companion away temporarily. Recall any time with Summon." },
        { id="comp_forget", label="Forget companion", format=".companion forget", wl=true, group="Companion", danger=true,
          tooltip="Permanently release your companion: the bond and its memory are wiped and the pool character is freed, so you can create a new one." },
    }

    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    info:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    info:SetJustifyH("LEFT")
    info:SetText(WLP.colors.muted ..
        "Your ONE permanent battle companion - a bound bot that fights at your side, chats, and remembers you. "
        .. "Once it is out, drive it like any bot from the Bots tab ($follow, $attack, $talents spec ...). Available to every player."
        .. WLP.colors.reset)

    WLP.LayoutRows(parent, rows, { yTop = 8 + info:GetStringHeight() + 14, sectionTitle = "Your companion" })
end

WLP.RegisterTab({
    id = "companion", label = "Companion", wl = true,
    builder = companionBuilder,
})

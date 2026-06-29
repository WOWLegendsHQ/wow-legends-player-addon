-- WoWLegendsPlayer/UI/Tabs/Bots.lua
-- The PlayerBot command center (PLAYER_COMMANDS.md §1-§4). Two command kinds:
--   • dot-commands  .playerbots ...   (manage WHO your bots are)  → run as you
--   • bot orders    $word             (tell your bots WHAT to do)  → party/whisper
-- The scope bar at the very top decides where $ orders go: ALL my bots (party/
-- raid) or the TARGETED bot (whisper). Sub-tabs ("top tabs"): Party · Roles ·
-- Combat · Items · Dungeon.

local addonName, WLP = ...

-- def builders ---------------------------------------------------------------
local function order(id, label, word, tooltip, args, danger)   -- $ bot order
    return { id = id, label = label, format = word, send = "bot",
             group = "Bots", tooltip = tooltip, args = args, danger = danger }
end
local function pb(id, label, fmt, tooltip, args, danger)        -- .playerbots dot-command
    return { id = id, label = label, format = fmt, group = "Bots",
             tooltip = tooltip, args = args, danger = danger }
end

-- ─── PARTY: build & manage your bots (.playerbots) ─────────────────────────
local Build = {
    pb("pb_list",     "List my bots",      ".playerbots bot list",
        "Show your bots: online (+), your offline alts (-), and randoms in your group."),
    pb("pb_addclass", "Add class bot",     ".playerbots bot addclass %s %s",
        "Summon a fresh, pre-geared DISPOSABLE class bot of your faction - the fastest way to fill a party. Gender optional (male/female).\nClasses: warrior paladin hunter rogue priest dk shaman mage warlock druid. (DK needs you to meet the heroic level requirement.)",
        { {key="class",placeholder="class",choices=WLP.Specs.classes,width=90}, {key="gender",placeholder="gender",choices={"male","female"},optional=true,width=80} }),
    pb("pb_lookup",   "Classes available", ".playerbots bot lookup",
        "List the classes you can summon with Add class bot."),
    pb("pb_add",      "Add bot by name",   ".playerbots bot add %s",
        "Add your OWN character(s) as bots (you become master). Their progress persists. Comma-separate several. Blank = current target.",
        { {key="name",placeholder="Name[,Name2]",fallback="target",width=150} }),
    pb("pb_addacct",  "Add whole account", ".playerbots bot addaccount %s",
        "Add ALL characters on that account (or the named char's account) as bots at once.",
        { {key="acct",placeholder="account / char",width=150} }),
    pb("pb_login",    "Login a bot",       ".playerbots bot login %s",
        "Bring one of your offline bots online by name.",
        { {key="name",placeholder="Name",fallback="target",width=150} }),
    pb("pb_remove",   "Remove a bot",      ".playerbots bot remove %s",
        "Remove / log out one of your bots (aliases: logout, rm). Blank = current target.",
        { {key="name",placeholder="Name",fallback="target",width=150} }),
    pb("pb_remall",   "Remove ALL bots",   ".playerbots bot remove *",
        "Log out every bot you currently control.", nil, true),
}

local Manage = {
    pb("pb_init",   "Regear to my gear", ".playerbots bot init=auto %s",
        "Re-gear addclass bot(s), scaled to YOUR gear. Target a bot name, or * for all bots in your group.\n(init=auto is the player option; specific quality tiers may be GM-restricted depending on the server's AutoInitOnly setting.)",
        { {key="name",placeholder="name / *",fallback="target",width=120} }),
    pb("pb_levelup","Re-roll at level",  ".playerbots bot levelup",
        "Re-roll your bots at their current level."),
    pb("pb_refresh","Refresh gear",      ".playerbots bot refresh",
        "Re-roll your bots' consumables and gear."),
    pb("pb_random", "Full re-randomize", ".playerbots bot random",
        "Completely re-randomize your bots.", nil, true),
    pb("pb_quests", "Init instance quests", ".playerbots bot quests",
        "Initialize instance quests for your bots."),
    pb("pb_setkey", "Set account key",   ".playerbots account setKey %s",
        "Set a security key on your account so a trusted friend can link to it and command your characters.",
        { {key="key",placeholder="key",width=120} }),
    pb("pb_link",   "Link to account",   ".playerbots account link %s %s",
        "Link to a friend's account using their key, so you can add their characters as bots. Needs the server's AllowTrustedAccountBots enabled.",
        { {key="acct",placeholder="account",width=100}, {key="key",placeholder="key",width=70} }),
    pb("pb_linked", "Linked accounts",   ".playerbots account linkedAccounts",
        "List the accounts linked to yours."),
    pb("pb_unlink", "Unlink account",    ".playerbots account unlink %s",
        "Remove a link.", { {key="acct",placeholder="account",width=120} }),
}

local function partyBuilder(parent)
    WLP.LayoutRows(parent, Build,  { yTop = 8, x = 8,   columnWidth = 360, sectionTitle = "Build your party (.playerbots)" })
    WLP.LayoutRows(parent, Manage, { yTop = 8, x = 380, columnWidth = 368, sectionTitle = "Re-gear & account linking" })
end

-- ─── ROLES: a bot's role = its spec ($talents) ─────────────────────────────
local Roles = {
    order("r_report",  "Current spec",   "talents",           "Report the bot's current spec + help."),
    order("r_list",    "List specs",     "talents spec list", "List this class's premade specs (point spreads)."),
    order("r_set",     "Set spec",       "talents spec %s",
        "Switch to a named spec - this sets tank/heal/dps.\nWarrior: arms fury protection | Paladin: holy protection retribution | Hunter: beast mastery / marksmanship / survival | Rogue: assasination combat subtlety | Priest: discipline holy shadow | DK: blood frost unholy | Shaman: elemental enhancement restoration | Mage: arcane fire frost | Warlock: affliction demonology destruction | Druid: balance / feral combat / restoration.",
        { {key="spec",placeholder="spec name",width=160} }),
    order("r_switch",  "Dual-spec",      "talents switch %s", "Activate primary (1) or secondary (2) dual-spec.",
        { {key="n",placeholder="1 or 2",choices={"1","2"},width=70} }),
    order("r_autopick","Auto-pick tree", "talents autopick",  "Auto-pick a full talent tree for the level."),
    order("r_apply",   "Apply talent link","talents apply %s","Apply a specific talent link (shift-click a talent calculator link into the box).",
        { {key="link",placeholder="talent link",width=160} }),
}

local function rolesBuilder(parent)
    local used = WLP.LayoutRows(parent, Roles, { yTop = 8, sectionTitle = "Set roles via spec ($talents)" })

    -- Spec → role reference, straight from §3.
    local y = -(8 + used + 6)
    local ref = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ref:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
    ref:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    ref:SetJustifyH("LEFT")
    ref:SetText(
        WLP.colors.label .. "Pick a tank, a healer, and some DPS:" .. WLP.colors.reset .. "\n"
        .. WLP.colors.accent .. "Tank" .. WLP.colors.reset .. " = protection (warrior/paladin), blood (DK), feral combat (druid)\n"
        .. WLP.colors.good   .. "Heal" .. WLP.colors.reset .. " = holy / discipline (priest, paladin), restoration (druid/shaman)\n"
        .. WLP.colors.muted  .. "Everything else is DPS. Whisper a single bot to set just that one, or use party scope to set the lot."
        .. WLP.colors.reset)
end

-- ─── COMBAT: movement + combat orders ($) ──────────────────────────────────
local Movement = {
    order("o_follow",   "Follow",    "follow",   "Follow you."),
    order("o_stay",     "Stay",      "stay",     "Hold current position."),
    order("o_summon",   "Summon",    "summon",   "Pull the bot(s) to you (e.g. into a dungeon)."),
    order("o_flee",     "Flee",      "flee",     "Fall back / flee toward you."),
    order("o_runaway",  "Run away",  "runaway",  "Run away from the group / kite."),
    order("o_grind",    "Grind",     "grind",    "Resume roaming / grinding."),
    order("o_disperse", "Disperse",  "disperse", "Spread out."),
    order("o_home",     "Home",      "home",     "Set / return to home (selected innkeeper)."),
    order("o_taxi",     "Take taxi", "taxi",     "Take a flight path."),
    order("o_tele",     "Teleport",  "teleport", "Teleport (e.g. to you)."),
    order("o_go",       "Go to",     "go %s",    "Travel to a named place or coords.",
        { {key="where",placeholder="place / coords",width=150} }),
}
local Combat = {
    order("o_attack",   "Attack",        "attack",       "Attack your current target."),
    order("o_tankatk",  "Tank attack",   "tank attack",  "The tank engages your target."),
    order("o_pull",     "Pull",          "pull",         "Pull your target."),
    order("o_maxdps",   "Max DPS",       "max dps",      "Switch to maximum-DPS posture."),
    order("o_focus",    "Focus heal",    "focus heal %s","Tell healers which target(s) to prioritize. Blank = your target.",
        { {key="who",placeholder="player (opt)",optional=true,width=120} }),
    order("o_cast",     "Cast spell",    "cast %s",      "Cast a named spell (optionally on a target).",
        { {key="spell",placeholder="spell [target]",width=150} }),
    order("o_savemana", "Save mana",     "save mana",    "Healers conserve mana / use efficient spells."),
    order("o_drink",    "Drink",         "drink",        "Sit and restore mana / health."),
    order("o_rti",      "Set raid icon", "rti %s",       "Set / report the raid-target icon the bot focuses.",
        { {key="icon",placeholder="icon (opt)",choices={"skull","cross","circle","star","square","triangle","diamond","moon"},optional=true,width=100} }),
    order("o_release",  "Release",       "release",      "Corpse run after death."),
    order("o_revive",   "Revive",        "revive",       "Resurrect at the spirit healer."),
    order("o_reset",    "Reset AI",      "reset botAI",  "Reset the bot's AI state.", nil, true),
}

local function combatBuilder(parent)
    WLP.LayoutRows(parent, Movement, { yTop = 8, x = 8,   columnWidth = 360, sectionTitle = "Movement & position" })
    WLP.LayoutRows(parent, Combat,   { yTop = 8, x = 372, columnWidth = 376, sectionTitle = "Combat" })
end

-- ─── ITEMS: gear, loot & vendor orders ($) ─────────────────────────────────
local Gear = {
    order("i_autogear",  "Auto-gear",      "autogear",       "Equip the best available gear the bot has."),
    order("i_autogearb", "Auto-gear BiS",  "autogear bis",   "Equip best-in-slot."),
    order("i_upgrade",   "Equip upgrades", "equip upgrade",  "Equip any upgrades sitting in the bot's bags."),
    order("i_equip",     "Equip item",     "equip %s",       "Equip a linked item (shift-click it into the box).",
        { {key="item",placeholder="[item]",width=150} }),
    order("i_unequip",   "Unequip item",   "unequip %s",     "Take off a linked item.",
        { {key="item",placeholder="[item]",width=150} }),
    order("i_use",       "Use item",       "use %s",         "Use / consume a linked item.",
        { {key="item",placeholder="[item]",width=150} }),
    order("i_repair",    "Repair gear",    "repair",         "Repair the bot's gear at a vendor."),
    order("i_maint",     "Maintenance",    "maintenance",    "Learn spells/skills, top up consumables, enchant, repair, sell junk."),
    order("i_buff",      "Buff",           "buff %s",        "Cast buffs (optionally a class's set).",
        { {key="class",placeholder="class (opt)",choices=WLP.Specs.classes,optional=true,width=110} }),
    order("i_trainer",   "Trainer",        "trainer",        "Show what the bot can learn from the selected trainer."),
}
local Loot = {
    order("l_lootall",  "Loot all",     "loot all",  "Loot everything nearby (works in a party)."),
    order("l_roll",     "Loot roll",    "roll %s",   "Set loot-roll behaviour for linked item or all.",
        { {key="how",placeholder="pass/need/greed",choices={"pass","need","greed"},width=120} }),
    order("l_sell",     "Sell item",    "sell %s",   "Sell a linked item to the vendor (s * = all greys).",
        { {key="item",placeholder="[item] / *",width=130} }),
    order("l_buy",      "Buy item",     "buy %s",    "Buy a linked item from the vendor.",
        { {key="item",placeholder="[item]",width=130} }),
    order("l_open",     "Open items",   "open items","Open lootable containers in the bot's bags."),
    order("l_destroy",  "Destroy item", "destroy %s","Destroy a linked item.",
        { {key="item",placeholder="[item]",width=130} }, true),
}

local function itemsBuilder(parent)
    WLP.LayoutRows(parent, Gear, { yTop = 8, x = 8,   columnWidth = 360, sectionTitle = "Gear (whisper a bot)" })
    WLP.LayoutRows(parent, Loot, { yTop = 8, x = 372, columnWidth = 376, sectionTitle = "Loot & vendor" })
end

-- ─── DUNGEON: the guided run flow (§4) ─────────────────────────────────────
local function dungeonBuilder(parent)
    local info = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    info:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    info:SetJustifyH("LEFT")
    info:SetText(WLP.colors.muted ..
        "The Dungeon Finder won't drag your bots inside - you summon them. Flow: build a party (Party tab) -> "
        .. "set roles (Roles tab: a tank, a healer, dps) -> gear up -> walk in -> Summon party -> drive the fight. "
        .. "On this realm bots usually auto-summon a few seconds after the leader zones in; Summon is the manual backup."
        .. WLP.colors.reset)

    local Steps = {
        pb("d_gear",   "1. Gear party to my gear", ".playerbots bot init=auto *",
            "Re-gear all bots in your group, scaled to your gear, before you go in."),
        pb("d_quests", "1b. Init instance quests", ".playerbots bot quests",
            "Initialize the dungeon's quests on your bots."),
        order("d_summon", "2. Summon party in", "summon",
            "Pull your whole party to you. Say this in party scope once you're at the entrance."),
    }
    local Drive = {
        order("d_tankatk", "Tank, pull/attack", "tank attack", "Send the tank in on your target."),
        order("d_attack",  "Everyone attack",   "attack",      "DPS attack your target."),
        order("d_pull",    "Pull",              "pull",        "Pull your target."),
        order("d_focus",   "Focus heal target", "focus heal %s","Healers prioritize this target. Blank = your target.",
            { {key="who",placeholder="player (opt)",optional=true,width=120} }),
        order("d_maxdps",  "Max DPS",           "max dps",     "Maximum-DPS posture for the burn."),
    }
    local Recover = {
        order("d_follow",  "Follow",  "follow",  "Regroup on you between packs."),
        order("d_stay",    "Stay",    "stay",    "Hold position (e.g. while you skip a pack)."),
        order("d_revive",  "Revive",  "revive",  "Resurrect at the spirit healer after a wipe."),
        order("d_release", "Release", "release", "Corpse run after death."),
    }

    local y = 8 + info:GetStringHeight() + 14
    local used = WLP.LayoutRows(parent, Steps, { yTop = y, x = 8, columnWidth = 360, sectionTitle = "Get in" })
    WLP.LayoutRows(parent, Drive,   { yTop = y, x = 372, columnWidth = 376, sectionTitle = "Drive the fight" })
    WLP.LayoutRows(parent, Recover, { yTop = y + used + 6, x = 8, columnWidth = 360, sectionTitle = "Regroup & recover" })
end

-- ─── Tab assembly: scope bar + sub-tabs ────────────────────────────────────
WLP.RegisterTab({
    id = "bots", label = "Bots",
    builder = function(parent)
        local bar = WLP.MakeScopeSelector(parent)
        bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
        bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4)

        local body = CreateFrame("Frame", nil, parent)
        body:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
        body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

        WLP.BuildSubTabs(body, {
            { label = "Party",   builder = partyBuilder },
            { label = "Roles",   builder = rolesBuilder },
            { label = "Combat",  builder = combatBuilder },
            { label = "Items",   builder = itemsBuilder },
            { label = "Dungeon", builder = dungeonBuilder },
        }, "bots")
    end,
})

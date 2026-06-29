-- WoWLegendsPlayer/Data/Specs.lua
-- Class / spec / race reference, source-verified against PLAYER_COMMANDS.md
-- (§8.1 classes, §8.2 specs, §8.3 races, §3 spec→role). The exact spec tokens
-- matter — they are what `$talents spec <name>` expects, quirks and all
-- (rogue "assasination" with one 's', druid "feral combat", "beast mastery").

local addonName, WLP = ...

local S = {}
WLP.Specs = S

-- §8.1 — classes for .playerbots bot addclass and .companion create.
S.classes = { "warrior", "paladin", "hunter", "rogue", "priest", "dk", "shaman", "mage", "warlock", "druid" }

S.classLabel = {
    warrior = "Warrior", paladin = "Paladin", hunter = "Hunter", rogue = "Rogue",
    priest = "Priest", dk = "Death Knight", shaman = "Shaman", mage = "Mage",
    warlock = "Warlock", druid = "Druid",
}

-- §8.2 — premade specs per class. Tokens passed verbatim to $talents spec.
S.specs = {
    warrior = { "arms", "fury", "protection" },
    paladin = { "holy", "protection", "retribution" },
    hunter  = { "beast mastery", "marksmanship", "survival" },
    rogue   = { "assasination", "combat", "subtlety" },   -- sic: one 's'
    priest  = { "discipline", "holy", "shadow" },
    dk      = { "blood", "frost", "unholy" },
    shaman  = { "elemental", "enhancement", "restoration" },
    mage    = { "arcane", "fire", "frost" },
    warlock = { "affliction", "demonology", "destruction" },
    druid   = { "balance", "feral combat", "restoration" },
}

-- §8.3 — companion races must match your faction.
S.races = {
    Alliance = { "human", "dwarf", "nightelf", "gnome", "draenei" },
    Horde    = { "orc", "undead", "tauren", "troll", "bloodelf" },
}

-- §3 — spec → dungeon role. A bot's role IS its spec.
--   Tank = Protection (warrior/paladin) · Blood (DK) · Feral (druid)
--   Heal = Holy/Discipline (priest/paladin) · Restoration (druid/shaman)
--   everything else = DPS
local TANK = { ["protection"] = true, ["blood"] = true, ["feral combat"] = true }
local HEAL = { ["holy"] = true, ["discipline"] = true, ["restoration"] = true }

function S.RoleOf(spec)
    spec = (spec or ""):lower()
    if TANK[spec] then return "Tank" end
    if HEAL[spec] then return "Healer" end
    return "DPS"
end

-- Suggest the spec a class should use for a given role, or nil if it can't fill
-- that role. Used by the Roles tab's quick tank/heal/dps buttons.
local ROLE_SPEC = {
    warrior = { Tank = "protection", DPS = "fury" },
    paladin = { Tank = "protection", Healer = "holy", DPS = "retribution" },
    hunter  = { DPS = "marksmanship" },
    rogue   = { DPS = "combat" },
    priest  = { Healer = "holy", DPS = "shadow" },
    dk      = { Tank = "blood", DPS = "frost" },
    shaman  = { Healer = "restoration", DPS = "elemental" },
    mage    = { DPS = "frost" },
    warlock = { DPS = "affliction" },
    druid   = { Tank = "feral combat", Healer = "restoration", DPS = "balance" },
}

function S.RoleSpec(class, role)
    local m = ROLE_SPEC[(class or ""):lower()]
    return m and m[role] or nil
end

-- Convenience: flat, space-joined spec list for a class (tooltips).
function S.SpecList(class)
    local t = S.specs[(class or ""):lower()]
    return t and table.concat(t, "  ") or "?"
end

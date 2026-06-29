-- WoWLegendsPlayer/Core/Util.lua
-- Theme colours, print helpers, small string/target utilities.
-- Palette is shared with the GM addon so both panels feel like one product.

local addonName, WLP = ...

-- ─── Brand palette ─────────────────────────────────────────────────────────
WLP.colors = {
    brand   = "|cffffc94d",   -- WoW Legends gold
    accent  = "|cff45d7ff",   -- frost cyan (Wrath) — your own (.) commands
    legend  = "|cffff8000",   -- legendary orange — WL-exclusive marker
    bot      = "|cffe6cc80",  -- bot tan — $ orders to your bots
    good     = "|cff33ff99",
    warn     = "|cffff9933",
    danger   = "|cffff4444",
    label    = "|cffffd100",
    muted    = "|cff8899aa",
    white    = "|cffffffff",
    reset    = "|r",
}

-- RGB equivalents for SetTextColor / SetVertexColor / pip texture calls.
WLP.rgb = {
    brand  = { 1.00, 0.79, 0.30 },
    accent = { 0.27, 0.84, 1.00 },
    legend = { 1.00, 0.50, 0.00 },
    bot    = { 0.90, 0.80, 0.50 },
    good   = { 0.20, 1.00, 0.60 },
    danger = { 1.00, 0.27, 0.27 },
    muted  = { 0.53, 0.60, 0.67 },
}

-- Row category metadata — a pip colour + legend name per command kind.
-- "player" = a dot-command you run as yourself; "bot" = a $ order to your bots;
-- "wl" = a WoW Legends exclusive player command (Companion / XP / Hardcore).
WLP.cats = {
    player = { name = "Your command (.)",   rgb = WLP.rgb.accent, color = WLP.colors.accent },
    bot    = { name = "Bot order ($)",       rgb = WLP.rgb.bot,    color = WLP.colors.bot },
    wl     = { name = "WoW Legends (*)", rgb = WLP.rgb.legend, color = WLP.colors.legend },
}

-- Pick the category for a command def (used for the row pip + tooltip line).
function WLP.CatOf(def)
    if def.send == "bot" then return "bot" end
    if def.wl then return "wl" end
    return "player"
end

-- ─── Print ─────────────────────────────────────────────────────────────────
function WLP.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(WLP.colors.brand .. "WLP" .. WLP.colors.reset .. ": " .. tostring(msg))
end

function WLP.Warn(msg)
    DEFAULT_CHAT_FRAME:AddMessage(WLP.colors.brand .. "WLP" .. WLP.colors.reset
        .. ": " .. WLP.colors.warn .. tostring(msg) .. WLP.colors.reset)
end

-- ─── String / value helpers ────────────────────────────────────────────────
function WLP.IsBlank(s)
    return s == nil or s == "" or (type(s) == "string" and s:match("^%s*$") ~= nil)
end

function WLP.Trim(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Resolve an arg value, applying its fallback when blank.
--   fallback="target" → UnitName("target")
--   fallback="self"   → UnitName("player")
function WLP.ResolveArg(value, arg)
    if value == nil or value == "" then
        if arg and arg.fallback == "target" then
            local n = UnitName("target")
            if n and n ~= "" then return n end
        elseif arg and arg.fallback == "self" then
            return UnitName("player")
        end
        return nil
    end
    return value
end

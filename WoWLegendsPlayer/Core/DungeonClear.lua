-- WoWLegendsPlayer/Core/DungeonClear.lua
-- Dungeon Clear (mod-dungeon-clear) chat bridge.
--
-- The tank bot sends all its non-error run announcements as LANG_ADDON party
-- messages with prefix "DC" and payload "CHAT\t<text>" — which a stock client
-- never displays, so without this listener the whole run is silent (only error
-- refusals arrive, as normal whispers). We print those payloads to the chat
-- frame as "[DungeonClear] <text>".
--
-- 3.3.5a fires CHAT_MSG_ADDON for every addon message (there is no
-- RegisterAddonMessagePrefix on this client — that API is MoP+), so we just
-- filter on the prefix. Richer payloads ride the same prefix (STATUS\t...,
-- BOSS\t...) for a future status panel; we ignore those for now.

local addonName, WLP = ...

local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message)
    if prefix ~= "DC" or type(message) ~= "string" then return end
    local text = message:match("^CHAT\t(.+)$")
    if not text or text == "" then return end
    DEFAULT_CHAT_FRAME:AddMessage(
        WLP.colors.brand .. "[DungeonClear]" .. WLP.colors.reset .. " " .. text)
end)

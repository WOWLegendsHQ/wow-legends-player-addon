-- WoWLegendsPlayer/Core/NameplateBubbles.lua
-- Speech over enemy nameplates.
--
-- The 3.3.5a client draws NO chat bubble over a unit whose enemy nameplate is
-- showing (V on): the line still reaches the chat frame, but nothing appears
-- over the speaker's head. Found by Cazius on the PTR, 2026-11-08
-- (handoffs/2026-11-08_addon_player_nameplate_bubbles.md). The server cannot
-- change it, so we draw the bubble ourselves - only in exactly that case:
--   * the line is a /say or /yell from someone else (player, bot or NPC);
--   * the player has chat bubbles on (the client would have drawn one);
--   * the speaker has a visible nameplate that is NOT friendly (a friendly
--     plate does not hide the client's own bubble, so drawing one would double);
--   * exactly one visible plate carries that name - with five "Stormwind Guard"
--     plates up we cannot know which one spoke, and a bubble over the wrong
--     head is worse than none.
-- Toggle: /wlp bubbles (on by default).

local addonName, WLP = ...

local NB = {}
WLP.NameplateBubbles = NB

local BORDER = "Interface\\Tooltips\\Nameplate-Border"
local MAX_TEXT_WIDTH = 220
local PAD = 10
local SAY_COLOR  = { 1, 1, 1 }
local YELL_COLOR = { 1, 0.25, 0.25 }

-- ─── Nameplates ────────────────────────────────────────────────────────────
-- In 3.3.5 a nameplate is an UNNAMED child of WorldFrame whose second region
-- is the "Nameplate-Border" texture; its name is one of its FontStrings and
-- its first child is the health bar (coloured by reaction).
local function isNameplate(f)
    if not f or (f.GetName and f:GetName()) or not f.GetRegions then return false end
    local _, border = f:GetRegions()
    return border ~= nil and border.GetObjectType ~= nil and border:GetObjectType() == "Texture"
        and border:GetTexture() == BORDER
end

local function plateNameRegion(f, name)
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" and r:GetText() == name then
            return r
        end
    end
end

-- Friendly = the plates the client still bubbles over: green (friendly NPC)
-- or blue (friendly player). Hostile red, neutral yellow and tapped grey are
-- the "enemy" plates V shows.
local function isFriendlyPlate(f)
    local bar = f.GetChildren and f:GetChildren()
    if not bar or not bar.GetStatusBarColor then return false end
    local r, g, b = bar:GetStatusBarColor()
    if not r then return false end
    return r < 0.2 and (g > 0.9 or b > 0.9)
end

-- The one visible, non-friendly plate named `name`, or nil (none, or ambiguous).
function NB.FindPlate(name)
    if not name or name == "" or not WorldFrame then return nil end
    local found
    for _, f in ipairs({ WorldFrame:GetChildren() }) do
        if isNameplate(f) and f:IsVisible() and plateNameRegion(f, name) then
            if found then return nil end         -- two plates, same name: can't tell who spoke
            found = f
        end
    end
    if found and isFriendlyPlate(found) then return nil end
    return found
end

-- ─── Bubbles ───────────────────────────────────────────────────────────────
local pool, byPlate = {}, {}

local function release(b)
    b:Hide()
    if b.plate then byPlate[b.plate] = nil end
    b.plate, b.name = nil, nil
    table.insert(pool, b)
end

local function newBubble()
    local b = CreateFrame("Frame", nil, WorldFrame)
    b:SetFrameStrata("BACKGROUND")
    if b.SetBackdrop then
        b:SetBackdrop({
            bgFile = "Interface\\Tooltips\\ChatBubble-Background",
            edgeFile = "Interface\\Tooltips\\ChatBubble-Backdrop",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
    end
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    b.text = fs
    b:SetScript("OnUpdate", function(self)
        local p = self.plate
        -- Plates are recycled as units come and go: if this one stopped being
        -- the speaker, the bubble goes with it.
        if GetTime() >= (self.expires or 0) or not p or not p:IsVisible()
            or not plateNameRegion(p, self.name) then
            release(self)
        end
    end)
    b:Hide()
    return b
end

local function duration(msg)
    local d = 3 + #msg / 15
    if d > 10 then d = 10 end
    return d
end

function NB.Show(plate, name, msg, color)
    local b = byPlate[plate] or table.remove(pool) or newBubble()
    byPlate[plate] = b
    b.plate, b.name = plate, name
    b.expires = GetTime() + duration(msg)

    local fs = b.text
    fs:SetWidth(0)
    fs:SetText(msg)
    fs:SetTextColor(color[1], color[2], color[3])
    local w = fs:GetStringWidth() or 0
    if w > MAX_TEXT_WIDTH then
        fs:SetWidth(MAX_TEXT_WIDTH)
        w = MAX_TEXT_WIDTH
    end
    local h = fs:GetStringHeight() or 12
    b:SetWidth(w + PAD * 2)
    b:SetHeight(h + PAD * 2)
    b:ClearAllPoints()
    b:SetPoint("BOTTOM", plate, "TOP", 0, 2)
    if b.SetFrameLevel and plate.GetFrameLevel then b:SetFrameLevel(plate:GetFrameLevel() + 5) end
    b:Show()
    return b
end

-- ─── Wiring ────────────────────────────────────────────────────────────────
local YELLS = { CHAT_MSG_YELL = true, CHAT_MSG_MONSTER_YELL = true }

function NB.Enabled()
    if WLP.db and WLP.db.nameplateBubbles == false then return false end
    -- With chat bubbles off the client would draw none either; stay consistent.
    if GetCVar and GetCVar("chatBubbles") == "0" then return false end
    return true
end

function NB.OnChat(event, msg, sender)
    if not NB.Enabled() or type(msg) ~= "string" or msg == "" then return nil end
    if not sender or sender == "" or sender == UnitName("player") then return nil end
    local plate = NB.FindPlate(sender)
    if not plate then return nil end
    return NB.Show(plate, sender, msg, YELLS[event] and YELL_COLOR or SAY_COLOR)
end

local listener = CreateFrame("Frame")
for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL" }) do
    listener:RegisterEvent(e)
end
listener:SetScript("OnEvent", function(_, event, msg, sender)
    local ok, err = pcall(NB.OnChat, event, msg, sender)
    if not ok and WLP.Warn then WLP.Warn("nameplate bubble: " .. tostring(err)) end
end)

-- /wlp bubbles [on|off] - toggles when no argument is given.
function NB.SetEnabled(on)
    if not WLP.db then return end
    WLP.db.nameplateBubbles = on and true or false
    if not on then
        for plate, b in pairs(byPlate) do release(b) end
    end
    WLP.Print("speech over enemy nameplates: " .. (on and "ON" or "OFF"))
end

-- Headless smoke-test harness: stub the 3.3.5a WoW API, load the addon in TOC
-- order, fire ADDON_LOADED + PLAYER_LOGIN, and dry-run BuildLine on every def.
-- Ported from the GM addon's harness for the Player addon (namespace WLP).

unpack = table.unpack          -- 5.1 global the addon relies on
local MSGS, ERRORS, FMT_ERRORS = {}, {}, {}

-- ─── Frame / region stub ───────────────────────────────────────────────────
local FRAMES = {}
local FrameMT
local methods = {}

local function newFrame()
    local f = { _scripts = {}, _events = {} }
    table.insert(FRAMES, f)
    return setmetatable(f, FrameMT)
end

function methods.GetText(self) return self._text or "" end
function methods.SetText(self, t) self._text = t; return self end
function methods.GetStringWidth() return 12 end
function methods.GetStringHeight() return 12 end
function methods.GetHeight() return 12 end
function methods.GetWidth() return 120 end
function methods.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function methods.GetBottom() return 50 end
function methods.GetTop() return 100 end
function methods.GetLeft() return 0 end
function methods.GetRight() return 100 end
function methods.GetValue() return 0 end
function methods.GetVerticalScroll() return 0 end
function methods.GetVerticalScrollRange() return 0 end
function methods.HasFocus() return false end
function methods.GetID(self) return self._id or 1 end
function methods.SetID(self, n) self._id = n; return self end
function methods.IsShown() return false end
function methods.GetObjectType() return "Frame" end
function methods.GetName(self) return self._name end
function methods.CreateFontString() return newFrame() end
function methods.CreateTexture() return newFrame() end
function methods.GetFontString(self) self._fs = self._fs or newFrame(); return self._fs end
function methods.SetFontString(self, fs) self._fs = fs; return self end
function methods.GetScrollBar(self) self._sb = self._sb or newFrame(); return self._sb end
function methods.GetRegions() return end
function methods.RegisterEvent(self, e) self._events[e] = true; return self end
function methods.UnregisterEvent(self, e) self._events[e] = nil; return self end
function methods.UnregisterAllEvents(self) self._events = {}; return self end
function methods.SetScript(self, name, fn) self._scripts[name] = fn; return self end
function methods.HookScript(self, name, fn)
    local prev = self._scripts[name]
    self._scripts[name] = function(...) if prev then prev(...) end fn(...) end
    return self
end
function methods.GetScript(self, name) return self._scripts[name] end
function methods.GetChecked() return nil end
function methods.IsMouseOver() return false end

-- No-op (chainable) setters/actions. Anything NOT listed here or above reads
-- as nil on a frame — matching real WoW, where unset fields (.data, ._name) are
-- nil rather than a callable. (A function __index would wrongly make `if not
-- self.data` always truthy.)
for _, name in ipairs({
    "ClearAllPoints", "ClearFocus", "EnableMouse", "EnableMouseWheel", "EnableKeyboard",
    "Hide", "Raise", "RegisterForClicks", "RegisterForDrag", "SetAllPoints", "SetAlpha",
    "SetAutoFocus", "SetBackdrop", "SetBackdropBorderColor", "SetBackdropColor",
    "SetClampedToScreen", "SetCursorPosition", "SetDrawLayer", "SetFont", "SetFontObject",
    "SetFontString", "SetFrameLevel", "SetFrameStrata", "SetHeight", "SetHighlightTexture",
    "SetJustifyH", "SetJustifyV", "SetMask", "SetMaxLetters", "SetMovable", "SetNormalTexture",
    "SetOwner", "SetParent", "SetPoint", "SetScale", "SetScrollChild", "SetSize",
    "SetButtonState", "SetTexCoord", "SetTextColor", "SetTextInsets", "SetTexture",
    "SetToplevel", "SetValue", "SetValueStep", "SetVertexColor", "SetVerticalScroll",
    "SetMinMaxValues", "SetWidth", "Show", "StartMoving", "StopMovingOrSizing",
    "AddLine", "AddMessage",
    "SetDesaturated", "SetStatusBarTexture", "SetStatusBarColor", "SetChecked", "SetBlendMode",
    "SetShadowOffset", "SetHyperlink", "LockHighlight", "UnlockHighlight",
}) do
    methods[name] = function(self) return self end
end

FrameMT = { __index = methods }

-- ─── Globals ────────────────────────────────────────────────────────────────
CreateFrame = function(_, name) local f = newFrame(); f._name = name; if name then _G[name] = f end; return f end
UIParent = newFrame()
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(MSGS, msg or "") end }
GameTooltip = newFrame()
StaticPopupDialogs = {}
StaticPopup_Show = function() return nil end
SlashCmdList = {}
YES, NO, CANCEL = "Yes", "No", "Cancel"

for _, n in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
    "GameFontHighlight", "GameFontHighlightSmall", "GameFontDisable", "GameFontDisableSmall" }) do
    _G[n] = {}
end

GetTime = function() return 0 end
GetAddOnMetadata = function(_, key) return key == "Version" and "0.1.0" or "x" end
SendChatMessage = function() end
ChatFrame_OpenChat = function() end
PlaySound = function() end
IsShiftKeyDown = function() return false end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
UnitName = function() return "Tester" end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitIsPlayer = function() return true end
UnitFactionGroup = function() return "Alliance" end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
SendAddonMessage = function() end
UnitGUID = function() return nil end
GetItemIcon = function() return nil end
GetItemInfo = function() return nil end
MouseIsOver = function() return false end
hooksecurefunc = function() end
date = os.date
UISpecialFrames = {}
ITEM_QUALITY_COLORS = {}

-- Faux scroll + dropdown API
FauxScrollFrame_GetOffset = function() return 0 end
FauxScrollFrame_Update = function() end
FauxScrollFrame_SetOffset = function() end
FauxScrollFrame_OnVerticalScroll = function(_, _, _, fn) if fn then pcall(fn) end end
ScrollFrame_OnScrollRangeChanged = function() end
UIDropDownMenu_SetWidth = function() end
UIDropDownMenu_JustifyText = function() end
UIDropDownMenu_Initialize = function(dd, fn) if fn then pcall(fn, dd, 1) end end
UIDropDownMenu_CreateInfo = function() return {} end
UIDropDownMenu_AddButton = function() end
UIDropDownMenu_SetText = function() end
UIDropDownMenu_SetSelectedValue = function() end

-- ─── Load addon in TOC order ────────────────────────────────────────────────
local files = {
    "Core/Init.lua", "Core/Util.lua", "Core/SavedVars.lua", "Core/CommandRunner.lua",
    "Core/DungeonClear.lua", "Core/Warband.lua", "Core/NameplateBubbles.lua", "Core/DuelCountdown.lua",
    "Core/Paths.lua",
    "Data/Specs.lua", "Data/WarbandProps.lua",
    "UI/ConfirmDialog.lua", "UI/Widgets.lua", "UI/MainFrame.lua",
    "UI/Tabs/Companion.lua", "UI/Tabs/Bots.lua", "UI/Tabs/DungeonClear.lua",
    "UI/Tabs/Warband.lua", "UI/Tabs/XP.lua", "UI/Tabs/Hardcore.lua", "UI/Tabs/Paths.lua",
    "UI/Tabs/Favorites.lua", "UI/Tabs/History.lua",
    "UI/PathsFrame.lua", "UI/PathsAlerts.lua", "UI/ToggleButton.lua",
}

local WLP = {}
for _, rel in ipairs(files) do
    local chunk, lerr = loadfile(BASE .. "/" .. rel)
    if not chunk then
        table.insert(ERRORS, "LOAD " .. rel .. ": " .. tostring(lerr))
    else
        local ok, rerr = pcall(chunk, "WoWLegendsPlayer", WLP)
        if not ok then table.insert(ERRORS, "RUN " .. rel .. ": " .. tostring(rerr)) end
    end
end

-- Dry-run BuildLine on every command def as rows are built (catches %s/arg
-- mismatches that only surface when a command is actually assembled).
if WLP.CreateCommandRow then
    local orig = WLP.CreateCommandRow
    WLP.CreateCommandRow = function(parent, def)
        local vals = {}
        for _, a in ipairs(def.args or {}) do vals[a.key] = a.numeric and "1" or "x" end
        local ok, line = pcall(WLP.BuildLine, def, vals)
        if not ok then
            table.insert(FMT_ERRORS, (def.id or def.label or "?") .. ": " .. tostring(line))
        end
        return orig(parent, def)
    end
end

-- Regression: LayoutRows must report real height even when #rows is an exact
-- multiple of rowsPerColumn (else stacked sections overlap).
if WLP.LayoutRows then
    for _, rpc in ipairs({ 2, 3 }) do
        local fake = {}
        for i = 1, rpc * 2 do fake[i] = { id = "t" .. i, label = "t", format = ".x", group = "g" } end
        local h = WLP.LayoutRows(newFrame(), fake, { yTop = 8, rowsPerColumn = rpc, columnWidth = 372 })
        if not h or h < 70 then
            table.insert(ERRORS, "LayoutRows height collapse: " .. (rpc * 2) .. " rows / " .. rpc .. "-col returned " .. tostring(h))
        end
    end
end

-- ─── Fire events ────────────────────────────────────────────────────────────
local function fire(event, arg)
    for _, f in ipairs(FRAMES) do
        if f._events[event] and f._scripts.OnEvent then
            local ok, err = pcall(f._scripts.OnEvent, f, event, arg)
            if not ok then table.insert(ERRORS, "EVENT " .. event .. ": " .. tostring(err)) end
        end
    end
end
fire("ADDON_LOADED", "WoWLegendsPlayer")
fire("PLAYER_LOGIN")

-- Paths window: feed a full push (every status the window can show) and draw
-- each Path, the tracker line and a toast - the window only draws on OnShow,
-- which this stub never fires.
if WLP.Paths and WLP.Paths.UI then
    local T = string.char(9)
    local function line(...) return table.concat({ ... }, T) end
    local lines = {
        line("H", "990000", "Swear at the Herald of the Fallen, in every starting zone.", "0"),
        line("P", "long_road", "The Long Road", "path", "active", "1795250000", "1335", "0", "", "1", "", "0"),
        line("T", "long_road", "creed", "THE LONG ROAD is PERMANENT.", "0"),
        line("T", "long_road", "creed", "Do you swear it?", "0"),
        line("R", "long_road", "Achievement_Boss_Ragnaros", "Experience stops at level 60.", "0"),
        line("G", "long_road", "the old world", "Ragnaros", "1", "1", "60", "Achievement_Boss_Ragnaros", "0"),
        line("G", "long_road", "the old world", "Nefarian", "0", "1", "60", "Achievement_Boss_Nefarion", "0"),
        line("G", "long_road", "Outland", "Illidan", "0", "1", "70", "Achievement_Boss_Illidan", "0"),
        line("P", "iron_oath", "The Iron Oath", "path", "done", "0", "734", "0", "", "1", "", "0"),
        line("G", "iron_oath", "the journey", "Reach level 80", "80", "80", "0", "Achievement_Level_80", "0"),
        line("P", "pilgrims_way", "The Pilgrim's Way", "path", "forsaken", "0", "1663", "0", "", "0", "", "0"),
        line("P", "slow_burn", "The Slow Burn", "path", "none", "0", "1638", "0", "Too late.", "1", "", "0"),
        line("T", "slow_burn", "offer", "I swear the Slow Burn.", "0"),
        line("G", "slow_burn", "the journey", "Reach level 80", "57", "80", "0", "Achievement_Level_80", "0"),
        line("P", "hardcore", "Hardcore", "trial", "fallen", "0", "0", "0", "", "1", "Ability_Rogue_FeignDeath", "0"),
        line("G", "hardcore", "the journey", "Level reached without dying", "12", "80", "0", "Achievement_Level_80", "0"),
        line("D", "16", "0", "1"),
    }
    for _, l in ipairs(lines) do
        local ok, err = pcall(WLP.Paths.Handle, l)
        if not ok then table.insert(ERRORS, "PATHS handle: " .. tostring(err)) end
    end
    if not WLP.Paths.data or #WLP.Paths.data.list ~= 5 then
        table.insert(ERRORS, "PATHS: push did not give 5 Paths")
    else
        local ui = WLP.Paths.UI
        WLP.db.pathsTracker = true
        for _, p in ipairs(WLP.Paths.data.list) do
            local ok, err = pcall(function() ui.Open(p.key); ui.Render() end)
            if not ok then table.insert(ERRORS, "PATHS render " .. p.key .. ": " .. tostring(err)) end
        end
        local ok, err = pcall(ui.RefreshTracker)
        if not ok then table.insert(ERRORS, "PATHS tracker: " .. tostring(err)) end
        local tt = ui.TrackerText(WLP.Paths.data.byKey.long_road)
        if not tt:find("1/3, next Nefarian") then table.insert(ERRORS, "PATHS tracker text: " .. tt) end
        for _, kind in ipairs({ "goal", "stage", "done", "forsaken" }) do
            local p = WLP.Paths.data.byKey.long_road
            ok, err = pcall(ui.Toast, { kind = kind, path = p, goal = p.goals[1], stage = { name = "the old world" } })
            if not ok then table.insert(ERRORS, "PATHS toast " .. kind .. ": " .. tostring(err)) end
        end
    end
end

-- Fuzz: invoke every OnClick once (opens dropdowns, runs commands, switches
-- tabs/sub-tabs) to exercise click paths a build-only pass never reaches.
local CLICK_ERRORS = {}
local n = #FRAMES
for i = 1, n do
    local f = FRAMES[i]
    local fn = f._scripts and f._scripts.OnClick
    if fn then
        local ok, err = pcall(fn, f, "LeftButton")
        if not ok then table.insert(CLICK_ERRORS, tostring(err)) end
    end
end

-- ─── Report ─────────────────────────────────────────────────────────────────
RESULT = {
    tabs = WLP.tabs and #WLP.tabs or 0,
    errors = ERRORS,
    fmt_errors = FMT_ERRORS,
    click_errors = CLICK_ERRORS,
    chat = MSGS,
}

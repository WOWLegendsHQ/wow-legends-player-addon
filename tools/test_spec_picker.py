#!/usr/bin/env python3
"""End-to-end regression test of the per-bot spec picker (Bots > Roles).

Loads the real addon files in a stub WoW env, builds the Roles sub-tab,
selects a spec on the real dropdown, and asserts the exact whisper sequence:
$talents spec <premade name> followed by $autogear (order matters - the bot's
command queue is FIFO, so autogear runs after the new spec is applied).

    pip install lupa
    python tools/test_spec_picker.py
"""
import os
from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.abspath(os.path.join(HERE, "..", "WoWLegendsPlayer")).replace("\\", "/")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().BASE = BASE

lua.execute(r'''
unpack = table.unpack
SENT = {}

-- ─── minimal frame stub (mirror of tools/harness.lua) ──────────────────────
local FrameMT; local methods = {}
local function newFrame()
    return setmetatable({ _scripts = {}, _events = {} }, FrameMT)
end
function methods.GetText(self) return self._text or "" end
function methods.SetText(self, t) self._text = t; return self end
function methods.GetStringWidth() return 12 end
function methods.GetStringHeight() return 12 end
function methods.GetHeight() return 12 end
function methods.GetWidth() return 120 end
function methods.GetBottom() return 50 end
function methods.GetValue() return 0 end
function methods.GetVerticalScroll() return 0 end
function methods.GetVerticalScrollRange() return 0 end
function methods.HasFocus() return false end
function methods.GetID(self) return self._id or 1 end
function methods.SetID(self, n) self._id = n; return self end
function methods.IsShown() return false end
function methods.GetName(self) return self._name end
function methods.CreateFontString() return newFrame() end
function methods.CreateTexture() return newFrame() end
function methods.SetFontString(self, fs) self._fs = fs; return self end
function methods.RegisterEvent(self, e) self._events[e] = true; return self end
function methods.SetScript(self, name, fn) self._scripts[name] = fn; return self end
function methods.HookScript(self, name, fn)
    local prev = self._scripts[name]
    self._scripts[name] = function(...) if prev then prev(...) end fn(...) end
    return self
end
function methods.GetScript(self, name) return self._scripts[name] end
for _, n in ipairs({ "ClearAllPoints","ClearFocus","EnableMouse","EnableMouseWheel","Hide","Raise",
    "RegisterForClicks","RegisterForDrag","SetAllPoints","SetAutoFocus","SetBackdrop",
    "SetBackdropBorderColor","SetBackdropColor","SetClampedToScreen","SetDrawLayer","SetFontObject",
    "SetFrameLevel","SetFrameStrata","SetHeight","SetHighlightTexture","SetJustifyH","SetMaxLetters",
    "SetMovable","SetPoint","SetScrollChild","SetSize","SetTexCoord","SetTextColor","SetTextInsets",
    "SetTexture","SetToplevel","SetVerticalScroll","SetMinMaxValues","SetValueStep","SetWidth","Show",
    "AddMessage","SetOwner","AddLine" }) do
    methods[n] = function(self) return self end
end
FrameMT = { __index = methods }

CreateFrame = function(_, name) local f = newFrame(); f._name = name; if name then _G[name] = f end; return f end
UIParent = newFrame()
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = newFrame()
StaticPopupDialogs = {}
StaticPopup_Show = function() return nil end
SlashCmdList = {}
for _, n in ipairs({ "GameFontNormal","GameFontNormalSmall","GameFontNormalLarge",
    "GameFontHighlight","GameFontHighlightSmall","GameFontDisable","GameFontDisableSmall" }) do _G[n] = {} end
GetTime = function() return 0 end
IsShiftKeyDown = function() return false end
GetNumRaidMembers = function() return 0 end
GetNumPartyMembers = function() return 0 end
UnitName = function() return "Botty" end
UnitClass = function() return "Paladin", "PALADIN" end
UnitIsPlayer = function() return true end
UnitFactionGroup = function() return "Alliance" end
ChatFrame_OpenChat = function() end
SendChatMessage = function(msg, chan, _, target)
    table.insert(SENT, (chan or "?") .. "|" .. (target or "-") .. "|" .. msg)
end

-- ─── load the real files ────────────────────────────────────────────────────
local WLP = {}
WoWLegendsPlayer_DB = { subTabs = {}, inputs = {}, history = {}, favorites = {} }
WLP.db = WoWLegendsPlayer_DB
local function run(rel)
    local chunk = assert(loadfile(BASE .. "/" .. rel))
    chunk("WoWLegendsPlayer", WLP)
end
run("Core/Util.lua"); run("Core/SavedVars.lua"); run("Core/CommandRunner.lua")
run("Data/Specs.lua"); run("UI/Widgets.lua")

-- capture the spec-picker dropdown as Bots.lua creates it
local pickerDD
local origChoice = WLP.CreateChoice
WLP.CreateChoice = function(parent, w, h, choices, placeholder, onSelect)
    local c = origChoice(parent, w, h, choices, placeholder, onSelect)
    if placeholder == "target a bot first" then pickerDD = c end
    return c
end
WLP.RegisterTab = function(def) TABDEF = def end   -- stand-in for MainFrame's
run("UI/Tabs/Bots.lua")
TABDEF.builder(newFrame())                          -- builds all sub-tabs incl. Roles

assert(pickerDD, "spec picker dropdown was not created")
-- choices must be the targeted class's premades (Paladin per the stubs)
local n = 0; local first
for i, opt in ipairs(pickerDD.choices) do n = i; if i == 1 then first = opt.text .. "=" .. opt.value end end
CHOICE_COUNT, CHOICE_FIRST = n, first

-- select Protection: must whisper the spec change, then autogear
SENT = {}
pickerDD.SetValue("prot pve")
RESULT = table.concat(SENT, "\n")
''')

sent = str(lua.globals().RESULT).splitlines()
count = lua.globals().CHOICE_COUNT
first = str(lua.globals().CHOICE_FIRST)
print("paladin choices :", count, "| first:", first)
print("sent on select  :")
for s in sent:
    print("   " + s)

ok = (
    count == 6
    and first == "Holy - Healer=holy pve"
    and len(sent) == 2
    and sent[0] == "WHISPER|Botty|$talents spec prot pve"
    and sent[1] == "WHISPER|Botty|$autogear"
)
print("\nSPEC PICKER TEST:", "PASS" if ok else "FAIL")
raise SystemExit(0 if ok else 1)

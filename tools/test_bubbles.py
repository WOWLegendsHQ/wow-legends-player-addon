#!/usr/bin/env python3
"""Unit test of speech over enemy nameplates (Core/NameplateBubbles.lua).

Builds fake 3.3.5 nameplates (unnamed WorldFrame children whose 2nd region is
the Nameplate-Border texture, a name FontString, a coloured health bar) and
checks the rules that decide whether a bubble is drawn:

  * hostile / neutral plate, chat bubbles on, option on  -> bubble, right text
  * friendly plate (the client bubbles those itself)      -> nothing (no doubles)
  * two visible plates with the speaker's name            -> nothing (can't tell)
  * our own line, option off, chatBubbles CVar off        -> nothing
  * a yell is red, a say is white
  * a recycled plate (now showing someone else) drops its bubble

    pip install lupa
    python tools/test_bubbles.py
"""
import os
from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.abspath(os.path.join(HERE, "..", "WoWLegendsPlayer")).replace("\\", "/")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().BASE = BASE

lua.execute(r'''
unpack = table.unpack
NOW = 100
GetTime = function() return NOW end
CVARS = { chatBubbles = "1" }
GetCVar = function(k) return CVARS[k] end
UnitName = function() return "Me" end

-- minimal widget fakes --------------------------------------------------------
local function region(kind, text)
    local r = { kind = kind, text = text }
    function r:GetObjectType() return self.kind end
    function r:GetTexture() return self.text end
    function r:GetText() return self.text end
    return r
end

local function frame(name)
    local f = { name = name, shown = false, points = {}, scripts = {}, regions = {}, children = {} }
    function f:GetName() return self.name end
    function f:GetRegions() return unpack(self.regions) end
    function f:GetChildren() return unpack(self.children) end
    function f:IsVisible() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent() end
    function f:SetFrameStrata() end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level or 1 end
    function f:SetBackdrop() end
    function f:SetWidth(w) self.w = w end
    function f:SetHeight(h) self.h = h end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) table.insert(self.points, { ... }) end
    function f:CreateFontString()
        local fs = { text = "", color = nil }
        function fs:SetPoint() end
        function fs:SetJustifyH() end
        function fs:SetWidth(w) self.w = w end
        function fs:SetText(t) self.text = t end
        function fs:GetText() return self.text end
        function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
        function fs:GetStringWidth() return #self.text * 6 end
        function fs:GetStringHeight() return 12 end
        return fs
    end
    return f
end
CreateFrame = function() return frame(nil) end

local PLATES = {}
WorldFrame = { GetChildren = function() return unpack(PLATES) end }

local function plate(name, r, g, b, shown)
    local p = frame(nil)
    p.regions = { region("Texture", "glow"), region("Texture", "Interface\\Tooltips\\Nameplate-Border"),
                  region("FontString", name), region("FontString", "80") }
    local bar = {}
    function bar:GetStatusBarColor() return r, g, b end
    p.children = { bar }
    p.shown = shown ~= false
    table.insert(PLATES, p)
    return p
end

local WLP = { db = { nameplateBubbles = true } }
WLP.Warn = function(m) error(m) end
WLP.Print = function() end
local chunk = assert(loadfile(BASE .. "/Core/NameplateBubbles.lua"))
chunk("WoWLegendsPlayer", WLP)
local NB = WLP.NameplateBubbles

FAILS, CHECKS = {}, 0
local function check(name, cond)
    CHECKS = CHECKS + 1
    if not cond then table.insert(FAILS, name) end
end

-- a hostile NPC, a neutral one, a friendly NPC, a friendly player, a hidden plate,
-- two guards with the same name, and a named (non-nameplate) frame
local leader  = plate("Raid Leader", 1, 0, 0)
local trader  = plate("Neutral Trader", 1, 1, 0)
plate("Friendly Guard", 0, 1, 0)
plate("Botfriend", 0, 0, 1)
plate("Hidden One", 1, 0, 0, false)
plate("Stormwind Guard", 1, 0, 0)
plate("Stormwind Guard", 1, 0, 0)
local named = frame("SomeAddonFrame"); named.regions = { region("Texture", "x"), region("Texture", "Interface\\Tooltips\\Nameplate-Border"), region("FontString", "Sneaky") }; named.shown = true; table.insert(PLATES, named)

-- 1. hostile NPC says something -> bubble above its plate, white
local b = NB.OnChat("CHAT_MSG_MONSTER_SAY", "For the Horde! Hic!", "Raid Leader")
check("hostile: bubble", b ~= nil and b.shown)
check("hostile: text", b and b.text.text == "For the Horde! Hic!")
check("hostile: anchored to plate", b and b.points[1] and b.points[1][2] == leader)
check("say is white", b and b.text.color[1] == 1 and b.text.color[2] == 1)

-- 2. neutral plate counts as enemy; a yell is red
local y = NB.OnChat("CHAT_MSG_MONSTER_YELL", "Get off my lawn!", "Neutral Trader")
check("neutral: bubble", y ~= nil)
check("yell is red", y and y.text.color[1] == 1 and y.text.color[2] < 0.5)

-- 3. no doubles / no guesses
check("friendly NPC: none", NB.OnChat("CHAT_MSG_MONSTER_SAY", "hi", "Friendly Guard") == nil)
check("friendly player: none", NB.OnChat("CHAT_MSG_SAY", "hi", "Botfriend") == nil)
check("hidden plate: none", NB.OnChat("CHAT_MSG_SAY", "hi", "Hidden One") == nil)
check("ambiguous name: none", NB.OnChat("CHAT_MSG_MONSTER_SAY", "halt", "Stormwind Guard") == nil)
check("named frame is not a plate", NB.OnChat("CHAT_MSG_SAY", "hi", "Sneaky") == nil)
check("no plate at all: none", NB.OnChat("CHAT_MSG_SAY", "hi", "Somebody Far") == nil)
check("own line: none", NB.OnChat("CHAT_MSG_SAY", "hi", "Me") == nil)

-- 4. a second line from the same speaker reuses the bubble
local b2 = NB.OnChat("CHAT_MSG_MONSTER_SAY", "Second line.", "Raid Leader")
check("same speaker reuses bubble", b2 == b and b.text.text == "Second line.")

-- 5. long text wraps at the max width
local long = string.rep("word ", 80)
local bl = NB.OnChat("CHAT_MSG_SAY", long, "Raid Leader")
check("long text capped width", bl and bl.text.w == 220)

-- 6. expiry and plate recycling drop the bubble
NOW = NOW + 60
b.scripts.OnUpdate(b)
check("expires", not b.shown)
local r = NB.OnChat("CHAT_MSG_MONSTER_SAY", "Back again.", "Raid Leader")
leader.regions[3].text = "Someone Else"           -- the client reused this plate
r.scripts.OnUpdate(r)
check("recycled plate drops bubble", not r.shown)
leader.regions[3].text = "Raid Leader"

-- 7. switches
CVARS.chatBubbles = "0"
check("chatBubbles off: none", NB.OnChat("CHAT_MSG_SAY", "hi", "Raid Leader") == nil)
CVARS.chatBubbles = "1"
WLP.db.nameplateBubbles = false
check("option off: none", NB.OnChat("CHAT_MSG_SAY", "hi", "Raid Leader") == nil)
WLP.db.nameplateBubbles = true
check("option back on: bubble", NB.OnChat("CHAT_MSG_SAY", "hi", "Raid Leader") ~= nil)

RESULT_FAILS = table.concat(FAILS, ", ")
RESULT_CHECKS = CHECKS
''')

fails = str(lua.globals().RESULT_FAILS)
if fails:
    print("FAILED checks:", fails)
    print("\nNAMEPLATE BUBBLE TEST: FAIL")
    raise SystemExit(1)
print("all %d checks passed" % int(lua.globals().RESULT_CHECKS))
print("\nNAMEPLATE BUBBLE TEST: PASS")

#!/usr/bin/env python3
"""Unit test of the Duel Master countdown (Core/DuelCountdown.lua).

Feeds CHAT_MSG_ADDON events shaped exactly like wowlegends_duelmaster.cpp's
AddonMsg (prefix WLDUEL, whisper to self, tab-separated body) and checks:

  * C ticks show the number and "vs <opponent> (<spec>)", gold for the last 5
  * F flashes FIGHT!, E shows Victory / Defeat / No result, then they fade out
  * a countdown that stops ticking (duel called off) clears itself
  * other prefixes, other channels and OTHER SENDERS are ignored - nobody but
    the server's whisper-to-self may put text in the middle of the screen

    pip install lupa
    python tools/test_duel.py
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
UnitName = function() return "Me" end
UIParent = {}

local FRAMES = {}
CreateFrame = function()
    local f = { shown = false, alpha = 1, scripts = {}, events = {} }
    function f:SetWidth() end
    function f:SetHeight() end
    function f:SetPoint() end
    function f:SetFrameStrata() end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:CreateFontString()
        local fs = { text = "" }
        function fs:SetFont() end
        function fs:SetPoint() end
        function fs:SetJustifyH() end
        function fs:SetText(t) self.text = t end
        function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
        return fs
    end
    table.insert(FRAMES, f)
    return f
end

local WLP = {}
WLP.Warn = function(m) error(m) end
local chunk = assert(loadfile(BASE .. "/Core/DuelCountdown.lua"))
chunk("WoWLegendsPlayer", WLP)
local DC = WLP.DuelCountdown
local frame, big, sub = DC.frame, DC.big, DC.sub

local listener
for _, fr in ipairs(FRAMES) do if fr.events.CHAT_MSG_ADDON then listener = fr end end
local function fire(prefix, msg, channel, sender)
    listener.scripts.OnEvent(listener, "CHAT_MSG_ADDON", prefix, msg, channel or "WHISPER", sender or "Me")
end
local function tick(dt) NOW = NOW + dt; frame.scripts.OnUpdate(frame) end

FAILS, CHECKS = {}, 0
local function check(name, cond)
    CHECKS = CHECKS + 1
    if not cond then table.insert(FAILS, name) end
end

-- 1. countdown ticks
fire("WLDUEL", "C\t20\tGrommash\tArms Warrior")
check("C: shown", frame.shown)
check("C: number", big.text == "20")
check("C: vs line", sub.text == "vs Grommash (Arms Warrior)")
check("C: white early", big.color[1] == 1 and big.color[2] == 1 and big.color[3] == 1)
tick(1); fire("WLDUEL", "C\t5\tGrommash\tArms Warrior")
check("C: gold for last five", big.text == "5" and big.color[3] == 0)
fire("WLDUEL", "C\t9\tGrommash\t")
check("C: no spec, no brackets", sub.text == "vs Grommash")

-- 2. FIGHT! flash, then fade and hide
fire("WLDUEL", "F")
check("F: text", big.text == "FIGHT!" and sub.text == "")
tick(1.5)
check("F: fading", frame.shown and frame.alpha < 1 and frame.alpha > 0)
tick(1)
check("F: gone", not frame.shown)

-- 3. results
fire("WLDUEL", "E\tW\tGrommash")
check("E W: victory", frame.shown and big.text == "Victory" and sub.text == "you beat Grommash")
fire("WLDUEL", "E\tL\tGrommash")
check("E L: defeat", big.text == "Defeat" and sub.text == "Grommash won this one")
fire("WLDUEL", "E\t-\tGrommash")
check("E -: no result", big.text == "No result")
tick(10)
check("E: gone after hold + fade", not frame.shown)

-- 4. a countdown nobody finishes clears itself
fire("WLDUEL", "C\t12\tGrommash\tArms Warrior")
tick(2)
check("stale: still up at 2s", frame.shown)
tick(2)
check("stale: gone after 3s silence", not frame.shown)

-- 5. only our own server whisper counts
fire("WLDUEL", "C\t20\tX\tY", "WHISPER", "SomePrankster")
check("other sender ignored", not frame.shown)
fire("WLDUEL", "C\t20\tX\tY", "PARTY", "Me")
check("other channel ignored", not frame.shown)
fire("DC", "C\t20\tX\tY")
check("other prefix ignored", not frame.shown)
check("junk kind not handled", DC.Handle("Z\t1") == false)
check("C without a number not handled", DC.Handle("C\tsoon\tX") == false)

RESULT_FAILS = table.concat(FAILS, ", ")
RESULT_CHECKS = CHECKS
''')

fails = str(lua.globals().RESULT_FAILS)
if fails:
    print("FAILED checks:", fails)
    print("\nDUEL COUNTDOWN TEST: FAIL")
    raise SystemExit(1)
print("all %d checks passed" % int(lua.globals().RESULT_CHECKS))
print("\nDUEL COUNTDOWN TEST: PASS")

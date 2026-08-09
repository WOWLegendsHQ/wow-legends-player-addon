#!/usr/bin/env python3
"""Unit test of the Warband Camp system-message parser (Core/Warband.lua).

Feeds the literal shipped v1.5.0 reply strings (some with |cff..|r color codes,
which must be stripped) and asserts every state transition, including the
regression trap: the "N of M" status form must be matched BEFORE the unlimited
"N things" form, or the zone capture swallows half the sentence.

    pip install lupa
    python tools/test_warband.py
"""
import os
from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.abspath(os.path.join(HERE, "..", "WoWLegendsPlayer")).replace("\\", "/")

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().BASE = BASE

lua.execute(r'''
unpack = table.unpack
SENT, AFTERQ = {}, {}
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
SendChatMessage = function(msg) table.insert(SENT, msg) end

local WLP = {}
WLP.After = function(delay, fn) table.insert(AFTERQ, fn) end
WLP.AddLogin = function() end
local chunk = assert(loadfile(BASE .. "/Core/Warband.lua"))
chunk("WoWLegendsPlayer", WLP)
local W = WLP.Warband

FAILS = {}
local function check(name, cond)
    if not cond then table.insert(FAILS, name) end
end

-- 1. not enabled (with color codes)
W.ParseSystem("|cff88ccffWarband Camps are not enabled on this realm.|r")
check("disabled: probed", W.probed == true)
check("disabled: enabled=false", W.enabled == false)

-- 2. no camp yet
W.ParseSystem("You have no Warband Camp yet. Stand somewhere nice and use .camp claim.")
check("nocamp: enabled", W.enabled == true)
check("nocamp: hasCamp=false", W.hasCamp == false)

-- 3. status, capped form, colored zone
W.ParseSystem("Your Warband Camp is in |cffffc94dElwynn Forest|r, with 12 of 200 things set up.")
check("status: zone", W.zone == "Elwynn Forest")
check("status: count", W.count == 12)
check("status: cap", W.cap == 200)

-- 4. status, unlimited form (MaxProps=0) - zone must capture cleanly
W.ParseSystem("Your Warband Camp is in Durotar, with 7 things set up.")
check("unlim: zone", W.zone == "Durotar")
check("unlim: count", W.count == 7)
check("unlim: cap=nil", W.cap == nil)

-- 5. place success, so-far form: count moves, cap stays nil
W.ParseSystem("Tent set up (8 so far).")
check("sofar: count", W.count == 8)
check("sofar: cap stays nil", W.cap == nil)

-- 6. place success, of form
W.ParseSystem("Campfire set up (13 of 200).")
check("place: count", W.count == 13)
check("place: cap", W.cap == 200)

-- 7. camp full
W.ParseSystem("Your camp is full (200 things).")
check("full: count=cap", W.count == 200 and W.cap == 200)

-- 8. claim success queues a re-probe; draining it sends .camp
local before = #SENT
W.ParseSystem("This ground is yours. Your Warband Camp is founded in this very spot.")
check("claim: hasCamp", W.hasCamp == true)
check("claim: probe queued", #AFTERQ > 0)
for _, fn in ipairs(AFTERQ) do fn() end
check("claim: probe sends .camp", #SENT > before and SENT[#SENT] == ".camp")

-- 9. unrelated system line: returns false, state untouched
local z = W.zone
check("noise: returns false", W.ParseSystem("You have learned a new spell: Fireball.") == false)
check("noise: state untouched", W.zone == z and W.count == 200)

RESULT_FAILS = table.concat(FAILS, ", ")
''')

fails = str(lua.globals().RESULT_FAILS)
if fails:
    print("FAILED checks:", fails)
    print("\nWARBAND PARSER TEST: FAIL")
    raise SystemExit(1)
print("all 18 checks passed")
print("\nWARBAND PARSER TEST: PASS")

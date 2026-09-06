#!/usr/bin/env python3
"""Unit test of the Warband Camp system-message parser (Core/Warband.lua).

Feeds the literal shipped reply strings (v1.5.0 props + v1.6.0 camp staff, some
with |cff..|r color codes, which must be stripped) and asserts every state
transition, including two regression traps:

  * the "N of M" status form must be matched BEFORE the unlimited "N things"
    form, or the zone capture swallows half the sentence;
  * a camp-staff line must never move the prop gauge - staff live in their own
    server table with their own cap, and nothing reports how many you have.

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

FAILS, CHECKS = {}, 0
local function check(name, cond)
    CHECKS = CHECKS + 1
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

-- 10. CAMP STAFF (repack v1.6.0). They ride the same .camp place command but
-- live in their own server table with their own cap - so a hire must NOT move
-- the prop gauge. That is the whole trap: count/cap belong to props only.
local pCount, pCap = W.count, W.cap
W.ParseSystem("|cff00ff00Goblin Banker|r takes up position at your camp.")
check("staff: hire parsed", W.hasCamp == true)
check("staff: prop count untouched", W.count == pCount and W.cap == pCap)
check("staff: not full", W.staffFull == false)

W.ParseSystem("Barmaid will arrive shortly.")
check("staff: late arrival parsed", W.ParseSystem("Human Guard will arrive shortly.") == true)
check("staff: count still untouched", W.count == pCount and W.cap == pCap)

W.ParseSystem("You already have 6 at your camp. Send one away with |cffffff00.camp remove|r first.")
check("staff: cap flagged", W.staffFull == true)
check("staff: cap learned", W.staffCap == 6)
check("staff: cap did not touch props", W.count == pCount and W.cap == pCap)

W.ParseSystem("Orc Guard takes up position at your camp.")
check("staff: hire clears the full flag", W.staffFull == false)

RESULT_FAILS = table.concat(FAILS, ", ")
RESULT_CHECKS = CHECKS
''')

fails = str(lua.globals().RESULT_FAILS)
if fails:
    print("FAILED checks:", fails)
    print("\nWARBAND PARSER TEST: FAIL")
    raise SystemExit(1)
print("all %d checks passed" % int(lua.globals().RESULT_CHECKS))
print("\nWARBAND PARSER TEST: PASS")

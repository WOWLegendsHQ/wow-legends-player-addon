#!/usr/bin/env python3
"""Unit test of the spoken-LFG row (repack v1.6.0 natural-language LFG).

Two traps this locks down, both silent failures in-game:

  1. The line must be spoken RAW. A '$' prefix makes it a bot order and a '.'
     prefix makes it a dot-command; either way the server's SAY/YELL hook never
     sees a trigger phrase and nothing whispers you back. WLP.RunSay must not
     decorate the text the way RunBotOrder deliberately does.
  2. The size arg is optional, and "lfg " with a trailing space is not the same
     line as "lfg" once the server trims and compares (MatchLfgPhrase requires
     the line to START with a trigger). BuildLine has to drop the blank.

    pip install lupa
    python tools/test_lfg.py
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
SendChatMessage = function(msg, channel)
    table.insert(SENT, { text = msg, channel = channel })
end

local WLP = {}
WLP.IsBlank = function(s) return s == nil or s == "" or (type(s) == "string" and s:match("^%s*$") ~= nil) end
WLP.Trim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
WLP.PushHistory = function() end
WLP.GetBotScope = function() return "all" end
WLP.ResolveArg = function(v, arg)
    if WLP.IsBlank(v) and arg.fallback == "target" then return nil end
    return v
end

local chunk = assert(loadfile(BASE .. "/Core/CommandRunner.lua"))
chunk("WoWLegendsPlayer", WLP)

FAILS, CHECKS = {}, 0
local function check(name, cond)
    CHECKS = CHECKS + 1
    if not cond then table.insert(FAILS, name) end
end

-- The row as UI/Tabs/Bots.lua defines it.
local def = { id = "lfg_say", label = "Ask for a group", format = "lfg %s", send = "say",
              args = { { key = "size", placeholder = "size (opt)",
                         choices = { "5", "10", "20", "25", "40" }, optional = true } } }

-- 1. no size -> the bare trigger, no trailing space
local line = WLP.BuildLine(def, {})
check("blank size -> 'lfg'", line == "lfg")

-- 2. a size the server accepts
check("size 10 -> 'lfg 10'", WLP.BuildLine(def, { size = "10" }) == "lfg 10")
check("size 40 -> 'lfg 40'", WLP.BuildLine(def, { size = "40" }) == "lfg 40")

-- 3. RunSay speaks it verbatim in SAY - no '$', no '.', no rewriting
WLP.RunSay(WLP.BuildLine(def, { size = "25" }))
check("spoken once", #SENT == 1)
check("channel is SAY", SENT[1] and SENT[1].channel == "SAY")
check("text verbatim", SENT[1] and SENT[1].text == "lfg 25")
check("no bot prefix", SENT[1] and SENT[1].text:sub(1, 1) ~= "$")
check("no dot prefix", SENT[1] and SENT[1].text:sub(1, 1) ~= ".")

-- 4. RunBotOrder still prefixes - the two paths must not have merged
WLP.RunBotOrder("lfg 10", { scope = "whisper", bot = "Botty" })
check("bot order keeps $", SENT[2] and SENT[2].text == "$lfg 10")

-- 5. an empty line is not spoken at all
local before = #SENT
WLP.RunSay("")
WLP.RunSay(nil)
check("blank never spoken", #SENT == before)

-- 6. preview shows the plain line (no '$' - that decoration is bot-order only)
check("preview is plain", WLP.PreviewLine(def, { size = "10" }) == "lfg 10")

RESULT_FAILS = table.concat(FAILS, ", ")
RESULT_CHECKS = CHECKS
''')

fails = str(lua.globals().RESULT_FAILS)
checks = int(lua.globals().RESULT_CHECKS)
if fails:
    print("FAILED checks:", fails)
    print("\nLFG SAY TEST: FAIL")
    raise SystemExit(1)
print("all %d checks passed" % checks)
print("\nLFG SAY TEST: PASS")

#!/usr/bin/env python3
"""Unit test of the Paths data half (Core/Paths.lua).

Feeds CHAT_MSG_ADDON events shaped exactly like wowlegends_paths.cpp's
UiAnswer (prefix WLPATH, whisper to self, tab-separated) and checks:

  * the ask: "Q\\t<reqId>" as an addon whisper to oneself, at most one per
    5.5 s (the server answers one per 5 s and drops the rest)
  * H / P / T / R / G lines build a set; nothing shows before D; T parts join
    with a space; extra trailing fields are ignored (forward compatible)
  * only our latest reqId or a push (0) is accepted; a push replaces the set
  * other prefixes, channels and SENDERS are ignored
  * the toasts: none on the first set; a boss credited; a gated stage cleared;
    fulfilled (and only that); forsaken; a level-up gives none
  * the Herald's entry from a 3.3.5a creature GUID (entries above 65535 too)

    pip install lupa
    python tools/test_paths.py
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
GUIDS = {}
UnitGUID = function(u) return GUIDS[u] end
SENT = {}
SendAddonMessage = function(prefix, msg, channel, target)
    table.insert(SENT, { prefix = prefix, msg = msg, channel = channel, target = target })
end

local FRAMES = {}
CreateFrame = function()
    local f = { scripts = {}, events = {} }
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    table.insert(FRAMES, f)
    return f
end

local WLP = {}
WLP.Warn = function(m) error(m) end
local logins = {}
WLP.AddLogin = function(fn) table.insert(logins, fn) end
local timers = {}
WLP.After = function(d, fn) table.insert(timers, { at = NOW + d, fn = fn }) end
local chunk = assert(loadfile(BASE .. "/Core/Paths.lua"))
chunk("WoWLegendsPlayer", WLP)
local P = WLP.Paths

local listener
for _, fr in ipairs(FRAMES) do if fr.events.CHAT_MSG_ADDON then listener = fr end end
local T = string.char(9)
local function line(...) return table.concat({ ... }, T) end
local function fire(msg, prefix, channel, sender)
    listener.scripts.OnEvent(listener, "CHAT_MSG_ADDON", prefix or "WLPATH", msg, channel or "WHISPER", sender or "Me")
end
local EVENTS
P.OnChange(function(set, events) EVENTS = events end)

FAILS, CHECKS = {}, 0
local function check(name, cond)
    CHECKS = CHECKS + 1
    if not cond then table.insert(FAILS, name) end
end

-- a full answer: reqId r; lr = Long Road bosses done, 4 bits; lv = level; st = statuses
local function answer(r, o)
    o = o or {}
    local lr = o.lr or { 0, 0, 0, 0 }
    local L = {
        line("H", "990000", "Swear at the Herald of the Fallen, in every starting zone.", r),
        line("P", "long_road", "The Long Road", "path", o.long or "active", "1795250000", "1335", "0", "", "1", "", r),
        line("T", "long_road", "offer", "I swear the Long Road. History will not be skipped.", r),
        line("T", "long_road", "creed", "THE LONG ROAD is PERMANENT. Your experience will LOCK at 60", r),
        line("T", "long_road", "creed", "until Ragnaros has fallen. Do you swear it?", r),
        line("R", "long_road", "Achievement_Boss_Ragnaros", "Experience stops at level 60.", r),
        line("R", "long_road", "Achievement_Boss_Illidan", "Experience stops at level 70.", r),
        line("G", "long_road", "the old world", "Ragnaros", lr[1], "1", "60", "Achievement_Boss_Ragnaros", r),
        line("G", "long_road", "the old world", "Nefarian", lr[2], "1", "60", "Achievement_Boss_Nefarion", r),
        line("G", "long_road", "the old world", "C'Thun", lr[3], "1", "60", "Achievement_Boss_CThun", r),
        line("G", "long_road", "Outland", "Illidan", lr[4], "1", "70", "Achievement_Boss_Illidan", r),
        line("P", "iron_oath", "The Iron Oath", "path", o.iron or "active", "0", "734", "0", "", "1", "", r, "a-future-field"),
        line("G", "iron_oath", "the journey", "Reach level 80", o.lv or "57", "80", "0", "Achievement_Level_80", r),
        line("P", "slow_burn", "The Slow Burn", "path", "none", "0", "1638", "0", "Must be sworn before level 5.", "0", "", r),
        line("P", "hardcore", "Hardcore", "trial", "none", "0", "0", "1", "", "1", "Ability_Rogue_FeignDeath", r),
    }
    local n = #L
    L[#L + 1] = line("D", tostring(n), r, "1")
    return L
end
local function feed(L) for _, l in ipairs(L) do fire(l) end end

-- 1. the ask
check("login handler registered", #logins == 1)
logins[1]()
check("login asks after a few seconds, not at once", #SENT == 0 and #timers == 1 and timers[1].at - NOW >= 3)
NOW = NOW + 4; timers[1].fn()
check("Q sent", #SENT == 1 and SENT[1].prefix == "WLPATH" and SENT[1].channel == "WHISPER" and SENT[1].target == "Me")
local req1 = SENT[1].msg:match("^Q\t(%d+)$")
check("Q format exact", req1 ~= nil and #req1 <= 9 and req1 ~= "0")
check("second ask within 5 s refused", P.Ask() == false and #SENT == 1)

-- 2. an answer builds a set, shown only on D
local L = answer(req1)
for i = 1, #L - 1 do fire(L[i]) end
check("nothing before D", P.data == nil)
fire(L[#L])
local d = P.data
check("set after D", d ~= nil and #d.list == 4)
check("herald", d.herald.entry == 990000 and d.herald.where:find("starting zone") ~= nil)
local lrp = d.byKey.long_road
check("P fields", lrp.name == "The Long Road" and lrp.kind == "path" and lrp.status == "active"
    and lrp.sworn == 1795250000 and lrp.trophy == 1335 and lrp.canSwear == false and lrp.live == true)
check("T parts joined with a space", P.Text(lrp, "creed") == "THE LONG ROAD is PERMANENT. Your experience will LOCK at 60 until Ragnaros has fallen. Do you swear it?")
check("offer", P.Text(lrp, "offer"):find("History will not be skipped") ~= nil)
check("R lines in order", #lrp.rules == 2 and lrp.rules[2].icon == "Achievement_Boss_Illidan")
check("G lines", #lrp.goals == 4 and lrp.goals[4].gate == 70 and lrp.goals[1].done == false)
local st = P.Stages(lrp)
check("stages grouped in order", #st == 2 and st[1].name == "the old world" and #st[1].goals == 3 and st[1].gate == 60 and st[2].gate == 70)
check("extra trailing field ignored", d.byKey.iron_oath.trophy == 734 and d.byKey.iron_oath.status == "active")
check("switched-off path", d.byKey.slow_burn.live == false and d.byKey.slow_burn.reason:find("level 5") ~= nil)
check("trial", d.byKey.hardcore.kind == "trial" and d.byKey.hardcore.canSwear and d.byKey.hardcore.icon == "Ability_Rogue_FeignDeath")
check("first set: no toasts", EVENTS ~= nil and #EVENTS == 0)

-- 3. stale answers and strangers are ignored
local before = P.data
feed(answer("12345"))
check("stale reqId ignored", P.data == before)
fire(answer("0")[1], "WLPATH", "WHISPER", "SomePrankster")
fire(line("D", "0", "0", "1"), "WLPATH", "WHISPER", "SomePrankster")
check("other sender ignored", P.data == before)
fire(line("D", "0", "0", "1"), "WLPATH", "PARTY", "Me")
check("other channel ignored", P.data == before)
check("junk type not handled", P.Handle("Z" .. T .. "0") == false)
check("no reqId not handled", P.Handle("D" .. T .. "3") == false)

-- 4. pushes (reqId 0) and the toasts
feed(answer("0", { lr = { 1, 0, 0, 0 } }))
check("push replaces the set", P.data ~= before and P.data.byKey.long_road.goals[1].done)
check("boss credited: one toast", #EVENTS == 1 and EVENTS[1].kind == "goal" and EVENTS[1].goal.label == "Ragnaros")

feed(answer("0", { lr = { 1, 1, 1, 0 } }))
local kinds = {}
for _, e in ipairs(EVENTS) do kinds[#kinds + 1] = e.kind end
check("last boss of a gated stage: two bosses + the stage", table.concat(kinds, ",") == "goal,goal,stage"
    and EVENTS[3].stage.name == "the old world" and EVENTS[3].stage.gate == 60)

feed(answer("0", { lr = { 1, 1, 1, 0 }, lv = "58" }))
check("a level-up: no toast", #EVENTS == 0)

feed(answer("0", { lr = { 1, 1, 1, 1 }, long = "done", lv = "58" }))
check("fulfilled: only the fulfilled toast", #EVENTS == 1 and EVENTS[1].kind == "done" and EVENTS[1].path.key == "long_road")

feed(answer("0", { lr = { 1, 1, 1, 1 }, long = "done", lv = "58", iron = "forsaken" }))
check("forsaken toast", #EVENTS == 1 and EVENTS[1].kind == "forsaken" and EVENTS[1].path.key == "iron_oath")

-- a push with fewer Paths drops the missing ones
local short = { line("H", "990000", "x", "0"), line("P", "hardcore", "Hardcore", "trial", "active", "0", "0", "0", "", "1", "Ability_Rogue_FeignDeath", "0"), line("D", "2", "0", "1") }
feed(short)
check("push is the whole set", #P.data.list == 1 and P.data.byKey.long_road == nil)

-- 5. a new ask after the gap, and only its answer counts
NOW = NOW + 6
check("ask after the gap", P.Ask() == true and #SENT == 2)
local req2 = SENT[2].msg:match("^Q\t(%d+)$")
check("new reqId", req2 ~= nil and req2 ~= req1)
feed(answer(req1))
check("the old ask's answer is now stale", #P.data.list == 1)
feed(answer(req2))
check("the new ask's answer counts", #P.data.list == 4)

-- 6. the Herald from a GUID
GUIDS.npc = "0xF1300F1B30001234"     -- entry 990000 = 0x0F1B30
check("herald entry parsed", P.NpcEntry(GUIDS.npc) == 990000 and P.IsHerald("npc"))
GUIDS.npc = "0xF130001A4F000099"     -- entry 6735, an innkeeper
check("other npc", P.NpcEntry(GUIDS.npc) == 6735 and not P.IsHerald("npc"))
check("a player is no npc", P.NpcEntry("0x0000000000000012") == nil)
check("junk guid", P.NpcEntry(nil) == nil and P.NpcEntry("0xF13") == nil)

RESULT_FAILS = table.concat(FAILS, ", ")
RESULT_CHECKS = CHECKS
''')

fails = str(lua.globals().RESULT_FAILS)
if fails:
    print("FAILED checks:", fails)
    print("\nPATHS TEST: FAIL")
    raise SystemExit(1)
print("all %d checks passed" % int(lua.globals().RESULT_CHECKS))
print("\nPATHS TEST: PASS")

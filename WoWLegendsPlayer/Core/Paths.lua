-- WoWLegendsPlayer/Core/Paths.lua
-- The Paths of Legends: the data half of the Paths window (UI/PathsFrame.lua).
--
-- Protocol of record (prefix WLPATH, an addon whisper to oneself, fields
-- tab-separated; server: wowlegends_paths.cpp UiAnswer):
--   C->S  Q <reqId>                                    ask; 1 answer / 5 s
--   S->C  H <heraldEntry> <whereText> <reqId>
--         P <key> <name> <kind> <status> <swornTime> <trophyItem>
--           <canSwear> <reason> <live> <icon> <reqId>
--         T <key> <field> <text> <reqId>               offer / creed, in parts
--         R <key> <icon> <text> <reqId>                "what you give up"
--         G <key> <group> <label> <have> <need> <gateLevel> <icon> <reqId>
--         D <count> <reqId> <version>                  done: render
-- The server pushes the whole set again (reqId 0) whenever a Path changes.
-- Every word and icon comes from the server, so a new Path needs no addon
-- change. We ask on login and when the window opens - never on a timer.
--
-- Without the server half nothing is ever answered and nothing breaks: the
-- window just says so.

local addonName, WLP = ...

local P = {}
WLP.Paths = P

local PREFIX = "WLPATH"
local ASK_GAP = 5.5        -- the server answers one Q per 5 s and drops the rest
local LOGIN_DELAY = 4      -- "a few seconds after entering the world"
P.HERALD_ENTRY = 990000    -- until the first H line says otherwise

-- where the reqId sits in each line (fields counted from the type letter)
local REQ_AT = { H = 4, P = 12, T = 5, R = 5, G = 9, D = 3 }

P.data = nil               -- the last complete set
P.askedAt = nil            -- GetTime() of the last Q we sent
local building = nil       -- the set being received
local latestReq = nil      -- the reqId of our last Q
local seq = nil
local listeners = {}

function P.OnChange(fn) listeners[#listeners + 1] = fn end

local function notify(set, events)
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, set, events)
        if not ok and WLP.Warn then WLP.Warn("paths: " .. tostring(err)) end
    end
end

local function split(msg)
    local out = {}
    for part in (msg .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = part end
    return out
end

local function newSet(reqId)
    return { reqId = reqId, herald = { entry = P.HERALD_ENTRY, where = "" },
             list = {}, byKey = {}, lines = 0 }
end

local function pathOf(set, key)
    local p = set.byKey[key]
    if not p then
        p = { key = key, name = key, kind = "path", status = "none", sworn = 0,
              trophy = 0, canSwear = false, reason = "", live = true, icon = "",
              text = { offer = {}, creed = {} }, rules = {}, goals = {} }
        set.byKey[key] = p
        set.list[#set.list + 1] = p
    end
    return p
end

-- The joined text of a T field ("offer" / "creed").
function P.Text(p, field)
    local parts = p and p.text[field]
    if not parts or #parts == 0 then return "" end
    return table.concat(parts, " ")
end

-- Goals in stage order: { { name = group, gate = n, goals = {...}, done = bool }, ... }
function P.Stages(p)
    local out, at = {}, {}
    for _, g in ipairs(p.goals) do
        local s = at[g.group]
        if not s then
            s = { name = g.group, gate = 0, goals = {}, done = true }
            at[g.group] = s
            out[#out + 1] = s
        end
        s.goals[#s.goals + 1] = g
        if g.gate > s.gate then s.gate = g.gate end
        if not g.done then s.done = false end
    end
    return out
end

-- ─── Toasts: what changed between two complete sets ─────────────────────────
-- boss credited (a one-step goal done), stage cleared (every goal of a gated
-- stage done), Path fulfilled, forsaken. A Path that is fulfilled in this very
-- push gets only the fulfilled toast.
function P.Diff(old, new)
    local out = {}
    if not old or not new then return out end
    for _, p in ipairs(new.list) do
        local o = old.byKey[p.key]
        if o then
            if p.status == "done" and o.status ~= "done" then
                out[#out + 1] = { kind = "done", path = p }
            elseif p.status == "forsaken" and o.status == "active" then
                out[#out + 1] = { kind = "forsaken", path = p }
            elseif p.status == "active" and o.status == "active" then
                for i, g in ipairs(p.goals) do
                    local og = o.goals[i]
                    if og and og.label == g.label and g.need == 1 and g.done and not og.done then
                        out[#out + 1] = { kind = "goal", path = p, goal = g }
                    end
                end
                local was = {}
                for _, s in ipairs(P.Stages(o)) do was[s.name] = s.done end
                for _, s in ipairs(P.Stages(p)) do
                    if s.done and s.gate > 0 and was[s.name] == false then
                        out[#out + 1] = { kind = "stage", path = p, stage = s }
                    end
                end
            end
        end
    end
    return out
end

local function finish(set)
    local old = P.data
    P.data = set
    P.receivedAt = GetTime()
    if set.herald and set.herald.entry then P.HERALD_ENTRY = set.herald.entry end
    notify(set, P.Diff(old, set))
end

-- One WLPATH message body (after the prefix). Returns true when it was ours.
function P.Handle(msg)
    if type(msg) ~= "string" then return false end
    local f = split(msg)
    local kind = f[1]
    local at = REQ_AT[kind]
    if not at then return false end
    local req = tonumber(f[at])
    if not req then return false end
    -- the answer to our latest ask, or a push; anything else is stale
    if req ~= 0 and req ~= latestReq then return false end

    if kind == "D" then
        if building and building.reqId == req then
            building.expected = tonumber(f[2])
            building.version = tonumber(f[4])
            local set = building
            building = nil
            finish(set)
        end
        return true
    end

    if not building or building.reqId ~= req then building = newSet(req) end
    local set = building
    set.lines = set.lines + 1

    if kind == "H" then
        set.herald.entry = tonumber(f[2]) or P.HERALD_ENTRY
        set.herald.where = f[3] or ""
    elseif kind == "P" then
        local p = pathOf(set, f[2])
        p.name = (f[3] ~= "" and f[3]) or f[2]
        p.kind = f[4] ~= "" and f[4] or "path"
        p.status = f[5] ~= "" and f[5] or "none"
        p.sworn = tonumber(f[6]) or 0
        p.trophy = tonumber(f[7]) or 0
        p.canSwear = f[8] == "1"
        p.reason = f[9] or ""
        p.live = f[10] ~= "0"
        p.icon = f[11] or ""
    elseif kind == "T" then
        local p = pathOf(set, f[2])
        local field = f[3]
        p.text[field] = p.text[field] or {}
        if f[4] and f[4] ~= "" then table.insert(p.text[field], f[4]) end
    elseif kind == "R" then
        local p = pathOf(set, f[2])
        p.rules[#p.rules + 1] = { icon = f[3] or "", text = f[4] or "" }
    elseif kind == "G" then
        local p = pathOf(set, f[2])
        local have, need = tonumber(f[5]) or 0, tonumber(f[6]) or 1
        p.goals[#p.goals + 1] = { group = f[3] or "", label = f[4] or "", have = have,
            need = need, gate = tonumber(f[7]) or 0, icon = f[8] or "", done = have >= need }
    end
    return true
end

-- Ask the realm for the full set. Returns false when it would be dropped
-- (the server answers one ask per 5 s per character).
function P.Ask()
    local now = GetTime()
    if P.askedAt and now - P.askedAt < ASK_GAP then return false end
    P.askedAt = now
    seq = (seq or (math.floor(now) % 100000)) + 1
    if seq > 999999999 then seq = 1 end
    latestReq = seq
    SendAddonMessage(PREFIX, "Q\t" .. seq, "WHISPER", UnitName("player"))
    return true
end

-- The creature entry inside a 3.3.5a GUID ("0xF130" + 6 hex entry + 6 hex
-- counter); nil for anything that is not a creature or vehicle.
function P.NpcEntry(guid)
    if type(guid) ~= "string" or #guid ~= 18 then return nil end
    local hi = guid:sub(3, 5):upper()
    if hi ~= "F13" and hi ~= "F15" then return nil end
    return tonumber(guid:sub(7, 12), 16)
end

function P.IsHerald(unit)
    return P.NpcEntry(UnitGUID(unit or "npc")) == P.HERALD_ENTRY
end

-- Only our own server's whisper-to-self counts.
local listener = CreateFrame("Frame")
listener:RegisterEvent("CHAT_MSG_ADDON")
listener:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "WHISPER" or sender ~= UnitName("player") then return end
    local ok, err = pcall(P.Handle, message)
    if not ok and WLP.Warn then WLP.Warn("paths: " .. tostring(err)) end
end)

if WLP.AddLogin then
    WLP.AddLogin(function()
        WLP.After(LOGIN_DELAY, function() P.Ask() end)
    end)
end

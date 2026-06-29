-- WoWLegendsPlayer/Core/SavedVars.lua
-- Frame-position persistence, history ring buffer, favorites, input cache,
-- and the shared bot-order scope ("all" my bots vs "whisper" the target).

local addonName, WLP = ...

local HISTORY_MAX = 30

local function db() return WLP.db or WoWLegendsPlayer_DB end

-- ─── Bot-order scope ───────────────────────────────────────────────────────
function WLP.GetBotScope() return (db() and db().botScope) or "all" end

function WLP.SetBotScope(scope)
    local d = db()
    if d then d.botScope = scope end
    if WLP.RefreshScopeSelectors then WLP.RefreshScopeSelectors() end
end

-- ─── Frame positions ───────────────────────────────────────────────────────
function WLP.SaveFramePoint(frame, key)
    if not frame or not key then return end
    local point, _, relPoint, x, y = frame:GetPoint()
    if not point then return end
    local d = db()
    d[key] = d[key] or {}
    d[key].point, d[key].relPoint, d[key].x, d[key].y = point, relPoint, x, y
end

function WLP.RestoreFramePoint(frame, key, fallback)
    if not frame then return end
    local saved = db() and db()[key]
    frame:ClearAllPoints()
    if saved and saved.point then
        frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    elseif fallback then
        frame:SetPoint(fallback.point or "CENTER", UIParent, fallback.relPoint or fallback.point or "CENTER",
            fallback.x or 0, fallback.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ─── History (newest first, deduped against most-recent entry) ─────────────
function WLP.PushHistory(line)
    if WLP.IsBlank(line) then return end
    local d = db()
    d.history = d.history or {}
    if d.history[1] == line then return end
    table.insert(d.history, 1, line)
    while #d.history > HISTORY_MAX do table.remove(d.history) end
    if WLP.RefreshHistoryTab then WLP.RefreshHistoryTab() end
end

function WLP.GetHistory()
    local d = db()
    return (d and d.history) or {}
end

function WLP.ClearHistory()
    local d = db()
    if not d then return end
    d.history = {}
    if WLP.RefreshHistoryTab then WLP.RefreshHistoryTab() end
end

-- ─── Favorites (keyed by group:id so duplicates across tabs collapse) ───────
local function favKey(def) return (def.group or "?") .. ":" .. (def.id or def.label or "?") end

function WLP.IsFavorite(def)
    local d = db(); d.favorites = d.favorites or {}
    return d.favorites[favKey(def)] ~= nil
end

function WLP.ToggleFavorite(def)
    local d = db(); d.favorites = d.favorites or {}
    local k = favKey(def)
    if d.favorites[k] then
        d.favorites[k] = nil
        WLP.Print("unpinned " .. (def.label or k))
    else
        local copy = {}
        for ck, cv in pairs(def) do
            if type(cv) ~= "function" then copy[ck] = cv end
        end
        d.favorites[k] = copy
        WLP.Print("pinned " .. WLP.colors.brand .. (def.label or k) .. WLP.colors.reset .. " to Favorites")
    end
    if WLP.RefreshFavoritesTab then WLP.RefreshFavoritesTab() end
end

function WLP.GetFavorites()
    local d = db(); d.favorites = d.favorites or {}
    local list = {}
    for _, def in pairs(d.favorites) do table.insert(list, def) end
    table.sort(list, function(a, b) return (a.label or "") < (b.label or "") end)
    return list
end

-- ─── Per-input remembered values ───────────────────────────────────────────
function WLP.GetInputCache(rowKey, argKey)
    local d = db(); d.inputs = d.inputs or {}
    local row = d.inputs[rowKey]
    return row and row[argKey] or nil
end

function WLP.SetInputCache(rowKey, argKey, value)
    local d = db(); d.inputs = d.inputs or {}
    d.inputs[rowKey] = d.inputs[rowKey] or {}
    d.inputs[rowKey][argKey] = value
end

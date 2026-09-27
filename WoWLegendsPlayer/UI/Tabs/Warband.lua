-- WoWLegendsPlayer/UI/Tabs/Warband.lua
-- * Warband Camp (repack v1.5.0, task #74): manage the whole camp by buttons —
-- claim/travel/visit/break, gather alts, and place props from categorized
-- dropdowns. Authored from handoffs/2026-08-09_addon_warband_tab.md.
-- State + reply parsing live in Core/Warband.lua; the prop catalogue in
-- Data/WarbandProps.lua. Module ships OFF server-side: on the literal
-- not-enabled reply this panel greys out for the session.
-- Camp staff (repack v1.6.0) ride the same place dropdown as a last category;
-- they have their own server-side cap and NO readable count, so no gauge.
-- Boundaries: NO Warband Bank, NO banner picker (still unbuilt server-side).

local addonName, WLP = ...

local function row(id, label, fmt, tooltip, args)
    return { id = id, label = label, format = fmt, wl = true, group = "Warband",
             tooltip = tooltip, args = args }
end

local CampRows = {
    row("wb_claim", "Claim camp", ".camp claim",
        "Found your Warband Camp on the ground you're standing on. The server refuses with a one-line reason if the spot won't work (indoors, water, city, bridge, too close to another camp, ...)."),
    row("wb_go", "Travel to camp", ".camp go",
        "Teleport to your camp. 5-minute cooldown (shared with Visit); blocked in combat, while dead, and in BGs/arenas/Pilgrim's Way."),
    row("wb_alts", "Gather alts", ".camp alts",
        "Manually re-gather your alts at the camp (max 8). They normally gather on their own at login."),
    row("wb_visit", "Visit player", ".camp visit %s",
        "Travel to another player's camp. Shares the 5-minute cooldown with Travel. Blank = your current target.",
        { {key="name",placeholder="player",fallback="target",width=120} }),
    row("wb_list", "Nearby camps", ".camp list",
        "List camps near you - who, zone, distance - in your chat."),
}

local function warbandBuilder(parent)
    local W = WLP.Warband
    local c = WLP.colors

    -- ─── Status bar ────────────────────────────────────────────────────────
    local statusFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    statusFS:SetJustifyH("LEFT")

    local refresh = WLP.MakeFlatButton(parent, 90, 22, "Refresh", { justify = "CENTER" })
    refresh:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -6)
    refresh:SetScript("OnClick", function() WLP.RunCommand(".camp") end)

    -- ─── Body (everything below the status bar; hidden when disabled) ──────
    local body = CreateFrame("Frame", nil, parent)
    body:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -34)
    body:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    -- Left: camp actions
    local used = WLP.LayoutRows(body, CampRows, { yTop = 8, x = 8, columnWidth = 360,
        sectionTitle = "Your camp" })

    local breakBtn = WLP.MakeFlatButton(body, 168, 24, "Break camp...", { justify = "CENTER", danger = true })
    breakBtn:SetPoint("TOPLEFT", body, "TOPLEFT", 18, -(used + 4))
    breakBtn:SetScript("OnClick", function()
        -- The server itself is two-step: `.camp leave` prints its warning line,
        -- our popup then sends `.camp leave confirm`.
        WLP.RunCommand(".camp leave")
        StaticPopup_Show("WLP_CONFIRM_CAMP_LEAVE")
    end)
    breakBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Break camp", 1, 0.45, 0.45)
        GameTooltip:AddLine("Destroys your camp and ALL its props. Cannot be undone. Asks for confirmation.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    breakBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Right: prop placement
    local hdr = WLP.CreateSectionHeader(body, "Place props")
    hdr:SetPoint("TOPLEFT", body, "TOPLEFT", 380, -8)

    local catDD = WLP.CreateChoice(body, 170, 24, WLP.WarbandProps.CategoryNames(), "category")
    catDD:SetPoint("TOPLEFT", body, "TOPLEFT", 384, -(8 + hdr:GetHeight() + 8))

    local propDD = WLP.CreateChoice(body, 170, 24, {}, "prop")
    propDD:SetPoint("LEFT", catDD, "RIGHT", 8, 0)

    -- Category pick fills the prop list (dot-call style, matching CreateChoice).
    -- It also swaps the hint: staff obey different rules from scenery.
    local origCatSet = catDD.SetValue
    catDD.SetValue = function(v)
        origCatSet(v)
        propDD.SetChoices(v and WLP.WarbandProps.PropChoices(v) or {})
        propDD.SetValue(nil)
        if body.SetPlaceHint then body.SetPlaceHint(v and WLP.WarbandProps.IsStaff(v)) end
    end

    local placeBtn = WLP.MakeFlatButton(body, 110, 24, "Place", { justify = "CENTER" })
    placeBtn:SetPoint("TOPLEFT", catDD, "BOTTOMLEFT", 0, -10)
    local removeBtn = WLP.MakeFlatButton(body, 140, 24, "Remove nearest", { justify = "CENTER" })
    removeBtn:SetPoint("LEFT", placeBtn, "RIGHT", 8, 0)
    removeBtn:SetScript("OnClick", function() WLP.RunCommand(".camp remove") end)

    -- 3-second per-prop server cooldown -> debounce the button client-side.
    local lastPlace = 0
    placeBtn:SetScript("OnClick", function()
        local key = propDD.GetValue()
        if not key then WLP.Warn("pick a category and a prop first.") return end
        if GetTime() - lastPlace < 3 then return end   -- "Steady on - one thing at a time."
        lastPlace = GetTime()
        WLP.RunCommand(".camp place " .. key)
        placeBtn.label:SetText("Placing...")
        WLP.After(3, function() placeBtn.label:SetText("Place") end)
    end)

    -- Rotate (repack v1.7.0): turns the PROP nearest you (within 10 yd) in
    -- place. Props only - staff are not in that table. Shares the placing
    -- cooldown server-side ("Give it a moment.").
    local function rotateBtn(label, arg, anchor, tip)
        local b = WLP.MakeFlatButton(body, 84, 22, label, { justify = "CENTER" })
        b:SetPoint(unpack(anchor))
        b:SetScript("OnClick", function() WLP.RunCommand(".camp rotate" .. (arg and (" " .. arg) or "")) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 0.82, 0.30)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:AddLine("Turns the prop nearest you (within 10 yd) without moving it.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    local rotL = rotateBtn("Turn left", "left", { "TOPLEFT", placeBtn, "BOTTOMLEFT", 0, -8 },
        "45 degrees to the left.")
    local rotR = rotateBtn("Turn right", "right", { "LEFT", rotL, "RIGHT", 6, 0 },
        "45 degrees to the right.")
    rotateBtn("Face me", "face", { "LEFT", rotR, "RIGHT", 6, 0 },
        "Turns it to face you.")

    local placeHint = body:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeHint:SetPoint("TOPLEFT", rotL, "BOTTOMLEFT", -4, -8)
    placeHint:SetPoint("RIGHT", body, "RIGHT", -8, 0)
    placeHint:SetJustifyH("LEFT")

    local PROP_HINT = "Props appear IN FRONT of you - face where you want it before clicking Place. "
        .. "Bigger props land further out; stand on a table to place at table height. "
        .. "You must be within 32 yd of the camp centre, on the ground."
    -- Staff are counted separately from props server-side, and nothing reports
    -- how many you have - so no gauge, and the cap only shows up as a refusal.
    local STAFF_HINT = "Camp staff are people, not scenery: up to "
        .. (WLP.WarbandProps.staffCap or 6) .. " of them, counted separately from your props "
        .. "(the gauge above does not move). Guards take YOUR faction and defend the camp; "
        .. "the banker, merchant, barmaid and steward are neutral, so any visitor can use them "
        .. "(the steward can repair, keep a mailbox, cure resurrection sickness and reset dungeons - "
        .. "whichever the server owner leaves on). "
        .. "Remove nearest sends one away too."
    function body.SetPlaceHint(isStaff)
        placeHint:SetText(isStaff and STAFF_HINT or PROP_HINT)
    end
    body.SetPlaceHint(false)

    -- ─── Facts footer ──────────────────────────────────────────────────────
    local facts = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    facts:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 8, 8)
    facts:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 8)
    facts:SetJustifyH("LEFT")
    facts:SetText(c.muted
        .. "The camp belongs to your ACCOUNT - every character shares it. Others see it only within 40 yd; "
        .. "friends can walk right in, no invite needed. Your alts gather there at login (max 8) and stroll "
        .. "around - whisper an alt 'follow' (a bot whisper, not a dot-command) to take it adventuring.\n"
        .. "Cooldowns: Travel / Visit share 5 min; placing has a 3 s per-prop breather." .. c.reset)

    -- ─── Disabled view (module ships OFF) ──────────────────────────────────
    local disabledFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    disabledFS:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -60)
    disabledFS:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -60)
    disabledFS:SetJustifyH("LEFT")
    disabledFS:SetText(c.danger .. "Warband Camps are not enabled on this realm." .. c.reset
        .. "\n\n" .. c.muted .. "The server owner can turn them on in mod_wowlegends.conf. "
        .. "This panel wakes up on its own once they are." .. c.reset)
    disabledFS:Hide()

    -- ─── State -> UI ───────────────────────────────────────────────────────
    local function render()
        if W.probed and W.enabled == false then
            body:Hide(); disabledFS:Show()
            statusFS:SetText(c.danger .. "Warband Camps: disabled" .. c.reset)
            return
        end
        disabledFS:Hide(); body:Show()
        if not W.probed then
            statusFS:SetText(c.muted .. "Camp: checking... (or hit Refresh)" .. c.reset)
        elseif W.hasCamp == false then
            statusFS:SetText(c.label .. "Camp: " .. c.reset
                .. "none yet - stand somewhere nice in the open world and Claim.")
        else
            local things = W.count and (W.count .. (W.cap and (" of " .. W.cap) or "") .. " things set up")
                or "contents unknown"
            -- Staff have no gauge (the server reports no count) - the only
            -- honest thing to show is that the last hire hit the cap.
            local staff = W.staffFull
                and (c.danger .. "  -  camp staff full (" .. (W.staffCap or WLP.WarbandProps.staffCap or 6)
                     .. ") - Remove nearest to free a place" .. c.reset)
                or ""
            statusFS:SetText(c.label .. "Camp: " .. c.reset .. c.accent .. (W.zone or "?") .. c.reset
                .. c.muted .. "  -  " .. things .. c.reset .. staff)
        end
    end
    W.OnChange(render)
    parent:HookScript("OnShow", render)
    render()
end

WLP.RegisterTab({
    id = "warband", label = "Warband", wl = true,
    builder = warbandBuilder,
})

local addonName, ns = ...
local f = CreateFrame("Frame", "ForeverThreatFrame", UIParent)

local PLAYER_BAR_HEIGHT = 18
local PET_BAR_HEIGHT = 14
local BAR_WIDTH = 190
local PET_BAR_WIDTH = 176
local ABSOLUTE_MAX_ROWS = 10

local bars = {}
local timeSinceLast = 0
local UPDATE_INTERVAL = 0.15
local settingsCategory = nil
local lockSettingRef = nil

-- Combat Exit Linger & Fade Engine (Solo / Open World)
local OUT_OF_COMBAT_LINGER = 12.0
local FADE_DURATION = 3.0
local lingerActive = false
local lingerElapsed = 0

-- Dungeon / Group Cumulative Threat & Idle Reset State
local DEFAULT_DUNGEON_IDLE_RESET = 90
local cumulativeThreat = {}      -- [uniqueKey] = { threat, label, classToken, isPet, isPlayer }
local lastCombatEndTime = nil    -- Timestamp from GetTime() when last pull ended
local errorThrottleUntil = 0
local MAX_LOG_ENTRIES = 200
local MAX_ERROR_ENTRIES = 50

-- ----------------------------------------------------------------------------
-- Debug Logger & Error Dump Window
-- ----------------------------------------------------------------------------
local function LogDebug(category, msg)
if not ForeverThreatDB then return end
    if not ForeverThreatDB.debugLog then ForeverThreatDB.debugLog = {} end
        local stamp = date("%H:%M:%S")
        table.insert(ForeverThreatDB.debugLog, string.format("[%s][%s] %s", stamp, category, tostring(msg)))
        while #ForeverThreatDB.debugLog > MAX_LOG_ENTRIES do
            table.remove(ForeverThreatDB.debugLog, 1)
            end
            end

            local errorFrame = CreateFrame("Frame", "ForeverThreatErrorFrame", UIParent, "BasicFrameTemplateWithInset")
            errorFrame:SetSize(520, 340)
            errorFrame:SetPoint("CENTER")
            errorFrame:SetFrameStrata("DIALOG")
            errorFrame:SetMovable(true)
            errorFrame:EnableMouse(true)
            errorFrame:RegisterForDrag("LeftButton")
            errorFrame:SetScript("OnDragStart", errorFrame.StartMoving)
            errorFrame:SetScript("OnDragStop", errorFrame.StopMovingOrSizing)
            errorFrame:Hide()

            errorFrame.title = errorFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            errorFrame.title:SetPoint("LEFT", errorFrame.TitleBg, "LEFT", 6, 0)
            errorFrame.title:SetText("ForeverThreat - Error & Debug Dump (Ctrl+C to Copy)")

            local scrollFrame = CreateFrame("ScrollFrame", "ForeverThreatErrorScroll", errorFrame, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", errorFrame, "TOPLEFT", 12, -30)
            scrollFrame:SetPoint("BOTTOMRIGHT", errorFrame, "BOTTOMRIGHT", -32, 40)

            local editBox = CreateFrame("EditBox", nil, scrollFrame)
            editBox:SetMultiLine(true)
            editBox:SetFontObject("ChatFontNormal")
            editBox:SetWidth(465)
            editBox:SetAutoFocus(false)
            editBox:SetScript("OnEscapePressed", function() errorFrame:Hide() end)
            scrollFrame:SetScrollChild(editBox)

            local clearBtn = CreateFrame("Button", nil, errorFrame, "UIPanelButtonTemplate")
            clearBtn:SetSize(110, 22)
            clearBtn:SetPoint("BOTTOMLEFT", errorFrame, "BOTTOMLEFT", 12, 10)
            clearBtn:SetText("Clear Logs")
            clearBtn:SetScript("OnClick", function()
            if ForeverThreatDB then
                ForeverThreatDB.errorLog = {}
                ForeverThreatDB.debugLog = {}
                end
                editBox:SetText("Logs cleared.")
                end)

            local function ShowLogDumpWindow(autoTriggered)
            local lines = {}
            table.insert(lines, "=== ForeverThreat Diagnostic Dump (" .. date("%Y-%m-%d %H:%M:%S") .. ") ===")
            table.insert(lines, "Group Members: " .. tostring(GetNumGroupMembers()) .. " | InInstance: " .. tostring(IsInInstance()))
            table.insert(lines, "")
            table.insert(lines, "--- CAPTURED ERRORS ---")
            if ForeverThreatDB and ForeverThreatDB.errorLog and #ForeverThreatDB.errorLog > 0 then
                for _, entry in ipairs(ForeverThreatDB.errorLog) do
                    table.insert(lines, entry)
                    table.insert(lines, "----------------------------------------")
                    end
                    else
                        table.insert(lines, "(No errors recorded)")
                        end

                        table.insert(lines, "")
                        table.insert(lines, "--- RECENT DEBUG TRACE (Last 40) ---")
                        if ForeverThreatDB and ForeverThreatDB.debugLog and #ForeverThreatDB.debugLog > 0 then
                            local startIdx = math.max(1, #ForeverThreatDB.debugLog - 39)
                            for i = startIdx, #ForeverThreatDB.debugLog do
                                table.insert(lines, ForeverThreatDB.debugLog[i])
                                end
                                else
                                    table.insert(lines, "(No debug events recorded)")
                                    end

                                    editBox:SetText(table.concat(lines, "\n"))
                                    errorFrame:Show()
                                    if not autoTriggered then
                                        editBox:HighlightText()
                                        editBox:SetFocus()
                                        end
                                        end

                                        local function RecordError(err)
                                        local trace = debugstack(2, 12, 12)
                                        local fullEntry = string.format("[%s] %s\n%s", date("%H:%M:%S"), tostring(err), tostring(trace))
                                        if not ForeverThreatDB then ForeverThreatDB = {} end
                                            if not ForeverThreatDB.errorLog then ForeverThreatDB.errorLog = {} end

                                                local last = ForeverThreatDB.errorLog[#ForeverThreatDB.errorLog]
                                                if not last or not last:find(tostring(err), 1, true) then
                                                    table.insert(ForeverThreatDB.errorLog, fullEntry)
                                                    while #ForeverThreatDB.errorLog > MAX_ERROR_ENTRIES do
                                                        table.remove(ForeverThreatDB.errorLog, 1)
                                                        end
                                                        print("|cffff3333ForeverThreat Error Captured:|r Opening diagnostic window (/ftm errors). Pausing updates for 5s.")
                                                        ShowLogDumpWindow(true)
                                                        end
                                                        errorThrottleUntil = GetTime() + 5.0
                                                        end

                                                        -- ----------------------------------------------------------------------------
                                                        -- Mode Detection & Cumulative Reset Helpers
                                                        -- ----------------------------------------------------------------------------
                                                        local function IsDungeonCumulativeMode()
                                                        local inInstance, instanceType = IsInInstance()
                                                        if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
                                                            return true
                                                            end
                                                            if GetNumGroupMembers() >= 5 then
                                                                return true
                                                                end
                                                                return false
                                                                end

                                                                local function GetDungeonIdleTimeout()
                                                                if ForeverThreatDB and ForeverThreatDB.dungeonIdleTimeout ~= nil then
                                                                    return tonumber(ForeverThreatDB.dungeonIdleTimeout) or DEFAULT_DUNGEON_IDLE_RESET
                                                                    end
                                                                    return DEFAULT_DUNGEON_IDLE_RESET
                                                                    end

                                                                    local function ResetCumulativeThreat(reason)
                                                                    wipe(cumulativeThreat)
                                                                    lastCombatEndTime = nil
                                                                    for i = 1, ABSOLUTE_MAX_ROWS do
                                                                        bars[i]:Hide()
                                                                        end
                                                                        if ForeverThreatDB and ForeverThreatDB.locked then
                                                                            f:Hide()
                                                                            end
                                                                            LogDebug("RESET", "Cumulative threat wiped (" .. tostring(reason or "manual") .. ").")
                                                                            end

                                                                            local function GetMaxRows()
                                                                            if ForeverThreatDB and ForeverThreatDB.maxRows then
                                                                                return ForeverThreatDB.maxRows
                                                                                end
                                                                                return 10
                                                                                end

                                                                                local function UpdateFrameDimensions()
                                                                                local maxRows = GetMaxRows()
                                                                                f:SetSize(BAR_WIDTH, (PLAYER_BAR_HEIGHT + 2) * maxRows)
                                                                                end

                                                                                -- ----------------------------------------------------------------------------
                                                                                -- Frame Construction, Hitbox & Drag Overlay
                                                                                -- ----------------------------------------------------------------------------
                                                                                f:SetPoint("CENTER", UIParent, "CENTER", 250, -50)
                                                                                f:SetMovable(true)
                                                                                f:EnableMouse(true)
                                                                                f:RegisterForDrag("LeftButton")
                                                                                f:Hide()

                                                                                local dragOverlay = f:CreateTexture(nil, "BACKGROUND", nil, -7)
                                                                                dragOverlay:SetAllPoints(f)
                                                                                dragOverlay:SetColorTexture(0, 0.5, 0.85, 0.45)
                                                                                dragOverlay:Hide()

                                                                                local dragTitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                                                                                dragTitle:SetPoint("CENTER", f, "CENTER")
                                                                                dragTitle:SetText("ForeverThreat (Drag to Move)")
                                                                                dragTitle:Hide()

                                                                                f:SetScript("OnDragStart", function(self)
                                                                                if not (ForeverThreatDB and ForeverThreatDB.locked) then
                                                                                    self:StartMoving()
                                                                                    end
                                                                                    end)

                                                                                f:SetScript("OnDragStop", function(self)
                                                                                self:StopMovingOrSizing()
                                                                                if not ForeverThreatDB then ForeverThreatDB = {} end
                                                                                    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
                                                                                    ForeverThreatDB.point = point
                                                                                    ForeverThreatDB.relativePoint = relativePoint
                                                                                    ForeverThreatDB.x = xOfs
                                                                                    ForeverThreatDB.y = yOfs
                                                                                    end)

                                                                                local function CreateBar(index)
                                                                                local bar = CreateFrame("StatusBar", nil, f)
                                                                                bar:SetSize(BAR_WIDTH, PLAYER_BAR_HEIGHT)
                                                                                bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
                                                                                bar:SetMinMaxValues(0, 100)

                                                                                bar.bg = bar:CreateTexture(nil, "BACKGROUND")
                                                                                bar.bg:SetAllPoints(bar)
                                                                                bar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.75)

                                                                                bar.nameText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                                                                                bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
                                                                                bar.nameText:SetJustifyH("LEFT")
                                                                                bar.nameText:SetWidth(BAR_WIDTH - 20)
                                                                                bar.nameText:SetWordWrap(false)

                                                                                return bar
                                                                                end

                                                                                for i = 1, ABSOLUTE_MAX_ROWS do
                                                                                    bars[i] = CreateBar(i)
                                                                                    end

                                                                                    -- ----------------------------------------------------------------------------
                                                                                    -- Test Bar Preview Engine
                                                                                    -- ----------------------------------------------------------------------------
                                                                                    local function ShowTestPreview()
                                                                                    local maxDisplay = GetMaxRows()
                                                                                    local testSamples = {
                                                                                        { name = "MainTank (Warrior)", isPet = false, pct = 100, r = 0.78, g = 0.61, b = 0.43 },
                                                                                        { name = "Pet: Wolf",          isPet = true,  pct = 82,  r = 0.75, g = 0.55, b = 0.25 },
                                                                                        { name = "MageDPS",            isPet = false, pct = 74,  r = 0.41, g = 0.80, b = 0.94 },
                                                                                        { name = "OffTank (Paladin)",  isPet = false, pct = 68,  r = 0.96, g = 0.55, b = 0.73 },
                                                                                        { name = "RogueDPS",           isPet = false, pct = 62,  r = 1.00, g = 0.96, b = 0.41 },
                                                                                        { name = "HunterDPS",          isPet = false, pct = 58,  r = 0.67, g = 0.83, b = 0.45 },
                                                                                        { name = "ShadowPriest",       isPet = false, pct = 52,  r = 1.00, g = 1.00, b = 1.00 },
                                                                                        { name = "Pet: Imp",           isPet = true,  pct = 48,  r = 0.75, g = 0.55, b = 0.25 },
                                                                                        { name = "WarlockDPS",         isPet = false, pct = 45,  r = 0.53, g = 0.53, b = 0.93 },
                                                                                        { name = "[You] Player",       isPet = false, pct = 39,  r = 0.20, g = 0.90, b = 0.40 },
                                                                                    }

                                                                                    local yOfs = 0
                                                                                    local count = math.min(#testSamples, maxDisplay)

                                                                                    for i = 1, count do
                                                                                        local sample = testSamples[i]
                                                                                        local bar = bars[i]
                                                                                        bar:Show()
                                                                                        bar:ClearAllPoints()

                                                                                        if sample.isPet then
                                                                                            bar:SetSize(PET_BAR_WIDTH, PET_BAR_HEIGHT)
                                                                                            bar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -yOfs)
                                                                                            bar:SetAlpha(0.65)
                                                                                            bar.nameText:SetFontObject("GameFontDisableSmall")
                                                                                            bar.nameText:SetPoint("LEFT", bar, "LEFT", 6, 0)
                                                                                            bar.nameText:SetWidth(PET_BAR_WIDTH - 20)
                                                                                            bar:SetStatusBarColor(sample.r, sample.g, sample.b)
                                                                                            yOfs = yOfs + PET_BAR_HEIGHT + 2
                                                                                            else
                                                                                                bar:SetSize(BAR_WIDTH, PLAYER_BAR_HEIGHT)
                                                                                                bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -yOfs)
                                                                                                bar:SetAlpha(1.0)
                                                                                                bar.nameText:SetFontObject("GameFontHighlightSmall")
                                                                                                bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
                                                                                                bar.nameText:SetWidth(BAR_WIDTH - 20)
                                                                                                bar:SetStatusBarColor(sample.r, sample.g, sample.b)
                                                                                                yOfs = yOfs + PLAYER_BAR_HEIGHT + 2
                                                                                                end

                                                                                                bar:SetValue(sample.pct)
                                                                                                bar.nameText:SetText(sample.name)
                                                                                                end

                                                                                                for i = count + 1, ABSOLUTE_MAX_ROWS do bars[i]:Hide() end
                                                                                                    end

                                                                                                    local function TriggerTimedPreview(seconds)
                                                                                                    lingerActive = false
                                                                                                    f:SetAlpha(1.0)
                                                                                                    UpdateFrameDimensions()
                                                                                                    f:Show()
                                                                                                    ShowTestPreview()

                                                                                                    C_Timer.After(seconds or 5, function()
                                                                                                    local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
                                                                                                    if not inCombat and (ForeverThreatDB and ForeverThreatDB.locked) and not lingerActive and not (IsDungeonCumulativeMode() and next(cumulativeThreat)) then
                                                                                                        for i = 1, ABSOLUTE_MAX_ROWS do bars[i]:Hide() end
                                                                                                            f:Hide()
                                                                                                            end
                                                                                                            end)
                                                                                                    end

                                                                                                    local function SetFrameLocked(locked)
                                                                                                    if not ForeverThreatDB then ForeverThreatDB = {} end
                                                                                                        ForeverThreatDB.locked = locked

                                                                                                        UpdateFrameDimensions()

                                                                                                        if not locked then
                                                                                                            lingerActive = false
                                                                                                            f:SetAlpha(1.0)
                                                                                                            f:EnableMouse(true)
                                                                                                            f:Show()
                                                                                                            dragOverlay:Show()
                                                                                                            dragTitle:Show()
                                                                                                            ShowTestPreview()
                                                                                                            else
                                                                                                                dragOverlay:Hide()
                                                                                                                dragTitle:Hide()
                                                                                                                for i = 1, ABSOLUTE_MAX_ROWS do bars[i]:Hide() end
                                                                                                                    local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
                                                                                                                    if not inCombat and not lingerActive and not (IsDungeonCumulativeMode() and next(cumulativeThreat)) then
                                                                                                                        f:Hide()
                                                                                                                        end
                                                                                                                        end
                                                                                                                        end

                                                                                                                        -- ----------------------------------------------------------------------------
                                                                                                                        -- Helpers: Labeling & Safe Styling
                                                                                                                        -- ----------------------------------------------------------------------------
                                                                                                                        local function GetPetOwnerUnit(unit)
                                                                                                                        if unit == "pet" then
                                                                                                                            return "player"
                                                                                                                            elseif unit:match("^partypet(%d+)$") then
                                                                                                                                local id = unit:match("^partypet(%d+)$")
                                                                                                                                return "party" .. id
                                                                                                                                elseif unit:match("^raidpet(%d+)$") then
                                                                                                                                    local id = unit:match("^raidpet(%d+)$")
                                                                                                                                    return "raid" .. id
                                                                                                                                    end
                                                                                                                                    return nil
                                                                                                                                    end

                                                                                                                                    local function FormatUnitLabel(unit)
                                                                                                                                    local unitName = UnitName(unit)
                                                                                                                                    if not unitName then return unit end

                                                                                                                                        local ownerToken = GetPetOwnerUnit(unit)
                                                                                                                                        if ownerToken then
                                                                                                                                            if ownerToken == "player" then
                                                                                                                                                return "Pet: " .. unitName
                                                                                                                                                else
                                                                                                                                                    local ownerName = UnitName(ownerToken)
                                                                                                                                                    if ownerName then
                                                                                                                                                        return ownerName .. "'s " .. unitName
                                                                                                                                                        else
                                                                                                                                                            return "Pet: " .. unitName
                                                                                                                                                            end
                                                                                                                                                            end
                                                                                                                                                            end

                                                                                                                                                            if unit == "targettarget" then
                                                                                                                                                                return "[Target] " .. unitName
                                                                                                                                                                end

                                                                                                                                                                return unitName
                                                                                                                                                                end

                                                                                                                                                                local function ApplyClassColorByToken(bar, classToken, isPet)
                                                                                                                                                                if isPet then
                                                                                                                                                                    bar:SetStatusBarColor(0.75, 0.55, 0.25)
                                                                                                                                                                    else
                                                                                                                                                                        local color = classToken and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken]
                                                                                                                                                                        if color then
                                                                                                                                                                            bar:SetStatusBarColor(color.r, color.g, color.b)
                                                                                                                                                                            else
                                                                                                                                                                                bar:SetStatusBarColor(0.8, 0.2, 0.2)
                                                                                                                                                                                end
                                                                                                                                                                                end
                                                                                                                                                                                end

                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                -- Render Cumulative Dungeon Bars (Persists Across Pulls up to Timeout)
                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                local function RenderCumulativeBars()
                                                                                                                                                                                local list = {}
                                                                                                                                                                                local peakThreat = 0

                                                                                                                                                                                for key, data in pairs(cumulativeThreat) do
                                                                                                                                                                                    if data.threat > peakThreat then
                                                                                                                                                                                        peakThreat = data.threat
                                                                                                                                                                                        end
                                                                                                                                                                                        table.insert(list, {
                                                                                                                                                                                            key = key,
                                                                                                                                                                                            label = data.label,
                                                                                                                                                                                            classToken = data.classToken,
                                                                                                                                                                                            isPet = data.isPet,
                                                                                                                                                                                            threat = data.threat,
                                                                                                                                                                                            isPlayer = data.isPlayer,
                                                                                                                                                                                        })
                                                                                                                                                                                        end

                                                                                                                                                                                        if #list == 0 or peakThreat <= 0 then
                                                                                                                                                                                            return
                                                                                                                                                                                            end

                                                                                                                                                                                            table.sort(list, function(a, b)
                                                                                                                                                                                            return a.threat > b.threat
                                                                                                                                                                                            end)

                                                                                                                                                                                            local currentMaxRows = GetMaxRows()
                                                                                                                                                                                            local displayList = {}
                                                                                                                                                                                            local playerRank = nil

                                                                                                                                                                                            for rank, entry in ipairs(list) do
                                                                                                                                                                                                if entry.isPlayer then
                                                                                                                                                                                                    playerRank = rank
                                                                                                                                                                                                    break
                                                                                                                                                                                                    end
                                                                                                                                                                                                    end

                                                                                                                                                                                                    if not playerRank or playerRank <= currentMaxRows then
                                                                                                                                                                                                        for i = 1, math.min(#list, currentMaxRows) do
                                                                                                                                                                                                            table.insert(displayList, list[i])
                                                                                                                                                                                                            end
                                                                                                                                                                                                            else
                                                                                                                                                                                                                for i = 1, currentMaxRows - 1 do
                                                                                                                                                                                                                    table.insert(displayList, list[i])
                                                                                                                                                                                                                    end
                                                                                                                                                                                                                    table.insert(displayList, list[playerRank])
                                                                                                                                                                                                                    end

                                                                                                                                                                                                                    f:SetAlpha(1.0)
                                                                                                                                                                                                                    f:Show()

                                                                                                                                                                                                                    local currentYOffset = 0
                                                                                                                                                                                                                    local renderCount = #displayList

                                                                                                                                                                                                                    for i = 1, renderCount do
                                                                                                                                                                                                                        local entry = displayList[i]
                                                                                                                                                                                                                        local bar = bars[i]
                                                                                                                                                                                                                        local barPct = math.min(100, math.max(5, (entry.threat / peakThreat) * 100))

                                                                                                                                                                                                                        bar:ClearAllPoints()

                                                                                                                                                                                                                        if entry.isPet then
                                                                                                                                                                                                                            bar:SetSize(PET_BAR_WIDTH, PET_BAR_HEIGHT)
                                                                                                                                                                                                                            bar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -currentYOffset)
                                                                                                                                                                                                                            bar:SetAlpha(0.65)
                                                                                                                                                                                                                            bar.nameText:SetFontObject("GameFontDisableSmall")
                                                                                                                                                                                                                            bar.nameText:SetPoint("LEFT", bar, "LEFT", 6, 0)
                                                                                                                                                                                                                            bar.nameText:SetWidth(PET_BAR_WIDTH - 20)
                                                                                                                                                                                                                            currentYOffset = currentYOffset + PET_BAR_HEIGHT + 2
                                                                                                                                                                                                                            else
                                                                                                                                                                                                                                bar:SetSize(BAR_WIDTH, PLAYER_BAR_HEIGHT)
                                                                                                                                                                                                                                bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -currentYOffset)
                                                                                                                                                                                                                                bar:SetAlpha(1.0)
                                                                                                                                                                                                                                bar.nameText:SetFontObject("GameFontHighlightSmall")
                                                                                                                                                                                                                                bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
                                                                                                                                                                                                                                bar.nameText:SetWidth(BAR_WIDTH - 20)
                                                                                                                                                                                                                                currentYOffset = currentYOffset + PLAYER_BAR_HEIGHT + 2
                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                bar:Show()
                                                                                                                                                                                                                                bar.nameText:SetText(entry.label)
                                                                                                                                                                                                                                bar:SetValue(barPct)
                                                                                                                                                                                                                                ApplyClassColorByToken(bar, entry.classToken, entry.isPet)
                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                for i = renderCount + 1, ABSOLUTE_MAX_ROWS do
                                                                                                                                                                                                                                    bars[i]:Hide()
                                                                                                                                                                                                                                    end
                                                                                                                                                                                                                                    end

                                                                                                                                                                                                                                    -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                    -- Main Display Refresh (Protected & Mode-Aware)
                                                                                                                                                                                                                                    -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                    local function UpdateThreatDisplayInternal()
                                                                                                                                                                                                                                    if ForeverThreatDB and not ForeverThreatDB.locked then return end

                                                                                                                                                                                                                                        local dungeonMode = IsDungeonCumulativeMode()
                                                                                                                                                                                                                                        local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))

                                                                                                                                                                                                                                        if dungeonMode then
                                                                                                                                                                                                                                            lingerActive = false
                                                                                                                                                                                                                                            if not inCombat or not UnitExists("target") or UnitIsDead("target") or UnitIsFriend("player", "target") then
                                                                                                                                                                                                                                                if next(cumulativeThreat) then
                                                                                                                                                                                                                                                    RenderCumulativeBars()
                                                                                                                                                                                                                                                    end
                                                                                                                                                                                                                                                    return
                                                                                                                                                                                                                                                    end
                                                                                                                                                                                                                                                    else
                                                                                                                                                                                                                                                        if not inCombat and lingerActive then
                                                                                                                                                                                                                                                            return
                                                                                                                                                                                                                                                            end
                                                                                                                                                                                                                                                            if not UnitExists("target") or UnitIsDead("target") or UnitIsFriend("player", "target") then
                                                                                                                                                                                                                                                                if not lingerActive then
                                                                                                                                                                                                                                                                f:Hide()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if not inCombat and not lingerActive then
                                                                                                                                                                                                                                                                f:Hide()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local currentMaxRows = GetMaxRows()
                                                                                                                                                                                                                                                                local unitsToWatch = {"player", "pet"}
                                                                                                                                                                                                                                                                if not dungeonMode then
                                                                                                                                                                                                                                                                table.insert(unitsToWatch, "targettarget")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local numGroup = GetNumGroupMembers()
                                                                                                                                                                                                                                                                if IsInRaid() and numGroup > 0 then
                                                                                                                                                                                                                                                                for i = 1, math.min(numGroup, 40) do
                                                                                                                                                                                                                                                                table.insert(unitsToWatch, "raid" .. i)
                                                                                                                                                                                                                                                                table.insert(unitsToWatch, "raidpet" .. i)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif IsInGroup() and numGroup > 0 then
                                                                                                                                                                                                                                                                for i = 1, math.min(numGroup, 4) do
                                                                                                                                                                                                                                                                table.insert(unitsToWatch, "party" .. i)
                                                                                                                                                                                                                                                                table.insert(unitsToWatch, "partypet" .. i)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local collectedData = {}
                                                                                                                                                                                                                                                                local seenNames = {}

                                                                                                                                                                                                                                                                for _, unit in ipairs(unitsToWatch) do
                                                                                                                                                                                                                                                                if UnitExists(unit) then
                                                                                                                                                                                                                                                                local rawName = UnitName(unit)
                                                                                                                                                                                                                                                                local isPet = (GetPetOwnerUnit(unit) ~= nil)
                                                                                                                                                                                                                                                                local uniqueKey = (isPet and "PET:" or "PLY:") .. tostring(rawName)

                                                                                                                                                                                                                                                                if rawName and not seenNames[uniqueKey] then
                                                                                                                                                                                                                                                                seenNames[uniqueKey] = true

                                                                                                                                                                                                                                                                local ok, isTanking, _, scaledPct = pcall(UnitDetailedThreatSituation, unit, "target")
                                                                                                                                                                                                                                                                if not ok then
                                                                                                                                                                                                                                                                scaledPct = nil
                                                                                                                                                                                                                                                                isTanking = false
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if type(scaledPct) ~= "number" then
                                                                                                                                                                                                                                                                local okStat, status = pcall(UnitThreatSituation, unit, "target")
                                                                                                                                                                                                                                                                if okStat and type(status) == "number" and status > 0 then
                                                                                                                                                                                                                                                                scaledPct = status * 33
                                                                                                                                                                                                                                                                elseif UnitIsUnit("targettarget", unit) then
                                                                                                                                                                                                                                                                scaledPct = 100
                                                                                                                                                                                                                                                                isTanking = true
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if type(scaledPct) == "number" and scaledPct > 0 then
                                                                                                                                                                                                                                                                local _, classToken = UnitClass(unit)
                                                                                                                                                                                                                                                                local label = FormatUnitLabel(unit)
                                                                                                                                                                                                                                                                local isPlayer = UnitIsUnit(unit, "player")

                                                                                                                                                                                                                                                                if dungeonMode then
                                                                                                                                                                                                                                                                if not cumulativeThreat[uniqueKey] then
                                                                                                                                                                                                                                                                cumulativeThreat[uniqueKey] = {
                                                                                                                                                                                                                                                                threat = 0,
                                                                                                                                                                                                                                                                label = label,
                                                                                                                                                                                                                                                                classToken = classToken,
                                                                                                                                                                                                                                                                isPet = isPet,
                                                                                                                                                                                                                                                                isPlayer = isPlayer,
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                cumulativeThreat[uniqueKey].threat = cumulativeThreat[uniqueKey].threat + (scaledPct * UPDATE_INTERVAL)
                                                                                                                                                                                                                                                                cumulativeThreat[uniqueKey].label = label
                                                                                                                                                                                                                                                                if classToken then
                                                                                                                                                                                                                                                                cumulativeThreat[uniqueKey].classToken = classToken
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                local isCurrentTarget = UnitIsUnit("targettarget", unit) or (isTanking == true)
                                                                                                                                                                                                                                                                local sortWeight = isCurrentTarget and 1000 or (isPet and 100 or 200)
                                                                                                                                                                                                                                                                table.insert(collectedData, {
                                                                                                                                                                                                                                                                unit = unit,
                                                                                                                                                                                                                                                                label = label,
                                                                                                                                                                                                                                                                classToken = classToken,
                                                                                                                                                                                                                                                                isPet = isPet,
                                                                                                                                                                                                                                                                scaledPct = scaledPct,
                                                                                                                                                                                                                                                                sortWeight = sortWeight,
                                                                                                                                                                                                                                                                })
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if dungeonMode then
                                                                                                                                                                                                                                                                RenderCumulativeBars()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if #collectedData == 0 then
                                                                                                                                                                                                                                                                if not lingerActive then
                                                                                                                                                                                                                                                                f:Hide()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                table.sort(collectedData, function(a, b)
                                                                                                                                                                                                                                                                return a.sortWeight > b.sortWeight
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                local displayList = {}
                                                                                                                                                                                                                                                                local playerRank = nil

                                                                                                                                                                                                                                                                for rank, entry in ipairs(collectedData) do
                                                                                                                                                                                                                                                                if UnitIsUnit(entry.unit, "player") then
                                                                                                                                                                                                                                                                playerRank = rank
                                                                                                                                                                                                                                                                break
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if not playerRank or playerRank <= currentMaxRows then
                                                                                                                                                                                                                                                                for i = 1, math.min(#collectedData, currentMaxRows) do
                                                                                                                                                                                                                                                                table.insert(displayList, collectedData[i])
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                for i = 1, currentMaxRows - 1 do
                                                                                                                                                                                                                                                                table.insert(displayList, collectedData[i])
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                table.insert(displayList, collectedData[playerRank])
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                f:Show()

                                                                                                                                                                                                                                                                local currentYOffset = 0
                                                                                                                                                                                                                                                                local renderCount = #displayList

                                                                                                                                                                                                                                                                for i = 1, renderCount do
                                                                                                                                                                                                                                                                local entry = displayList[i]
                                                                                                                                                                                                                                                                local bar = bars[i]

                                                                                                                                                                                                                                                                bar:ClearAllPoints()

                                                                                                                                                                                                                                                                if entry.isPet then
                                                                                                                                                                                                                                                                bar:SetSize(PET_BAR_WIDTH, PET_BAR_HEIGHT)
                                                                                                                                                                                                                                                                bar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -currentYOffset)
                                                                                                                                                                                                                                                                bar:SetAlpha(0.65)
                                                                                                                                                                                                                                                                bar.nameText:SetFontObject("GameFontDisableSmall")
                                                                                                                                                                                                                                                                bar.nameText:SetPoint("LEFT", bar, "LEFT", 6, 0)
                                                                                                                                                                                                                                                                bar.nameText:SetWidth(PET_BAR_WIDTH - 20)
                                                                                                                                                                                                                                                                currentYOffset = currentYOffset + PET_BAR_HEIGHT + 2
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                bar:SetSize(BAR_WIDTH, PLAYER_BAR_HEIGHT)
                                                                                                                                                                                                                                                                bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -currentYOffset)
                                                                                                                                                                                                                                                                bar:SetAlpha(1.0)
                                                                                                                                                                                                                                                                bar.nameText:SetFontObject("GameFontHighlightSmall")
                                                                                                                                                                                                                                                                bar.nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
                                                                                                                                                                                                                                                                bar.nameText:SetWidth(BAR_WIDTH - 20)
                                                                                                                                                                                                                                                                currentYOffset = currentYOffset + PLAYER_BAR_HEIGHT + 2
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                bar:Show()
                                                                                                                                                                                                                                                                bar.nameText:SetText(entry.label)
                                                                                                                                                                                                                                                                bar:SetValue(entry.scaledPct)
                                                                                                                                                                                                                                                                ApplyClassColorByToken(bar, entry.classToken, entry.isPet)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                for i = renderCount + 1, ABSOLUTE_MAX_ROWS do
                                                                                                                                                                                                                                                                bars[i]:Hide()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local function SafeUpdateThreatDisplay()
                                                                                                                                                                                                                                                                if GetTime() < errorThrottleUntil then
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                local ok, err = xpcall(UpdateThreatDisplayInternal, function(e) return e end)
                                                                                                                                                                                                                                                                if not ok then
                                                                                                                                                                                                                                                                RecordError(err)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Options Menu Integration (Modern Settings API)
                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                local function RegisterSettingsMenu()
                                                                                                                                                                                                                                                                local category, layout = Settings.RegisterVerticalLayoutCategory("ForeverThreat")
                                                                                                                                                                                                                                                                settingsCategory = category

                                                                                                                                                                                                                                                                -- 1. Lock/Unlock Checkbox
                                                                                                                                                                                                                                                                local function GetLockValue()
                                                                                                                                                                                                                                                                return ForeverThreatDB and ForeverThreatDB.locked or false
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local function SetLockValue(value)
                                                                                                                                                                                                                                                                SetFrameLocked(value)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local lockSetting = Settings.RegisterProxySetting(
                                                                                                                                                                                                                                                                category,
                                                                                                                                                                                                                                                                "FOREVERTHREAT_LOCK_FRAME",
                                                                                                                                                                                                                                                                type(false),
                                                                                                                                                                                                                                                                "Lock Threat Meter",
                                                                                                                                                                                                                                                                false,
                                                                                                                                                                                                                                                                GetLockValue,
                                                                                                                                                                                                                                                                SetLockValue
                                                                                                                                                                                                                                                                )
                                                                                                                                                                                                                                                                lockSettingRef = lockSetting

                                                                                                                                                                                                                                                                Settings.CreateCheckbox(category, lockSetting, "When checked, the threat frame is locked and hidden outside of combat. Uncheck to move and reposition.")

                                                                                                                                                                                                                                                                -- 2. Max Visible Rows Dropdown
                                                                                                                                                                                                                                                                local function GetMaxRowsValue()
                                                                                                                                                                                                                                                                return GetMaxRows()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local function SetMaxRowsValue(value)
                                                                                                                                                                                                                                                                if not ForeverThreatDB then ForeverThreatDB = {} end
                                                                                                                                                                                                                                                                ForeverThreatDB.maxRows = tonumber(value) or 10
                                                                                                                                                                                                                                                                UpdateFrameDimensions()
                                                                                                                                                                                                                                                                if not (ForeverThreatDB and ForeverThreatDB.locked) then
                                                                                                                                                                                                                                                                ShowTestPreview()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local rowsSetting = Settings.RegisterProxySetting(
                                                                                                                                                                                                                                                                category,
                                                                                                                                                                                                                                                                "FOREVERTHREAT_MAX_ROWS",
                                                                                                                                                                                                                                                                type(10),
                                                                                                                                                                                                                                                                "Max Visible Rows",
                                                                                                                                                                                                                                                                10,
                                                                                                                                                                                                                                                                GetMaxRowsValue,
                                                                                                                                                                                                                                                                SetMaxRowsValue
                                                                                                                                                                                                                                                                )

                                                                                                                                                                                                                                                                local function GetRowOptions()
                                                                                                                                                                                                                                                                local container = Settings.CreateControlTextContainer()
                                                                                                                                                                                                                                                                container:Add(5, "5 Rows (Minimal)")
                                                                                                                                                                                                                                                                container:Add(8, "8 Rows (Standard)")
                                                                                                                                                                                                                                                                container:Add(10, "10 Rows (Raid Focus)")
                                                                                                                                                                                                                                                                return container:GetData()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                Settings.CreateDropdown(category, rowsSetting, GetRowOptions, "Sets the maximum number of threat bars displayed simultaneously.")

                                                                                                                                                                                                                                                                -- 3. Dungeon Idle Reset Timeout Dropdown (60s, 90s, 120s, Never)
                                                                                                                                                                                                                                                                local function GetIdleTimeoutValue()
                                                                                                                                                                                                                                                                return GetDungeonIdleTimeout()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local function SetIdleTimeoutValue(value)
                                                                                                                                                                                                                                                                if not ForeverThreatDB then ForeverThreatDB = {} end
                                                                                                                                                                                                                                                                ForeverThreatDB.dungeonIdleTimeout = tonumber(value) or DEFAULT_DUNGEON_IDLE_RESET
                                                                                                                                                                                                                                                                LogDebug("CONFIG", "Dungeon idle reset timeout set to " .. tostring(ForeverThreatDB.dungeonIdleTimeout) .. "s")
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local idleTimeoutSetting = Settings.RegisterProxySetting(
                                                                                                                                                                                                                                                                category,
                                                                                                                                                                                                                                                                "FOREVERTHREAT_DUNGEON_IDLE_TIMEOUT",
                                                                                                                                                                                                                                                                type(90),
                                                                                                                                                                                                                                                                "Dungeon Idle Reset Timeout",
                                                                                                                                                                                                                                                                DEFAULT_DUNGEON_IDLE_RESET,
                                                                                                                                                                                                                                                                GetIdleTimeoutValue,
                                                                                                                                                                                                                                                                SetIdleTimeoutValue
                                                                                                                                                                                                                                                                )

                                                                                                                                                                                                                                                                local function GetIdleTimeoutOptions()
                                                                                                                                                                                                                                                                local container = Settings.CreateControlTextContainer()
                                                                                                                                                                                                                                                                container:Add(60, "60 Seconds (Fast Pulls)")
                                                                                                                                                                                                                                                                container:Add(90, "90 Seconds (Default)")
                                                                                                                                                                                                                                                                container:Add(120, "120 Seconds (Relaxed)")
                                                                                                                                                                                                                                                                container:Add(0, "Never (Manual /ftm reset Only)")
                                                                                                                                                                                                                                                                return container:GetData()
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                Settings.CreateDropdown(
                                                                                                                                                                                                                                                                category,
                                                                                                                                                                                                                                                                idleTimeoutSetting,
                                                                                                                                                                                                                                                                GetIdleTimeoutOptions,
                                                                                                                                                                                                                                                                "In dungeons or 5+ player groups, resets accumulated threat if out of combat longer than this duration between pulls."
                                                                                                                                                                                                                                                                )

                                                                                                                                                                                                                                                                -- 4. Test Preview Button
                                                                                                                                                                                                                                                                local testData = {
                                                                                                                                                                                                                                                                name = "Test Preview (5s)",
                                                                                                                                                                                                                                                                buttonText = "Show Test Preview",
                                                                                                                                                                                                                                                                buttonClickHandler = function()
                                                                                                                                                                                                                                                                TriggerTimedPreview(5)
                                                                                                                                                                                                                                                                end,
                                                                                                                                                                                                                                                                tooltip = "Temporarily renders sample threat bars for 5 seconds to test visibility and placement.",
                                                                                                                                                                                                                                                                }

                                                                                                                                                                                                                                                                if layout and layout.AddInitializer and Settings.CreateElementInitializer then
                                                                                                                                                                                                                                                                local buttonInitializer = Settings.CreateElementInitializer("SettingButtonControlTemplate", testData)
                                                                                                                                                                                                                                                                layout:AddInitializer(buttonInitializer)
                                                                                                                                                                                                                                                                elseif Settings.CreateButton then
                                                                                                                                                                                                                                                                Settings.CreateButton(category, "Show Test Preview", testData.buttonClickHandler, testData.tooltip)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if layout and layout.OnDisplay then
                                                                                                                                                                                                                                                                layout:OnDisplay(function()
                                                                                                                                                                                                                                                                SetFrameLocked(false)
                                                                                                                                                                                                                                                                if lockSettingRef and lockSettingRef.SetValue then
                                                                                                                                                                                                                                                                lockSettingRef:SetValue(false)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                Settings.RegisterAddOnCategory(category)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Event Dispatcher
                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                f:RegisterEvent("ADDON_LOADED")
                                                                                                                                                                                                                                                                f:RegisterEvent("PLAYER_REGEN_DISABLED")
                                                                                                                                                                                                                                                                f:RegisterEvent("PLAYER_REGEN_ENABLED")
                                                                                                                                                                                                                                                                f:RegisterEvent("PLAYER_TARGET_CHANGED")
                                                                                                                                                                                                                                                                f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
                                                                                                                                                                                                                                                                f:RegisterEvent("UNIT_PET")
                                                                                                                                                                                                                                                                f:RegisterEvent("UNIT_FLAGS")
                                                                                                                                                                                                                                                                f:RegisterEvent("GROUP_ROSTER_UPDATE")
                                                                                                                                                                                                                                                                f:RegisterEvent("PLAYER_ENTERING_WORLD")

                                                                                                                                                                                                                                                                f:SetScript("OnEvent", function(self, event, unit)
                                                                                                                                                                                                                                                                if event == "ADDON_LOADED" and unit == addonName then
                                                                                                                                                                                                                                                                if not ForeverThreatDB then
                                                                                                                                                                                                                                                                ForeverThreatDB = {
                                                                                                                                                                                                                                                                locked = false,
                                                                                                                                                                                                                                                                maxRows = 10,
                                                                                                                                                                                                                                                                dungeonIdleTimeout = DEFAULT_DUNGEON_IDLE_RESET,
                                                                                                                                                                                                                                                                point = "CENTER",
                                                                                                                                                                                                                                                                relativePoint = "CENTER",
                                                                                                                                                                                                                                                                x = 250,
                                                                                                                                                                                                                                                                y = -50,
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if ForeverThreatDB.locked == nil then ForeverThreatDB.locked = false end
                                                                                                                                                                                                                                                                if ForeverThreatDB.maxRows == nil then ForeverThreatDB.maxRows = 10 end
                                                                                                                                                                                                                                                                if ForeverThreatDB.dungeonIdleTimeout == nil then ForeverThreatDB.dungeonIdleTimeout = DEFAULT_DUNGEON_IDLE_RESET end
                                                                                                                                                                                                                                                                if not ForeverThreatDB.debugLog then ForeverThreatDB.debugLog = {} end
                                                                                                                                                                                                                                                                if not ForeverThreatDB.errorLog then ForeverThreatDB.errorLog = {} end

                                                                                                                                                                                                                                                                LogDebug("INIT", "Addon loaded. DungeonMode=" .. tostring(IsDungeonCumulativeMode()) .. " IdleTimeout=" .. tostring(GetDungeonIdleTimeout()) .. "s")
                                                                                                                                                                                                                                                                UpdateFrameDimensions()

                                                                                                                                                                                                                                                                if ForeverThreatDB.x and ForeverThreatDB.y then
                                                                                                                                                                                                                                                                f:ClearAllPoints()
                                                                                                                                                                                                                                                                f:SetPoint(ForeverThreatDB.point or "CENTER", UIParent, ForeverThreatDB.relativePoint or "CENTER", ForeverThreatDB.x, ForeverThreatDB.y)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                RegisterSettingsMenu()

                                                                                                                                                                                                                                                                if not ForeverThreatDB.locked then
                                                                                                                                                                                                                                                                SetFrameLocked(false)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
                                                                                                                                                                                                                                                                or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))

                                                                                                                                                                                                                                                                if not version or version:match("^@") then
                                                                                                                                                                                                                                                                version = "1.3.5"
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                print(string.format("|cff00ccffForeverThreat|r v%s loaded. Type |cff00ff00/ftm|r for commands or |cff00ff00/ftm errors|r for logs.", version))

                                                                                                                                                                                                                                                                elseif event == "PLAYER_ENTERING_WORLD" then
                                                                                                                                                                                                                                                                LogDebug("ZONE", "Entering world. Instance=" .. tostring(IsInInstance()) .. " Group=" .. tostring(GetNumGroupMembers()))

                                                                                                                                                                                                                                                                elseif event == "GROUP_ROSTER_UPDATE" then
                                                                                                                                                                                                                                                                LogDebug("GROUP", "Roster updated. Members=" .. tostring(GetNumGroupMembers()) .. " CumulativeMode=" .. tostring(IsDungeonCumulativeMode()))

                                                                                                                                                                                                                                                                elseif event == "PLAYER_REGEN_DISABLED" then
                                                                                                                                                                                                                                                                lingerActive = false
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                f:SetAlpha(1.0)

                                                                                                                                                                                                                                                                local timeout = GetDungeonIdleTimeout()
                                                                                                                                                                                                                                                                if IsDungeonCumulativeMode() and lastCombatEndTime and timeout > 0 then
                                                                                                                                                                                                                                                                local idleGap = GetTime() - lastCombatEndTime
                                                                                                                                                                                                                                                                if idleGap > timeout then
                                                                                                                                                                                                                                                                ResetCumulativeThreat(string.format("pull gap %.1fs > %ds", idleGap, timeout))
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                LogDebug("COMBAT", string.format("Chain pull resumed after %.1fs (< %ds).", idleGap, timeout))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                lastCombatEndTime = nil

                                                                                                                                                                                                                                                                LogDebug("COMBAT", "Combat started. CumulativeMode=" .. tostring(IsDungeonCumulativeMode()))
                                                                                                                                                                                                                                                                SafeUpdateThreatDisplay()

                                                                                                                                                                                                                                                                elseif event == "PLAYER_REGEN_ENABLED" then
                                                                                                                                                                                                                                                                LogDebug("COMBAT", "Combat ended. CumulativeMode=" .. tostring(IsDungeonCumulativeMode()))
                                                                                                                                                                                                                                                                if IsDungeonCumulativeMode() then
                                                                                                                                                                                                                                                                lingerActive = false
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                lastCombatEndTime = GetTime()
                                                                                                                                                                                                                                                                f:SetAlpha(1.0)
                                                                                                                                                                                                                                                                if next(cumulativeThreat) then
                                                                                                                                                                                                                                                                RenderCumulativeBars()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                lastCombatEndTime = nil
                                                                                                                                                                                                                                                                local wasVisible = f:IsShown()
                                                                                                                                                                                                                                                                if wasVisible and (ForeverThreatDB and ForeverThreatDB.locked) then
                                                                                                                                                                                                                                                                lingerActive = true
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                f:SetAlpha(1.0)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                elseif event == "PLAYER_TARGET_CHANGED" then
                                                                                                                                                                                                                                                                SafeUpdateThreatDisplay()
                                                                                                                                                                                                                                                                elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
                                                                                                                                                                                                                                                                if unit == "target" or unit == "player" or unit == "pet" then
                                                                                                                                                                                                                                                                SafeUpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif event == "UNIT_PET" then
                                                                                                                                                                                                                                                                if unit == "player" then
                                                                                                                                                                                                                                                                SafeUpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif event == "UNIT_FLAGS" then
                                                                                                                                                                                                                                                                if unit == "player" or unit == "pet" then
                                                                                                                                                                                                                                                                SafeUpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Update Ticker, Configurable Dungeon Idle Reset & Smooth Linger Fade
                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                f:SetScript("OnUpdate", function(self, elapsed)
                                                                                                                                                                                                                                                                if ForeverThreatDB and not ForeverThreatDB.locked then return end
                                                                                                                                                                                                                                                                if GetTime() < errorThrottleUntil then return end

                                                                                                                                                                                                                                                                local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))

                                                                                                                                                                                                                                                                if IsDungeonCumulativeMode() then
                                                                                                                                                                                                                                                                local timeout = GetDungeonIdleTimeout()
                                                                                                                                                                                                                                                                if timeout > 0 and not inCombat and lastCombatEndTime and next(cumulativeThreat) then
                                                                                                                                                                                                                                                                local idleElapsed = GetTime() - lastCombatEndTime
                                                                                                                                                                                                                                                                if idleElapsed > timeout then
                                                                                                                                                                                                                                                                ResetCumulativeThreat(string.format("idle timeout %.1fs > %ds", idleElapsed, timeout))
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif lingerActive and not inCombat then
                                                                                                                                                                                                                                                                lingerElapsed = lingerElapsed + elapsed

                                                                                                                                                                                                                                                                if lingerElapsed >= (OUT_OF_COMBAT_LINGER + FADE_DURATION) then
                                                                                                                                                                                                                                                                lingerActive = false
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                self:SetAlpha(1.0)
                                                                                                                                                                                                                                                                for i = 1, ABSOLUTE_MAX_ROWS do bars[i]:Hide() end
                                                                                                                                                                                                                                                                self:Hide()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                elseif lingerElapsed >= OUT_OF_COMBAT_LINGER then
                                                                                                                                                                                                                                                                local fadeProgress = (lingerElapsed - OUT_OF_COMBAT_LINGER) / FADE_DURATION
                                                                                                                                                                                                                                                                self:SetAlpha(math.max(0, 1.0 - fadeProgress))
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                self:SetAlpha(1.0)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if not inCombat then return end

                                                                                                                                                                                                                                                                timeSinceLast = timeSinceLast + elapsed
                                                                                                                                                                                                                                                                if timeSinceLast >= UPDATE_INTERVAL then
                                                                                                                                                                                                                                                                timeSinceLast = 0
                                                                                                                                                                                                                                                                SafeUpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                -- Slash Commands (/fthreat, /ftm, /foreverthreat)
                                                                                                                                                                                                                                                                -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                                SLASH_FOREVERTHREAT1 = "/fthreat"
                                                                                                                                                                                                                                                                SLASH_FOREVERTHREAT2 = "/ftm"
                                                                                                                                                                                                                                                                SLASH_FOREVERTHREAT3 = "/foreverthreat"
                                                                                                                                                                                                                                                                SlashCmdList["FOREVERTHREAT"] = function(msg)
                                                                                                                                                                                                                                                                msg = (msg or ""):lower():match("^%s*(.-)%s*$")
                                                                                                                                                                                                                                                                local cmd, arg = msg:match("^(%S+)%s*(%S*)$")

                                                                                                                                                                                                                                                                if cmd == "unlock" or cmd == "move" then
                                                                                                                                                                                                                                                                local currentLocked = ForeverThreatDB and ForeverThreatDB.locked
                                                                                                                                                                                                                                                                SetFrameLocked(not currentLocked)
                                                                                                                                                                                                                                                                if lockSettingRef and lockSettingRef.SetValue then
                                                                                                                                                                                                                                                                lockSettingRef:SetValue(ForeverThreatDB.locked)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Frame " .. (ForeverThreatDB.locked and "locked." or "unlocked for moving."))
                                                                                                                                                                                                                                                                elseif cmd == "lock" then
                                                                                                                                                                                                                                                                SetFrameLocked(true)
                                                                                                                                                                                                                                                                if lockSettingRef and lockSettingRef.SetValue then
                                                                                                                                                                                                                                                                lockSettingRef:SetValue(true)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Frame locked.")
                                                                                                                                                                                                                                                                elseif cmd == "reset" or cmd == "clear" then
                                                                                                                                                                                                                                                                ResetCumulativeThreat("manual /ftm reset")
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Cumulative dungeon threat cleared.")
                                                                                                                                                                                                                                                                elseif cmd == "timeout" then
                                                                                                                                                                                                                                                                local num = tonumber(arg)
                                                                                                                                                                                                                                                                if num and (num == 0 or num == 60 or num == 90 or num == 120) then
                                                                                                                                                                                                                                                                ForeverThreatDB.dungeonIdleTimeout = num
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Dungeon idle reset timeout set to " .. (num == 0 and "Never (manual reset only)." or (num .. "s.")))
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Usage: /ftm timeout 60 | 90 | 120 | 0")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif cmd == "errors" or cmd == "log" or cmd == "debug" then
                                                                                                                                                                                                                                                                ShowLogDumpWindow(false)
                                                                                                                                                                                                                                                                elseif cmd == "rows" then
                                                                                                                                                                                                                                                                local num = tonumber(arg)
                                                                                                                                                                                                                                                                if num and (num == 5 or num == 8 or num == 10) then
                                                                                                                                                                                                                                                                ForeverThreatDB.maxRows = num
                                                                                                                                                                                                                                                                UpdateFrameDimensions()
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Max rows set to " .. num .. ".")
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Usage: /ftm rows 5 | 8 | 10")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif cmd == "test" then
                                                                                                                                                                                                                                                                TriggerTimedPreview(5)
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Showing test preview for 5 seconds.")
                                                                                                                                                                                                                                                                elseif cmd == "opt" or cmd == "options" or cmd == "config" then
                                                                                                                                                                                                                                                                SetFrameLocked(false)
                                                                                                                                                                                                                                                                if lockSettingRef and lockSettingRef.SetValue then
                                                                                                                                                                                                                                                                lockSettingRef:SetValue(false)
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                if settingsCategory and Settings.OpenToCategory then
                                                                                                                                                                                                                                                                Settings.OpenToCategory(settingsCategory:GetID())
                                                                                                                                                                                                                                                                elseif SettingsPanel and SettingsPanel.Open then
                                                                                                                                                                                                                                                                SettingsPanel:Open()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat Commands:|r")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm unlock|r         - Toggle frame unlock to reposition")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm lock|r           - Lock frame in place")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm reset|r          - Clear accumulated dungeon threat")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm timeout [60|90|120|0]|r - Set dungeon idle reset delay")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm errors|r         - Open error & debug log dump window")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm rows [5|8|10]|r    - Set maximum visible row count")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm test|r           - Show sample preview bars for 5s")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm opt|r            - Open options panel (and unlocks frame)")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

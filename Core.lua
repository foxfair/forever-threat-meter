local addonName, ns = ...
local f = CreateFrame("Frame", "ForeverThreatFrame", UIParent)

local PLAYER_BAR_HEIGHT = 18
local PET_BAR_HEIGHT = 14
local BAR_WIDTH = 190
local PET_BAR_WIDTH = 176
local ABSOLUTE_MAX_ROWS = 10

local bars = {}
local isUnlocked = false
local timeSinceLast = 0
local UPDATE_INTERVAL = 0.15
local settingsCategory = nil

-- Combat Exit Linger & Fade Engine
local OUT_OF_COMBAT_LINGER = 12.0  -- Stay fully visible for 12s
local FADE_DURATION = 3.0          -- Fade smoothly over 3s (Total: 15s)
local lingerActive = false
local lingerElapsed = 0

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

    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetColorTexture(0.08, 0.08, 0.08, 0.75)

    -- Unit Name
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
                        if not inCombat and (ForeverThreatDB and ForeverThreatDB.locked) and not lingerActive then
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
                                f:Show()
                                dragOverlay:Show()
                                dragTitle:Show()
                                ShowTestPreview()
                                else
                                    dragOverlay:Hide()
                                    dragTitle:Hide()
                                    for i = 1, ABSOLUTE_MAX_ROWS do bars[i]:Hide() end
                                        local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
                                        if not inCombat and not lingerActive then
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

                                                                                    local function ApplySafeBarColor(bar, unit, isPet)
                                                                                    if isPet then
                                                                                        bar:SetStatusBarColor(0.75, 0.55, 0.25)
                                                                                        else
                                                                                            local _, classToken = UnitClass(unit)
                                                                                            local color = classToken and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken]
                                                                                            if color then
                                                                                                bar:SetStatusBarColor(color.r, color.g, color.b)
                                                                                                else
                                                                                                    bar:SetStatusBarColor(0.8, 0.2, 0.2)
                                                                                                    end
                                                                                                    end
                                                                                                    end

                                                                                                    -- ----------------------------------------------------------------------------
                                                                                                    -- Main Display Refresh
                                                                                                    -- ----------------------------------------------------------------------------
                                                                                                    local function UpdateThreatDisplay()
                                                                                                    if ForeverThreatDB and not ForeverThreatDB.locked then return end

                                                                                                        local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))

                                                                                                        -- While in post-combat linger, do not clear the existing display on dead/dropped target
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

                                                                                                                        local currentMaxRows = GetMaxRows()
                                                                                                                        local unitsToWatch = {"player", "pet", "targettarget"}

                                                                                                                        local numGroup = GetNumGroupMembers()
                                                                                                                        if IsInRaid() and numGroup > 0 then
                                                                                                                            for i = 1, numGroup do
                                                                                                                                table.insert(unitsToWatch, "raid" .. i)
                                                                                                                                table.insert(unitsToWatch, "raidpet" .. i)
                                                                                                                                end
                                                                                                                                elseif IsInGroup() and numGroup > 0 then
                                                                                                                                    for i = 1, numGroup do
                                                                                                                                        table.insert(unitsToWatch, "party" .. i)
                                                                                                                                        table.insert(unitsToWatch, "partypet" .. i)
                                                                                                                                        end
                                                                                                                                        end

                                                                                                                                        local collectedData = {}
                                                                                                                                        local evaluatedUnits = {}

                                                                                                                                        for _, unit in ipairs(unitsToWatch) do
                                                                                                                                            if UnitExists(unit) then
                                                                                                                                                local alreadyEvaluated = false
                                                                                                                                                for _, prevUnit in ipairs(evaluatedUnits) do
                                                                                                                                                    if UnitIsUnit(unit, prevUnit) then
                                                                                                                                                        alreadyEvaluated = true
                                                                                                                                                        break
                                                                                                                                                        end
                                                                                                                                                        end

                                                                                                                                                        if not alreadyEvaluated then
                                                                                                                                                            table.insert(evaluatedUnits, unit)

                                                                                                                                                            local isTanking, _, scaledPct = UnitDetailedThreatSituation(unit, "target")

                                                                                                                                                            if not scaledPct then
                                                                                                                                                                local status = UnitThreatSituation(unit, "target")
                                                                                                                                                                if status then
                                                                                                                                                                    scaledPct = 100
                                                                                                                                                                    elseif UnitIsUnit("targettarget", unit) then
                                                                                                                                                                        scaledPct = 100
                                                                                                                                                                        isTanking = true
                                                                                                                                                                        end
                                                                                                                                                                        end

                                                                                                                                                                        if scaledPct then
                                                                                                                                                                            local isPet = (GetPetOwnerUnit(unit) ~= nil)
                                                                                                                                                                            local isCurrentTarget = UnitIsUnit("targettarget", unit) or (isTanking == true)

                                                                                                                                                                            local sortWeight = 0
                                                                                                                                                                            if isCurrentTarget then
                                                                                                                                                                                sortWeight = 1000
                                                                                                                                                                                elseif isPet then
                                                                                                                                                                                    sortWeight = 100
                                                                                                                                                                                    else
                                                                                                                                                                                        sortWeight = 200
                                                                                                                                                                                        end

                                                                                                                                                                                        table.insert(collectedData, {
                                                                                                                                                                                            unit = unit,
                                                                                                                                                                                            isPet = isPet,
                                                                                                                                                                                            scaledPct = scaledPct,
                                                                                                                                                                                            sortWeight = sortWeight,
                                                                                                                                                                                        })
                                                                                                                                                                                        end
                                                                                                                                                                                        end
                                                                                                                                                                                        end
                                                                                                                                                                                        end

                                                                                                                                                                                        if #collectedData == 0 then
                                                                                                                                                                                            if not lingerActive then
                                                                                                                                                                                                f:Hide()
                                                                                                                                                                                                end
                                                                                                                                                                                                return
                                                                                                                                                                                                end

                                                                                                                                                                                                table.sort(collectedData, function(a, b)
                                                                                                                                                                                                if a.sortWeight ~= b.sortWeight then
                                                                                                                                                                                                    return a.sortWeight > b.sortWeight
                                                                                                                                                                                                    end
                                                                                                                                                                                                    return false
                                                                                                                                                                                                    end)

                                                                                                                                                                                                -- 9+1 Self-Pinning
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
                                                                                                                                                                                                                                    bar.nameText:SetText(FormatUnitLabel(entry.unit))
                                                                                                                                                                                                                                    bar:SetValue(entry.scaledPct)
                                                                                                                                                                                                                                    ApplySafeBarColor(bar, entry.unit, entry.isPet)
                                                                                                                                                                                                                                    end

                                                                                                                                                                                                                                    for i = renderCount + 1, ABSOLUTE_MAX_ROWS do
                                                                                                                                                                                                                                        bars[i]:Hide()
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
                                                                                                                                                                                                                                            type(true),
                                                                                                                                                                                                                                                                "Lock Threat Meter",
                                                                                                                                                                                                                                                                true,
                                                                                                                                                                                                                                                                GetLockValue,
                                                                                                                                                                                                                                                                SetLockValue
                                                                                                                                                                                                                                        )

                                                                                                                                                                                                                                        Settings.CreateCheckbox(category, lockSetting, "When checked, the threat frame is locked and hidden outside of combat. Uncheck to move and reposition.")

                                                                                                                                                                                                                                        -- 2. 3-Way Max Rows Dropdown Selection (5, 8, 10)
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

                                                                                                                                                                                                                                                -- 3. Test Preview Button
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

                                                                                                                                                                                                                                                        f:SetScript("OnEvent", function(self, event, unit)
                                                                                                                                                                                                                                                        if event == "ADDON_LOADED" and unit == addonName then
                                                                                                                                                                                                                                                            if not ForeverThreatDB then
                                                                                                                                                                                                                                                                ForeverThreatDB = {
                                                                                                                                                                                                                                                                locked = true,
                                                                                                                                                                                                                                                                maxRows = 10,
                                                                                                                                                                                                                                                                point = "CENTER",
                                                                                                                                                                                                                                                                relativePoint = "CENTER",
                                                                                                                                                                                                                                                                x = 250,
                                                                                                                                                                                                                                                                y = -50,
                                                                                                                                                                                                                                                                }
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if ForeverThreatDB.locked == nil then
                                                                                                                                                                                                                                                                ForeverThreatDB.locked = true
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                if ForeverThreatDB.maxRows == nil then
                                                                                                                                                                                                                                                                ForeverThreatDB.maxRows = 10
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                UpdateFrameDimensions()

                                                                                                                                                                                                                                                                if ForeverThreatDB.x and ForeverThreatDB.y then
                                                                                                                                                                                                                                                                f:ClearAllPoints()
                                                                                                                                                                                                                                                                f:SetPoint(ForeverThreatDB.point or "CENTER", UIParent, ForeverThreatDB.relativePoint or "CENTER", ForeverThreatDB.x, ForeverThreatDB.y)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                RegisterSettingsMenu()

                                                                                                                                                                                                                                                                local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
                                                                                                                                                                                                                                                                or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
                                                                                                                                                                                                                                                                or "1.3.2"
                                                                                                                                                                                                                                                                print(string.format("|cff00ccffForeverThreat|r v%s loaded. Type |cff00ff00/ftm|r or |cff00ff00/fthreat|r for commands.", version))

                                                                                                                                                                                                                                                                elseif event == "PLAYER_REGEN_DISABLED" then
                                                                                                                                                                                                                                                                -- New fight begins: immediately reset linger and restore full opacity
                                                                                                                                                                                                                                                                lingerActive = false
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                f:SetAlpha(1.0)
                                                                                                                                                                                                                                                                UpdateThreatDisplay()

                                                                                                                                                                                                                                                                elseif event == "PLAYER_REGEN_ENABLED" then
                                                                                                                                                                                                                                                                -- Fight finished: activate 15-second linger loop
                                                                                                                                                                                                                                                                local wasVisible = f:IsShown()
                                                                                                                                                                                                                                                                if wasVisible and (ForeverThreatDB and ForeverThreatDB.locked) then
                                                                                                                                                                                                                                                                lingerActive = true
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                f:SetAlpha(1.0)
                                                                                                                                                                                                                                                                end

                                                                                                                                                                                                                                                                elseif event == "PLAYER_TARGET_CHANGED" then
                                                                                                                                                                                                                                                                UpdateThreatDisplay()
                                                                                                                                                                                                                                                                elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
                                                                                                                                                                                                                                                                if unit == "target" or unit == "player" or unit == "pet" then
                                                                                                                                                                                                                                                                UpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif event == "UNIT_PET" then
                                                                                                                                                                                                                                                                if unit == "player" then
                                                                                                                                                                                                                                                                UpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                elseif event == "UNIT_FLAGS" then
                                                                                                                                                                                                                                                                if unit == "player" or unit == "pet" then
                                                                                                                                                                                                                                                                UpdateThreatDisplay()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end)

                                                                                                                                                                                                                                                        -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                        -- Update Ticker & Smooth Linger Fade
                                                                                                                                                                                                                                                        -- ----------------------------------------------------------------------------
                                                                                                                                                                                                                                                        f:SetScript("OnUpdate", function(self, elapsed)
                                                                                                                                                                                                                                                        if ForeverThreatDB and not ForeverThreatDB.locked then return end

                                                                                                                                                                                                                                                            local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))

                                                                                                                                                                                                                                                            -- 1. Handle Out-of-Combat Linger and Fade
                                                                                                                                                                                                                                                            if lingerActive and not inCombat then
                                                                                                                                                                                                                                                                lingerElapsed = lingerElapsed + elapsed

                                                                                                                                                                                                                                                                if lingerElapsed >= (OUT_OF_COMBAT_LINGER + FADE_DURATION) then
                                                                                                                                                                                                                                                                -- Full 15 seconds elapsed: clean hide and reset
                                                                                                                                                                                                                                                                lingerActive = false
                                                                                                                                                                                                                                                                lingerElapsed = 0
                                                                                                                                                                                                                                                                self:SetAlpha(1.0)
                                                                                                                                                                                                                                                                for i = 1, ABSOLUTE_MAX_ROWS do bars[i]:Hide() end
                                                                                                                                                                                                                                                                self:Hide()
                                                                                                                                                                                                                                                                return
                                                                                                                                                                                                                                                                elseif lingerElapsed >= OUT_OF_COMBAT_LINGER then
                                                                                                                                                                                                                                                                -- In the final 3-second fade window (12s - 15s)
                                                                                                                                                                                                                                                        local fadeProgress = (lingerElapsed - OUT_OF_COMBAT_LINGER) / FADE_DURATION
                                                                                                                                                                                                                                                        self:SetAlpha(math.max(0, 1.0 - fadeProgress))
                                                                                                                                                                                                                                                        else
                                                                                                                                                                                                                                                            -- First 12 seconds: stay solid
                                                                                                                                                                                                                                                            self:SetAlpha(1.0)
                                                                                                                                                                                                                                                            end
                                                                                                                                                                                                                                                            return
                                                                                                                                                                                                                                                            end

                                                                                                                                                                                                                                                            -- 2. Regular In-Combat Refresh
                                                                                                                                                                                                                                                            if not inCombat then return end

                                                                                                                                                                                                                                                                timeSinceLast = timeSinceLast + elapsed
                                                                                                                                                                                                                                                                if timeSinceLast >= UPDATE_INTERVAL then
                                                                                                                                                                                                                                                                timeSinceLast = 0
                                                                                                                                                                                                                                                                UpdateThreatDisplay()
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
                                                                                                                                                                                                                                                            print("|cff00ccffForeverThreat:|r Frame " .. (ForeverThreatDB.locked and "locked." or "unlocked for moving."))
                                                                                                                                                                                                                                                            elseif cmd == "lock" then
                                                                                                                                                                                                                                                                SetFrameLocked(true)
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat:|r Frame locked.")
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
                                                                                                                                                                                                                                                                if settingsCategory and Settings.OpenToCategory then
                                                                                                                                                                                                                                                                Settings.OpenToCategory(settingsCategory:GetID())
                                                                                                                                                                                                                                                                elseif SettingsPanel and SettingsPanel.Open then
                                                                                                                                                                                                                                                                SettingsPanel:Open()
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                else
                                                                                                                                                                                                                                                                print("|cff00ccffForeverThreat Commands:|r")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm unlock|r      - Toggle frame unlock to reposition")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm lock|r        - Lock frame in place")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm rows [5|8|10]|r - Set maximum visible row count")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm test|r        - Show sample preview bars for 5s")
                                                                                                                                                                                                                                                                print("  |cff00ff00/ftm opt|r         - Open the options settings panel")
                                                                                                                                                                                                                                                                end
                                                                                                                                                                                                                                                                end

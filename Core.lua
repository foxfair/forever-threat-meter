local addonName, ns = ...
local f = CreateFrame("Frame", "ForeverThreatFrame", UIParent)

local PLAYER_BAR_HEIGHT = 18
local PET_BAR_HEIGHT = 14
local BAR_WIDTH = 190
local PET_BAR_WIDTH = 176
local MAX_ROWS = 6

local bars = {}
local isUnlocked = false
local timeSinceLast = 0
local UPDATE_INTERVAL = 0.15

-- ----------------------------------------------------------------------------
-- Frame Construction, Hitbox & Drag Overlay
-- ----------------------------------------------------------------------------
f:SetSize(BAR_WIDTH, (PLAYER_BAR_HEIGHT + 2) * MAX_ROWS)
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

for i = 1, MAX_ROWS do
    bars[i] = CreateBar(i)
    end

    -- ----------------------------------------------------------------------------
    -- Test Bar Preview Engine
    -- ----------------------------------------------------------------------------
    local function ShowTestPreview()
    local testSamples = {
        { name = "MainTank (Warrior)", isPet = false, pct = 100, r = 0.78, g = 0.61, b = 0.43 },
        { name = "Pet: Wolf",          isPet = true,  pct = 82,  r = 0.75, g = 0.55, b = 0.25 },
        { name = "MageDPS",            isPet = false, pct = 74,  r = 0.41, g = 0.80, b = 0.94 },
    }

    local yOfs = 0
    for i = 1, #testSamples do
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

                for i = #testSamples + 1, MAX_ROWS do bars[i]:Hide() end
                    end

                    local function TriggerTimedPreview(seconds)
                    f:Show()
                    ShowTestPreview()

                    C_Timer.After(seconds or 5, function()
                    local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
                    if not inCombat and (ForeverThreatDB and ForeverThreatDB.locked) then
                        for i = 1, MAX_ROWS do bars[i]:Hide() end
                            f:Hide()
                            end
                            end)
                    end

                    local function SetFrameLocked(locked)
                    if not ForeverThreatDB then ForeverThreatDB = {} end
                        ForeverThreatDB.locked = locked

                        if not locked then
                            f:Show()
                            dragOverlay:Show()
                            dragTitle:Show()
                            ShowTestPreview()
                            else
                                dragOverlay:Hide()
                                dragTitle:Hide()
                                for i = 1, MAX_ROWS do bars[i]:Hide() end
                                    local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
                                    if not inCombat then
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
                                                                                    bar:SetStatusBarColor(0.75, 0.55, 0.25) -- Muted amber
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

                                                                                                    if not UnitExists("target") or UnitIsDead("target") or UnitIsFriend("player", "target") then
                                                                                                        f:Hide()
                                                                                                        return
                                                                                                        end

                                                                                                        -- Check if combat is active on player or pet
                                                                                                        local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
                                                                                                        if not inCombat then
                                                                                                            f:Hide()
                                                                                                            return
                                                                                                            end

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

                                                                                                                            local rowIndex = 1
                                                                                                                            local currentYOffset = 0
                                                                                                                            local evaluatedUnits = {}

                                                                                                                            for _, unit in ipairs(unitsToWatch) do
                                                                                                                                if rowIndex > MAX_ROWS then break end

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

                                                                                                                                                    -- 1. Try Group API first
                                                                                                                                                    local _, _, scaledPct = UnitDetailedThreatSituation(unit, "target")

                                                                                                                                                    -- 2. Solo Fallback: If group API returns nil, query UnitThreatSituation or direct aggro
                                                                                                                                                    if not scaledPct then
                                                                                                                                                        local status = UnitThreatSituation(unit, "target")
                                                                                                                                                        if status then
                                                                                                                                                            -- Pass through a fallback value
                                                                                                                                                            scaledPct = (status >= 2) and 100 or 50
                                                                                                                                                            elseif UnitIsUnit("targettarget", unit) then
                                                                                                                                                                -- If the mob is actively hitting this unit, it holds 100% threat
                                                                                                                                                                scaledPct = 100
                                                                                                                                                                end
                                                                                                                                                                end

                                                                                                                                                                if scaledPct then
                                                                                                                                                                    f:Show()
                                                                                                                                                                    local bar = bars[rowIndex]
                                                                                                                                                                    local isPet = (GetPetOwnerUnit(unit) ~= nil)

                                                                                                                                                                    bar:ClearAllPoints()

                                                                                                                                                                    if isPet then
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
                                                                                                                                                                            bar.nameText:SetText(FormatUnitLabel(unit))

                                                                                                                                                                            bar:SetValue(scaledPct)
                                                                                                                                                                            ApplySafeBarColor(bar, unit, isPet)

                                                                                                                                                                            rowIndex = rowIndex + 1
                                                                                                                                                                            end
                                                                                                                                                                            end
                                                                                                                                                                            end
                                                                                                                                                                            end

                                                                                                                                                                            if rowIndex == 1 then
                                                                                                                                                                                f:Hide()
                                                                                                                                                                                else
                                                                                                                                                                                    for i = rowIndex, MAX_ROWS do
                                                                                                                                                                                        bars[i]:Hide()
                                                                                                                                                                                        end
                                                                                                                                                                                        end
                                                                                                                                                                                        end

                                                                                                                                                                                        -- ----------------------------------------------------------------------------
                                                                                                                                                                                        -- Options Menu Integration (Modern Settings API)
                                                                                                                                                                                        -- ----------------------------------------------------------------------------
                                                                                                                                                                                        local function RegisterSettingsMenu()
                                                                                                                                                                                        local category, layout = Settings.RegisterVerticalLayoutCategory("ForeverThreat")

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

                                                                                                                                                                                        -- 2. Test Preview Button
                                                                                                                                                                                        local buttonName = "Test Preview (5s)"
                                                                                                                                                                                        local buttonText = "Show Test Preview"
                                                                                                                                                                                        local onClick = function()
                                                                                                                                                                                        TriggerTimedPreview(5)
                                                                                                                                                                                        end
                                                                                                                                                                                        local tooltip = "Temporarily renders sample threat bars for 5 seconds to test visibility and placement."

                                                                                                                                                                                        if layout and layout.AddInitializer then
                                                                                                                                                                                            local initializer = CreateSettingsButtonInitializer(buttonName, buttonText, onClick, tooltip)
                                                                                                                                                                                            layout:AddInitializer(initializer)
                                                                                                                                                                                            elseif Settings.CreateButton then
                                                                                                                                                                                                Settings.CreateButton(category, buttonName, buttonText, onClick, tooltip)
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
                                                                                                                                                                                                            point = "CENTER",
                                                                                                                                                                                                            relativePoint = "CENTER",
                                                                                                                                                                                                            x = 250,
                                                                                                                                                                                                            y = -50,
                                                                                                                                                                                                        }
                                                                                                                                                                                                        end

                                                                                                                                                                                                        if ForeverThreatDB.locked == nil then
                                                                                                                                                                                                            ForeverThreatDB.locked = true
                                                                                                                                                                                                            end

                                                                                                                                                                                                            if ForeverThreatDB.x and ForeverThreatDB.y then
                                                                                                                                                                                                                f:ClearAllPoints()
                                                                                                                                                                                                                f:SetPoint(ForeverThreatDB.point or "CENTER", UIParent, ForeverThreatDB.relativePoint or "CENTER", ForeverThreatDB.x, ForeverThreatDB.y)
                                                                                                                                                                                                                end

                                                                                                                                                                                                                RegisterSettingsMenu()

                                                                                                                                                                                                                local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
                                                                                                                                                                                                                or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
                                                                                                                                                                                                                or "1.2.0"
                                                                                                                                                                                                                print(string.format("|cff00ccffForeverThreat|r v%s loaded. Type |cff00ff00/ftm|r or |cff00ff00/fthreat|r for commands.", version))

                                                                                                                                                                                                                elseif event == "PLAYER_REGEN_DISABLED" then
                                                                                                                                                                                                                    UpdateThreatDisplay()
                                                                                                                                                                                                                    elseif event == "PLAYER_REGEN_ENABLED" then
                                                                                                                                                                                                                        if ForeverThreatDB and ForeverThreatDB.locked then
                                                                                                                                                                                                                            self:Hide()
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

                                                                                                                                                                                                f:SetScript("OnUpdate", function(self, elapsed)
                                                                                                                                                                                                if ForeverThreatDB and not ForeverThreatDB.locked then return end

                                                                                                                                                                                                    local inCombat = UnitAffectingCombat("player") or (UnitExists("pet") and UnitAffectingCombat("pet"))
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

                                                                                                                                                                                                if msg == "unlock" or msg == "move" then
                                                                                                                                                                                                    local currentLocked = ForeverThreatDB and ForeverThreatDB.locked
                                                                                                                                                                                                    SetFrameLocked(not currentLocked)
                                                                                                                                                                                                    print("|cff00ccffForeverThreat:|r Frame " .. (ForeverThreatDB.locked and "locked." or "unlocked for moving."))
                                                                                                                                                                                                    elseif msg == "lock" then
                                                                                                                                                                                                        SetFrameLocked(true)
                                                                                                                                                                                                        print("|cff00ccffForeverThreat:|r Frame locked.")
                                                                                                                                                                                                        elseif msg == "test" then
                                                                                                                                                                                                            TriggerTimedPreview(5)
                                                                                                                                                                                                            print("|cff00ccffForeverThreat:|r Showing test preview for 5 seconds.")
                                                                                                                                                                                                            elseif msg == "opt" or msg == "options" or msg == "config" then
                                                                                                                                                                                                                Settings.OpenToCategory("ForeverThreat")
                                                                                                                                                                                                                else
                                                                                                                                                                                                                    print("|cff00ccffForeverThreat Commands:|r")
                                                                                                                                                                                                                    print("  |cff00ff00/ftm unlock|r  - Toggle frame unlock to reposition")
                                                                                                                                                                                                                    print("  |cff00ff00/ftm lock|r    - Lock frame in place")
                                                                                                                                                                                                                    print("  |cff00ff00/ftm test|r    - Show sample preview bars for 5s")
                                                                                                                                                                                                                    print("  |cff00ff00/ftm opt|r     - Open the options settings panel")
                                                                                                                                                                                                                    end
                                                                                                                                                                                                                    end

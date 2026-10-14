std = "lua51"

-- Ignore unused arguments and unused loop variables
unused_args = false

-- Add WoW-specific globals so they are not flagged as undefined
globals = {
    "CreateFrame",
    "UIParent",
    "UnitName",
    "UnitClass",
    "UnitExists",
    "UnitIsDead",
    "UnitIsFriend",
    "UnitIsUnit",
    "UnitAffectingCombat",
    "UnitDetailedThreatSituation",
    "UnitThreatSituation",
    "GetNumGroupMembers",
    "IsInRaid",
    "IsInGroup",
    "Settings",
    "SettingsPanel",
    "C_Timer",
    "C_AddOns",
    "GetAddOnMetadata",
    "CUSTOM_CLASS_COLORS",
    "RAID_CLASS_COLORS",
    "ForeverThreatDB",
    "SLASH_FOREVERTHREAT1",
    "SLASH_FOREVERTHREAT2",
    "SLASH_FOREVERTHREAT3",
    "SlashCmdList",
    "print",
}

-- Ignore warning codes:
-- 211: Unused local variable
-- 212: Unused argument
-- 113: Accessing undefined global (fallback)
ignore = { "211", "212" }

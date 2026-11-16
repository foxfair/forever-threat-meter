# ForeverThreat

A lightweight, taint-safe combat threat meter built specifically for **World of Warcraft: Forever** (`1.60.1`, Interface `16001`).

ForeverThreat provides clean, low-overhead threat visibility across solo play, 5-player dungeons, and 10-/20-player raids while avoiding combat UI taint by relying exclusively on safe scaled threat percentages (`UnitDetailedThreatSituation` / `UnitThreatSituation`) rather than arithmetic on restricted combat values.

---

## Key Features

* **Taint-Safe Threat Engine:** Evaluates threat using safe scaled percentages with protected `pcall` / `xpcall` execution to prevent combat taint and Lua error loops.
* **9+1 Self-Pinning Row Layout:** Displays top threat holders in descending order while always pinning your own character to the bottom slot if you fall outside the top visible rows.
* **Pet Subordination:** Automatically indents and styles player and party/raid pets (`Pet: <Name>` / `<Owner>'s <Pet>`) beneath standard player bars.
* **Dual Display Modes:**
  * **Solo / Small Group Mode:** Shows real-time target threat during combat, holds the display for 12 seconds after leaving combat, and smoothly fades out over 3 seconds (15 seconds total linger).
  * **Dungeon & 5+ Player Cumulative Mode:** Automatically activates inside party/raid instances or groups of 5+ players. Accumulates every player's threat contribution across consecutive chain pulls without wiping when targets die, resetting automatically only after an extended out-of-combat break (default **90 seconds**) or via `/ftm reset`.
* **Native Blizzard Settings Integration:** Configure frame lock state, visible row presets (`5`, `8`, or `10`), dungeon idle reset timeout (`60s`, `90s`, `120s`, or `Never`), and a 5-second test preview directly from **Options > AddOns > ForeverThreat**.
* **Built-In Diagnostic & Error Dump Window:** Captures runtime stack traces and timestamped debug events in `SavedVariables` with a circuit-breaker throttle and a scrollable copy-paste window (`/ftm errors`).

---

## Installation

1. Download the latest `ForeverThreat-vX.X.X.zip` release from [CurseForge](https://www.curseforge.com/wow/addons/forever-threat-meter) or [GitHub Releases](https://github.com/foxfair/forever-threat-meter/releases).
2. Extract the `ForeverThreat` folder into your WoW Forever AddOns directory:
   ```text
   <WoW_Forever_Directory>/_classic_/Interface/AddOns/ForeverThreat

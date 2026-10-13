# ForeverThreat

**ForeverThreat** is a lightweight, zero-bloat, taint-safe combat threat meter developed specifically for the **WoW Forever** engine (Interface `16001` / modern 12.x architecture). 

Designed to operate seamlessly within modern client security constraints, ForeverThreat provides real-time, high-contrast threat tracking without triggering restricted secret-value Lua comparisons or action button execution taint.

---

## Features

- **Secrecy & Taint Compliant:** Pipes native threat values directly to C-side status bar widgets, completely avoiding arithmetic taint and secret-value comparison crashes during combat.
- **Smart Pet & Companion Handling:** 
  - Subordinated visual styling for pets (indented, dimmed alpha, distinct typography).
  - Accurate name resolution (`Pet: [Name]` or `[Owner]'s [Pet]`).
  - Full support for Hunter pets, Warlock minions, and Shaman elementals.
- **Solo Play Fallback:** Resolves the standard Blizzard API limitation where group threat queries return `nil` when soloing in the open world.
- **Native Blizzard Settings Integration:** Configurable directly via the in-game interface menu (`Game Menu > Options > AddOns > ForeverThreat`).
- **Drag & Repositioning:** Built-in lock toggle and visible movement overlay with automatic coordinate persistence (`ForeverThreatDB`).
- **Interactive 5-Second Test Preview:** Test frame positioning, fonts, and bar appearance at any time out of combat.

---

## Slash Commands

You can control ForeverThreat using `/ftm`, `/fthreat`, or `/foreverthreat`:

| Command | Description |
| :--- | :--- |
| `/ftm` | Display command help in chat |
| `/ftm unlock` | Unlock the frame to drag and reposition |
| `/ftm lock` | Lock the frame in its current position |
| `/ftm test` | Trigger a 5-second sample preview (Tank, Pet, DPS) |
| `/ftm opt` | Open the Blizzard Settings options panel |

*(Note: `/ft` was released to prevent keybind/alias collisions with FlightTimer).*

---

## Installation

1. Download `ForeverThreat-v1.2.0.zip`.
2. Extract the archive into your World of Warcraft directory:
   ```text
   World of Warcraft/_retail_/Interface/AddOns/

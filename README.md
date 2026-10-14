# ForeverThreat

**ForeverThreat** is a lightweight, zero-bloat, taint-safe combat threat meter developed specifically for the **WoW Forever** engine (Interface `16001` / modern 12.x architecture).

Built to operate strictly within modern client security constraints, ForeverThreat provides real-time, high-contrast threat tracking across solo, party, and raid encounters without triggering restricted secret-value Lua errors or combat UI execution taint.

---

## Why ForeverThreat? (Pros & Trade-offs)

Most legacy threat meters (such as Omen, ClassicThreatMeter, or older ThreatClassic2 forks) rely on legacy combat log parsing or arithmetic comparisons on threat metrics. On the modern 12.x engine, reading and comparing protected combat values inside execution paths can trigger client halts, action button taint, or secret-value Lua crashes. 

ForeverThreat was engineered specifically around these modern engine restrictions.

### Why You Should Use This Addon (Pros)
* **Zero Combat Execution Taint:** Threat values pass straight from native Blizzard C-APIs into status bar widgets without intermediary arithmetic or secret-value comparisons. Keybinds, mouse look, and action buttons will never break during high-APM encounters.
* **Smart Companion Subordination:** Hunter pets, Warlock minions, and group guardians display with dedicated visual subordination (dimmed opacity, indented rows, and owner attribution like `[Owner]'s [Pet]`), preventing pet taunts from obscuring player aggro priorities.
* **Always-Visible Self-Pinning (9 + 1 Layout):** Even when tracking larger groups, your personal threat bar is pinned to the bottom slot if you fall below the top-ranked rows. You will never drop off the meter.
* **Solo & Guardian Fallback:** Resolves the standard engine bug where group threat calls return `nil` when soloing or when fighting alongside untracked summons (e.g., Shaman Earth Elementals).
* **15-Second Post-Combat Review:** Avoids the frustration of meters vanishing the millisecond a mob dies. Combat data lingers for 15 seconds after `PLAYER_REGEN_ENABLED` (or until a new pull begins).
* **Negligible Footprint:** Completely standalone under 500 lines of clean Lua. No Ace3 libraries, LibSharedMedia, or background network communication sync overhead.

### Design Trade-offs (Cons / What It Doesn't Do)
* **Relative Percentages Only:** Displays scaled threat percentages (`scaledPct`) rather than absolute numbers (e.g., `1.4M raw threat`), adhering to modern engine restrictions against converting secret combat values to plain text.
* **Target-Centric Only:** Focuses exclusively on your current hostile target (`target`). It does not track multi-target AoE threat across all off-target nameplates simultaneously.
* **Curated Layout Options:** Offers streamlined 5-, 8-, and 10-row presets to preserve screen real estate rather than expansive

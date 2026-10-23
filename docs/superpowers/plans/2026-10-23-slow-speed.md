# Slower Simulation Speed Plan

**Goal:** Add a 0.5× observation speed alongside the existing 1× and 2× speeds.

**Architecture:** Extend the accepted speed values and update the existing cycle button. The frame loop already applies `state.speed` to elapsed simulation time; the save serializer/restorer already stores it.

**Files:** `index.html`, `README.md`.

**Review focus:** Cycle is 1× → 2× → 0.5× → 1×; saved 0.5× restores correctly; legacy 1×/2× save values remain accepted; visible and accessible speed labels agree; no other time or action logic changes; no automated tests.

- [x] Update the speed options, current cycle, accessibility label, and README.
- [x] Inspect save validation and frame integration; run static diff/syntax checks only.
- [ ] Commit, obtain a fresh scoped review, publish, and verify the live response.

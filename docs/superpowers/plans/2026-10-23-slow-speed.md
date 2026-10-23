# Slower Simulation Speed Plan

**Goal:** Add a 0.5× observation speed alongside the existing 1× and 2× speeds.

**Architecture:** Extend the accepted speed values and update the existing cycle button. The frame loop already applies `state.speed` to elapsed simulation time; the save serializer/restorer already stores it.

**Files:** `index.html`, `README.md`.

**Review focus:** Cycle is 1× → 2× → 0.5× → 1×; saved 0.5× restores correctly; legacy 1×/2× save values remain accepted; visible and accessible speed labels agree; no other time or action logic changes; no automated tests.

- [x] Update the speed options, current cycle, accessibility label, and README.
- [x] Inspect save validation and frame integration; run static diff/syntax checks only.
- [x] Commit, obtain a fresh scoped review, publish, and verify the live response.

## Publication record

- Implementation commit: `a444e197294885af3a2d15d9c95b3036ce3c28db`.
- Fresh read-only review of `a6a6adfc2a7266d7e811a59d76130845c99345e9..a444e197294885af3a2d15d9c95b3036ce3c28db`: no Critical, Important, or Minor issues; approved to publish.
- Static checks: staged `git diff --cached --check` and `node --check` on the extracted inline script passed. No automated tests were added or run.
- Pages workflow `39970673560` succeeded. Cache-busted response `?v=a444e1972948` returned HTTP 200 with the 0.5× option, three-speed cycle, save validation, and dynamic accessible label.

# Point Guidance Countdown Plan

**Goal:** Show how many in-game seconds of Point guidance remain in the Choice signals summary.

**Architecture:** Extend the existing guidance summary in `renderDecisionSignals` using `Math.ceil(state.guidance.remaining)`. Keep the existing target and independent-choice wording, scoring, timer, and save shape unchanged.

**Files:** `index.html`, `README.md`.

**Review focus:** Countdown appears only for active guidance on the inspected Norn; it uses in-game seconds and rounds an active fraction up; other Norns/expired guidance keep their existing summaries; no new live announcements, simulation behavior, or save data; no automated tests.

- [x] Add the remaining-time cue and explain the seven-second guidance duration in README.
- [x] Inspect selection, speed/pause, and guidance timer refresh; run static diff/syntax checks only.
- [ ] Commit, obtain a fresh scoped review, publish, and verify the live response.

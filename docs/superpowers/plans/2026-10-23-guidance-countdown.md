# Point Guidance Countdown Plan

**Goal:** Show how many in-game seconds of Point guidance remain in the Choice signals summary.

**Architecture:** Extend the existing guidance summary in `renderDecisionSignals` using `Math.ceil(state.guidance.remaining)`. Keep the existing target and independent-choice wording, scoring, timer, and save shape unchanged.

**Files:** `index.html`, `README.md`.

**Review focus:** Countdown appears only for active guidance on the inspected Norn; it uses in-game seconds and rounds an active fraction up; other Norns/expired guidance keep their existing summaries; no new live announcements, simulation behavior, or save data; no automated tests.

- [x] Add the remaining-time cue and explain the seven-second guidance duration in README.
- [x] Inspect selection, speed/pause, and guidance timer refresh; run static diff/syntax checks only.
- [x] Commit, obtain a fresh scoped review, publish, and verify the live response.

## Publication record

- Final implementation commit: `15cd2af57f10ed72621189e3104aae2bc4caed35`.
- Fresh read-only re-review of `000900e95afa65d225a7d76851f212b4b2ecd2e0..15cd2af57f10ed72621189e3104aae2bc4caed35` found no Critical, Important, or Minor issues and approved publication. The initial review's singular/plural finding was corrected before publishing.
- Static checks after the copy fix: `git diff --cached --check` and `node --check` on the extracted inline script passed. No automated tests were added or run.
- Pages workflow `39971283803` succeeded. Cache-busted response `?v=15cd2af57f10` returned HTTP 200 with the active-guidance guard, rounded countdown, correct singular/plural unit, preserved independent choice, and no live-region marking.

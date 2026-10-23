# Sociability Help Clarification Plan

**Goal:** Align the Sociability helper with the success, speech, and player-feedback events already gated by that trait.

**Architecture:** Update the existing helper paragraph and matching README description. Keep its current `aria-describedby` relationship and all simulation behavior unchanged.

**Files:** `index.html`, `README.md`.

**Review focus:** Copy is accurate to existing observation gates; no runtime, persistence, or accessibility wiring changes; no automated tests.

- [x] Update the notebook helper and README with concise, consistent wording.
- [x] Inspect the observation gates and run diff/syntax checks; do not add or run automated tests.
- [x] Commit, obtain a fresh scoped review, publish, and verify the live response.

## Publication record

- Implementation commit: `733bf8e5024d16ab736a4a4a4dbd14d840904a20`.
- Fresh read-only review of `c24f16807497ab6fad921eecc31c865293ab2863..733bf8e5024d16ab736a4a4dbd14d840904a20`: no Critical, Important, or Minor issues; approved to publish.
- Static checks: `git diff --cached --check` and `node --check` on the extracted inline script passed. No automated tests were added or run.
- Pages workflow `39970037056` succeeded. Cache-busted response `?v=733bf8e5024d16ab` returned HTTP 200 and contained the concrete “fruit”/“spinner” wording, Praise/Scold explanation, and existing Sociability description wiring.

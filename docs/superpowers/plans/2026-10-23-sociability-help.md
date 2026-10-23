# Sociability Help Clarification Plan

**Goal:** Align the Sociability helper with the success, speech, and player-feedback events already gated by that trait.

**Architecture:** Update the existing helper paragraph and matching README description. Keep its current `aria-describedby` relationship and all simulation behavior unchanged.

**Files:** `index.html`, `README.md`.

**Review focus:** Copy is accurate to existing observation gates; no runtime, persistence, or accessibility wiring changes; no automated tests.

- [ ] Update the notebook helper and README with concise, consistent wording.
- [ ] Inspect the observation gates and run diff/syntax checks; do not add or run automated tests.
- [ ] Commit, obtain a fresh scoped review, publish, and verify the live response.

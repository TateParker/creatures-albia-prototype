# Feedback at Association Limits Plan

**Goal:** Make direct Praise/Scold feedback explain when clamping prevents a further association change.

**Architecture:** Compare each selected Norn's association before and after the existing ±0.2 clamped update, then use one outcome description consistently in its reason, journal event, memory, and toast.

**Files:** `index.html`, `README.md`.

**Review focus:** Changed-value messages remain accurate; max/min messages say no further change occurred; feedback eligibility, event links, memories, social observation, RNG, save shape, and learning amounts remain unchanged; no automated tests.

- [x] Make Praise and Scold explanations conditional on whether the clamped value changed.
- [x] Document the bounded association feedback and inspect all resulting text; run static diff/syntax checks only.
- [ ] Commit, obtain a fresh scoped review, publish, and verify the live response.

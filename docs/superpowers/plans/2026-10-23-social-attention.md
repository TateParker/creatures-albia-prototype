# Trait-Weighted Social Attention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a nearby Norn's validated sociability value control the chance that it learns from another Norn's success.

**Architecture:** Keep the shared attention gate in `shareObservation` before both existing learning paths. Use the existing seeded random source and sociability value directly, and document the effect in the README; no save fields or UI are needed.

**Tech Stack:** Standalone HTML, inline JavaScript, CSS, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-10-23-social-attention-design.md`

## Global Constraints

- Sociability is validated in the inclusive range 0–1 and directly represents observation probability.
- One gate applies to both word hearing and behavior imitation.
- Existing self/range checks, learning amounts, cooldown, events, and memory explanations remain unchanged.
- Do not add or run automated tests.
- Keep the prototype local-first, inspectable, and free of LLM/network behavior.

## Review Focus

- Boundary traits 0 and 1 mean no observation and guaranteed eligible observation respectively; the probability comparison must reflect both boundaries.
- The actor and observers beyond 330 pixels must be excluded before the probability roll.
- A single successful roll must gate both word learning and behavior imitation, with no second observation roll in either path.
- Existing saves remain compatible because no persisted field is added; account for the changed RNG draw sequence.
- README language should describe the probability without implying that distant Norns can observe or learn.

---

### Task 1: Apply trait-weighted attention to social observation

**Files:**
- Modify: `index.html` — shared observer eligibility and learning gate in `shareObservation`.
- Modify: `README.md` — explain that sociability affects nearby attention.
- Modify: `docs/superpowers/specs/2026-10-23-social-attention-design.md` only if implementation reveals a necessary specification correction.

**Interfaces:**
- Consumes: `state.rng(): number`, `observer.traits.sociability: number` validated in `[0, 1]`.
- Produces: a single probabilistic gate before existing word and behavior learning.

- [x] **Step 1: Inspect the final diff against the five review-focus conditions.** Confirm the actor/range checks precede the roll, `>=` rejects zero and accepts a roll below one for trait 1, and there is exactly one roll before both learning paths.
- [x] **Step 2: Replace the threshold condition in `index.html`.** For each eligible observer, continue when `state.rng() >= observer.traits.sociability`; do not change learning math, cooldown, or event text.
- [x] **Step 3: Update `README.md`.** State that nearby observation and learning chance depends on the observing Norn's sociability.
- [x] **Step 4: Run static verification.** Run `git diff --check` and extract the inline script from `index.html` to a temporary file under `.superpowers/sdd/2026-10-23-social-attention/`; run `node --check` on that script. Expected: both exit successfully with no whitespace or JavaScript syntax errors. Do not add or run automated tests.
- [x] **Step 5: Commit the implementation and documentation.** Commit `e7a6746` (`Make social observation trait weighted`).
- [x] Obtain a read-only scoped review of `f2b20c9..e7a6746`. It found no Critical, Important, or Minor issues and approved publication; the reviewer confirmed the probability boundaries, shared gate, unchanged save shape, and preserved learning behavior.
- [x] Published to `origin/main` at `3089d0c`. GitHub Pages workflow [39934327229](https://github.com/TateParker/creatures-albia-prototype/actions/runs/39934327229) succeeded for this head. A cache-busted live HTTP 200 contained the direct probability gate; GitHub's `main` README API returned the updated explanation (README is not copied into the Pages artifact).

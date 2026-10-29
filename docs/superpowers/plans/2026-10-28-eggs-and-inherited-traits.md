# Eggs and Inherited Traits Implementation Plan

> Keep the task checkboxes current. Preserve the existing uncommitted teaching and command work.

**Goal:** Add eggs, incubation, inherited traits, and child Norns to the local simulation.

**Architecture:** Add a bounded family panel, a small egg state model advanced by simulation time, and a child constructor that inherits curiosity and sociability with seeded variation. Expand schema validation and restoration for dynamic Norns while retaining schema-1 and schema-2 compatibility.

**Tech Stack:** Existing single-file HTML/CSS/JavaScript app and local browser storage; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-28-eggs-and-inherited-traits-design.md`

## Constraints

- Preserve the uncommitted typed teaching, push-to-talk, and command changes.
- Keep the maximum population at four Norns plus incubating eggs combined.
- Incubation is 45 in-game seconds and follows pause/speed.
- Child trait values are the parents' average plus a small seeded variation, clamped to `[0.05, 0.95]`.
- Children inherit no learned words, behavior associations, or memories.
- Keep schema 1 and 2 save loading intact; schema 3 stores dynamic family state.
- Do not add or run automated tests. Perform source review and `git diff --check` only.

## Task 1: Add family controls and bounded egg creation

**Files:** `index.html`

- [x] Add accessible family controls to choose a second parent and start an egg with the selected Norn.
- [x] Disable egg creation when two distinct parents are unavailable or the population limit is reached.
- [x] Store the egg's child identity, parents, blended palette, inherited trait values, and incubation time.
- [x] Record the family event and parent memories.

## Task 2: Hatch young Norns and render eggs

**Files:** `index.html`

- [x] Draw a nest, incubating eggs, and progress indicators in the habitat.
- [x] Advance incubation with simulation time and stop it while paused.
- [x] Hatch eggs into active, selectable Norns with fresh needs and blank learning state.
- [x] Render dynamic child names, generation, parentage, and speech bubble stacking for up to four Norns.

## Task 3: Migrate and validate saves

**Files:** `index.html`

- [x] Write schema-3 snapshots with dynamic Norn identity, ancestry, colors, eggs, and the next child number.
- [x] Validate population counts, identity formats, palettes, ancestry, egg parents, and hatch timers before restore.
- [x] Preserve schema-1 and schema-2 restore behavior by supplying the original fixed Norn identities and no family state.
- [x] Ensure hatching and egg creation trigger autosave and exported snapshots include the same family state.

## Task 4: Document and review

**Files:** `README.md`, this plan, and `.superpowers/sdd/2026-10-28-eggs-and-inherited-traits/progress.md`

- [x] Explain egg controls, incubation timing, the population cap, and inheritance boundaries in README.
- [x] Review family creation, hatch flow, and all save-version paths manually.
- [x] Run `git diff --check`; do not run automated tests.

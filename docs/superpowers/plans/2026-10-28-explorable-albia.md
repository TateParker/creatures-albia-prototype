# Explorable Albia Implementation Plan

> Preserve the existing uncommitted teaching, command, and family work.

**Goal:** Turn the current single screen into a scrollable three-region habitat.

**Architecture:** Separate the 960-unit camera viewport from the 2880-unit simulation world. Translate world rendering by a transient camera offset, map pointer input back into world coordinates, and retain the current Norn/object simulation rules. Bump saves to schema 4 for expanded positions while preserving schemas 1–3.

**Tech Stack:** Existing single-file HTML/CSS/JavaScript app and local browser storage; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-28-explorable-albia-design.md`

## Constraints

- Keep three 960-unit regions and a 960-unit viewport.
- Camera follows the selected Norn until the player scrolls manually; selecting a Norn or activating guidance resumes follow.
- Keep existing fruit/spinner needs and learning rules; distribute the resources so the Norns travel across regions.
- Camera position is transient. Schema 4 validates world positions up to the new map bounds; schemas 1–3 retain their historical 865-unit limit.
- Do not add or run automated tests. Perform source review and `git diff --check` only.

## Task 1: Add navigation controls and camera state

**Files:** `index.html`

- [x] Add accessible west/east and follow-selected controls plus a live region label.
- [x] Implement camera follow and manual region navigation.
- [x] Re-center on the selected Norn after selection, guidance, and restore.

## Task 2: Draw and interact with the wide world

**Files:** `index.html`

- [x] Separate `WORLD_WIDTH` from `VIEW_WIDTH` and render the three named regions with distinct palettes and landmarks.
- [x] Apply camera translation to scene drawing while keeping prompts and pause overlay viewport-relative.
- [x] Map clicks and object hit testing through the camera offset.
- [x] Place the spinner in Glassfall Hollow and update movement bounds for the wider world.

## Task 3: Preserve save compatibility

**Files:** `index.html`

- [x] Write schema-4 snapshots and accept schemas 1–4.
- [x] Validate schema-4 Norn positions against the wider map and keep schema-1/2/3 bounds unchanged.
- [x] Restore family state and center the transient camera on the selected Norn.

## Task 4: Document and review

**Files:** `README.md`, this plan, and `.superpowers/sdd/2026-10-28-explorable-albia/progress.md`

- [x] Document the regions, navigation, camera-follow behavior, and longer Norn journeys.
- [x] Review viewport transforms, coordinate conversions, movement bounds, and schema paths manually.
- [x] Run `git diff --check`; do not run automated tests.

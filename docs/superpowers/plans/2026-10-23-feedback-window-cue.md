# Feedback Window Cue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the selected Norn's recent action and the remaining Praise/Scold window directly beside the feedback controls.

**Architecture:** Derive the displayed status from the selected Norn's existing `lastSuccess` and `state.time` during `renderUI()`. Attach the existing help element as the accessible description for Praise and Scold; do not create state or change the feedback handlers.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-feedback-window-cue-design.md`

## Global Constraints

- Keep the standalone static HTML build and local simulation.
- Do not add or run automated tests under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

## Review Focus

- No success, expired success, and already-responded success produce a clear wait state.
- A recent unanswered food or toy success identifies the correct Norn and action.
- Remaining time never displays zero while the existing feedback handler still accepts the response.
- Pause and simulation speed are reflected through `state.time`, not wall-clock time.
- Switching the selected Norn switches the cue to that Norn's `lastSuccess`.
- Feedback eligibility, one-response behavior, save shape, and learning amounts remain unchanged.
- The changing help is not an aria-live region and is referenced by both controls.

---

### Task 1: Contextual Praise/Scold window

**Files:**
- Modify: `index.html`

**Interfaces:**
- Consumes: `renderUI()`, selected Norn, `lastSuccess`, `OBJECTS`, and `state.time`.
- Produces: selected-Norn feedback-window copy using the existing help element and control descriptions.

- [x] Bind the feedback help element in the existing UI map and give both controls its description.
- [x] Derive waiting, expired, responded, and active-countdown copy from `lastSuccess` and simulation time.
- [x] Keep the countdown at least one while the current feedback guard still accepts a response; allow pause and speed to follow automatically.
- [x] Inspect the unchanged feedback handlers and save serializer to confirm the cue changes no behavior or persisted fields.
- [x] Run `git diff --check` and `node --check` against the extracted inline script. Do not add or run automated tests.
- [x] Commit implementation/docs, obtain a fresh scoped review, then publish and verify the Pages response.

**Check:** Static source inspection, `git diff --check`, inline-script syntax validation, fresh scoped review, successful Pages workflow, and cache-busted HTTP verification.

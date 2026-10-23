# Reset Confirmation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require an explicit confirmation before Reset discards progress or replaces the saved grove.

**Architecture:** Ask through `window.confirm` in the existing Reset click handler; invoke the unchanged `resetSimulation()` only when confirmed. Document the prompt's effect.

**Tech Stack:** Existing self-contained HTML and JavaScript; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-reset-confirmation-design.md`

## Global Constraints

- Preserve the existing lock, save comparison, reset routine, and conflict behavior.
- Do not add or run automated tests under the standing user instruction.
- Keep the prototype local-first and dependency-free.

## Review Focus

- Confirm starts the same reset routine that the existing button invokes.
- Cancel does not change in-memory or persisted state and does not show a reset result toast.
- The confirmation accurately describes memory-only and browser-saved progress.

---

### Task 1: Confirm before resetting

**Files:**
- Modify: `index.html` Reset click handler.
- Modify: `README.md` Reset help.

**Interfaces:**
- Consumes: the existing `resetSimulation()` function and Reset button.
- Produces: a confirmed path to existing reset behavior and a cancel path with no mutation.

- [x] Add `window.confirm` to the Reset button handler; call `resetSimulation()` only when it returns true.
- [x] Clarify in README that Reset asks before replacing the current/saved grove.
- [x] Inspect confirm and cancel paths. Run `git diff --check` and `node --check` on the extracted inline script; do not add or run automated tests.
- [x] Commit the verified implementation.

### Task 2: Review and publish

**Files:**
- Review: `index.html`, `README.md`, and the design/plan files.

**Interfaces:**
- Consumes: Task 1 implementation commit and static-check evidence.
- Produces: a fresh scoped review, successful Pages deployment, and live-response verification.

- [x] Obtain a fresh read-only review; resolve any Critical or Important finding before publishing.
- [x] Push the reviewed implementation and confirm the Pages workflow succeeds.
- [x] Verify the published response includes the confirmation guard before the reset call.
- [x] Record completion in the plan ledger and local handoff.

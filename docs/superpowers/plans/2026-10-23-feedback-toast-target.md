# Feedback Toast Target Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Praise and Scold toasts identify which learned object association changed or reached its limit.

**Architecture:** Reuse the existing grounded `objectLabel` and changed/capped outcome branches in each feedback handler. Update the help documentation to describe the more specific toast. This is presentation-only and adds no state.

**Tech Stack:** Existing self-contained HTML, CSS, and JavaScript; no new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-feedback-toast-target-design.md`

## Global Constraints

- Keep feedback eligibility, learning amounts, journal, memories, social observation, RNG, save fields, and decision formulas unchanged.
- Do not add or run automated tests under the standing user instruction.
- Keep the prototype local-first and inspectable.

## Review Focus

- Both changed and capped Praise toasts name the selected object and match the journal/reason outcome.
- Both changed and capped Scold toasts name the selected object and match the journal/reason outcome.
- No feedback action, saved data, or observer behavior changes with the copy update.

---

### Task 1: Name the affected association in feedback toasts

**Files:**
- Modify: `index.html` Praise and Scold `showToast` calls.
- Modify: `README.md` feedback instructions.

**Interfaces:**
- Consumes: existing `objectLabel` and `changed` values from both feedback handlers.
- Produces: immediate feedback text naming the object and its changed or capped outcome.

- [x] Update Praise/Scold toast strings to include `objectLabel` in both outcome branches; keep their existing changed/capped meaning.
- [x] Update README’s feedback instruction to mention that the immediate confirmation names the affected object association.
- [x] Inspect all four toast outcomes. Run `git diff --check` and `node --check` on the extracted inline script; do not add or run automated tests.
- [x] Commit the verified implementation.

### Task 2: Review and publish

**Files:**
- Review: `index.html`, `README.md`, and the design/plan files.

**Interfaces:**
- Consumes: Task 1 implementation commit and its verification.
- Produces: a scoped review record, successful Pages deployment, and cache-busted live response verification.

- [x] Obtain a fresh read-only review of the base-to-head change; resolve any Critical or Important finding before publishing.
- [x] Push the reviewed implementation and confirm the Pages workflow succeeds.
- [x] Verify the live response includes all four object-labelled toast outcomes and the existing observer call.
- [x] Record completion and deployment evidence in the local handoff and plan ledger.

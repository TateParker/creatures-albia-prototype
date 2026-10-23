# Learning Feedback Timing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Praise and Scold controls easy to find and explain their current timing window.

**Architecture:** Add a named, responsive group around the two existing buttons and a visible description linked with `aria-describedby`. Keep handlers and simulation rules unchanged; update the play instructions to match the current 12-second rule.

**Tech Stack:** Standalone HTML, CSS, inline JavaScript, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-10-23-feedback-timing-design.md`

## Global Constraints

- Preserve the existing 12 in-game second feedback window and one response per success.
- Keep Praise and Scold keyboard-accessible native buttons.
- Add no persisted state or simulation logic.
- Do not add or run automated tests.

## Review Focus

- The group and timing hint remain visible, understandable, and wrapped at narrow widths.
- Both buttons remain in the same group and retain their original handlers and labels.
- The copy states one response within 12 in-game seconds after a meal or play; it does not promise the action is currently eligible.
- Praise and Scold amounts, event records, memories, and save shape remain unchanged.

---

### Task 1: Clarify and group learning feedback

**Files:**
- Modify: `index.html` — feedback group markup and responsive styling.
- Modify: `README.md` — clarify timing and one-response behavior.
- Modify: `docs/superpowers/specs/2026-10-23-feedback-timing-design.md` — record design.

**Interfaces:**
- Keep existing `applyPraise()` and `applyScold()` behavior and button IDs.

- [x] **Step 1: Label the controls.** Wrap the existing Praise and Scold buttons in a `role="group"` named “Learning feedback”; link a visible timing description through `aria-describedby`. Add wrapping styles that fit the current toolbar and narrow layout.
- [x] **Step 2: Align play guidance.** Update README to say one response may be given within 12 in-game seconds after eating or playing.
- [x] **Step 3: Verify the source.** Run `git diff --check` and `node --check` on the extracted inline script. Inspect the exact diff for unchanged handler wiring and responsive wrapping. Do not add or run automated tests.
- [ ] **Step 4: Commit, request a scoped read-only review, publish only if clear, and verify Pages plus a cache-busted live response.**

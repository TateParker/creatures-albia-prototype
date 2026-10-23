# Accessibility Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let keyboard users target fruit and the spinner and keep Norn speech readable on narrow screens.

**Architecture:** Add two semantic buttons that share the existing Point/Teach object behavior with canvas clicks. Size the existing canvas speech bubbles from responsive CSS scale so their text and box have fixed minimum screen dimensions.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript canvas; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-accessibility-polish-design.md`

## Global Constraints

- Preserve the static, self-contained browser build and add no network calls or dependencies.
- Keep current learning, Point/Teach, simulation, and persistence rules unchanged except for equivalent keyboard object activation.
- Provide a visible keyboard focus indicator and accessible descriptions for object targets.
- Do not add or run automated tests under the standing session constraint; use static inspection, syntax checks, and deployment verification.

## Review Focus

- Mismatched Teach object: must retain existing mismatch feedback and award no word confidence.
- Pointing mode: clicking a scene object or activating its matching button must set the same guidance and journal event.
- No active mode: activating a target button must clearly and consistently point to its object.
- Keyboard focus: both targets must be reachable and visibly focused in the existing page flow.
- Narrow scene: speech font and bubble dimensions must remain at their specified CSS-pixel minimums without changing speech lifetime or object coordinates.

---

### Task 1: Accessible habitat targets and readable speech

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Add a labeled `Habitat objects` group with native buttons for `fruit` and `spinner`.
- Add a shared object activation helper that teaches when Teach mode is active and otherwise points the selected Norn to the requested object.
- Keep `handleCanvasClick(event)` selecting Norns outside Point/Teach modes and use the shared helper when a scene object is activated in either mode.
- Pass responsive canvas scale into Norn speech drawing; maintain at least 14 CSS-pixel speech text and 76-by-32 CSS-pixel bubbles.

- [x] Add the accessible object button group, dynamic help copy, and README guidance for keyboard object targeting.
- [x] Route button and canvas object activations through shared Point/Teach behavior without changing mismatch handling.
- [x] Scale speech text and bubble geometry to CSS-pixel minimums while preserving the animated world position; stagger simultaneous bubbles.
- [x] Inspect keyboard labels/focus, mismatch and Point branches, responsive speech calculations, and unchanged persistence behavior.
- [x] Run `git diff --check` and `node --check` on the extracted inline script; do not run automated tests.
- [ ] Commit the slice, request a scoped code review, publish after a clean review, and verify the Pages workflow and live response.

**Check:** Static source review; `git diff --check`; inline script syntax check; successful Pages workflow and cache-busted response containing the target controls and responsive speech sizing.

The user authorized continued prototype and accessibility improvements during the remaining work window. No automated tests were added or run.

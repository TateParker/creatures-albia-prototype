# Sociability Inspector Explanation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Explain the Sociability percentage in the Norn inspector and expose inherited trait bars as accessible meters.

**Architecture:** Add a visible helper line below Inherited tendencies and pass its ID to the Sociability trait renderer. Give both existing trait bars named 0–100 meter semantics without changing their appearance or simulation values.

**Tech Stack:** Standalone HTML, CSS, inline JavaScript, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-10-23-sociability-explainer-design.md`

## Global Constraints

- Keep the Sociability and Curiosity names and displayed percentages unchanged.
- The Sociability help text must be visible and linked to its meter with `aria-describedby`.
- Trait meters use min 0, max 100, and current rounded percentage.
- Do not change simulation behavior or persisted state.
- Do not add or run automated tests.

## Review Focus

- A selected Sociability meter references an existing help element; Curiosity does not incorrectly reference social-help text.
- Both meter values remain within the declared 0–100 range and match the visible rounded percentage.
- Helper text remains readable on narrow layouts using existing wrapping and inspector width.
- The meter markup adds no form control semantics, persistence fields, or simulation changes.
- README's existing explanation remains accurate and the new UI phrasing agrees with it.

---

### Task 1: Explain Sociability beside the inspector meters

**Files:**
- Modify: `index.html` — inherited tendency help and meter semantics in `renderTrait`.

**Interfaces:**
- Consumes: `renderTrait(label, value)` and the existing `#traits` inspector container.
- Produces: named 0–100 meters; Sociability references the visible help copy by ID.

- [x] **Step 1: Add visible inspector help.** Place a short `p` with ID `sociabilityHelp` directly under **Inherited tendencies** and before `#traits`; explain that Sociability is the chance to notice a nearby Norn's success.
- [x] **Step 2: Add accessible meter semantics in `renderTrait`.** Set role `meter`, aria-label to the trait label, min `0`, max `100`, current to the same rounded percent displayed, and value text to that percent. Accept an optional description ID and set `aria-describedby` only when supplied.
- [x] **Step 3: Associate only Sociability with the helper.** Pass `sociabilityHelp` for the Sociability render call; leave Curiosity unassociated.
- [x] **Step 4: Inspect the final diff against the five review-focus conditions; run `git diff --check` and `node --check` on the extracted inline script.** Expected: no whitespace or JavaScript syntax errors, and the helper/ARIA references are correct. Do not add or run automated tests.
- [ ] **Step 5: Commit as `Explain sociability in inspector`, obtain a scoped read-only review, publish the approved change, and verify the Pages workflow and cache-busted page response.**

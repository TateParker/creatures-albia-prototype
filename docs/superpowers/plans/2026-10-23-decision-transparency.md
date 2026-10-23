# Decision Transparency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the live factors behind each Norn's existing fruit-versus-spinner choice.

**Architecture:** Factor the current scoring formula and thresholds into a shared read-only helper. Render a compact notebook card from that result and its component contributions.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript canvas; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-decision-transparency-design.md`

## Global Constraints

- Preserve the self-contained static browser build and make no network calls.
- Keep decision formulas, thresholds, tie behavior, guidance, timing, learning, and persistence unchanged.
- Do not add or run automated tests under the standing session constraint; use static inspection, syntax checks, and deployment verification.

## Review Focus

- Score parity: the UI and `chooseTarget` must use one helper with the exact existing formulas, thresholds, and spinner-on-tie rule.
- Player guidance: show guidance only for the Norn it targets, and preserve the seven-second override.
- Settled drives: report no autonomous target only when both original thresholds are crossed.
- Save compatibility: add no persisted state or schema change.
- Accessibility: expose labels, scores, components, and meter values without relying on color alone.

---

### Task 1: Share decision scores with the notebook

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Produce a read-only decision score result containing `fruitNeed`, `fruitHabit`, `fruitScore`, `spinnerNeed`, `spinnerHabit`, `spinnerScore`, and `targetId`.
- Use the result in both `chooseTarget(norn)` and the selected Norn's choice-signal renderer.

- [x] Factor the existing formulas, thresholds, and tie behavior into the shared helper without changing simulation choices.
- [x] Add a compact notebook card showing current preference/guidance and both score breakdowns with accessible meter labels and values.
- [x] Document the new choice-signal display in README.
- [x] Inspect selector/display parity, guidance, thresholds, responsive styles, and unchanged persistence fields; run `git diff --check` and `node --check` on the extracted inline script. Do not run automated tests.
- [x] Commit the implementation as `957be11`; inline-script syntax validation and staged diff whitespace checks passed.
- [ ] Request scoped review; publish only after a clear review, then verify the Pages workflow and a cache-busted live response.

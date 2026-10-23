# Journal History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let players reveal the grove’s full retained journal without making the default page view longer.

**Architecture:** Add one native disclosure button below the recent-moments list. Keep expansion in transient UI state and rebuild journal DOM only when the event IDs or expansion state changes.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-journal-history-design.md`

## Global Constraints

- Preserve the standalone static HTML build.
- Do not change event creation, retention, ordering in storage, or persistence format.
- Do not add or run automated tests under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

## Review Focus

- Empty through three-event journal: empty copy or existing moments remain visible and no irrelevant toggle appears.
- Four through twelve events: the toggle reveals every retained moment in oldest-to-newest order and labels the count accurately.
- A new event arrives while expanded: the view stays expanded, count updates, and the 12-event cap is still reflected.
- Routine inspector refreshes with unchanged event IDs do not replace the live region or reset expansion.
- Keyboard activation updates visible content and the button’s expanded state and label.

---

### Task 1: Expandable recent-moments journal

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Consumes the existing `state.events` list (newest first, capped at 12) and `renderJournal()` renderer.
- Produces a native `#journalToggle` button with `aria-expanded`, plus transient `journalExpanded` rendering state.

- [x] Add the hidden-by-default “Show all moments” control beneath the event list and a compact style for it.
- [x] Keep the newest three visible by default; when expanded, render all retained moments in chronological reading order.
- [x] Show the toggle only when there are more than three moments; keep its text, visibility, and `aria-expanded` in sync.
- [x] Skip DOM reconstruction when the event-ID sequence and expanded state are unchanged.
- [x] Update README to describe revealing the retained journal, then inspect empty, collapsed, expanded, and changing-event paths in source.
- [x] Run `git diff --check` and `node --check` against the extracted inline script. Do not add or run automated tests.
- [ ] Commit the implementation, README, plan, and spec; retain the SDD ledger in the ignored plan workspace.

**Check:** Static source review, `git diff --check`, inline-script syntax validation, a fresh scoped code review, successful Pages workflow, and cache-busted HTTP verification.

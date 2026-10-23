# Memory Traceability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let players trace a remembered Norn moment to its retained journal event.

**Architecture:** Render a native action with each memory whose source event is still retained. Its handler expands the journal and focuses the deterministic event item. Memoize memory rendering by memory content and source availability to preserve button focus during routine inspector refreshes.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-memory-traceability-design.md`

## Global Constraints

- Keep the standalone static HTML build.
- No changes to saved data, event or memory limits, or learning rules.
- Do not add or run automated tests under the standing session instruction; verify through source inspection, JavaScript syntax validation, diff checks, review, and deployment.

## Review Focus

- Memory source still retained: one native, clearly named button finds the event; memory source missing: text remains and the button is absent.
- Collapsed journal: activation expands all retained events before locating the event.
- Expanded journal: activation keeps it expanded and focuses the matching item.
- A new event while a memory button is focused does not discard focus unless that memory's content or source availability actually changes.
- A new event while a journal item is focused preserves focus on that item when it remains retained in the expanded history.
- Event focus uses a stable ID and does not add every journal card to sequential keyboard navigation.

---

### Task 1: Trace memories to recent events

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Consumes memory `eventId` values, `state.events`, `renderJournal()`, and the existing `journalExpanded` state.
- Produces event items with IDs `journal-event-<id>`, `showMemoryEvent(eventId)`, and memoized memory rendering.

- [x] Give each journal event a deterministic ID and programmatic focus target; style its focused state visibly.
- [x] Render a labeled “Find in journal” button when a memory's event remains retained; preserve plain memory text otherwise.
- [x] On activation, expand/render the journal, scroll the matching event into view, and focus it.
- [x] Avoid recreating unchanged memory buttons during routine inspector refreshes; include source-retention state in the render key.
- [x] Update README and inspect both source-present and source-expired paths, collapsed and already-expanded navigation, and focus stability.
- [x] Run `git diff --check` and `node --check` against the extracted inline script. Do not add or run automated tests.
- [ ] Commit implementation/docs, obtain fresh scoped review, then publish and verify the Pages response.

**Check:** Static source review, `git diff --check`, inline-script syntax validation, a fresh scoped code review, successful Pages workflow, and cache-busted HTTP verification.

# Local Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a player's New Albia grove from a safe, versioned autosave stored in the current browser.

**Architecture:** Keep the self-contained `index.html` app and add serialization, validation, restore, and autosave helpers around its existing state object. Store JSON under one versioned localStorage key, rebuild runtime-only values during restore, and expose persistence status in the habitat UI. The README describes the local-only save boundary.

**Tech Stack:** Static HTML, CSS, vanilla JavaScript, browser localStorage.

**Spec:** `docs/superpowers/specs/2026-10-23-local-persistence-design.md`

## Global Constraints

- Preserve the self-contained static HTML prototype and its no-dependency setup.
- Store a single versioned record in browser `localStorage`.
- Do not silently replace malformed or newer-version saved data with a fresh run; report the issue and wait for the player's Reset action.
- Storage access or quota failures must not stop the in-memory simulation.
- A stale open tab must stop saving after another tab updates the shared grove.
- The session instruction prohibits adding or running automated tests; verify with source inspection, JavaScript syntax validation, and deployment checks.

## Review Focus

- Unsupported or malformed storage must not crash startup or get silently overwritten; inspect the version/validation branch and reset recovery path.
- Runtime-only values must work after restore; inspect reconstruction of `rng` and `observedEventIds`.
- Player learning must survive reload; inspect serializer coverage for needs, learned values, vocabulary, memories, events, and recent feedback state.
- Reset must clear the saved run as well as in-memory progress; inspect the key removal, fresh-state path, and user-facing copy.
- Private-mode or quota failures must leave simulation interactions usable; inspect all storage access behind error handling and the visible status branch.
- A second tab must not silently overwrite a newer save; inspect tab identity, storage event handling, and the stale-tab write guard.

---

### Task 1: Add a validated save format and restore path

**Files:**
- Modify: `index.html`

**Interfaces:**
- Add `SAVE_KEY`, `SAVE_SCHEMA_VERSION`, a serializer, a schema validator, and a restore helper.
- Extend the seeded RNG with a getter/setter for its current unsigned state.
- Reconstruct Norns and runtime-only values from a validated snapshot.

- [x] Save the mutable simulation fields, including Norn learning, vocabulary, memories, journal, feedback window, and RNG state.
- [x] Rebuild `rng`, Norn palette colors, and `observedEventIds` on restore; clear Point/Teach modes.
- [x] Reject unsupported or malformed records without throwing or overwriting the stored value.

**Check:** Static review confirms every persisted field and runtime-only rehydration; `node --check` on the extracted inline script succeeds.

### Task 2: Autosave and expose storage status

**Files:**
- Modify: `index.html`

**Interfaces:**
- Add a save-status element near the habitat clock and a small visual treatment for saved, saving, and unavailable states.
- Run a bounded periodic save while the world advances and save immediately after journal events, page hiding, or page exit.

- [x] Restore a valid save before the first render and show a concise restored/saved status.
- [x] Autosave active simulation progress periodically and flush after important changes and page visibility transitions.
- [x] Keep animation and interaction running when localStorage reads or writes fail.

**Check:** Source review confirms first-render restoration, bounded write frequency, and a caught failure path for each storage operation.

### Task 3: Reset semantics, documentation, and publish

**Files:**
- Modify: `index.html`
- Modify: `README.md`

- [x] Make Reset clear the saved run and begin the canonical initial grove; provide clear accessible status copy.
- [x] Explain that progress saves only in this browser and that clearing site data removes it.
- [x] Review corrupted/newer save handling, failure paths, learning preservation, and reset behavior.
- [ ] Commit the feature, push `main`, and confirm the Pages workflow and served page include the persistence status.

**Check:** `git diff --check`, `node --check` on the extracted inline script, GitHub Actions Pages result, and a cache-busted HTTP response containing the persistence status element.

# Save Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player download the current in-memory grove as a portable JSON file.

**Architecture:** Add a native button near the save status and serialize `getSaveSnapshot(observedSaveRevision)` from the existing state. Create a temporary Blob URL and download link, then clean both up without invoking or modifying the autosave path.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-save-export-design.md`

## Global Constraints

- Keep the standalone static HTML build and local simulation.
- Do not add or run automated tests under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

## Review Focus

- Export represents the current tab's in-memory simulation, including unsaved changes.
- Export does not call `saveNow`, mutate `localStorage`, advance revisions, or change simulation state.
- Download remains available when autosave is unavailable or blocked.
- File is valid JSON from the existing schema and filename contains a safe timestamp.
- Temporary anchor and object URL are cleaned up; errors use a clear status toast.
- Native button has a clear accessible name and works through its click handler.
- Existing autosave locking/conflict behavior remains unchanged.

---

### Task 1: Download the current run

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Consumes: `getSaveSnapshot(revision)`, `observedSaveRevision`, `ui`, `showToast`, `Blob`, and `URL.createObjectURL`.
- Produces: a user-initiated JSON download for the current tab's run.

- [x] Add an accessible **Download this run** button near the save status and bind it in the existing UI map.
- [x] Serialize the current snapshot to a timestamped JSON download and clean up the temporary URL/anchor.
- [x] Give success and preparation failures clear toast messages; keep export independent of autosave state.
- [x] Document the portable snapshot and the difference between browser autosave and a downloaded copy.
- [x] Inspect the save serializer and locking path to confirm export does not write storage, mutate revision, or alter simulation state.
- [x] Run `git diff --check` and `node --check` against the extracted inline script. Do not add or run automated tests.
- [x] Commit implementation/docs, obtain a fresh scoped review, then publish and verify the Pages response.

**Check:** Static source inspection, `git diff --check`, inline-script syntax validation, fresh scoped review, successful Pages workflow, and cache-busted HTTP verification.

## Publication record

- Implementation commit: `0068ebb34f4c438a6284965a473feb0f70707413`.
- Read-only scoped review of `2dcf35369ad305ad85b18bcfbed0d5d7096b24df..0068ebb34f4c438a6284965a473feb0f70707413`: no Critical, Important, or Minor findings; approved to publish.
- Static checks: `git diff --cached --check` and `node --check` on the extracted inline script passed. No automated tests were added or run.
- Pages workflow `39969190090` succeeded. Cache-busted response `?v=0068ebb34f4c438a` returned HTTP 200 and contained the button, current snapshot call, success toast, and timestamped JSON filename logic.

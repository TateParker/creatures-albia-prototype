# Save Export Design

## Intent

Let players keep a portable copy of the current local grove so they can inspect or back up the simulation without syncing it to a service.

## Goals and non-goals

- Add a visible, keyboard-operable **Download this run** button near the existing save status.
- Export a versioned JSON snapshot from the current in-memory state using the existing save serializer.
- Include unsaved changes in this tab's state; do not claim the download matches a newer run from another tab.
- Do not call the autosave path, mutate browser storage, change save revision, or alter simulation state.
- Announce successful or failed download preparation through the existing status toast.
- Do not add restore/import behavior or a remote service.

## Behavior

Activating the button serializes `getSaveSnapshot(observedSaveRevision)` into a JSON Blob, starts a user-initiated download with a timestamped filename, removes the temporary anchor, and releases the object URL. The export is a snapshot of this tab's current in-memory run, including progress not yet autosaved. Export remains available when autosave is unavailable or blocked because it does not write to local storage. The toast describes the file download and does not promise that a browser will complete a download it blocks.

The existing schema, validation, autosave, locking, conflict handling, and simulation remain unchanged.

## Constraints

- Keep the standalone static HTML build and local simulation.
- Do not add or run automated tests under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

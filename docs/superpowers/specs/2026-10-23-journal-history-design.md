# Journal History Design

## Intent

Let players inspect the full recent record of what happened in the grove, while keeping the initial page view compact.

## Goals and non-goals

- Keep the newest three moments visible by default.
- Add a keyboard-accessible control to reveal or collapse the full event history currently retained by the simulation (up to 12 moments).
- Keep moments in chronological reading order and keep the count accurate.
- Preserve the existing event cap, simulation behavior, and save schema.
- Do not add dependencies, network calls, or persisted interface state.

## Behavior

When more than three events are available, show a native button below the journal. It starts collapsed with “Show all N moments,” expands all retained events, and then reads “Show fewer moments.” The button exposes its state with `aria-expanded`. Fewer than four events need no toggle. New events update the count; an expanded journal stays expanded until the player collapses it. The visible order is oldest to newest within the currently shown events.

The renderer should avoid replacing unchanged journal content on every inspector refresh. A changed event-ID sequence or expanded state is sufficient to trigger a render because retained event text and timestamps are immutable.

## Constraints

- Keep the standalone static HTML build.
- Do not change event creation, retention, ordering in storage, or persistence format.
- Do not add or run automated tests under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

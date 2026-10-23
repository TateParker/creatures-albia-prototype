# Memory Traceability Design

## Intent

Let a player follow a Norn's remembered moment back to the journal entry that records what happened.

## Goals and non-goals

- Add a **Find in journal** action to a memory only while its source event remains in the retained recent history.
- When activated, reveal the full journal if needed, scroll to the source event, and move keyboard focus there.
- Keep a memory visible after its source event expires from the 12-event journal, while removing the unavailable action.
- Keep the journal and memory DOM stable across routine inspector refreshes when their content has not changed.
- Do not change learning, memory creation, event retention, simulation decisions, or persistence data.
- Do not add dependencies or network calls.

## Behavior

Each memory already stores its source `eventId`. If that ID is present in `state.events`, render a native “Find in journal” button beneath the memory. The button's accessible name identifies it as the journal destination for that memory. Activating it expands the journal, renders the retained event list, scrolls the matching item into view, and focuses the item. Event list items receive stable IDs and `tabindex="-1"` so they can be focused programmatically without joining the regular Tab sequence.

If an event falls out of the retained history, its memory remains as plain text and its button disappears. Cache a small content key for the rendered memories (including whether each source event is retained) so unchanged inspector refreshes do not recreate focused buttons. Keep event-list item IDs deterministic from event IDs and preserve the existing journal's own render guard. When a journal refresh replaces a focused event item, restore focus to that event if it remains in the expanded list.

## Constraints

- Keep the standalone static HTML build.
- No changes to saved data, event or memory limits, or learning rules.
- Do not add or run automated tests under the standing session instruction; verify through source inspection, JavaScript syntax validation, diff checks, review, and deployment.

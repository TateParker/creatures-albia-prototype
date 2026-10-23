# Local Persistence

## Intent

Let a player return to the same New Albia grove after closing or reloading the page, keeping the Norns' needs, behavior, learning, words, memories, and recent moments intact.

## Goals

- Restore the current simulation from one automatic save in the current browser profile.
- Preserve deterministic behavior by saving the random generator's current state as well as the original seed.
- Preserve Norn and journal data while rebuilding runtime-only functions and `Set` values on load.
- Show whether the grove is saved in this browser, and explain when storage is unavailable or a saved version cannot be read.
- Serialize every save and Reset with an exclusive Web Lock; reject a write if shared storage has changed since this tab last observed it.
- Detect when another open tab updates the same grove, then stop this tab's writes and ask the player to reload.
- Make Reset begin a fresh grove and atomically replace its previous automatic save when safe persistence is available.
- Keep all persistence local, offline, and independent of accounts or third-party services.

## Non-goals

- No cloud sync, account, server, external model, export/import, multiple save slots, or real-time simulation while the page is closed.
- No migration beyond the first versioned save format in this slice.

## Constraints

- Preserve the self-contained static HTML prototype and its no-dependency setup.
- Store a single versioned record in browser `localStorage`.
- Do not silently replace malformed or newer-version saved data with a fresh run; report the issue and wait for the player's Reset action.
- Storage access, quota, or locking failures must not stop the in-memory simulation. Without usable Web Locks, all persistence fails closed and Reset affects memory only.
- The session instruction prohibits adding or running automated tests; use source inspection, JavaScript syntax validation, and deployment checks.

## Approaches

- **Versioned local autosave (chosen):** Save periodically while the simulation is active and immediately after important events or when the page is hidden. This preserves the current local-first design and works on GitHub Pages; the save belongs to one browser profile.
- Manual save/load controls: More explicit, but add extra controls and let an unexpected close lose progress between saves.
- Cloud saves: Make progress portable across devices, but require accounts and a service, which conflicts with the current offline prototype.

## Behavior

On startup, the game reads the single saved record. A valid record restores simulation time, pause and speed settings, selected Norn, guidance, recent events, Norn needs and positions, learned associations, words, memories, cooldowns, and random generator state. The world does not advance while the page is closed. Teaching and pointing modes are cleared on reload so an old pointer gesture cannot remain active.

The UI displays a short save status. A valid restored grove is identified as restored from this browser. If the browser denies storage, cannot write the record, or lacks usable Web Locks, the simulation continues in memory and the status reports that progress is not being saved. Parsing, validation, and reconstruction share an error boundary: malformed data is preserved, a fresh in-memory grove starts, and automatic writes remain blocked until the player chooses Reset. Reconstruction admits only validated mutable fields and preserves canonical Norn names and palette colors.

Every save and Reset acquires the same exclusive Web Lock, compares the current raw record with the exact record last observed by this tab, and only then writes the next revision. A tab restored from an older revision cannot overwrite a newer record even if its storage notification has not arrived. Storage events remain an early stale-tab notification, including browser-data clearing. Reset starts the canonical initial grove in memory and uses this same guarded writer to atomically replace the previous record. If storage changed, the tab must reload before saving or replacing the shared run. If locking or storage is unavailable, Reset leaves the stored value intact and the fresh grove remains in memory.

## Builder choices

- Use the key `new-albia-save-v1` and a `schemaVersion` field with value `1`.
- Retain temporary writer IDs as metadata. Add a nonnegative safe-integer revision, treating existing v1 saves without one as revision zero; increment it after each successful write. If the safe-integer limit is reached, block further writes.
- Use a shared exclusive Web Lock around a synchronous read/compare/write, with exact raw-record comparison as the stale-state guard. Never fall back to unlocked localStorage writes. Retain `storage` notifications without treating delayed notifications for an already observed value as new conflicts.
- Request runtime snapshots at a short interval while running, after recorded events, and on `pagehide`/hidden visibility. Lock acquisition is asynchronous; lifecycle saves are best effort and may not finish before the page closes.
- Invalidate queued autosaves before Reset and suppress new autosaves until its serialized write completes; do not remove the key before writing the fresh record.
- Do not save transient toast text or active Point/Teach modes. Persist the remaining guidance timer and any active contextual speech bubble.
- Reconstruct the random generator from the saved generator state; rebuild `observedEventIds` as a `Set` and restore palette colors from the canonical Norn identity.
- Explain in README that clearing this site's browser data removes the local save.

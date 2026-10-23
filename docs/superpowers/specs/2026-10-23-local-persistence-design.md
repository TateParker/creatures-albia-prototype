# Local Persistence

## Intent

Let a player return to the same New Albia grove after closing or reloading the page, keeping the Norns' needs, behavior, learning, words, memories, and recent moments intact.

## Goals

- Restore the current simulation from one automatic save in the current browser profile.
- Preserve deterministic behavior by saving the random generator's current state as well as the original seed.
- Preserve Norn and journal data while rebuilding runtime-only functions and `Set` values on load.
- Show whether the grove is saved in this browser, and explain when storage is unavailable or a saved version cannot be read.
- Detect when another open tab updates the same grove, then stop this tab's writes and ask the player to reload.
- Make Reset begin a fresh grove and remove its previous automatic save.
- Keep all persistence local, offline, and independent of accounts or third-party services.

## Non-goals

- No cloud sync, account, server, external model, export/import, multiple save slots, or real-time simulation while the page is closed.
- No migration beyond the first versioned save format in this slice.

## Constraints

- Preserve the self-contained static HTML prototype and its no-dependency setup.
- Store a single versioned record in browser `localStorage`.
- Do not silently replace malformed or newer-version saved data with a fresh run; report the issue and wait for the player's Reset action.
- Storage access or quota failures must not stop the in-memory simulation.
- The session instruction prohibits adding or running automated tests; use source inspection, JavaScript syntax validation, and deployment checks.

## Approaches

- **Versioned local autosave (chosen):** Save periodically while the simulation is active and immediately after important events or when the page is hidden. This preserves the current local-first design and works on GitHub Pages; the save belongs to one browser profile.
- Manual save/load controls: More explicit, but add extra controls and let an unexpected close lose progress between saves.
- Cloud saves: Make progress portable across devices, but require accounts and a service, which conflicts with the current offline prototype.

## Behavior

On startup, the game reads the single saved record. A valid record restores simulation time, pause and speed settings, selected Norn, guidance, recent events, Norn needs and positions, learned associations, words, memories, cooldowns, and random generator state. The world does not advance while the page is closed. Teaching and pointing modes are cleared on reload so an old pointer gesture cannot remain active.

The UI displays a short save status. A valid restored grove is identified as saved in this browser. If the browser denies storage or cannot write the record, the simulation continues in memory and the status reports that progress is not being saved. If the record is corrupt or from an unsupported schema version, it is preserved, a fresh in-memory grove starts, and automatic writes remain blocked until the player chooses Reset. If another open tab saves or resets this grove, this tab stops writing and tells the player to reload to continue from the newer state. Reset starts the existing canonical initial grove, clears the old saved record, and resumes autosaving.

## Builder choices

- Use the key `new-albia-save-v1` and a `schemaVersion` field with value `1`.
- Give each page tab a temporary writer ID and listen for `storage` events so an older open tab cannot keep autosaving after another tab updates the grove.
- Save runtime snapshots at a short interval while running, after recorded events, and on `pagehide`/hidden visibility; keep local writes small and synchronous.
- Do not save transient toast text or active Point/Teach modes. Persist the remaining guidance timer and any active contextual speech bubble.
- Reconstruct the random generator from the saved generator state; rebuild `observedEventIds` as a `Set` and restore palette colors from the canonical Norn identity.
- Explain in README that clearing this site's browser data removes the local save.

# Feedback Window Cue Design

## Intent

Help the player act on the short Praise/Scold window by showing which recent action belongs to the selected Norn and how much in-game time remains.

## Goals and non-goals

- Derive the cue from the selected Norn's existing `lastSuccess` and simulation time.
- While feedback is eligible, identify the Norn and the food/toy action and show a positive, rounded-up in-game seconds remaining value.
- Explain the waiting, expired, and already-responded states.
- Keep the existing 12-second eligibility and one-response checks unchanged.
- Keep the cue current at the UI refresh cadence and let it naturally pause or speed up with simulation time.
- Make the help text the description for both Praise and Scold controls without a live announcement every refresh.
- Add no simulation field, save field, external service, or decision change.

## Behavior

The existing feedback help updates from the selected Norn's `lastSuccess`. Before a success, it asks the player to wait for a meal or play. For an unanswered success at or under 12 in-game seconds old, it states the action and rounds remaining time up, with a minimum of one while the existing handler still accepts the response. After the window expires it tells the player to wait for another action. After one response it says feedback was already recorded and asks the player to wait for the next action. The text is not an aria-live region; each control references it as a description, so a focused button has current context without repeated announcements.

The existing handlers remain the authority for feedback eligibility. The cue is informative and does not disable controls or change the 12-second boundary.

## Constraints

- Keep the standalone static HTML build and local simulation.
- Do not add or run automated tests under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

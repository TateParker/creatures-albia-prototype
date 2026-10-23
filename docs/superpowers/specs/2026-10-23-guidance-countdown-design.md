# Point Guidance Countdown Design

## Intent

Explain how long the player's current Point command continues to override a Norn's independent target choice.

## Behavior

- While guidance is active for the inspected Norn, include the guided object, remaining in-game seconds, and independent choice in the existing Choice signals summary.
- Round remaining time up so an active subsecond override displays at least one second.
- Let the existing UI refresh update the count; do not add a live region or a timer.
- Document that Point guidance lasts up to seven in-game seconds.

## Constraints

- Use the existing guidance timer and decision scores without changing either.
- Add no simulation or save fields.
- Do not add or run automated tests under the standing user instruction.

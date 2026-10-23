# Feedback Toast Target Design

## Intent

Make the immediate Praise/Scold confirmation identify whether the fruit or spinner association changed, so the player can connect feedback to the action they just observed.

## Approaches

- Keep the generic “association” toast: no change, but the immediate confirmation remains ambiguous when a Norn has just used either object.
- Name the affected object in each existing changed/capped toast: recommended and chosen because the code already has the grounded object label and outcome; this adds context without changing simulation state or layout.
- Add a numeric association value: more detail, but it requires choosing display precision and interpreting the score scale, which is unnecessary for a confirmation toast.

## Behavior

- Praise toasts identify the affected object and whether its association grew stronger or was already at its strongest.
- Scold toasts identify the affected object and whether its association weakened or was already at its weakest.
- Keep the existing feedback eligibility, association updates, journal, memories, observer behavior, RNG, save fields, and decision formula unchanged.

## Constraints

- Keep the prototype local-first and dependency-free.
- Do not add or run automated tests under the standing user instruction.

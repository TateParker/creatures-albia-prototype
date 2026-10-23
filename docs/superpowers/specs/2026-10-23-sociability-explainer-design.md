# Sociability Inspector Explanation — Design

## Intent

The Norn inspector shows Sociability as a percent and bar, but does not explain what that trait means in play. Since sociability now sets the chance to notice a nearby Norn's success, make that meaning visible where the trait is inspected.

## Goals

- Add one short, visible explanation below **Inherited tendencies**: Sociability is the chance to notice a nearby Norn's success.
- Expose the two inherited tendency bars as named, 0–100 meters to assistive technology.
- Associate the Sociability meter with the same visible explanation using `aria-describedby`.
- Preserve the existing names, values, layout, simulation behavior, and saved state.

## Non-goals

- Change sociability values or observation probabilities.
- Add a tutorial, tooltip, preference panel, or new persistence data.
- Change how Curiosity or Sociability is inherited or used.

## Approaches

1. **Show a short explanation beside the inherited tendencies and link it to the Sociability meter (selected).** It is visible on touch and narrow screens, works without interaction, and gives screen-reader users the same context.
2. **Rename Sociability to a phrase such as “Social attention.”** This may be shorter but loses the inherited trait's familiar name and does not explain the percentage.
3. **Use a hover tooltip.** This avoids persistent copy but is unreliable on touch screens and easy to miss.

The user authorized continued small prototype improvements; a visible linked hint is the implementation call because it explains the trait in its existing inspector context with no behavior change.

## Constraints and implementation notes

- `renderTrait(label, value)` in `index.html` builds the inherited tendency display.
- Give its `.tiny-meter` an accessible name, minimum `0`, maximum `100`, current rounded percent, and percent value text.
- Add a short visible helper with an ID and set that ID as `aria-describedby` on the Sociability meter only.
- Keep visual meter fill and labels unchanged. No simulation or save fields change.
- Do not add or run automated tests. Use static whitespace and inline JavaScript syntax checks, then a scoped review and deployment verification.

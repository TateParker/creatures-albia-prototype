# Slower Simulation Speed Design

## Intent

Let players slow the habitat to watch Norn decisions and interactions more closely.

## Behavior

- Keep the existing 1× default and 2× option.
- Add 0.5× and cycle the speed control through 1×, 2×, then 0.5×.
- Save and restore the selected speed using the existing field; accept 0.5 alongside existing 1 and 2 values.
- Keep the change local to the existing simulation speed multiplier. Do not alter action rates, random behavior, or save schema version.

## Constraints

- Preserve old saves with speed 1 or 2.
- Keep the speed button's accessible name synchronized with its visible value.
- Do not add or run automated tests under the standing user instruction.

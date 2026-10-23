# Reset Confirmation Design

## Intent

Prevent an accidental Reset from discarding the current tab's in-memory progress or replacing this browser's saved grove.

## Approaches

- Keep the current one-click Reset: fastest, but a stray activation can replace progress.
- Use the browser's native confirmation before calling the existing reset routine: recommended and chosen because it is keyboard accessible, dependency-free, and leaves the proven save/lock code untouched.
- Build a custom in-page dialog: allows visual styling but adds focus management and more interface code for a single confirmation.

## Behavior

- Activating Reset opens a concise confirmation that says current progress will be discarded and the saved run replaced if it can be safely updated.
- Confirm runs the existing reset path unchanged.
- Cancel leaves the in-memory grove, saved run, and status untouched.

## Constraints

- Preserve the existing cross-tab lock and stale-save conflict protection.
- Keep the prototype local-first and dependency-free.
- Do not add or run automated tests under the standing user instruction.

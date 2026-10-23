# Learning Feedback Timing — Design

## Intent

Make the Praise and Scold controls easier to find and explain when they apply. The controls already sit in the habitat toolbar and accept one response within 12 in-game seconds after a meal or play event; that timing is not currently visible beside them.

## Goals

- Give Praise and Scold a visible, named control group.
- Show the existing 12 in-game second window and one-response rule beside the controls.
- Preserve the current feedback mechanics and click behavior.

## Non-goals

- Change learning amounts, feedback eligibility, timers, or event copy.
- Add dynamic button disabling, countdowns, saved state, or new events.

## Approaches

1. **Labeled Praise/Scold group with a visible timing hint (chosen).** It explains the feature before the player clicks and keeps the current buttons and feedback path intact.
2. Disable and enable the buttons according to recent-action state. This could teach timing through affordance, but changes interaction behavior and needs careful handling of simulation speed and selected Norns.
3. Explain the rule only in a toast after a failed click. This preserves the layout but hides the rule until the player makes a mistake.

The user authorized continued small prototype improvements through 11:23 AM Toronto time. The visible group is the smallest high-value change and directly addresses the earlier question about locating Scold.

## Design

Wrap Praise and Scold in a labeled **Learning feedback** group and associate a visible hint with the group: “Choose one within 12 in-game seconds after a meal or play.” Let the group wrap naturally at narrow widths. Keep both native buttons and their handlers unchanged so existing success, error toasts, and learning remain authoritative.

Update the README to mention the 12 in-game second window and one-response limit. No simulation code, save schema, or decision scoring changes.

## Constraints

- Keep the controls keyboard and screen-reader accessible.
- Keep the timing hint readable on narrow screens.
- Do not add or run automated tests; use `git diff --check`, inline-script syntax validation, scoped review, and live Pages verification.

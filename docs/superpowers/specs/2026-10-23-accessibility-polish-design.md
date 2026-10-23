# Accessibility Polish Design

## Intent

Make the two existing object interactions usable without canvas pointer precision and keep learned speech readable on narrow screens. This follows the scoped review of vocabulary learning, which found that Teach mode could be entered by keyboard but not completed and that speech text shrank with the scene.

## Goals and non-goals

- Add keyboard and screen-reader accessible controls for the fruit dish and wind-up spinner.
- Keep canvas pointer interaction intact and route both input methods through the same Point/Teach behavior.
- Keep speech bubbles at a readable minimum screen size while preserving their position above each Norn.
- Do not change vocabulary learning rules, simulation decisions, persistence, or visual art style.
- Add no dependencies or network calls; keep the single-file static build.

## Approaches

1. **Visible native object buttons below the scene (chosen).** Two standard buttons expose the fruit dish and spinner as focusable targets. They invoke the same object action as clicking the scene: teach the selected word when Teach mode is active, otherwise point the selected Norn to that object. Existing canvas clicks remain available. This adds a compact row but reuses browser keyboard, focus, and assistive-technology behavior.
2. **Keyboard navigation inside the canvas.** Add a focused canvas widget with arrow-key selection and live announcements. This keeps controls inside the illustration but requires custom focus, selection, and key handling for a scene that currently has no semantic object layer.
3. **DOM speech bubbles.** Position accessible HTML bubbles over the canvas. They would naturally use CSS pixels, but require synchronizing additional DOM elements with animated Norn coordinates and responsive canvas dimensions.

## Design

Use two visible buttons in a labeled Habitat objects group. A short help line explains the current action. In Teach mode, each button attempts to pair the selected word with its object and uses the existing mismatch feedback. Outside Teach mode, activating either button points the selected Norn to that object, whether or not Point mode was entered first. Canvas clicks continue to select Norns and use the existing Point/Teach modes. Reuse the existing button focus style and provide a minimum 40 CSS-pixel target height.

Keep speech bubbles in canvas rendering, but size their text and box from the canvas's CSS scale so their text remains at least 14 CSS pixels high and the bubble stays at least 76 by 32 CSS pixels. Their world position and speech lifetime remain unchanged; if both Norns speak at once, stagger their bubbles vertically so the wider mobile bubbles do not cover one another.

## Builder calls

- A direct object button activation points immediately when Teach mode is off; it is labeled as an object target and the help copy explains this behavior.
- Screen-size speech bubbles are preferred over new overlay elements because the speech strings are short and the existing canvas already owns their position and timing.
- Verification uses source review, `git diff --check`, inline-script syntax validation, and a cache-busted Pages response. The session constraint prohibits automated tests unless the user asks.

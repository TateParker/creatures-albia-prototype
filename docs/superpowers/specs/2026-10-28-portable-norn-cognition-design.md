# Portable Norn Cognition and Godot 3D Transition — Design

**Status:** Draft for review

## Intent

Improve Norn behavior through meaningful internal drives, persistent experience, contextual learning, and social observation. Keep simulation and learning local and responsive. Prepare the rules for a later 3D Godot version without moving the project to Godot before the browser prototype has taught us which mechanics work.

## Current state

New Albia is a static browser app in README.md and index.html. It has no build step or runtime service. Norns currently choose between fruit and a spinner using hunger, curiosity, and learned preferences; teaching, praise/scold, social observation, memory snippets, local saves, and browser on-device push-to-talk are already present. The save schema is version 4, and the grove currently caps at four Norns.

## Goals

- Replace the two independent need meters as the only internal state with a small, authored biochemical model.
- Add contextual episodic memory and bounded learning from outcomes, praise/scolding, words, and social observation.
- Keep decisions understandable in the inspector: show meaningful inputs, action scores, recalled experience, and the outcome that changed learning.
- Establish a deterministic cognition interface with plain observations and actions, so the web and future Godot world adapters can use the same contract.
- Keep all runtime behavior local. Preserve typed language teaching and the existing on-device-only push-to-talk behavior.

## Non-goals

- Do not add a cloud service, remote speech recognition, or a language model in the action loop.
- Do not make Norns' model size, chemical count, or vocabulary a claim about intelligence without measured behavior.
- Do not raise the four-Norn gameplay cap during the initial browser work. Use 12 Norns as a load scenario only.
- Do not implement pixel-based vision in the browser prototype. Start with structured local sensors; consider vision after the 3D environment exists.
- Do not begin the Godot rebuild in this work wave.

## Constraints

- Keep index.html runnable from disk or static hosting with no build step and no runtime network dependency.
- Use browser APIs only in adapters. Cognition code must not read the DOM, canvas, localStorage, microphone, or network.
- Keep current interactions, browser speech limits, event journal, and save safety intact.
- Current saves are schema version 4; migrate versions 1–4 and preserve learned state.
- Use fixed, seeded simulation behavior and serializable state. Do not store microphone audio.
- Start small: approximately 8–12 meaningful chemical channels, chemistry at 10 Hz, decisions at 5 Hz, a 128-unit recurrent-policy experiment, bounded learning on action associations, and a capped store of 512 salient episodes per Norn. These are tunable starting values, not claims of optimality.

## Approaches considered

1. **Continue adding cognition directly to index.html.** Fast for a small feature, but it ties future learning logic to the canvas, UI, and browser persistence.
2. **Move to Godot immediately.** This would create the 3D foundation sooner, but it would also rebuild the current world and learning behavior before those mechanics have been evaluated.
3. **Keep the browser as a playable harness and isolate a portable cognition core.** This keeps current work usable, gives the learning rules a clean boundary, and allows a later GDScript port. This is the selected approach, matching the user's preference to move to Godot eventually.

## Proposed architecture

- Keep index.html responsible for world state, canvas rendering, user controls, browser speech, and local save coordination.
- Add cognition.js as an ordinary local script with deterministic functions that advance chemistry at 10 Hz and decide actions at 5 Hz from structured observations. Return action scores, explanations, and recalled memory IDs. It must not depend on browser APIs.
- Describe observations with local object categories, relative distance and direction, action affordances, nearby Norns, player guidance, and selected language inputs. The browser adapter derives these from the existing 2D world. A future Godot adapter can derive them from physics queries or ray casts.
- Make chemistry data-driven, bounded, and deterministic. Map current hunger and curiosity values into the new chemistry so existing behavior and meters remain understandable.
- Keep the starter policy safe and interpretable. The recurrent controller is a measured pilot; retain the current chooser as a fallback. Only compact action-association weights learn online through eligibility traces and bounded reward/punishment signals; the recurrent feature weights remain fixed initially.
- Store episodes as structured, salient world events and retrieve a few using recency, importance, and context match. Keep the visible journal capped independently from long-term memory.
- Keep learned words, push-to-talk, and social hearing as adapters into the same concept and episode records. No generative model is required for the core.

## Future Godot phase

After the browser cognition milestones are accepted, create a Godot project, likely under a godot/ directory in the same repository while retaining the browser harness. Build a small 3D vertical slice with a Norn, a walkable habitat, fruit, a toy, and a player interaction. Port the cognition contract to GDScript and feed it structured 3D observations. Compare the same authored scenarios in both runtimes. Add image-based vision only if structured 3D sensors prove insufficient.

## Success measures

- Existing saves and interactions continue to work after each schema migration.
- A Norn can learn an action preference from an outcome, adjust it from praise/scolding, recall the relevant episode later, and explain the decision.
- Typed teaching and local push-to-talk continue to teach the selected meaning without remote processing.
- The browser remains usable offline, and the cognition core contains no browser or network calls.
- On the current Windows browser baseline, profile four live Norns and a 12-Norn stress scenario; keep the full frame below 16.6 ms at the 95th percentile before raising the gameplay population cap.
- In Godot, the same observations and outcomes produce behavior consistent with the accepted browser scenarios.
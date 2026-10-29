# Godot Albia Vertical Slice — Design

**Status:** Approved for implementation by the user's 2026-10-28 instruction to continue through the Godot work and review afterward.

## Intent

Create a small native 3D Godot version of New Albia while keeping the browser prototype playable as the reference. The slice should demonstrate that the locally authored Norn cognition contract can drive a creature in a 3D habitat, receive player guidance and feedback, and preserve its learned state.

## Scope

- Create a standalone Godot project in `godot/`.
- Target the latest stable Godot release available when work begins: 4.7.2-stable. Do not use the 4.8 beta.
- Use typed GDScript and local runtime only. The project must not depend on a cloud service, remote model, browser API, speech service, or network connection.
- Include one Norn, one walkable habitat, honey fruit, a spinner toy, and player guidance plus Praise/Scold controls.
- Port the existing chemistry channels, action IDs, deterministic recurrent policy, episode recall, and bounded action-association learning into a browser-independent GDScript core.
- Derive structured observations from local 3D sensor/physics queries; keep cognition independent of SceneTree, rendering, input, physics, and persistence.
- Save and restore the one-Norn learning state as local JSON under `user://`.
- Use original primitive meshes and materials for the vertical slice. Do not import or download third-party game art.
- Do not implement Godot speech recognition or text-to-speech in this phase. The browser push-to-talk test remains deferred because Codex's browser cannot provide speech recognition.

## Interaction and behavior

- The Norn re-evaluates choices at the same 5 Hz cadence and advances chemistry at 10 Hz, with bounded catch-up after pauses.
- The initial seed and traits are fixed for manual comparisons. The Norn should seek fruit while hungry, learn from eating and feedback, then seek the spinner when curiosity calls for it.
- Players can guide the Norn to either object and apply Praise or Scold. The HUD shows the Norn's important chemicals, current action, decision reason, and recalled moments.
- The habitat is navigable in a third-person or angled observer view, with a simple mouse/keyboard camera that does not become a player-character controller.

## Architecture

- `NornCognition` is a `RefCounted` GDScript API with data-in/data-out methods: `create_state`, `advance_chemistry`, `decide`, `preview`, `record_outcome`, `serialize_state`, and `restore_state`.
- A thin scene adapter owns the fixed-step scheduler, local physics queries, character movement, object interactions, controls, and save file.
- A `CharacterBody3D` Norn follows action targets. Interactable objects expose stable IDs and affordances through groups or a common script.
- The world uses a minimal authored scene and reusable primitive materials so the result is directly editable in the Godot editor.

## Review and acceptance

- The project imports and runs in Godot 4.7.2-stable without script/parser errors.
- The same fixed-seed, initial-chemistry and outcome scenarios are inspected in browser and Godot. Compare action IDs, action scores within floating-point tolerance, chemistry after food/toy/praise/scold, recalled episode count, and restored associations.
- In an interactive run, the Norn moves to fruit and spinner, responds to guidance and feedback, updates its visible chemistry, and preserves learned state across save/load.
- The existing four-Norn browser limit and browser runtime are unchanged.
- No automated test suite is added. Use Godot's editor/runtime and repeatable manual scenarios, consistent with the approved project constraint.

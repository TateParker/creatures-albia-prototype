# Godot Expanded Habitat and Meshy Asset Set — Proposed Design

**Status:** Approved for implementation. In-place code and documentation work is underway; paid generation, package build/admission, and runtime Norn replacement remain gated as described below.

## Intent

Expand the native Godot 3D slice from one small habitat into a connected three-region environment where Norns can encounter more varied, visible targets and learn from distinct outcomes. Improve the habitat's visual detail with locally imported, textured Meshy models, and document every existing and new model in a complete asset inventory.

The browser prototype remains the behavior reference and is outside this change. The requested Norn model is a review candidate only: do not replace the procedural runtime Norns until the user approves the candidate.

## Current state

- Repository: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`, branch `main`, revision `4548256`. The checkout was clean at task start. A local `game-dev catalog list` query returned zero packages and initialized the untracked metadata file `assets/generated/.game-dev/catalog.sqlite3`; that tool file is being preserved.
- The Godot 4.7.2 project creates its 24×18 habitat in code. It has a small meadow, four trees, two rocks, a path, the family nest, honey fruit, a spinner, a drawing station, charcoal, two independently simulated Norns, and egg visuals.
- `main.tscn` is a script-backed root scene. There are no imported model or texture files in `godot/` today. The Norn body uses 19 procedural primitive meshes per Norn; environment and prop parts are also primitive meshes. Text labels and the live drawing texture are generated at runtime.
- Cognition currently has six actions (`fruit`, `spinner`, `rest`, `observe_peer`, `idle`, `draw`), 20 named inputs, and a 256-value drawing observation. Object sensing is local, line-of-sight checked, and limited to a 10-unit radius. Movement walks directly toward a target and has no pathfinding.
- Cognition state is version 4 and world saves are version 6. The save loader migrates older versions and retains family, chemistry, learning, language, and drawing state.
- The browser prototype already has connected regions named Sunmeadow, Softwood Grove, and Glassfall Hollow; its code is not changed by this proposal.
- `game-dev` 1.5.0 is available and its local doctor passed. The Meshy CLI 0.4.0 package is present in npm's local cache. The stored Meshy login token was expired; the device authorization request failed before issuing a code because the endpoint could not be reached. The balance remains unavailable. No generation task was submitted and no credits were spent.
- The project `AGENTS.md` requires a rendered in-game recording and inspection for gameplay, rendering, or simulation changes. No pre-existing source edits were present at task start; preserve existing asset/tool data and keep implementation scoped.

## Goals

- Expand the Godot 3D habitat into the same three named, connected regions, keeping one continuous world and one simulation.
- Add a berry bush with a distinct forage action, a spring with a new bounded thirst need and drink action, and a curiosity landmark with an explore action.
- Let Norns reach adjacent regions autonomously using visible, local exploration cues. Keep the existing 10-unit sensing and line-of-sight rules; do not make unseen resources selectable by ordinary decisions.
- Record source-specific outcomes, chemistry changes, associations, and memories so the additional objects supply grounded learning experiences.
- Keep existing fruit, spinner, rest, social observation, drawing, guidance, teaching, Praise/Scold, save, and family behavior available.
- Replace the egg's procedural shell with a textured Meshy model while keeping its runtime name, progress label, inherited color cue, and incubation behavior.
- Generate a textured A-pose Norn model candidate and preview for review. Keep the current procedural Norn models in the game until the user approves replacement. Do not include rigging or animation in this asset batch.
- Create a complete inventory of current and new items, mesh components, model families, textures, gameplay affordances, generated asset paths, prompts, Meshy task IDs, validation, and license/provenance.
- Keep the built game self-contained and offline at runtime; generated GLB files and their embedded PBR textures are local assets.

## Non-goals

- Changing the browser prototype or its three-region behavior.
- Replacing runtime Norn bodies before user review, or generating a rig/animation without a separately approved scope and budget.
- Adding pathfinding, separate scenes, portals, fast travel, multiplayer, cloud inference, generated dialogue, or new life stages.
- Treating richer environmental experience as proof that the cognition system has become generally more intelligent. The result should expose additional grounded stimuli and learning opportunities; any performance claim would require a separate experiment.
- Recreating protected artwork or sounds from the Creatures games. New models should use an original soft, low-poly Albia style.

## Approaches considered

1. **More visual destinations using only current choices.** Spread new food and toy props across the regions and preserve the current action set. This has the least cognition and save risk, but does not add a new need or behavior.
2. **Three-region world with new needs and behaviors (selected).** Add source-specific foraging, a spring-driven thirst/drink behavior, and curiosity-led exploration. This gives the network new, inspectable choices and gives each new prop a meaningful outcome, at the cost of cognition, chemistry, HUD, vocabulary, and save-migration work.
3. **Art pass only.** Replace meshes and add scenery without changing behavior. This is simpler and improves appearance, but does not provide the requested richer experience for the Norns.

The user selected approach 2. The user also requested Meshy Norn and egg models, with the Norn replacement held for approval.

## Proposed world and interactions

The builder may tune exact coordinates after checking the Godot camera and current habitat scale. Keep a broad, unobstructed travel corridor because `NornActor` uses direct target movement rather than pathfinding.

| Region | Existing features retained | New experience |
|---|---|---|
| Sunmeadow | Honey fruit, family nest and eggs, drawing board and charcoal | Starting area and visible route to the next region |
| Softwood Grove | Region-specific trees, rocks and ground palette | Berry bush; successful foraging relieves hunger and records a `forage` association and episode |
| Glassfall Hollow | Wind-up spinner, with a water and stone palette | Spring; a new `thirst` signal makes Norns choose `drink`. A curiosity landmark supplies an `explore` target and a bounded novelty outcome |

Keep the current `fruit`, `spinner`, `rest`, `observe_peer`, `idle`, and `draw` action IDs stable and append `forage`, `drink`, and `explore`. Add a thirst need and the minimum perception cues required to distinguish the new targets. Curiosity-led exploration should use visible transition landmarks or other nearby cues to move through the connected world. The spring and berry bush must be sensed before autonomous use. Interactions must update the appropriate chemistry and create outcomes/memories that identify the actual target. Exploration rewards must be bounded and should not become an unlimited reward loop.

Provide guidance and vocabulary teaching for the new selectable targets using the existing local UI pattern. Keep the focused Norn clear in the HUD. Add a follow-focused-Norn camera mode for long travel; manual WASD/arrow panning and zoom remain available, and manual panning should pause follow until the player selects a Norn or gives guidance again.

## Asset inventory and Meshy output

Write the inventory to `godot/ASSET_INVENTORY.md`. List every current mesh component and instance count, not only logical objects. Current procedural entries include:

- Habitat: ground box, path box, four trees (trunk cylinder and canopy sphere each), two rock spheres, sky and directional light, and the Sunmeadow label.
- Nest and eggs: nest bowl cylinder and rim torus; each egg has a shell sphere, shine sphere, and generated progress label.
- Existing interactables: honey fruit (fruit sphere, stem cylinder, leaf sphere), spinner (base and axle cylinders, center sphere, two arm boxes), drawing board (wooden frame box, live-texture QuadMesh panel, shelf box), and charcoal (tool-rest box and stick cylinder).
- Each Norn has 19 procedural body/face/drawing meshes: body, belly, head, two outer ears, two inner ears, two eye sockets, two eyes, two pupils, two eyelids, nose, drawing arm, palm, and charcoal tip. Names and life-stage text are runtime labels.
- Dynamic labels and drawing marks are generated by the engine; they are not standalone Meshy assets.

The initial Meshy candidate set is one GLB per reusable model family: meadow-ground tile/material, path segment, tree, rock, nest, honey fruit, spinner, drawing station, charcoal tool, egg, berry bush, spring, curiosity landmark, and one shared Norn-species candidate. Reuse the tree, rock, path, fruit, and other suitable models by instancing or material variation. Preserve the Norn's per-individual color distinction where practical. If the Meshy output for the live drawing board cannot retain the current editable mark texture, keep that panel engine-authored and document the exception.

Use a coherent, original, soft low-poly game style, GLB, 2K PBR textures, simple silhouettes, and no text or background in generated models. Target a small-prop budget of at most 5,000 triangles and a larger combined habitat piece of at most 15,000 triangles; inspect actual output before integration. The Meshy Norn candidate should be in A-pose for review and remain outside the runtime asset directory. Its review preview must be shown to the user before any replacement request.

Use the configured generation workspace `assets/generated/`. Keep provenance and previews with Meshy job records. Build and verify canonical packages before admitting runtime assets to `godot/assets/`. Run a dry-run admission against the exact Godot project/destination and show its result before admission. Record the license actually issued by the Meshy account; do not assume a paid or free plan. The local `game-dev` catalog query returned zero packages and left the tool metadata file noted above.

Before any paid Meshy submission, check authenticated status and account balance, run the CLI's no-cost planner for the final model list, and present the exact credit estimate and a maximum spend request. Submit only after the user authorizes that ceiling. Do not automatically add a second model variant, texture rerun, remesh, rig, or animation if a result disappoints or fails a quality target; get fresh budget approval for extra paid work. If an asset needs a write-producing normalization step, present its exact source and output path before running it.

## Save and cognition compatibility

- Bump the cognition schema to version 5 and the world save schema to version 7 for the new action/need/perception and world-position bounds.
- Preserve version-1 through version-4 cognition records and version-1 through version-6 world saves, including names, family, chemistry, words, learned associations, episodes, drawing marks, and simulation state.
- Append new action IDs and new sensory inputs so old action names and existing input positions remain stable. Use an explicit migration/extension path that preserves the old policy's recurrent and existing action weights, initializes only new cues/actions deterministically, and initializes thirst to a safe bounded value.
- Keep the runtime simulation deterministic and local. No Meshy network calls, account access, or generated services run in Godot.

## Verification and acceptance

- All three regions are reachable in the one 3D scene, and the player can keep the focused Norn visible during long autonomous or guided travel.
- Norns can seek and use berries, drink when thirsty, and explore the curiosity landmark. Decisions and resulting UI/memories name the correct action and target; existing food, spinner, drawing, observation, feedback, vocabulary, save/load, and family behaviors remain usable.
- Version-1 through version-6 saves load with previous learning intact; new state and expanded positions round-trip safely.
- Every Meshy GLB and its textures are inspected, locally validated, packaged with provenance/license/hash data, and integrated to the approved location. The inventory covers all old and new models and clearly marks the Norn as candidate-only.
- The Norn candidate preview is delivered for review; runtime Norns remain procedural pending the user's approval.
- Run the project-required rendered recording in non-headless Godot, inspect representative frames, and respect the existing ten-recording retention cap. Report the recording path and what the frames verify.

## Remaining builder choices

- Set region coordinates, landmark spacing, and camera follow/pan behavior after checking the existing composition.
- Choose bounded thirst increase/recovery and forage/explore chemistry amounts from the existing chemistry model, keeping each need within 0–100 and exploration benefit finite.
- Choose the simplest reliable way to preserve the v4 recurrent policy while adding new inputs/actions; document any migration limitation before editing if exact preservation is not technically possible.
- Choose Meshy prompt wording and exact supported topology/texture settings after inspecting the local CLI help and dry-run output. Keep the overall asset list and style above.

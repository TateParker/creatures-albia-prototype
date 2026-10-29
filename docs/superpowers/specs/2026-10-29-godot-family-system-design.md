# Godot Family System — Design

**Status:** Draft for review; no implementation changes are included.

## Intent

Bring the browser prototype's egg, incubation, inheritance, and hatch loop into the Godot habitat. The goal is for two starter Norns to create a young Norn whose identity and inherited traits persist locally, and who becomes another active member of the same learning habitat.

## Current state

The Godot project has two independently simulated profiles, Mallow and Moss. `AlbiaWorld` currently creates those two actors directly, uses a fixed `PROFILE_IDS` list, and writes version-4 saves containing exactly those two profiles. The HUD has fixed Mallow and Moss focus buttons. The scene has no nest or family controls.

The browser prototype already implements family pairing, a four-slot combined population limit, 45-second egg incubation, bounded inherited curiosity and sociability, blended color, hatching, and schema validation. Its existing rules give a concrete baseline for the native version.

## Goals

- Let the player pair the focused Norn with a different existing Norn and start an egg.
- Show eggs in a visible habitat nest with names and incubation progress. Incubation follows simulation speed and stops while paused.
- Hatch an egg into a selectable, autonomous Norn with its own cognition, biochemistry, language, and social state.
- Inherit curiosity and sociability from both parents with small seeded variation, and blend the parents' coat colors.
- Record parentage and generation, and make egg and hatch events visible in family status and the parents' remembered moments.
- Limit living Norns and incubating eggs combined to four.
- Save dynamic Norn identities and active eggs locally in version 5. Preserve version-1 through version-4 saves.
- Verify the real egg-to-hatch flow using rendered gameplay recording and inspect the captured frames.

## Non-goals

- Aging, death, sex, mating compatibility, pregnancy, or inherited learned vocabulary and behavior.
- Norn release or retirement controls. With two founders and four total slots, a single run can hatch at most two children; repeatable multi-generation breeding needs a separate population-lifecycle decision.
- A full genome, mutation model, or genetics editor. Only the existing curiosity and sociability traits, plus coat color, are inherited in this slice.
- Population beyond four Norns and eggs combined, additional habitats, pathfinding, or new resource systems.
- Network services, generated dialogue, or machine-learning inference.
- Replacing the existing primitive Norn meshes with production character assets.

## Approaches

1. **Full bounded family cycle (selected).** Add dynamic profile creation, a visible egg state and nest, a compact pairing interface, deterministic inheritance, hatching, and version-5 persistence. This delivers a complete gameplay loop and reuses the browser prototype's established rules.
2. **Egg display without a living child.** Add a nest and countdown as a visual feature, but stop at hatching feedback. This is smaller, but leaves inheritance, roster selection, and family persistence unimplemented.
3. **3D presentation polish first.** Improve the habitat and Norn appearance before adding family behavior. This would improve the prototype's look, but would not extend its current two-Norn gameplay or test the life-cycle systems.

The full bounded family cycle is selected because the social slice already establishes independent Norn profiles and shared-world interaction, while the existing browser implementation supplies tested family rules to carry over.

## Player experience

- The roster/focus controls list every living Norn. Focusing a child displays its name, generation, and parents. Hatching does not unexpectedly redirect the player's current focus; the child can be selected from the roster.
- A compact, collapsible **Family** section uses the focused Norn as the first parent and offers a selector for a different living Norn as the second parent. **Start egg** is disabled if the parents are invalid or the combined population limit is full.
- The section shows the current living-Norn/egg count and the names, parents, and progress of incubating eggs. The nest is also visible in the 3D habitat, with each egg's name and a clear progress indicator.
- Starting an egg displays a confirmation and records a family memory for both parents. The egg begins at 45 in-game seconds. Pausing freezes its timer; 0.5×, 1×, and 2× speed change its real-time duration in the same way as the rest of the simulation.
- On hatch, the egg is replaced by a newly spawned Norn. A status message names the child and parents. The child begins with the normal fresh Godot need baseline, empty vocabulary, no remembered episodes except its birth record, and neutral learned action associations.

## Family and inheritance rules

- Stable child IDs use `norn-N`; their pending egg IDs use `egg-N`. `nextNornNumber` is monotonic and saved, so IDs are never reused after hatching or loading.
- Child names follow the existing browser list (`Sprout`, `Clover`, `Acorn`, `Pip`) in number order. If the chosen name is already used by a living Norn, append the child number to keep the visible roster unambiguous.
- A child's generation is one greater than the higher-generation parent. Generation is bounded at 3, matching the browser rules.
- Curiosity and sociability are each the parents' average plus deterministic uniform variation in `[-0.06, 0.06]`, clamped to `[0.05, 0.95]`.
- The child's coat color is a deterministic blend of the two parent colors. Its cognition seed is derived from the world seed and child number. Save the realized seed, traits, and color on the egg so loading cannot reroll inheritance.
- A hatch replaces one egg with one living Norn, so the combined count stays constant at the hatch moment. Parent profiles remain alive in this slice; egg and ancestry references must always resolve to profiles in the roster.
- Family events create inspectable neutral memory episodes for both parents. A hatch also records the child's parentage in its initial birth episode. Family events do not directly improve or punish food/play associations.
- Creating an egg and completing a hatch each trigger a local save. Ordinary simulation ticking does not add a new autosave loop.

## Data and architecture

- Replace fixed-roster iteration with a deterministic ordered collection of profile IDs plus a profile lookup map. Preserve Mallow and Moss as stable starter IDs. All chemistry, cognition, object sensing, observation, pause, and feedback loops operate over the current ordered roster.
- Make focus controls and actor creation data-driven so a hatched Norn receives the same actor, perception, and action-completion wiring as the starters.
- Extend `NornProfile` with stable generation, parent IDs, and body color. The existing cognition state remains the source for curiosity, sociability, and its deterministic seed.
- Represent a pending egg with an `NornEgg` world node that owns its stable child identity, parent IDs, generation, realized traits/color/seed, and remaining in-game seconds. It also renders the egg, name, and progress. The static nest is built as part of the habitat; egg-state serialization is explicit and does not depend on scene-node serialization.
- Refactor the HUD's fixed focus buttons into a roster-driven selector. Keep family controls inside a collapsible section so the existing needs, teaching, recording, and biochemistry controls remain readable.
- Preserve the current behavior that actor positions are re-laid out on load rather than saved. All family identity, learning state, and egg incubation state must be saved.

### Version-5 save shape

The top-level record retains `seed`, `simulationTime`, and `focusedNornId`, and adds `nextNornNumber`, a dynamic `norns` map, and an `eggs` array. Each Norn stores its stable ID, name, generation, parent IDs, coat color, cognition (including its seed), biochemistry, language, and feedback state. Each egg stores its ID, reserved child ID, name, parent IDs, generation, realized inherited traits/color, the child's deterministic cognition seed, and remaining incubation seconds.

Version-5 loading validates the complete candidate record before changing the live habitat. Validation checks unique starter/child/egg IDs, known and distinct parents, ancestry references and generation consistency, bounded traits/colors/timers, a valid focus, a monotonic next child number, and the four-slot population limit. Invalid data uses the current safe-reset path.

Versions 1–3 continue through their existing Mallow migration and deterministic Moss initialization. Version 4 restores its two independent profiles unchanged. All four legacy versions create generation-zero Mallow and Moss with their established starter colors, no ancestry, no eggs, and `nextNornNumber = 1`.

## Verification

- Verify bounded population and parent selection, child IDs/names, deterministic inheritance, and fresh child learning state with focused checks.
- Verify incubation follows speed, pauses correctly, and hatches once into a separate active profile with correct ancestry and parent memories.
- Verify version-5 round trips preserve multiple profiles, focus, learning state, and partial egg progress; migrate versions 1–4; reject malformed identities, lineage, traits, colors, timers, and over-capacity saves without partially replacing the live world.
- Run the existing social, habitat, biochemistry, AVI-writer, and recording-retention checks.
- Record the actual family flow in the rendered game. Use 2× simulation speed to show the real 45 in-game-second incubation without bypassing the hatch condition. Inspect frames showing parent selection, the egg and progress, the new selectable child, and its generation/parentage. Keep at most 10 completed clips and report the `user://recordings/` path.

## Constraints and builder choices

- Keep all state and computation local and deterministic.
- Preserve the current two starter identities and their existing saved learning through migration.
- Keep the family controls understandable and compact at the current 1280×720 window size.
- Use the browser prototype's family behavior as the baseline; the native version uses the existing Godot biochemistry, actor, and save architecture.

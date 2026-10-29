# Godot Family and Lifespan System — Design

**Status:** Approved for implementation; no gameplay code changes are included yet.

## Intent

Bring the browser prototype's egg, incubation, inheritance, and hatch loop into the Godot habitat, and give each Norn a visible lifespan. The goal is for two starter Norns to create young Norns who mature, learn, and eventually die of old age while their identities, family history, and inherited traits persist locally.

## Current state

The Godot project has two independently simulated profiles, Mallow and Moss. `AlbiaWorld` currently creates those two actors directly, uses a fixed `PROFILE_IDS` list, and writes version-4 saves containing exactly those two profiles. The HUD has fixed Mallow and Moss focus buttons. The scene has no nest, family, age, or death state. The world clock already follows pause and simulation speed, but Norn chemistry has no health, injury, or illness system.

The browser prototype already implements family pairing, a four-slot combined population limit, 45-second egg incubation, bounded inherited curiosity and sociability, blended color, hatching, and schema validation. Its existing rules give a concrete baseline for the native version.

## Original *Creatures 1* aging and death

The original game had an ageing chemical and age-related life-stage changes. Old-age death was intended, but the stock *Creatures 1* genomes omitted the gene that triggers it, so standard Norns generally aged without dying of old age. They could still die from other causes, including illness and starvation. This Godot design includes old-age death as an intentional life-cycle feature; illness and starvation deaths are deferred until the native simulation has a health or illness model. See the [Creatures Wiki's aging notes](https://creatures.fandom.com/wiki/Ageing) and [Discover Albia's Creatures 1 help](https://discoveralbia.com/help#creatures-1-faqs-and-help).

## Goals

- Let the player pair a focused living adult or elder Norn with a different living adult or elder Norn and start an egg.
- Show eggs in a visible habitat nest with names and incubation progress. Incubation follows simulation speed and stops while paused.
- Hatch an egg into a selectable, autonomous Norn with its own cognition, biochemistry, language, and social state.
- Show a Norn's age and life stage, mature newborns into adults, and end their active life at a deterministic old-age limit.
- Preserve deceased Norns as read-only family records and free their living-population slots.
- Inherit curiosity and sociability from both parents with small seeded variation, and blend the parents' coat colors.
- Record parentage and generation, and make egg and hatch events visible in family status and the parents' remembered moments.
- Limit living Norns and incubating eggs combined to four; deceased records do not occupy population slots.
- Save dynamic Norn identities, ages, death records, and active eggs locally in version 5. Preserve version-1 through version-4 saves.
- Verify the real egg-to-hatch flow using rendered gameplay recording and inspect the captured frames.

## Non-goals

- Death from illness, injury, or starvation; the current Godot biochemistry does not model health or disease. The family log records old-age deaths only in this slice.
- Sex, mating compatibility, pregnancy, and inherited learned vocabulary or behavior.
- Player-controlled release or retirement. Natural old-age deaths free slots for future generations; generation numbers have no gameplay cap.
- A full genome, mutation model, or genetics editor. Only the existing curiosity and sociability traits, plus coat color, are inherited in this slice.
- Population beyond four Norns and eggs combined, additional habitats, pathfinding, or new resource systems.
- Network services, generated dialogue, or machine-learning inference.
- Replacing the existing primitive Norn meshes with production character assets.

## Approaches

1. **Family cycle with age-based mortality (selected scope).** Add a bounded living population, eggs, inheritance, hatching, visible life stages, old-age death, and a persistent family archive in one version-5 save. This enables successive generations and builds death into the life cycle.
2. **Family cycle with broader biological hazards.** Add the same family and age features plus health, illness, and starvation deaths. This could reflect more of the original game's hazards, but requires a survival system that the current Godot biochemistry does not contain.
3. **Family cycle without death.** Add eggs, inheritance, and hatching while keeping Norns immortal. This is smaller, but the four-slot population limit would eventually stop further generations.

Age-based mortality is selected because the social slice already establishes independent profiles and shared-world time, and natural death lets the bounded population continue across generations. The user asked for aging and death; restricting mortality to old age is a scope choice based on the current absence of health chemistry. Other death causes can build on this later if a health model is added.

## Player experience

- The roster/focus controls list every living Norn with its current life stage and age. Focusing a child displays its name, generation, and parents. Hatching does not unexpectedly redirect the player's current focus; the child can be selected from the roster. Deceased Norns appear in a read-only family archive, not the active roster.
- A compact, collapsible **Family** section uses the focused adult/elder Norn as the first parent and offers a selector for a different living adult/elder as the second parent. **Start egg** is disabled if the parents are invalid or the combined population limit is full.
- The section shows the current living-Norn/egg count and the names, parents, and progress of incubating eggs. The nest is also visible in the 3D habitat, with each egg's name and a clear progress indicator.
- Starting an egg displays a confirmation and records a family memory for both parents. The egg begins at 45 in-game seconds. Pausing freezes its timer; 0.5×, 1×, and 2× speed change its real-time duration in the same way as the rest of the simulation.
- On hatch, the egg is replaced by a newly spawned newborn Norn. A status message names the child and parents. The child begins with the normal fresh Godot need baseline, empty vocabulary, no remembered episodes except its birth record, and neutral learned action associations.
- Newborns visibly grow through baby, child, adolescent, adult, and elder stages. Their body scale and age/stage label change; navigation and interaction distances remain constant. Mallow and Moss start as young adults so the family controls work immediately. Age advances in in-game seconds, pauses with the simulation, and follows 0.5×, 1×, and 2× speed.
- Adult and elder Norns may start an egg. At the terminal old-age limit, the Norn receives a death record, its actor leaves the habitat, and the family archive reports the event. Death does not directly alter another Norn's learned associations. If the last living Norn dies while eggs remain, those eggs continue incubating; if no living Norns or eggs remain, the habitat shows an extinction state and retains the saved archive until the player resets it.
- If the focused Norn dies while others live, focus moves to the first living profile in stable roster order. If no Norn is alive but eggs remain, the family view remains available and the first hatch becomes focused. With no living Norns or eggs, the UI shows the extinction state and permits starting a new run without deleting the archive first.

## Family and inheritance rules

- Stable child IDs use `norn-N`; their pending egg IDs use `egg-N`. `nextNornNumber` is monotonic and saved, so IDs are never reused after hatching or loading.
- Child names follow the existing browser list (`Sprout`, `Clover`, `Acorn`, `Pip`) in number order. If the chosen name is already used by a living Norn, append the child number to keep the visible roster unambiguous.
- A child's generation is one greater than the higher-generation parent. Generation has no gameplay cap so repeated family cycles can continue.
- Curiosity and sociability are each the parents' average plus deterministic uniform variation in `[-0.06, 0.06]`, clamped to `[0.05, 0.95]`.
- The child's coat color is a deterministic blend of the two parent colors. Its cognition seed is derived from the world seed and child number. Save the realized seed, traits, and color on the egg so loading cannot reroll inheritance.
- A hatch replaces one egg with one living Norn, so the combined count stays constant at the hatch moment. Egg parent IDs and all ancestry references resolve to retained profile records, including deceased parents.
- Newborn age starts at zero in-game seconds. The initial tuning targets are baby through 60 seconds, child through 180 seconds, adolescent through 420 seconds, adult through 3,000 seconds, then elder until old-age death at a deterministic per-Norn age of 3,600 ± 300 seconds (55–65 minutes at 1×). Lifespan variation is derived from the Norn's saved deterministic seed. Mallow and Moss start as adults aged 600 seconds. These are tuning constants and can be adjusted during the rendered walkthrough without changing the save contract.
- The profile stores age, its deterministic lifespan limit, alive/deceased status, and (after death) cause, age, and simulation time. Life stage is derived from age. Old age is the only mortality cause in this slice; hunger or depleted energy remain modeled needs and do not silently kill a Norn.
- A death removes the Norn from simulation, focus choices, and the four-slot population count, but never deletes its profile. Dead Norns remain inspectable in the family archive, and pending eggs can hatch even if one or both parents have died.
- Family events create inspectable neutral memory episodes for both parents. A hatch also records the child's parentage in its initial birth episode. Family events do not directly improve or punish food/play associations.
- Creating an egg, completing a hatch, crossing a life-stage boundary, and dying each trigger a local save. Ordinary age ticking does not add a per-frame autosave loop.

## Data and architecture

- Replace fixed-roster iteration with a deterministic ordered collection of profile IDs plus a profile lookup map. Preserve Mallow and Moss as stable starter IDs. Active simulation, focus, and observation loops use living profiles; profile records also retain deceased Norns for lineage. All living chemistry, cognition, object sensing, observation, pause, and feedback loops operate over the current ordered roster.
- Make focus controls and actor creation data-driven so a hatched Norn receives the same actor, perception, and action-completion wiring as the starters.
- Extend `NornProfile` with stable generation, parent IDs, body color, age/lifespan, and mortality state. The existing cognition state remains the source for curiosity, sociability, and its deterministic seed.
- Represent a pending egg with an `NornEgg` world node that owns its stable child identity, parent IDs, generation, realized traits/color/seed, and remaining in-game seconds. It also renders the egg, name, and progress. The static nest is built as part of the habitat; egg-state serialization is explicit and does not depend on scene-node serialization.
- Refactor the HUD's fixed focus buttons into a roster-driven selector. Keep family controls inside a collapsible section so the existing needs, teaching, recording, and biochemistry controls remain readable. Add an archive view for deceased Norns and an extinction state when no living profiles or eggs remain.
- Let the actor present stage-specific body scale and a readable life-stage label without changing its navigation or interaction radii.
- Preserve the current behavior that actor positions are re-laid out on load rather than saved. All family identity, learning state, and egg incubation state must be saved.

### Version-5 save shape

The top-level record retains `seed`, `simulationTime`, and `focusedNornId`, and adds `nextNornNumber`, a dynamic `norns` map, and an `eggs` array. Each Norn stores its stable ID, name, generation, parent IDs, coat color, age seconds, deterministic lifespan limit, alive/deceased status, an optional death record, cognition (including its seed), biochemistry, language, and feedback state. Each egg stores its ID, reserved child ID, name, parent IDs, generation, realized inherited traits/color, the child's deterministic cognition seed, and remaining incubation seconds. The map contains living profiles and read-only deceased lineage records.

Version-5 loading validates the complete candidate record before changing the live habitat. Validation checks unique starter/child/egg IDs, known and distinct parent references, ancestry references and generation consistency, bounded traits/colors/timers/ages, positive lifespan limits, consistent living/deceased and death fields, a living focus when any Norn is alive (or an empty focus when none are alive), a monotonic next child number, and the four-slot limit across living Norns and eggs. Invalid data uses the current safe-reset path.

Versions 1–3 continue through their existing Mallow migration and deterministic Moss initialization. Version 4 restores both profiles' learning state unchanged and supplies adulthood defaults for the new fields. All four legacy versions create generation-zero adult Mallow and Moss with their established starter colors, no ancestry, no eggs, age 600 seconds, and `nextNornNumber = 1`.

## Verification

- Verify bounded population and parent selection, child IDs/names, deterministic inheritance, and fresh child learning state with focused checks.
- Verify incubation follows speed, pauses correctly, and hatches once into a separate active profile with correct ancestry and parent memories.
- Verify age follows speed and pause, each stage changes once at its threshold, only adults/elders can parent, and an old-age death is recorded once, frees a slot, and persists across load. Verify a pending egg still hatches after a parent dies and that an all-deceased world retains its archive.
- Verify version-5 round trips preserve living/deceased profiles, ages, focus, learning state, and partial egg progress; migrate versions 1–4; reject malformed identities, lineage, age/death fields, traits, colors, timers, and over-capacity saves without partially replacing the live world.
- Run the existing social, habitat, biochemistry, AVI-writer, and recording-retention checks.
- Record the actual family and lifespan flow in the rendered game. Use 2× simulation speed to show the real 45 in-game-second incubation without bypassing the hatch condition. Use saved ages near life-stage and old-age boundaries to capture real transitions in a short run. Inspect frames showing parent selection, egg progress, a growing child, its generation/parentage, the old-age death notification, and the retained family archive. Keep at most 10 completed clips and report the `user://recordings/` path.

## Constraints and builder choices

- Keep all state and computation local and deterministic.
- Preserve the current two starter identities and their existing saved learning through migration.
- Preserve dead Norns' identity and ancestry so later generations can still show complete parentage.
- Keep the family controls understandable and compact at the current 1280×720 window size.
- Use the browser prototype's family behavior as the baseline; the native version uses the existing Godot biochemistry, actor, and save architecture.

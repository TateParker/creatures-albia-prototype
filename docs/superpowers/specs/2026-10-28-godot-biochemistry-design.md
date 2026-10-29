# Godot Biochemistry Core — Design

**Status:** Approved by user on 2026-10-28

## Intent

Give the native Godot Norn a more causal, inspectable internal biology while keeping simulation local, deterministic, and responsive. Food, movement, rest, play, and social feedback should change named chemical concentrations through a small data-driven reaction network. Those chemicals should continue to drive the existing cognition policy, memories, and visible needs.

This is a first playable biochemical model, not a claim of physiological accuracy. It creates a foundation that can later be extended with inherited reaction definitions, organs, receptors, emitters, life stages, and more species.

## Current state

`godot/scripts/norn_cognition.gd` currently stores ten values in the 0–100 range: glucose, hunger, curiosity, fatigue, reward, punishment, stress, social comfort, arousal, and satiety. Its authored `REACTION_TABLE` and five `CHEMICAL_COUPLINGS` apply direct scalar changes at 10 Hz. Food, toy use, Praise, and Scold change those values directly inside `record_outcome`.

`AlbiaWorld` owns the 10 Hz scheduler, sends the chemical values into cognition decisions, and records local outcomes. `HabitatUi` displays six of the ten values. Version-2 local saves store cognition and typed vocabulary; the current browser/Godot cognition comparison tools expect the existing cognition-only chemistry behavior.

The original Genetics Kit describes a 256-slot chemical address space with named chemicals, reaction genes, half-lives, stimuli, emitters, and receptors. Its manual also lists a small metabolic chain including starch, glucose, glycogen, and energy. The Creatures technical paper describes the biochemistry as a simple metabolism and hormonal system rather than a chemically accurate body. [Genetics Kit manual](https://cdn.akamai.steamstatic.com/steam/apps/1838430/manuals/Genetics_Kit_Manual.pdf?t=1640163808), [Grand and Cliff, “Creatures: Entertainment Software Agents with Artificial Life”](https://www.cp.eng.chula.ac.th/~vishnu/gameResearch/AI/creatures.pdf).

The user-provided `Creatures 1996 With Today's Technology — Research Briefing.html` argues that current hardware can support much larger networks. This design keeps the first Godot network small and profiles it at the research brief's 12-Norn population target before expanding the model.

## Goals

- Add a scene-independent `NornBiochemistry` core with named compounds and authored reaction definitions.
- Make the existing ten cognition signals authoritative compounds in that core, so `NornCognition` continues to receive the same input shape.
- Add a bounded metabolic pathway for digestible food, glucose, stored glycogen, cellular energy, activity, and rest.
- Route food, toy, Praise, Scold, social interaction, and activity through named biochemical inputs and reactions rather than applying duplicate direct chemistry edits in the world adapter.
- Keep stepping deterministic at the existing 10 Hz fixed interval, with bounded catch-up and finite `[0, 100]` concentrations.
- Preserve existing learning, memory, vocabulary, decisions, and old saves.
- Show useful compound levels and reaction activity in an in-game Biochemistry view while retaining the current compact needs summary.
- Keep the model inexpensive enough to profile 12 independent Norn states locally.

## Non-goals

- Do not attempt a full port of every Creatures chemical or claim that the model is biologically realistic.
- Do not add a 256-entry empty array, genome mutation, organ damage, gene expression, life stages, fertility, pregnancy, eggs, immune populations, spatial chemical diffusion, or user-authored genetic editing in this milestone.
- Do not change the browser prototype or its cognition contract.
- Do not add cloud services, remote models, speech services, or runtime network access.
- Do not let biochemical impulses bypass the existing bounded action-association learning rules.
- Do not add a general automated test suite; use focused chemistry checks and the required rendered recording walkthrough.

## Approaches considered

1. **Extend the existing reaction and coupling tables.** This would be the smallest change, but each new behavior would continue to edit drive scalars directly and the model would remain tightly coupled to cognition.
2. **Add a separate data-driven biochemical core.** This adds a clear boundary between compound simulation and cognition, supports an explicit metabolism, and can scale by iterating only active reactions. This is the selected approach.
3. **Port a full Creatures-style biochemical/genetic framework now.** This would include the reaction system alongside genome expression, organs, receptors, emitters, and life stages. It has the highest fidelity, but it would combine several major game systems before the first metabolic loop has been evaluated.

## Design decisions

- Start with 18 active, named compounds: the existing ten cognition signals plus starch, glycogen, pyruvate, ATP, ADP, oxygen, carbon dioxide, and water. Use stable string IDs and a registry that can grow; do not allocate unused chemical slots in the first version.
- Keep concentrations in the current `[0, 100]` scale. The documented Creatures range can be mapped to `[0, 1]` for reaction calculations; the existing HUD and cognition ranges stay familiar.
- Store reaction definitions as plain data with named reactants/products, stoichiometric amounts, bounded rates, and optional stimulus gates. Evaluate each reaction from the same start-of-step snapshot, accumulate deltas, then apply bounded changes together so table order does not affect results.
- Use a deterministic concentration-dependent rate approximation. Limit each reaction's flux by available reactants and the fixed step to prevent negative concentrations or runaway production. Decay is represented as an explicit sink; a reaction cannot create products from nothing.
- Treat environmental/game events as named, bounded inputs: eating adds digestible starch; activity consumes available energy and raises fatigue; rest lowers fatigue and supports recovery; toy use provides a curiosity-satisfaction input; Praise and Scold add reward or punishment signals; teaching/social events affect social comfort. Authored reaction rules determine resulting concentrations.
- Keep `NornBiochemistry` independent of SceneTree, renderer, input, physics, UI, saving APIs, and random-number sources. `AlbiaWorld` supplies plain stimuli and event IDs.
- `NornCognition` continues to own decisions, association learning, and episodic memory. Its ten-key `chemistry` dictionary becomes a synchronized readout from the biochemical state. Game outcomes use an external-chemistry recording path so `record_outcome` does not apply the old direct chemistry effect a second time. The existing default chemistry path remains available to fixed-seed cognition reference scenarios.
- Save schema version 3 adds serialized biochemical state. Valid version-1 and version-2 saves create a compatible biochemical state from their existing ten chemistry values, preserve cognition/language learning, and initialize new nutrient compounds to safe defaults. Version-3 restore validates compound IDs, finite concentration bounds, and record version before replacing live state.
- The compact HUD keeps hunger, curiosity, fatigue, glucose/energy, reward, and stress. An expandable Biochemistry view lists the 18 compounds and recent per-step reaction fluxes; it is an inspection view, not an action editor.
- Profile one, four, and twelve independent biochemical states at 10 Hz. The implementation should report cost alongside existing frame/update measurements before any increase in the number of active compounds or reaction rules.

## Integration shape

`NornBiochemistry` should expose scene-independent operations equivalent to:

- `create_state(initial_signals: Dictionary = {}) -> Dictionary`
- `advance(state: Dictionary, stimuli: Dictionary, dt: float) -> Dictionary`
- `apply_event(state: Dictionary, event_id: String, strength: float = 1.0) -> Dictionary`
- `read_signals(state: Dictionary) -> Dictionary`
- `serialize_state(state: Dictionary) -> Dictionary`
- `restore_state(record: Variant) -> Dictionary`
- `migrate_from_legacy_signals(signals: Dictionary) -> Dictionary`

The world adapter owns the existing 10 Hz accumulator. For each chemistry step it gathers activity/resting stimuli, advances biochemistry, synchronizes the ten readouts into cognition, and then lets the existing 5 Hz decision loop run. On food, toy, feedback, and teaching events, the world records the pre-event signal snapshot, applies the corresponding biochemical input, reads the post-event signals, and passes both snapshots to cognition for an episode plus its existing learning update.

The first authored pathway should cover digestion and energy use: starch is converted into glucose; glucose can be stored as glycogen or mobilized; glucose and oxygen support pyruvate/ATP production with carbon dioxide and water as waste; movement consumes ATP and produces ADP; rest recovers fatigue while stored energy is available. Drive and feedback signals continue through the same compound/reaction mechanism. Rates and event amounts remain authored constants for this version, not inheritable genes.

## Acceptance criteria

- Identical initial compound state, stimuli, events, and fixed steps produce identical results.
- All stored concentrations and reaction outputs stay finite and within `[0, 100]`; depleted substrates cannot go negative and reaction-table order does not change a step's result.
- Eating changes the nutrient/energy pathway and reduces hunger over subsequent chemistry steps; activity consumes energy and increases fatigue; rest recovers fatigue; toy use, Praise, Scold, and teaching produce their intended signal changes.
- The existing Norn policy still consumes exactly its ten chemistry keys, retains its action IDs and bounded learning, and remains consistent with the fixed-seed cognition reference scenarios.
- Version-1 and version-2 saves still load with their learned state intact; version-3 saves round-trip every compound and current cognition readout. Invalid biochemical records fall back through the existing safe-save path.
- The rendered recording walkthrough visibly shows a food/activity/rest/feedback sequence and the Biochemistry view. Inspect the clip, verify its AVI frames/index, and keep at most 10 clips.
- Measure 10 Hz biochemical update cost with 1, 4, and 12 states and confirm it remains suitable for local real-time use on the current development machine.

## Source notes

- User-provided research briefing: `C:/Users/Quad/Downloads/Creatures 1996 With Today's Technology — Research Briefing.html` (used as design input; its compute projections are targets to profile, not established measurements for this implementation).
- Gameware Development, *Creatures Genetics Kit Manual*, biochemical gene types and chemical reference, pp. 32–44; official manual linked above.
- Stephen Grand and Dave Cliff, “Creatures: Entertainment Software Agents with Artificial Life,” *Autonomous Agents and Multi-Agent Systems* 1 (1998), pp. 39–57; paper linked above.

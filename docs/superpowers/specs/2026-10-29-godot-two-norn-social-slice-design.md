# Godot Two-Norn Social Slice — Design

## Intent

Make social attention part of the playable Godot habitat by adding a second autonomous Norn. Both Norns should meet their own needs, notice one another, approach to observe, and learn from events they actually witness. This turns the current peer-comfort chemistry and `observe_peer` cognition action into visible gameplay.

## Current state

`AlbiaWorld` creates one Norn named Mallow and keeps one cognition, biochemistry, language, and feedback state. Each cognition decision receives an empty `nearbyNorns` list, and peer comfort is always stepped with `nearbyPeer = 0`. `NornCognition` already scores `observe_peer` and can record `observe` and `observe-feedback` episodes, but `NornActor` only walks to interactable objects. The HUD and local save also assume a single Norn.

## Goals

- Run Mallow and Moss as two independently thinking Norns with separate cognition, biochemistry, language vocabulary, feedback eligibility, and memories.
- Let both Norns choose food, play, rest, and peer observation while sharing the same habitat objects.
- Sense the other Norn with a bounded distance and line-of-sight check. Feed nearby peers into cognition and nearby-peer chemistry instead of placeholder values.
- Make `observe_peer` visible: an interested Norn approaches a peer and settles at a comfortable distance to watch.
- Record behavioral observation only when the Norn is attending and can see a peer's successful food/play event or player feedback. Use the existing observation learning rules and episode memories so learning remains tied to a real event.
- Let the player switch the focused Norn from the HUD. Guidance, teaching, Praise, and Scold apply to the focused Norn; both Norns continue simulating.
- Save and restore both Norns locally. Migrate version 1, 2, and 3 saves by preserving Mallow and creating Moss with a deterministic starter state.
- Keep the simulation local and deterministic, and verify the gameplay in a rendered recording.

## Non-goals

- More than two Norns, breeding, eggs, or inherited traits.
- Relationships, friendship scores, dominance, social hierarchies, or new personality systems beyond existing traits and compounds.
- Peer-to-peer vocabulary teaching, new words, generated dialogue, or spoken audio.
- Multiplayer, remote services, or machine-learning inference.

## Approaches

1. **Peer comfort only.** Add a second visual Norn and increase comfort when they are near. This is the smallest change, but would not use the existing observation action or show social learning.
2. **Two independent Norns with attentive observation (selected).** Give each Norn its own state and decision loop, add peer perception and approach movement, and record observed outcomes only when the observer has approached and is in range with line of sight. This is the approved direction because it makes the existing social cognition visible and keeps learning grounded in witnessed events.
3. **Full social model.** Add persistent relationships, vocabulary transfer, and expanded population systems. This has more depth but exceeds the approved two-Norn gameplay milestone.

## Behavior

Both Norns are present from a new run, have distinct names and appearance, and move independently toward shared fruit and spinner objects. At each decision step, each Norn receives its own chemistry, sensed objects, and nearby peers. When peer observation wins its decision, the Norn moves toward that peer, then remains nearby and visibly attentive. Urgent food or rest needs can still take priority.

Being near a peer activates the existing peer-comfort reaction. A successful food or spinner event, or an eligible Praise/Scold event, is offered to the other Norn only when it is in observation range, has line of sight, and is currently attending. The observer records an `observe` or `observe-feedback` episode that names the source actor and action. `NornCognition.record_outcome` supplies the existing sociability-weighted learning amount and memory; failed, distant, blocked, or unattended observation produces no learning.

The HUD identifies the focused Norn and provides a simple switch between Mallow and Moss. Existing direct player actions affect that Norn only. The other Norn keeps acting autonomously. The selected Norn's state is shown in the HUD and all other state remains independent.

Save version 4 stores both complete per-Norn states. Versions 1 through 3 retain Mallow's saved cognition and language and migrate its chemistry as today; migration seeds Moss from a fixed peer seed so old saves gain the same reproducible companion. Invalid data still follows the existing safe-reset path.

## Constraints and builder choices

- Keep two Norns as the fixed population for this slice; do not add population management UI.
- Reuse the existing deterministic cognition, chemistry, and language modules. Keep any new random behavior on the Norn's saved local state; prefer the existing deterministic observation update when no probability is needed.
- Keep shared object availability and respawn behavior. If both Norns target one object, the first valid arrival consumes it and the other re-decides.
- Keep camera and HUD readable with both Norns visible. The builder may choose compact focus buttons or a small selector, but the selected name must be clear before a player action is applied.
- Choose and document the observation radius, comfortable stopping distance, Moss seed/traits, starting position, and visual distinction after checking the habitat scale. These values should make the rendered walkthrough reliably show a real approach and observation.
- Preserve local save compatibility for versions 1 through 3.

## Verification outcomes

- Both Norns appear, can be focused separately, and continue autonomous activity while the other is selected.
- Peer perception includes only a nearby, visible partner; peer comfort changes from proximity and returns toward baseline after separation.
- An attentive observer can approach, observe a successful peer action and feedback, and gain only the matching behavioral association and a memory naming the source actor and action. Unattended, occluded, or out-of-range peers do not learn.
- Mallow and Moss state, language, and feedback windows remain separate after direct player actions and across save/load.
- Version 1, 2, and 3 saves migrate safely to version 4; malformed saves take the safe-reset path.
- A rendered gameplay clip visibly demonstrates both Norns and an observation event, is inspected after capture, and respects the 10-clip retention cap.

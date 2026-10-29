# New Albia — Godot 3D Slice

This native 3D project runs alongside the browser prototype. It targets Godot 4.7.2-stable Standard and keeps the browser version playable as the cognition reference.

## Open and run

Open this `godot/` folder in Godot 4.7.2-stable Standard, or launch it from PowerShell:

```powershell
Godot_v4.7.2-stable_win64.exe --path .\godot
```

Run the command examples in this guide from the repository root; they use `--path .\godot` so `res://` paths resolve against the native Godot project.

The current vertical slice starts with two independently simulated Norns, Mallow and Moss, in a small shared habitat with honey fruit, a wind-up spinner, local biochemistry and recurrent cognition, player guidance, Praise/Scold, typed vocabulary teaching, family pairing, and local JSON save/load. The living roster can grow to four Norns including unhatched eggs. All living Norns continue to act while one is focused. A Norn with high social attention can approach and watch another; witnessed food, play, Praise, and Scold events can change its learning, chemistry, and remembered moments.

## Controls

- Choose a living Norn from the HUD roster to focus them. Direct player actions and the HUD's age, stage, needs, biochemistry, vocabulary, and remembered moments follow the focused Norn; everyone else keeps simulating.
- Use **Guide to fruit** or **Guide to spinner** to direct the focused Norn for up to seven in-game seconds.
- **Praise** or **Scold** becomes available after the focused Norn eats or plays. One response can be applied within 12 in-game seconds.
- Select **Teach word**, type one word (up to 24 characters), then choose **Teach fruit**, **Teach spinner**, **Teach Praise**, or **Teach Scold**. Vocabulary belongs to the focused Norn. Teaching the same word and meaning again builds confidence; the Norn uses it in the status when confidence reaches 0.60. A word cannot be reassigned to another meaning.
- Outside Teach mode, Praise raises the matching fruit or spinner word confidence by 0.14; Scold lowers it by 0.14. Teaching Praise/Scold words does not apply behavior feedback.
- Choose **Biochemistry** to open the read-only, scrollable inspector. It shows all 18 named compound concentrations and up to six largest non-zero reaction fluxes from the latest chemistry step. The compact Needs/Body summary stays on the HUD.
- **Pause** or press **Space**. **Speed** cycles through 0.5×, 1×, and 2×.
- Move the observer camera with **WASD** or the arrow keys; use the mouse wheel to zoom.
- Use **Save**, **Load**, or **Reset** in the HUD.
- Pair the focused adult or elder with another eligible living adult or elder in **Family and eggs**, then choose **Start family egg**. The family panel shows each egg's incubation progress and the living-plus-egg population count.
- Use **Record video** to capture the running habitat, including the HUD. Select **Stop recording** to finalize the local AVI; use **Open recordings** to browse saved clips.

The save file is `user://albia_norn_save.json`, inside Godot's per-project user data directory. Version-5 saves include every living or deceased family profile, lineage, life state, partial incubation, cognition, biochemistry, language, feedback, focus, and simulation time. Version-1 through version-4 saves migrate with their existing learning and chemistry intact; profiles without family metadata receive deterministic founder defaults. No cloud service, remote model, runtime network access, speech input, or speech output is used by the Godot slice. The browser prototype remains the reference for voice features.

## Family and lifespan

Each Norn's life advances in simulation time, so pause and the 0.5×, 1×, and 2× speed controls affect aging and egg incubation along with the rest of the world. The deterministic stages are **Baby** from birth to 60 seconds, **Child** from 60 to 180 seconds, **Adolescent** from 180 to 420 seconds, **Adult** from 420 to 3,000 seconds, and **Elder** from 3,000 seconds until death. Seeded lifespans range from 3,300 to 3,900 simulated seconds, about 55 to 65 minutes at 1× speed. Old age is the only implemented cause of death; reaching the lifespan removes the living actor while preserving the deceased profile and family history.

Living adults and elders can pair with another living adult or elder. Pairing creates one 45-simulated-second egg, records both parents, and deterministically derives the child's name, seed, traits, and blended body color. Living Norns plus eggs share a limit of four. Eggs continue incubating if a parent dies. When a Norn dies, focus moves to another living family member when one exists; a read-only archive retains deceased relatives and lineage. Eggs can continue when no Norn is alive. When both the living roster and egg list are empty, the extinction panel preserves the archive until the player explicitly starts a new run.

## Biochemistry

Each Norn owns 18 bounded concentrations from 0 to 100: the ten cognition signals plus starch, glycogen, pyruvate, ATP, ADP, oxygen, carbon dioxide, and water. Eating, toy play, Praise, Scold, word teaching, and nearby peers add named inputs. Data-authored reactions digest and store fuel, produce or use energy, recover fatigue, and decay short-lived drives and feedback signals. The biochemical core stays local and deterministic; `AlbiaWorld` advances each profile every 0.1 simulated seconds, synchronizes the original ten signals into that Norn's cognition, and caps catch-up at five chemistry steps per rendered frame.

The **Biochemistry** HUD button opens the 340-by-600 read-only inspector without resizing the existing HUD. Concentrations appear in stable registry order. The lower section lists the six largest non-zero fluxes from the latest step. The inspector is for observing the simulation and does not edit chemical values.

Video recordings are saved under `user://recordings/` as local Motion JPEG AVI files at 1280×720 and 15 FPS. They contain video only. Godot's viewport is sampled while the simulation continues, including while paused; no external encoder or network service is required. The **Open recordings** button opens the local output folder. The game keeps at most 10 completed AVI clips; after a new clip is finalized, it removes the oldest filename timestamps until the folder is back under the limit.

## Cognition reference

`scripts/norn_cognition.gd` is a scene-independent port of the browser cognition core. `scenarios/browser_reference.json` captures fixed-seed decisions and outcomes. To print the Godot side of that scenario for manual comparison:

```powershell
Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/print_cognition_reference.gd
```

The Godot version is a vertical slice, not a full remake. It has one screen and primitive authored meshes, with a small deterministic family simulation rather than the browser prototype's larger connected habitat.

For a repeatable interaction walkthrough in a temporary headless run, use `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`. It observes autonomous and player-guided trips to both objects, focused actions and teaching, independent biochemistry and persistence, pause behavior, version-1 through version-5 migrations, old-age death, archive/focus restoration, and malformed-save recovery while restoring any save file that existed before the walkthrough. Run the dedicated family/lifespan model and UI assertions with `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_family_system.gd`, and the two-Norn social checks with `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_social_slice.gd`.

To record a rendered verification walkthrough, run `Godot_v4.7.2-stable_win64.exe --path .\godot --script res://tools/record_preview.gd`. It checks the initial HUD/camera clearance; teaches fruit, spinner, Praise, and Scold words through the HUD; checks invalid/conflicting words, confidence changes, utterance thresholds, Praise/Scold reinforcement, save/load migration, and biochemistry; guides Mallow to fruit and the spinner; applies feedback; prepares a bounded high-fatigue rest scenario; shows Moss approach Mallow, observe a fruit action, gain social comfort and a fruit association, and recall the observation; then pairs Mallow and Moss, displays their egg's advancing incubation, waits for the full 45-second hatch, shows the child's name, stage, and age, and advances Mallow through an old-age death with focus fallback and an archived family entry. The closing frames show the archived relative and death notice together. It restores any previous local save and saves a clip in `user://recordings/`.

To validate and inspect a real recorded clip, run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/inspect_recording.gd -- <path-to-clip> [frame-output-folder]`. The inspector checks the finalized RIFF/AVI header and index, decodes every JPEG frame at 1280×720, and saves 16 sample PNGs in the chosen folder (or `%TEMP%\albia-recording-frames` if omitted). To verify the AVI writer's container, index, and decoded JPEG frame, run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_avi_writer.gd`. To verify oldest-clip retention, run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_recording_retention.gd`.

The rendered family/lifespan walkthrough verified on 2026-10-29 as `user://recordings/habitat-20261029-094939.avi`: 590 frames at 1280×720; all 590 JPEGs decoded and all index entries validated. Inspected frames 0236 and 0295 show Sprout's incubation progressing from 4% to 22%; frame 0560 shows Sprout focused at age 60.1 seconds and Child stage; frame 0565 shows age 60.8 seconds and Child stage; frame 0571 shows Mallow's old-age archive entry and death notice together. The recordings folder contained 10 completed clips after capture.

Run the scene-independent biochemistry checks with `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_biochemistry.gd`, and the world, learning, save, and migration scenario with `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`.

To profile the rendered one-Norn scene at a real 60 FPS cap, run `Godot_v4.7.2-stable_win64.exe --path .\godot --scene res://tools/profile_scene.tscn --max-fps 60`. It samples frame interval, world-update work, and Norn movement work for 600 frames. To measure cognition separately, run `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/profile_cognition.gd`. It reports median, p95, and maximum microseconds for the 10 Hz chemistry and 5 Hz decision functions.

To measure the 10 Hz biochemical step and ten-signal cognition synchronization for 1, 4, and 12 independent Norns, run `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/profile_biochemistry.gd`. It warms up the model, checks state isolation and identical input results, then collects 1,000 samples per population and enforces a 1 ms p95 budget for 12 Norns.

### Reference profile

Measured on 2026-10-28 with Godot 4.7.2-stable on Windows 10 Pro, AMD Ryzen 7 5700X (8 cores / 16 threads), AMD Radeon RX 6750 XT, GL Compatibility renderer, and a 1280×720 window. The one-Norn / two-interactable scene ran for 600 frames at a 60 FPS cap: frame interval median 16.665 ms, p95 16.842 ms, maximum 17.283 ms; `AlbiaWorld` update work p95 0.395 ms; Norn movement physics p95 0.045 ms. The fixed-seed cognition profile measured 10 Hz chemistry p95 30 μs and 5 Hz decisions p95 306 μs. This is one local session; the FPS cap is 60 and frame pacing varies with display refresh and background load.

On 2026-10-29, the 1,000-sample biochemical profile on this same workstation measured 10 Hz chemistry plus synchronization of its ten signals into cognition. The latest run reported: 1 state median 40 μs / p95 49 μs / maximum 139 μs; 4 states 164 / 252 / 733 μs; 12 states 536.5 / 791 / 1,113 μs. The 12-state p95 stayed below the 1 ms budget. This measures the chemistry step and signal synchronization, not the separate 5 Hz cognition decisions or rendering, and is one local run subject to background load.

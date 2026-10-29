# New Albia — Godot 3D Slice

This native 3D project runs alongside the browser prototype. It targets Godot 4.7.2-stable Standard and keeps the browser version playable as the cognition reference.

## Open and run

Open this `godot/` folder in Godot 4.7.2-stable Standard, or launch it from PowerShell:

```powershell
Godot_v4.7.2-stable_win64.exe --path .\godot
```

Run the command examples in this guide from the repository root; they use `--path .\godot` so `res://` paths resolve against the native Godot project.

The current vertical slice contains two independently simulated Norns, Mallow and Moss, in a small shared habitat with honey fruit, a wind-up spinner, local biochemistry and recurrent cognition, player guidance, Praise/Scold, typed vocabulary teaching, and local JSON save/load. Both Norns continue to act while one is focused. A Norn with high social attention can approach and watch the other; witnessed food, play, Praise, and Scold events can change its learning, chemistry, and remembered moments.

## Controls

- Choose **Mallow** or **Moss** at the top of the HUD to focus that Norn. Direct player actions and the HUD's needs, biochemistry, vocabulary, and remembered moments follow the focused Norn; the other Norn keeps simulating.
- Use **Guide to fruit** or **Guide to spinner** to direct the focused Norn for up to seven in-game seconds.
- **Praise** or **Scold** becomes available after the focused Norn eats or plays. One response can be applied within 12 in-game seconds.
- Select **Teach word**, type one word (up to 24 characters), then choose **Teach fruit**, **Teach spinner**, **Teach Praise**, or **Teach Scold**. Vocabulary belongs to the focused Norn. Teaching the same word and meaning again builds confidence; the Norn uses it in the status when confidence reaches 0.60. A word cannot be reassigned to another meaning.
- Outside Teach mode, Praise raises the matching fruit or spinner word confidence by 0.14; Scold lowers it by 0.14. Teaching Praise/Scold words does not apply behavior feedback.
- Choose **Biochemistry** to open the read-only, scrollable inspector. It shows all 18 named compound concentrations and up to six largest non-zero reaction fluxes from the latest chemistry step. The compact Needs/Body summary stays on the HUD.
- **Pause** or press **Space**. **Speed** cycles through 0.5×, 1×, and 2×.
- Move the observer camera with **WASD** or the arrow keys; use the mouse wheel to zoom.
- Use **Save**, **Load**, or **Reset** in the HUD.
- Use **Record video** to capture the running habitat, including the HUD. Select **Stop recording** to finalize the local AVI; use **Open recordings** to browse saved clips.

The save file is `user://albia_norn_save.json`, inside Godot's per-project user data directory. Version-4 saves include both Norns' independent cognition, biochemistry, language, and feedback state, along with the focused Norn and simulation time. Version-1, version-2, and version-3 saves preserve Mallow's saved learning and start Moss from its deterministic seed; older saves without biochemistry migrate the available chemistry signals. No cloud service, remote model, runtime network access, speech input, or speech output is used by the Godot slice. The browser prototype remains the reference for voice features.

## Biochemistry

Each Norn owns 18 bounded concentrations from 0 to 100: the ten cognition signals plus starch, glycogen, pyruvate, ATP, ADP, oxygen, carbon dioxide, and water. Eating, toy play, Praise, Scold, word teaching, and nearby peers add named inputs. Data-authored reactions digest and store fuel, produce or use energy, recover fatigue, and decay short-lived drives and feedback signals. The biochemical core stays local and deterministic; `AlbiaWorld` advances each profile every 0.1 simulated seconds, synchronizes the original ten signals into that Norn's cognition, and caps catch-up at five chemistry steps per rendered frame.

The **Biochemistry** HUD button opens the 340-by-600 read-only inspector without resizing the existing HUD. Concentrations appear in stable registry order. The lower section lists the six largest non-zero fluxes from the latest step. The inspector is for observing the simulation and does not edit chemical values.

Video recordings are saved under `user://recordings/` as local Motion JPEG AVI files at 1280×720 and 15 FPS. They contain video only. Godot's viewport is sampled while the simulation continues, including while paused; no external encoder or network service is required. The **Open recordings** button opens the local output folder. The game keeps at most 10 completed AVI clips; after a new clip is finalized, it removes the oldest filename timestamps until the folder is back under the limit.

## Cognition reference

`scripts/norn_cognition.gd` is a scene-independent port of the browser cognition core. `scenarios/browser_reference.json` captures fixed-seed decisions and outcomes. To print the Godot side of that scenario for manual comparison:

```powershell
Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/print_cognition_reference.gd
```

The Godot version is a vertical slice, not a full remake. This build has two Norns, one screen, and primitive authored meshes; it does not yet include population management or family simulation. The browser prototype retains its larger connected habitat and broader family and language systems.

For a repeatable interaction walkthrough in a temporary headless run, use `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`. It observes autonomous and player-guided trips to both objects, focused actions and teaching, independent biochemistry and persistence, pause behavior, legacy migrations, and malformed-save recovery while restoring any save file that existed before the walkthrough. Run the dedicated two-Norn social checks with `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_social_slice.gd`.

To record a rendered verification walkthrough, run `Godot_v4.7.2-stable_win64.exe --path .\godot --script res://tools/record_preview.gd`. It checks the initial HUD/camera clearance; teaches fruit, spinner, Praise, and Scold words through the HUD; checks invalid/conflicting words, confidence changes, utterance thresholds, Praise/Scold reinforcement, save/load migration, and biochemistry; guides Mallow to fruit and the spinner; applies feedback; prepares a bounded high-fatigue rest scenario; then shows Moss approach Mallow, observe a fruit action, gain social comfort and a fruit association, and recall the observation in the focused HUD. It restores any previous local save and saves a clip in `user://recordings/`. Inspect the resulting video or extracted frames. To verify the AVI writer's container, index, and decoded JPEG frame, run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_avi_writer.gd`. To verify oldest-clip retention, run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_recording_retention.gd`.

The rendered two-Norn walkthrough verified on 2026-10-29 as `user://recordings/habitat-20261029-012127.avi`: 227 frames at 1280×720, with all JPEG frames decoded and the AVI index validated. Inspected frames show both Norns, the observation memory, Praise memory, and the live chemistry inspector. The recordings folder contained 10 completed clips after capture.

Run the scene-independent biochemistry checks with `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_biochemistry.gd`, and the world, learning, save, and migration scenario with `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`.

To profile the rendered one-Norn scene at a real 60 FPS cap, run `Godot_v4.7.2-stable_win64.exe --path .\godot --scene res://tools/profile_scene.tscn --max-fps 60`. It samples frame interval, world-update work, and Norn movement work for 600 frames. To measure cognition separately, run `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/profile_cognition.gd`. It reports median, p95, and maximum microseconds for the 10 Hz chemistry and 5 Hz decision functions.

To measure the 10 Hz biochemical step and ten-signal cognition synchronization for 1, 4, and 12 independent Norns, run `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/profile_biochemistry.gd`. It warms up the model, checks state isolation and identical input results, then collects 1,000 samples per population and enforces a 1 ms p95 budget for 12 Norns.

### Reference profile

Measured on 2026-10-28 with Godot 4.7.2-stable on Windows 10 Pro, AMD Ryzen 7 5700X (8 cores / 16 threads), AMD Radeon RX 6750 XT, GL Compatibility renderer, and a 1280×720 window. The one-Norn / two-interactable scene ran for 600 frames at a 60 FPS cap: frame interval median 16.665 ms, p95 16.842 ms, maximum 17.283 ms; `AlbiaWorld` update work p95 0.395 ms; Norn movement physics p95 0.045 ms. The fixed-seed cognition profile measured 10 Hz chemistry p95 30 μs and 5 Hz decisions p95 306 μs. This is one local session; the FPS cap is 60 and frame pacing varies with display refresh and background load.

On 2026-10-29, the 1,000-sample biochemical profile on this same workstation measured 10 Hz chemistry plus synchronization of its ten signals into cognition. The latest run reported: 1 state median 40 μs / p95 49 μs / maximum 139 μs; 4 states 164 / 252 / 733 μs; 12 states 536.5 / 791 / 1,113 μs. The 12-state p95 stayed below the 1 ms budget. This measures the chemistry step and signal synchronization, not the separate 5 Hz cognition decisions or rendering, and is one local run subject to background load.

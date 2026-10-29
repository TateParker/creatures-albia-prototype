# Godot Developmental Behavior Verification Ledger

- Date: 2026-10-29
- Project: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`
- Godot: 4.7.2.stable.mono.official
- Verification scope: baby parent following and child observation learning

## Rendered gameplay capture

Capture: `user://recordings/habitat-20261029-102149.avi`

The rendered walkthrough paired Mallow and Moss, hatched Sprout, settled the baby beside a living parent, aged Sprout into the child stage, and staged a witnessed Mallow fruit event. It then continued through Mallow's old-age death and archive entry. The script checks baby following and HUD reason, compares child learning with the 1.5× adult baseline, and confirms the remembered event. The recording restored the user's prior local save.

## AVI validation and visual inspection

Result: `AVI_INSPECTION_OK frames=613 decoded=613 dimensions=1280x720 sampled=16`. The inspector validated the AVI index and decoded all 613 frames.

Inspected samples extracted to `%TEMP%\albia-recording-frames`:

- `frame-0575-of-0612.png`: Sprout is selected as a Baby; the HUD says “Following their parent, Mallow,” and the baby stands beside Mallow.
- `frame-0588-of-0612.png`: Sprout is selected at Child stage and its remembered moments include “Sprout observed Mallow fruit.”
- `frame-0606-of-0612.png`: the scrolled HUD shows Mallow's archived old-age entry and death notice together; Moss is focused.

The recordings folder contained 9 completed clips after capture, below the 10-clip limit.

## Supporting checks

All checks ran sequentially from the repository root using the local Godot 4.7.2 Mono console executable.

| Check | Result |
| --- | --- |
| `--headless --path .\godot --script res://tools/verify_social_slice.gd` | `SOCIAL_SLICE_CHECKS_OK` |
| `--headless --path .\godot --script res://tools/verify_family_system.gd` | `FAMILY_SYSTEM_CHECKS_OK` |
| `--headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd` | `HABITAT_SCENARIO_OK`; includes save/load, v1–v5 migration, lifecycle, malformed-save, and restore checks |
| `git diff --check` | Passed; Git reports only line-ending conversion notices for modified files |

No save schema or persisted state fields changed. The existing version-5 format remains in use.
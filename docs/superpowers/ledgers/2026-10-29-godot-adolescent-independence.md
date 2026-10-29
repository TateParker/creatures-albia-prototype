# Godot Adolescent Independence Verification Ledger

- Date: 2026-10-29
- Project: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`
- Godot: 4.7.2.stable.mono.official
- Verification scope: adolescent non-parent peer preference and rendered family walkthrough

## Rendered gameplay capture

- Capture: `user://recordings/habitat-20261029-105017.avi`
- Local file: `C:\Users\Quad\AppData\Roaming\Godot\app_userdata\New Albia — Godot 3D Slice\recordings\habitat-20261029-105017.avi`
- Capture output: `VIDEO_CAPTURE_OK frames=959`
- Scenario assertion: `ADOLESCENT_INDEPENDENCE_CAPTURE_OK adolescent=Sprout peer=Clover parentDistance=3.00 peerDistance=4.20 reasonVisible=true`
- Later family assertion: `FAMILY_LIFESPAN_CAPTURE_OK incubation=45.032s childAge=61.2s stage=adolescent death=old-age noticeVisible=true focus=moss`

The rendered walkthrough created Clover through the family egg controls, aged Sprout into adolescence through the normal world tick, then confirmed that the nearer parent Mallow and the sibling Clover were both visible. Sprout selected Clover and the HUD named Clover in the observation reason. It continued through the existing lifespan and family archive scenario. The script restored the previous local save.

## AVI validation and visual inspection

Result: `AVI_INSPECTION_OK frames=959 decoded=959 dimensions=1280x720 sampled=16`. The inspector decoded every JPEG frame and validated the final AVI index.

Inspected samples in `C:\Temp\albia-adolescent-independence-frames`:

- `frame-0935-of-0958.jpg`: Sprout is focused as an Adolescent; the HUD shows “Sprout is observing peer” and “Observing peer Clover beyond the family.”
- `frame-0948-of-0958.png`: Mallow's archived old-age entry and death notice are visible together, with Moss focused.

The recordings folder contained 10 completed clips after capture. The retention rule removed the oldest clip, `habitat-20261029-024128.avi`, before the new clip was retained.

## Supporting checks

All checks ran sequentially from the repository root using Godot 4.7.2 Mono.

| Check | Result |
| --- | --- |
| `--headless --path .\godot --script res://tools/verify_social_slice.gd` | `SOCIAL_SLICE_CHECKS_OK` |
| `--headless --path .\godot --script res://tools/verify_family_system.gd` | `FAMILY_SYSTEM_CHECKS_OK` |
| `--headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd` | `HABITAT_SCENARIO_OK`; includes save/load, v1–v5 migration, lifecycle, malformed-save, and restore checks |
| Rendered `res://tools/record_preview.gd` | `VIDEO_CAPTURE_OK`; the adolescent, sibling, HUD reason, and final archive assertions succeeded |
| `res://tools/inspect_recording.gd` | `AVI_INSPECTION_OK frames=959 decoded=959 dimensions=1280x720 sampled=16` |

## Diagnosis and review

The first rendered attempts found no visible peers after actors were repositioned. A temporary scene diagnostic showed that visibility-ray queries had no hits after one physics frame, but both the closer parent and sibling became visible after a second frame. The walkthrough now waits, with a 2-second bound, until both peers are visible before running the decision assertion. No production targeting behavior was changed to work around capture timing.

The focused social verifier covers nearest visible non-parent selection, fallback when no non-parent is visible, and preserved guidance and need priorities. The family and habitat checks pass. The final `git diff --check` exited 0; Git only reported its standard LF-to-CRLF conversion notices. A self-review covered the changed gameplay code, verifier, rendered walkthrough, README, and ledger.

Final review: self-review only; no subagent was authorized or used.

No save schema, persisted fields, or save version changed. The existing version-5 format remains in use.

# Godot Family and Lifespan Verification Ledger

- Date: 2026-10-29
- Project: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`
- Godot: 4.7.2.stable.mono.official
- Renderer: OpenGL 3.3 Compatibility on AMD Radeon RX 6750 XT
Base commit: `1b683468308884e087dd94177c69b9fd71f98d9e`

## Rendered gameplay capture

Command:

```powershell
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path godot --script res://tools/record_preview.gd
```

Result:

```text
FAMILY_LIFESPAN_CAPTURE_OK incubation=45.000s childAge=61.2s stage=child death=old-age noticeVisible=true focus=moss archive=Mallow · Generation 0 · old age at age 3538 s childParents=["mallow", "moss"]
VIDEO_CAPTURE_OK frames=590 path=user://recordings/habitat-20261029-094939.avi flow=teach-fruit-food-spinner-activity-praise-scold-rest-social-observation-family-egg-hatch-stage-death-archive-save-load-migrations
```

The real rendered walkthrough created Mallow and Moss's egg through the HUD, advanced the complete 45-second simulation timer at 2×, hatched Sprout, crossed the 60-second child boundary through the normal world tick, and aged Mallow to the saved lifespan through the normal world tick. It confirmed Sprout's parent IDs, the old-age death notice, Mallow's archived record, and focus fallback to Moss. The preview restores the user's prior local save on both success and failure paths.

## AVI decode and frame inspection

Command:

```powershell
$recordingsPath = Join-Path $env:APPDATA 'Godot\app_userdata\New Albia — Godot 3D Slice\recordings'
$clipPath = Join-Path $recordingsPath 'habitat-20261029-094939.avi'
$frameOutput = Join-Path $env:TEMP 'albia-family-frames-approved-final'
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/inspect_recording.gd -- $clipPath $frameOutput
```

Result: `AVI_INSPECTION_OK frames=590 decoded=590 dimensions=1280x720 sampled=16`. The inspector validated the RIFF/AVI header, frame counts, index entries and frame offsets, decoded every embedded JPEG, and extracted 16 PNG samples.

Inspected frames:

- `frame-0236-of-0589.png`: named Sprout egg at 4% with 43.0 seconds remaining; Mallow and Moss appear as the two founders.
- `frame-0295-of-0589.png`: same egg at 22% with 35.1 seconds remaining.
- `frame-0554-of-0589.png`: incubation at 99% with 0.6 seconds remaining.
- `frame-0560-of-0589.png`: Sprout is selected; the HUD shows age 60.1 seconds and Child, and the child is visibly smaller than the adult founders.
- `frame-0565-of-0589.png`: Sprout remains selected at age 60.8 seconds and Child.
- `frame-0571-of-0589.png`: the scrolled HUD shows `Mallow · Generation 0 · old age at age 3538 s` and `Mallow reached old age and died.` together; Moss is focused and Sprout remains in the habitat.

The AVI is 590 frames at 15 FPS (about 39.3 seconds) and 1280×720. After capture and retention pruning, `user://recordings/` contained 10 completed clips; the new AVI remained in the folder.

## Supporting checks

All commands below ran from the repository root with this executable:

```powershell
$godot = 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe'
```

The following arguments were run with `& $godot`:

| Command | Result |
| --- | --- |
| `--headless --path godot --script res://tools/verify_family_system.gd` | `FAMILY_SYSTEM_CHECKS_OK` |
| `--headless --fixed-fps 60 --path godot --script res://tools/run_habitat_scenario.gd` | `HABITAT_SCENARIO_OK`; includes `LIFECYCLE SAVE/LOAD: deceased=true; deathNotice=true; archived=true; archiveUI=true; focus=moss; focusUI=true; egg=true` and v1–v5 migrations |
| `--headless --path godot --script res://tools/verify_biochemistry.gd` | `BIOCHEMISTRY_CHECKS_OK` |
| `--headless --path godot --script res://tools/verify_avi_writer.gd` | `AVI_WRITER_OK frames=2 dimensions=64x64` |
| `--headless --path godot --script res://tools/verify_recording_retention.gd` | `VIDEO_RETENTION_OK limit=10 removed=2 new_clip_kept=true` |
| `--path godot --quit-after 30` | Exit code 0; rendered main scene started under OpenGL Compatibility without errors |
| `git diff --check` | Passed; Git only reported the repository's existing LF-to-CRLF working-copy notices |

The retention verifier used an isolated temporary folder. The actual recordings folder was separately counted after rendered capture and contained exactly 10 AVI clips.

## Issues found and resolved during the walkthrough

- The death handler set its notice before saving, and `save_game()` replaced it with a generic save confirmation. A scenario regression now checks the death notice, and the handler reapplies the notice after saving so the UI can show it.
- The preview's legacy checks assumed Moss had non-empty vocabulary and compared version-1 migration against an earlier association value. The test fixture now allows a valid empty vocabulary and compares the migrated value against the current saved profile.
- To make the child age and old-age notice readable at the recorder's 15 FPS, the rendered walkthrough holds the selected Child HUD for captured frames and scrolls to the status line for the closing frames.

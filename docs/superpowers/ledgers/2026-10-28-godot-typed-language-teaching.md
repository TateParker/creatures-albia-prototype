# Godot Typed Language Teaching Execution Ledger

Plan: `docs/superpowers/plans/2026-10-28-godot-typed-language-teaching.md`
Spec: `docs/superpowers/specs/2026-10-28-free-text-language-teaching-design.md`
Workspace: the existing main checkout, as previously authorized.

Ruling: Use a focused rendered walkthrough check despite the older vertical-slice plan's no-automated-test-suite note — the user explicitly requested testing and the current `AGENTS.md` requires a recorded representative run; keep verification bounded to the preview scenario and targeted recorder/scene checks.

Task 1, initial RED: extended `godot/tools/record_preview.gd` to require a typed teaching field and Teach word control before capture. Rendered Godot run failed as expected: `VIDEO_CAPTURE_FAILED: The typed teaching field and Teach word control are missing from the HUD.`

## Completion record

- Added `NornLanguage` for one-word associations to fruit, spinner, Praise, and Scold. It trims input, compares case-insensitively, rejects phrases/conflicts, caps vocabulary at 32, adds 0.38 confidence per teaching, and only returns utterances at 0.60 confidence or above.
- Added a Teach word mode and text field to the Godot HUD. Selecting a target in teach mode teaches that meaning; outside teach mode, the existing guide and feedback actions stay active. The HUD displays all four initial word meanings and confidence values.
- Praise raises the active object-word confidence by 0.14 and Scold lowers it by 0.14. Teaching the words for Praise and Scold does not apply behavior feedback. Norn event status includes a learned word after its threshold is reached.
- Bumped the local save schema to version 2, preserving vocabulary and confidence. Version-1 saves load with empty vocabulary; load/reset clears transient teach mode. The rendered walkthrough restores the user's preexisting save after its migration scenario.
- Documented the controls and verification command in `godot/README.md`.

### Verification evidence

- Final rendered walkthrough: `Godot_v4.7.2-stable_mono_win64_console.exe --path godot --script res://tools/record_preview.gd` — `VIDEO_CAPTURE_OK frames=188 path=user://recordings/habitat-20261028-232541.avi flow=teach-fruit-praise-spinner-scold-pause-save-load-legacy`.
- Inspected full-resolution AVI frames showing typed words, the four learned mappings, Apple after fruit, good after Praise, toy after spinner, bad after Scold, and successful local load status. The version-2 save/load walkthrough verifies all four associations, their meanings, and their confidence values after deliberately corrupting/removing entries in memory.
- Parsed the emitted AVI's RIFF size, 1280×720 dimensions, all 188 `00dc` chunks and matching `idx1` entries; decoded sampled JPEGs successfully.
- `verify_avi_writer.gd` — `AVI_WRITER_OK frames=2 dimensions=64x64`.
- `verify_recording_retention.gd` — `VIDEO_RETENTION_OK limit=10 removed=2 new_clip_kept=true`; the user's recordings folder remained at the 10-clip limit after the rendered walkthrough.
- The walkthrough calls its backup/restore path after the migration check; a follow-up read confirmed the local save is a valid version-1 save with no vocabulary.
- Headless scene startup with `--quit-after 2` exited successfully without errors.
- `git diff --check` and trailing-whitespace checks passed after the final documentation updates.
- Temporary extracted frame PNGs and their montage remain in Godot's app-data directory: execution policy blocked deleting files outside the checkout. They are not AVI clips and do not affect the 10-clip cap; the temporary inspection script was removed from the project.

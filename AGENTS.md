# Project Agent Guidelines

## Godot recordings and verification

- Keep at most 10 completed gameplay clips in the Godot `user://recordings/` folder. After a new recording is finalized, remove the oldest timestamped clips until 10 or fewer remain. Do not remove a clip that is still being recorded.
- Run the video capture in rendered, non-headless mode so Godot produces viewport frames. Headless checks can supplement the recording but cannot verify viewport capture.
- When changing Godot gameplay, UI, rendering, or simulation behavior, verify the relevant behavior with the in-game video recording feature. Record a representative run and inspect the resulting clip or its extracted frames; report the recording path and what was verified. Use targeted automated or headless checks as appropriate in addition to the video capture.

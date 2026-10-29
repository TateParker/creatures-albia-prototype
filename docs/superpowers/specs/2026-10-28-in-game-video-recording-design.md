# In-Game Video Recording Design

## Intent

Add a start/stop recording control to the Godot habitat so a running scene can be captured and reviewed from a local video file.

## Goals

- Capture the running Godot viewport, including the habitat HUD, while the game continues to run.
- Let the player start and stop capture from the in-game HUD.
- Save a playable Motion JPEG AVI under `user://recordings/` and show the saved path and capture state in the HUD.
- Keep capture local and avoid network services or external runtime dependencies.

## Non-goals

- No network or remote live stream.
- No audio track; the current Godot slice has no audio output to capture.
- No desktop-wide recording outside the game viewport.

## Constraints

- Target Godot 4.7.2 Standard and the existing Windows desktop build.
- Godot Movie Maker is launch-time only, and FFmpeg is not installed on the current machine.
- Capture at 1280×720, 15 FPS, JPEG quality 0.75; capture after rendered frames and cap recording at the classic AVI size limit.
- Use only local Godot APIs and filesystem paths.

## Approaches

- Godot Movie Maker: produces AVI without an extra dependency, but cannot be started or stopped from the running game's HUD.
- Launch FFmpeg for viewport encoding: flexible, but FFmpeg is absent here and would add a runtime dependency.
- Capture viewport frames in game and write MJPEG AVI locally: supports the requested in-game control and uses the existing Godot runtime; it requires a small AVI writer.

## Chosen design

Use the third approach. `LocalVideoRecorder` samples the root viewport at 15 FPS, scales only if needed to 1280×720, encodes each frame as JPEG, and sends frames to a focused MJPEG AVI writer. The writer finalizes RIFF sizes and the frame index when recording stops. The HUD shows a recording indicator, elapsed time, the last saved path, and a control for opening the recordings folder.

## Risks

Viewport readback and JPEG encoding can create frame-time spikes while recording. Sampling at 15 FPS bounds the work; verification should confirm the file structure and inspect an extracted frame. Classic AVI has a 4 GiB limit, so capture stops before exceeding it.

# In-Game Video Recording Implementation Plan

> **For agentic workers:** Execute inline in the current checkout. Track each step with the checkbox syntax below.

**Goal:** Add HUD-controlled local recording of the live Godot viewport to a playable Motion JPEG AVI.

**Architecture:** `LocalVideoRecorder` samples the root viewport and hands JPEG frames to `MjpegAviWriter`, which writes and finalizes an AVI. `AlbiaWorld` exposes start/stop and folder actions; `HabitatUi` exposes recording state and saved location.

**Tech Stack:** Godot 4.7.2 GDScript, `Viewport`, `Image.save_jpg_to_buffer()`, and `FileAccess`.

**Spec:** `docs/superpowers/specs/2026-10-28-in-game-video-recording-design.md`

## Global Constraints

- Capture 1280×720 at 15 FPS and JPEG quality 0.75.
- Save files under `user://recordings/`.
- Do not add a network service, external encoder dependency, or audio track.
- Capture only the game viewport, not the desktop.
- Preserve all unrelated pre-existing working-tree changes.

## Review Focus

- A recording stopped from the HUD must finalize RIFF sizes and `idx1` offsets so the AVI is usable.
- Capture must wait until a rendered frame exists, avoiding black or stale first frames.
- An unwritable recordings directory must leave the game usable and report the failure in the HUD.
- Recording while paused must continue capturing the paused view without advancing simulation time.
- A long recording must stop before classic AVI exceeds its 4 GiB limit.

---

### Task 1: Define and verify the user-facing recording contract

**Files:**
- Create: `godot/tools/record_preview.gd`

**Interfaces:**
- Consumes: `AlbiaWorld.toggle_recording()`, `AlbiaWorld.is_recording()`, `AlbiaWorld.last_recording_path`, and `AlbiaWorld.recorded_frame_count`.
- Produces: a visible scene recording smoke walkthrough that exits nonzero unless capture starts, records multiple frames, stops, and creates a RIFF AVI.

- [x] **Step 1: Write the recording smoke walkthrough first**

The helper instantiates the main scene, guides Mallow toward fruit, toggles recording on and off, checks at least two frames and the `RIFF`/`AVI ` signature, and prints the generated local path.

- [x] **Step 2: Run it before implementation**

Run the helper with Godot 4.7.2 and confirm it fails because the recording API is not implemented.

### Task 2: Write MJPEG AVI files

**Files:**
- Create: `godot/scripts/mjpeg_avi_writer.gd`
- Modify: `godot/tools/record_preview.gd`

**Interfaces:**
- Produces: `begin(path: String, size: Vector2i, fps: int) -> Error`, `write_frame(jpeg_bytes: PackedByteArray) -> Error`, `finish() -> Error`, and `bytes_written() -> int`.

- [x] **Step 1: Implement a writer smoke case**

Use a generated Godot `Image` frame to verify the writer creates valid RIFF/AVI headers, a frame chunk, a final index, and correct frame counts.

- [x] **Step 2: Run the writer check and confirm the expected missing-writer failure**

- [x] **Step 3: Implement AVI headers, MJPEG chunks, `idx1`, and RIFF size patching**

- [x] **Step 4: Run the writer check again and inspect the first JPEG frame**

### Task 3: Add live capture and HUD controls

**Files:**
- Create: `godot/scripts/local_video_recorder.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/habitat_ui.gd`

**Interfaces:**
- Produces: a recorder that captures viewport frames at 15 FPS, toggles from the HUD, finalizes on stop or shutdown, reports errors, and opens the local recordings directory.

- [x] **Step 1: Implement capture using `RenderingServer.frame_post_draw` and `Viewport.get_texture().get_image()`**

- [x] **Step 2: Add recording state and start/stop/open-folder actions to `AlbiaWorld`**

- [x] **Step 3: Add Record/Stop, elapsed state, and saved path to the HUD**

- [x] **Step 4: Run the visible capture walkthrough and inspect the generated AVI and extracted frame**

### Task 4: Document local recordings

**Files:**
- Modify: `godot/README.md`

- [x] **Step 1: Document HUD usage, output directory, format, and the verification walkthrough command**

- [x] **Step 2: Run the walkthrough one final time and confirm the documented output path matches**

## Execution notes

- The pre-implementation recording helper failed on the missing `AlbiaWorld.toggle_recording()` API as expected.
- The pre-implementation writer check failed because `mjpeg_avi_writer.gd` did not exist; after implementation, the writer check passed with two JPEG frames, correct RIFF size, dimensions, rate, stream format, bitmap size, and index entries.
- The final visible capture walkthrough completed with 46 frames and produced a 2.47 MiB AVI at `user://recordings/habitat-20261028-224722.avi`.
- The walkthrough verified start/stop, 1280×720 header dimensions, finalized RIFF size and frame count, and that recording continues while the simulation is paused without advancing its clock.
- Extracted the first frame from the final AVI and visually confirmed it contains the habitat and recording HUD at 1280×720.
- Verified all 46 `00dc` compressed-frame chunks and `idx1` offsets/sizes in the final AVI; extracted first and last frames differ and show Mallow's movement.
- The existing headless habitat scenario still passed autonomous/guided fruit and spinner trips, Praise/Scold, pause/resume, save/load, malformed-save fallback, and save restoration.
- The Godot `--headless --editor --quit` scan registered the GDScript classes but reported that the .NET SDK 10.0.0 is unavailable in the mono editor build. The runtime scene load and writer smoke check succeeded without this SDK.
- No commit was created because the checkout contains unrelated pre-existing changes and the Godot work is already uncommitted.

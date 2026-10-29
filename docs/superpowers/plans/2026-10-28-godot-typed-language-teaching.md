# Godot Typed Language Teaching Implementation Plan

> Implement this plan inline in the current checkout as requested. Steps use checkbox syntax so progress can be tracked.

**Goal:** Let the player teach local Norn vocabulary for fruit, spinner, Praise, and Scold through the Godot HUD, with feedback reinforcing object-word confidence.

**Architecture:** Keep bounded word associations in a scene-independent `NornLanguage` GDScript class. `AlbiaWorld` coordinates teach mode, outcome feedback, and versioned local saves; `HabitatUi` supplies typed input and accessible target buttons. Learned words appear as contextual text, without speech recognition or network services.

**Tech Stack:** Godot 4.7.2-stable Standard, typed GDScript, local `user://` JSON save.

**Spec:** `docs/superpowers/specs/2026-10-28-free-text-language-teaching-design.md` (native adaptation; this step does not add speech input/output).

## Global Constraints

- Accept one trimmed word up to 24 characters and compare case-insensitively.
- Pair words explicitly with `fruit`, `spinner`, `praise`, or `scold`.
- Add 0.38 confidence for teaching the same word/target; use words at confidence 0.60 or higher; cap at 32 entries.
- Reject conflicting word targets and invalid input without changing learning.
- Praise and Scold remain behavior feedback outside Teach mode; in Teach mode they teach their named vocabulary targets.
- Save locally, accept existing version-1 saves with empty vocabulary, and write version-2 saves with vocabulary.
- Verify the relevant behavior using a rendered in-game recording and inspect its frames.

## Review Focus

- Blank, phrase, oversized, and conflicting input leaves vocabulary unchanged and reports a useful message.
- Teaching Praise/Scold never applies behavior feedback; ordinary Praise/Scold still updates behavior and the associated object-word confidence.
- Words below 0.60 are not shown as Norn utterances; words at or above 0.60 are used for the matching event.
- Version-1 and version-2 saves restore the expected vocabulary and cognition state.
- User-entered words remain plain text in HUD labels and saved JSON.

---

### Task 1: Add failing rendered walkthrough checks

**Files:**
- Modify: `godot/tools/record_preview.gd`

**Interfaces:**
- The walkthrough drives the real HUD input and target buttons, and checks word validation, confidence, feedback reinforcement, persistence, and the emitted AVI.

- [x] Check for the teach input and mode control, and exercise word teaching through their connected button signals.
- [x] Verify case-insensitive repeats, target conflicts, invalid phrases, Praise/Scold target teaching, object feedback reinforcement, utterance threshold, save/load, and legacy version-1 migration.
- [x] Run `Godot_v4.7.2-stable_win64.exe --path godot --script res://tools/record_preview.gd` in rendered mode and confirm it fails because the teaching UI/API is not present.

### Task 2: Implement the scene-independent vocabulary model

**Files:**
- Create: `godot/scripts/norn_language.gd`
- Modify: `godot/tools/record_preview.gd`

**Interfaces:**
- `NornLanguage.create_state() -> Dictionary`
- `NornLanguage.teach_word(state: Dictionary, input: String, target_id: String) -> Dictionary`
- `NornLanguage.adjust_target(state: Dictionary, target_id: String, delta: float) -> Array[Dictionary]`
- `NornLanguage.word_for_target(state: Dictionary, target_id: String) -> Dictionary`
- `NornLanguage.restore_state(value: Variant) -> Dictionary`

- [x] Implement the 32-entry cap, 24-character one-word validation, normalized keys, 0.38 teach increment, 0.60 utterance threshold, and target-safe restoration.
- [x] Verify the rendered walkthrough's validation, repeat, conflict, confidence, and utterance assertions.

### Task 3: Connect vocabulary, outcomes, HUD, and local saves

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/habitat_ui.gd`
- Modify: `godot/tools/record_preview.gd`

- [x] Add a Teach mode toggle and typed word field. In Teach mode, the fruit, spinner, Praise, and Scold controls teach their target; outside it, existing actions stay active.
- [x] Display learned words/confidence and show a learned word in the status when Mallow uses the matching object or feedback target.
- [x] Let Praise raise matching object-word confidence by 0.14 and Scold lower it by 0.14, clamped to `[0, 1]`.
- [x] Save language state in version 2, accept version 1 with empty vocabulary, and clear transient teaching mode on load/reset.
- [x] Verify feedback mode isolation and version-1/version-2 save behavior through the rendered walkthrough.

### Task 4: Record, inspect, and document

**Files:**
- Modify: `godot/README.md`
- Verify: rendered recording plus AVI writer and retention checks.

- [x] Run the full rendered walkthrough, inspect the recorded teaching, feedback, and persistence frames, and verify the AVI index/dimensions and 10-clip cap.
- [x] Run headless scene startup and targeted writer/retention checks; run `git diff --check`.
- [x] Document the Godot teaching controls and walkthrough command.

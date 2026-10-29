# Free-Text Language Teaching Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let the player teach each Norn custom words for the grove's two objects and for Praise and Scold, then inspect, hear, save, restore, and export those associations.

**Architecture:** Keep the standalone app in index.html and extend each Norn with a bounded list of custom word entries while preserving the existing fruit and spinner confidence fields. A typed word enters a teaching mode and is paired explicitly with one of four targets; the same word cannot map to two targets for a Norn. Generalize speech and social word learning to those targets, and migrate existing version-1 saves into the new save shape.

**Tech Stack:** Standalone HTML, CSS, inline JavaScript, browser storage, GitHub Pages; no dependencies.

**Spec:** docs/superpowers/specs/2026-10-28-free-text-language-teaching-design.md

## Global Constraints

- Teach one non-empty word of up to 24 characters; compare without case sensitivity and preserve entered capitalization for display.
- Support multiple words per target, but map each normalized word to one target per Norn.
- Keep the existing 0.38 teaching increase and 0.60 utterance threshold.
- Use the four targets fruit, spinner, praise, and scold.
- Praise and Scold clicks teach words only while Teach mode is active; otherwise preserve their current feedback behavior.
- Preserve existing version-1 saves and the current lock-based writer.
- Do not add or run automated tests; review source behavior and diffs only.
- Bound custom vocabulary to 32 entries per Norn as the implementation limit for the save format.

## Review Focus

- Blank, whitespace-only, multi-word, and over-24-character input must leave learning unchanged and give a clear cue while keeping Teach mode available.
- Case variants of the same word must update one same-target entry; mapping a known word to another target or exceeding 32 entries must not mutate learning.
- In Teach mode, object, Praise, and Scold controls must teach the selected target without applying behavior feedback; outside Teach mode the original handlers remain active.
- Version-1 saves must retain their fruit/spinner learning and load with no custom words; malformed version-2 custom entries must be rejected without overwriting storage.
- User text must remain plain text in the inspector, toast, journal, memories, and canvas speech bubble.

---

### Task 1: Add the custom vocabulary model and teaching controls

**Files:**
- Modify: index.html — target metadata, Norn state, input markup, mode rendering, teaching handlers.

**Interfaces:**
- Define WORD_TARGETS with target IDs fruit, spinner, praise, and scold; each entry has a display label and kind, and object entries include their object ID.
- Define normalizeWord(value) -> string using trim, Unicode NFKC normalization, and lowercase for matching.
- Define validateWordInput(value) -> { valid, word, normalized, reason }; accept one non-empty token of at most 24 input characters with no whitespace or control characters. Check target conflicts in teachWord after the player selects a target.
- Define findWordEntry(norn, normalized) -> { word, targetId, confidence, isBuiltIn, customIndex? } or null across built-in and custom entries.
- Define teachWord(norn, word, targetId) -> outcome; increment an existing same-target word by 0.38, add a new custom entry at 0.38, and report conflict or capacity outcomes without mutation.
- Store custom entries as norn.customWords: Array<{ word: string, targetId: string, confidence: number }>; retain norn.words.fruit and norn.words.spinner for the existing built-in words.
- Keep transient state.teachingMode separate from state.teachingWord so Teach mode works while the input is empty or invalid.

- [x] Add WORD_TARGETS, normalization and validation helpers, and the bounded customWords list to initial Norn state.
- [x] Replace the fixed selector with a labeled text input capped at 24 characters; explain that the player can choose an object, Praise, or Scold after activating Teach word.
- [x] Wire Teach mode to the current text field. Route canvas and accessible object buttons to the selected object target; route Praise and Scold clicks to their target only in Teach mode, with no feedback side effect.
- [x] On target selection, reject invalid text without mutation and keep Teach mode active so the player can correct it. On valid teaching, add 0.38 confidence and record a target-specific journal event and memory.
- [x] Preserve the input field after a teaching action for convenient repetition; clear active teaching mode and its transient word on success, cancel, Norn change, Point mode, reset, and restore.
- [x] Review blank, invalid, repeated, conflicting, and full-list paths in source; confirm failed teaching leaves confidence, journal, and behavior feedback unchanged.

### Task 2: Display, speak, and socially share custom words

**Files:**
- Modify: index.html — vocabulary inspector, speech helpers, word-hearing, Praise/Scold event flow.

**Interfaces:**
- Generalize speech to targetId values from WORD_TARGETS and store speech as { text, targetId, until }.
- Generalize speakKnownWord(norn, targetId, context) -> { normalizedWord, targetId, eventId, context } or null; choose the highest-confidence available word at or above 0.60, with the built-in word winning a confidence tie and custom entries retaining insertion order.
- Generalize recordWordHearing(observer, actor, spokenWord) to increase the matching built-in/custom confidence by 0.14 and record a linked hear event.

- [x] Render built-in and custom vocabulary entries in the inspector, grouped by target and showing confidence.
- [x] Generalize object seeking and success utterances to choose a learned word for the object target; keep existing event wording grounded in the object and context.
- [x] After a valid Praise or Scold event, let the actor speak a learned word for that feedback target. An observer who knows a word for the same feedback may also say it while observing; nearby listeners can learn either utterance through the existing sociability and distance gates.
- [x] Generalize observer learning so an utterance updates only the matching target's word confidence and links the hear event to the utterance.
- [x] Review tie-breaking, below-threshold words, both feedback types, and observer distance/sociability paths; confirm speech text remains within the bubble and save limits.

### Task 3: Persist and migrate custom vocabulary

**Files:**
- Modify: index.html — snapshot serialization, validation, restore migration, export.

**Interfaces:**
- Bump SAVE_SCHEMA_VERSION to 2 while keeping the existing localStorage key and exclusive writer.
- Version-2 Norns include customWords; version-2 speech uses targetId.
- Version-1 speech.objectId migrates to speech.targetId; version-1 Norns retain fruit/spinner confidence and receive an empty customWords list.
- Validate at most 32 custom entries per Norn, 24 input characters per word, valid target IDs, confidence in [0, 1], and case-normalized uniqueness across built-in and custom words.

- [x] Include customWords and generic speech target IDs in snapshots; retain allowlisted reconstruction of saved fields.
- [x] Accept and migrate valid version-1 records, and validate version-2 custom entries and generic speech targets.
- [x] Restore custom vocabulary without restoring transient Teach or Point modes; keep reset and conflict-checked writes on the existing exclusive-lock path.
- [x] Ensure Download this run exports a version-2 record that passes the same validation path.
- [x] Schedule successful teaching and feedback speech for the existing lock-safe save even when the grove is paused.
- [x] Review valid legacy saves, legacy speech, malformed targets, duplicate normalized words, capacity boundaries, and writer conflict paths in source; confirm invalid records cannot overwrite the observed save.

### Task 4: Update the user instructions and review the complete change

**Files:**
- Modify: README.md — teaching controls, word targets, threshold, persistence, and observer learning.
- Modify: docs/superpowers/specs/2026-10-28-free-text-language-teaching-design.md — record any approved implementation clarifications.

**Interfaces:**
- Keep README language consistent with the one-word input, object/Praise/Scold targets, two-exposure use threshold, and local-only save.

- [x] Explain how to type a word, activate Teach word, select an object or feedback target, and repeat teaching until the Norn uses it.
- [x] Explain the Praise/Scold target behavior while Teach mode is active and preserve the existing behavior description outside Teach mode.
- [x] Review the final diff against every acceptance criterion and Review Focus item; do not add or run automated tests.

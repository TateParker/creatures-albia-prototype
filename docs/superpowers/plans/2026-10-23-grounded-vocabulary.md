# Grounded Vocabulary Learning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task in the current session.

**Goal:** Add grounded object-word teaching, contextual Norn utterances, and social vocabulary learning to New Albia.

**Architecture:** Extend the existing single-file simulation with per-Norn word confidence, a teach mode that pairs a selected word with a clicked object, short canvas speech bubbles, and structured word events. Reuse the current local event and memory systems; keep all behavior deterministic.

**Tech Stack:** HTML, CSS, vanilla JavaScript, Canvas 2D.

**Spec:** [2026-10-23-grounded-vocabulary-design.md](../specs/2026-10-23-grounded-vocabulary-design.md)

## Global Constraints

- Keep the app self-contained and local-first; no external APIs or libraries.
- Use only the words `fruit` and `spinner` in this slice.
- Player teaching adds 38 percentage points; witnessed speech adds 14; each value clamps at 100%.
- A Norn speaks a word at 60% confidence or higher, after successfully using its matching object.
- Record memories and journal events only from actual teaching, utterance, or observation events.
- Do not add or run automated tests; verify the source by inspection and verify the Pages deployment operationally.

## Review Focus

- Teach mode must cancel or take precedence cleanly over Point mode.
- A mismatched word/object pairing must not raise word confidence.
- A Norn must not speak an unlearned word or speak it about the wrong object.
- Social vocabulary gain must require the observer to be nearby and an utterance to have occurred.
- Reset must clear vocabulary and teaching mode with the rest of simulation state.

---

### Task 1: Add grounded player teaching

**Files:**
- Modify: `index.html`

**Interfaces:**
- Add `VOCABULARY` definitions mapping each word to its object ID.
- Add nullable `state.teachingWord` and UI refs for the selector and teach button.
- Add `beginWordTeaching()` and `teachWord(norn, wordId, object)` handlers.

- [x] Add a selector for `fruit` and `spinner`, plus a **Teach word** button.
- [x] Enter a mutually exclusive teach mode and show matching canvas guidance.
- [x] Increase the selected Norn's matching word confidence by 0.38 on a valid pairing; preserve mode and explain a mismatch.
- [x] Record the teaching event and memory from the actual word/object pairing.

### Task 2: Add contextual speech and inspectable vocabulary

**Files:**
- Modify: `index.html`

**Interfaces:**
- Add `norn.words` as a confidence map and `norn.speech` as a timed bubble record.
- Add `renderVocabulary(container, norn)` and `speakKnownWord(norn, objectId)`.

- [x] Draw a short-lived speech bubble only for a word the Norn knows at 0.60 confidence or higher.
- [x] Speak only after a successful interaction with that word's object.
- [x] Display both word confidence values in the Norn notebook.
- [x] Ensure selecting a Norn, cancelling a mode, and reset update the related controls and state.

### Task 3: Add social word learning and publish

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Extend `shareObservation(actor, object, actionEvent, spokenWord)` to add 0.14 confidence only when an utterance is heard nearby.
- Continue to use `recordEvent(event)` for speech and observation memories.

- [x] Record each utterance and the observer's word-learning event with the speaker, word, and object grounded in simulation state.
- [x] Update the README controls and explain the local vocabulary loop.
- [x] Review mode transitions, confidence thresholds, event/memory grounding, and reset behavior.
- [x] Commit the feature, push `main`, and confirm the Pages workflow and served page include vocabulary teaching.

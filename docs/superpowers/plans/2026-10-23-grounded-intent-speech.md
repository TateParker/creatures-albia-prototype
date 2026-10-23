# Grounded Norn Intent Speech Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a Norn use a known word to express a newly selected object goal, with nearby Norns able to learn the word through sociability-weighted listening.

**Architecture:** Extend `speakKnownWord` with a seeking context. Extract word-hearing bookkeeping for reuse, while keeping success observation's shared word/imitation gate intact. Trigger intent speech only when the target changes and no current speech is active.

**Tech Stack:** Standalone HTML, CSS, inline JavaScript, GitHub Pages.

**Spec:** `docs/superpowers/specs/2026-10-23-grounded-intent-speech-design.md`

## Global Constraints

- Only a newly selected non-null target outside its existing arrival range can trigger intent speech.
- Intent speech requires word confidence `>= 0.6` and no active speech bubble.
- Nearby word hearing uses validated Sociability as a direct 0–1 probability.
- Intent speech never imitates behavior; successful events keep one shared word/imitation gate.
- Keep saves compatible; add no fields or migration.
- New social speech checks consume the existing RNG stream and may change later random outcomes in a saved run.
- No LLM, external calls, or automated tests.

## Review Focus

- Unchanged targets, null targets, targets already within arrival range, unknown words, and active bubbles produce no intent utterance.
- Intent events and memories say the Norn is looking for the target, while successful speech keeps its existing text and memory.
- A nearby observer who passes sociability can learn an intent word and gets a `hear` event linked to the utterance; failed attention or full word confidence produces no learning event.
- A successful action uses exactly one attention roll per eligible observer to gate both word hearing and imitation; the refactor does not add a second roll on this path.
- Intent word hearing performs no behavior imitation, no persisted fields or decision scores change, and the new sociability rolls use the existing RNG stream.

---

### Task 1: Express and share grounded target intent

**Files:**
- Modify: `index.html` — speech context, shared word-hearing recorder, target transition, and README documentation.
- Modify: `README.md` — describe known-word target expression.

**Interfaces:**
- `speakKnownWord(norn, objectId, context = "using")` emits existing word speech and returns `{ wordId, eventId, context }` when confidence is at least `0.6`.
- `recordWordHearing(observer, actor, object, spokenWord)` updates known word confidence and its linked event/memory.
- `shareSpokenWord(actor, object, spokenWord)` applies self/distance/sociability filters for standalone utterances only.

- [x] **Step 1: Add context-aware speech copy.** Keep successful-action wording as the default; for `context === "seeking"`, use “while looking for the …” in both event and memory text.
- [x] **Step 2: Extract word-hearing bookkeeping.** Reuse one `recordWordHearing` function from `shareObservation` and new `shareSpokenWord`; preserve the existing `0.14` increment, reason/action strings, event type, memory, and related utterance ID.
- [x] **Step 3: Trigger intent on a real target change.** In `updateNorn`, retain the previous target, select the new target, and when it is non-null, changed, still beyond its existing arrival range (52 for fruit, 48 for spinner), and no speech bubble is active, call `speakKnownWord(..., "seeking")` and `shareSpokenWord` if a known word was emitted. Player guidance wakes the same selection path without preassigning `targetId`, so guided target switches use this comparison.
- [x] **Step 4: Document the feature.** Update README's vocabulary sentence to explain that a known object word may be said while seeking that object and after using it.
- [x] **Step 5: Inspect the final diff against the five review-focus conditions; run `git diff --check` and `node --check` on the extracted inline script.** Expected: no whitespace or JavaScript syntax errors; success keeps a single shared gate and intent hearing cannot imitate. Do not add or run automated tests.
- [ ] **Step 6: Commit as `Let Norns voice known goals`, obtain a scoped read-only review, publish only if clear, and verify Pages plus a cache-busted live response.**

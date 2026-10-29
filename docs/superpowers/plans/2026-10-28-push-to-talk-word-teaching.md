# Push-to-Talk Word Teaching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player teach a selected Norn a spoken one-word association using a hold-to-talk control that requires on-device browser recognition.

**Architecture:** Keep typed teaching and existing word-learning state in `index.html`. Add a separate target selector and push-to-talk control; create one local-only recognition session per hold, then route a valid final transcript through the existing `teachWord` function. Document browser capability limits and the typed fallback.

**Tech Stack:** Standalone HTML, CSS, inline JavaScript, browser Web Speech API, GitHub Pages; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-28-push-to-talk-word-teaching-design.md`

## Global Constraints

- Use push-to-talk; recognition starts only from an explicit press and is stopped on release or cancellation.
- Require `SpeechRecognition.processLocally = true`; never fall back to browser-selected or remote processing.
- Do not automatically install or download speech language packs.
- Accept only one non-empty word up to 24 characters and reuse existing target-conflict, confidence, event, memory, and save behavior.
- Keep typed teaching available when local speech recognition is unsupported, unavailable, or denied.
- Do not retain microphone audio or recognition sessions in the save format.
- Do not add or run automated tests; review source behavior and diffs only.

## Review Focus

- Missing Web Speech API or missing `processLocally` support must not start recognition or use a remote recognizer.
- Denied microphone permission or an unavailable local language model must stop the session without teaching or changing feedback behavior.
- Releasing, cancelling, losing focus, changing Norn, resetting, restoring, or hiding the page must stop or abort the held session and prevent background listening.
- Empty, multi-word, or over-24-character transcripts must leave learning unchanged and provide clear feedback.
- Existing word-target conflicts and the 32-custom-word limit must reuse current behavior without mutation; one valid word teaches only the selected target.

---

### Task 1: Add the voice target and push-to-talk controls

**Files:**
- Modify: `index.html` — teaching controls, helper copy, CSS, and UI references.

**Interfaces:**
- Add `voiceTarget`, a native select with an empty prompt followed by the four `WORD_TARGETS` IDs: `fruit`, `spinner`, `praise`, and `scold`.
- Add `voiceButton`, a hold-to-speak button, and `voiceStatus`, a polite live-status region for availability and session feedback.
- Keep the existing `wordInput` and **Teach word** interaction unchanged.

- [x] Add the labeled target selector and hold-to-speak button near the existing word input; disable speech capture until a target is selected.
- [x] Add concise instructions that the player holds the control to speak one word and releases it to teach; state that typed teaching remains available.
- [x] Add pressed-state and accessible status semantics for voice capture; ensure keyboard users can hold and release the control.
- [x] Review the markup and UI state with no target selected, a target selected, and voice recognition unavailable.

### Task 2: Implement local-only recognition and direct teaching

**Files:**
- Modify: `index.html` — transient recognition session, event handlers, and cleanup paths.

**Interfaces:**
- Implement `createLocalSpeechRecognition() -> SpeechRecognition | null`; detect `window.SpeechRecognition` or `window.webkitSpeechRecognition`, require the instance to expose `processLocally`, set it to `true`, set `lang` from the document language (or `navigator.language`), and configure one-shot final results without interim transcription.
- Implement `startVoiceTeaching()`, `stopVoiceTeaching()`, and `cancelVoiceTeaching()` around one transient session that captures the selected Norn ID and target ID at press time.
- On explicit release and a final result, call `teachWord(getNorn(nornId), transcript, targetId)`; commit only once per session.

- [x] Start recognition only during pointer or keyboard press; stop on release, and abort on pointer cancellation, lost focus, Escape, or explicit cancellation.
- [x] Require local processing support and set `processLocally = true` before `start()`; fail closed with a clear status when the API or model is unavailable and never install a language pack automatically.
- [x] Use only the final transcript, pass it through existing one-word validation, and directly teach the captured Norn/target when the held session ends.
- [x] Handle microphone denial, no speech, language-not-supported, start errors, and invalid or conflicting words without applying Praise/Scold behavior or saving audio.
- [x] Cancel an active session on Norn change, reset, restore, and page hide; review that stale or late recognition events cannot teach after cancellation.

### Task 3: Document behavior and review the complete change

**Files:**
- Modify: `README.md` — speech teaching controls, local-only processing, availability limits, and typed fallback.
- Modify: `docs/superpowers/specs/2026-10-28-push-to-talk-word-teaching-design.md` — implementation clarifications if needed.

- [x] Explain target selection, hold-to-speak and release behavior, one-word teaching, local processing, and typed fallback.
- [x] Review API-unavailable, permission-denied, unsupported local-language, cancellation, invalid transcript, target conflict, and capacity paths in source.
- [x] Review the final diff against the design and acceptance criteria; run `git diff --check` and do not add or run automated tests.

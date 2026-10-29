# Push-to-Talk Word Teaching — Design

**Status:** Approved and implemented

## Intent

Let the player teach a selected Norn a spoken word without leaving the microphone open. The player chooses what the word means, holds a push-to-talk control, and the Norn learns the recognized word as soon as the player releases it.

## Current behavior

The player can type one word and pair it with Honey fruit, Wind-up spinner, Praise, or Scold. Norns can speak learned words in on-canvas bubbles, but the app has no microphone input. The prototype otherwise keeps its learning and storage in the browser.

## Goals and non-goals

- Add a separate, explicit hold-to-speak path for teaching one word to one of the four existing targets.
- Reuse current word validation, confidence changes, conflict handling, events, memories, and save behavior.
- Keep typed teaching available as the fallback and correction path.
- Do not continuously listen, transcribe sentences, interpret commands, retain audio, or use network speech recognition.

## Approaches

1. **On-device browser recognition (selected):** Use the browser's SpeechRecognition API only when its recognizer exposes the `processLocally` setting, set that setting to `true`, and start a session. Never fall back if local recognition fails. This best preserves the prototype's local-only behavior; availability and installed language packs vary by browser.
2. **Browser-selected recognition:** Use the same push-to-talk interaction, but let the browser choose local or remote recognition. This may work in more environments, but speech can be sent to a browser-provided service and would change the prototype's privacy promise.
3. **Bundled local recognition model:** Package a local speech model for more control over processing. This adds substantial download size, dependencies, and runtime cost to the current single-file prototype.

## Interaction and behavior

- Add a native target selector for Honey fruit, Wind-up spinner, Praise, or Scold, plus a **Hold to speak** control. The selector starts empty; voice teaching stays unavailable until a target is chosen.
- On pointer or keyboard press, request microphone access and start one-shot recognition. On release, stop recognition and use its final result. Pointer cancellation, focus loss, Escape, or another explicit cancel must stop without teaching.
- Accept the result only when it passes the current one-word, 24-character validation. Pair it immediately with the selected target through the existing teaching function; do not insert it for a separate confirmation step. Existing conflict and capacity errors remain in effect.
- Never fall back to browser-selected or remote processing. If the API lacks `processLocally` or local recognition fails for the page language, explain that voice teaching is unavailable in this browser and leave typed teaching usable. Do not automatically install or download language packs.
- Start no recognition until the player presses the control. Do not save audio or recognition sessions; only the resulting word association enters existing game state and saves.

## Implementation choices

- Use the document's declared language for recognition, with a browser-language fallback only if the document has no language.
- Require the recognizer to expose `processLocally`, set it to `true`, and fail closed on API or local-language errors; do not use `SpeechRecognition.available()` or `install()` to trigger a language-pack download.
- Keep recognition transient and outside the save schema. Only the final transcript is passed to `teachWord` after release. Cancel an active session on Norn change, reset, restore, loss of focus, explicit cancellation, or page hide.
- No automated tests are planned under the existing approved constraint; source and diff review will focus on microphone activation and shutdown, local-only rejection paths, target selection, invalid transcripts, and reuse of existing learning behavior.

## Acceptance criteria

- No microphone capture begins until the player holds the control, and releasing it stops recognition.
- A final single-word local transcript teaches the selected Norn the explicitly selected target immediately.
- Unsupported local recognition, denied permission, no speech, and invalid multi-word transcripts produce clear feedback without accidentally teaching or applying Praise/Scold behavior.
- Typed word teaching continues to work, and no audio or remote recognition fallback is added.

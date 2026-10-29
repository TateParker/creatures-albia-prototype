# Typed Norn Commands and Local Voice Replies Implementation Plan

> **For agentic workers:** Use the inline implementation workflow and keep this plan's checkboxes current.

**Goal:** Add a small verb/object command interface for the selected Norn and speak valid command replies with a local browser voice.

**Architecture:** Parse a bounded command grammar in the existing inline app. Resolve object words from the selected Norn's current vocabulary, require confidence `>= 0.6`, and route accepted commands through the existing guidance, journal, memory, and word-sharing behavior. Use Web Speech synthesis only with a voice whose `localService` is true, and only for command-triggered replies.

**Tech Stack:** Existing single-file HTML/CSS/JavaScript app; Web Speech synthesis API; no dependency additions.

**Spec:** `docs/superpowers/specs/2026-10-28-typed-norn-commands-and-local-replies-design.md`

## Global Constraints

- Keep the prototype self-contained and add no libraries.
- Parse only `push`, `eat`, and `play` with one learned object word; optionally accept the selected Norn's name prefix.
- Require the selected Norn's object-word confidence to be at least `0.6`.
- Preserve needs-driven completion; accepted commands supply the current seven-second guidance only.
- Use only `SpeechSynthesisVoice.localService === true`; do not use remote voices or services.
- Speak only valid command replies; preserve text output when speech is muted or unavailable.
- Do not persist speech queues, audio, or toggle preferences.
- Do not add or run automated tests; perform source review and `git diff --check` only.

## Review Focus

- Malformed, extra-token, unknown-verb, and Norn-name-prefixed commands must fail without mutating guidance.
- An unknown, conflicting, praise/scold, or low-confidence word must not resolve to an object command.
- `eat`/fruit and `play`/spinner mismatches must fail; `push` may use either object.
- Accepted commands must capture the selected Norn and reuse bounded seven-second guidance; drives still gate the actual action.
- Only local voices may be assigned to utterances; no local voice must leave text replies functional and explain audio status.

---

### Task 1: Add command controls and bounded command parsing

**Files:**
- Modify: `index.html` — command form markup, styles, input references, parser, and submit handler.

**Interfaces:**
- Produces: `parseNornCommand(norn, rawCommand)` returns either `{ valid: true, verb, objectId, learnedEntry }` or `{ valid: false, reason }`.
- Consumes: `findWordEntry`, `normalizeWord`, `WORD_TARGETS`, `OBJECTS`, and selected Norn state.

- [x] Add an accessible command input, submit button, and polite status text near the teaching controls.
- [x] Parse exactly two tokens, or three when the first token is the selected Norn's name; reject a different Norn's name.
- [x] Permit `push` for fruit/spinner, `eat` for fruit only, and `play` for spinner only.
- [x] Resolve the final word against that Norn's vocabulary; require an object target and confidence `>= 0.6`.
- [x] On rejection, show a specific message without changing state guidance or learning.
- [x] Review all parser branches from source.

### Task 2: Route valid commands into existing simulation behavior

**Files:**
- Modify: `index.html` — accepted-command flow and existing word-context display.

**Interfaces:**
- Consumes: `parseNornCommand`, `speakKnownWord`, `shareSpokenWord`, `recordEvent`, and `state.guidance`.
- Produces: valid submission sets seven-second guidance for the selected Norn, records a command event/memory, and creates the learned-word reply.

- [x] Record a command event and memory with the requested verb and object description.
- [x] Reuse the existing guidance target/duration; keep actual eating/playing controlled by current needs.
- [x] Speak/share the Norn's existing learned word for the object and present it in the current speech bubble.
- [x] Ensure failed or invalid commands do not produce a speech reply or social-learning event.

### Task 3: Add command-triggered local TTS

**Files:**
- Modify: `index.html` — local voice selection, mute control, voice status, and utterance management.

**Interfaces:**
- Produces: local voice availability state and `speakLocalCommandReply(norn, word)`; no-op when muted or unavailable.

- [x] Add an enabled-by-default page-session toggle for voice replies and a clear availability status.
- [x] Handle synchronous and `voiceschanged` voice lists; select only local voices, preferring the page/browser language.
- [x] Set one short utterance to the Norn's learned reply word; use different gentle pitch values for Mallow and Moss.
- [x] Cancel queued speech when the toggle is muted or the page is hidden/unloaded.
- [x] Keep speech synthesis outside simulation state and save snapshots; show text-only replies if no local voice exists.

### Task 4: Document and review the feature

**Files:**
- Modify: `README.md` — command grammar, confidence requirement, Norn agency, and local voice behavior.
- Modify: this plan — mark completed steps.

- [x] Explain command examples and that teaching a word twice raises it enough for use.
- [x] Explain that commands guide but do not override needs, and that audio replies require a local browser voice.
- [x] Review the complete working-tree diff against the spec; run `git diff --check` only.

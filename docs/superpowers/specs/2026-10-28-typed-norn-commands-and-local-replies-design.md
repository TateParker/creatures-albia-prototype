# Typed Norn Commands and Local Voice Replies — Design

**Status:** Implemented; implementation details below are working defaults.

## Intent

Start the next roadmap slice by letting the player give a selected Norn a small typed verb-and-object command and hear a brief local voice reply. The current prototype already teaches object words, tracks confidence per Norn, and provides temporary guidance toward fruit or the spinner. This feature connects those pieces without introducing actions the simulation cannot perform.

## Goals and non-goals

- Add a command field for the selected Norn with the grammar `[Norn name] verb object-word`; the name prefix is optional because the notebook already selects a Norn.
- Support `push <word>` for either known object, `eat <word>` for a learned fruit word, and `play <word>` for a learned spinner word.
- Resolve object words through that Norn's existing vocabulary and require confidence of at least `0.6`.
- Treat commands as short guidance: the Norn may approach the named object, but its existing needs still determine whether it eats or plays.
- Give a valid command a journal/memory entry and a text-bubble reply using the Norn's strongest known word for that object.
- Speak that reply only when the player issues a valid command. Use a browser speech voice marked as local; retain text replies when local speech output is unavailable or muted.
- Keep the app self-contained. Add no dependency, network speech service, saved audio, or new persistent speech preference.

Non-goals: teachable verbs, natural-language or AI parsing, multi-object actions, forced behavior, the `come`/`get`/`drop` command family, continuous narration, genetics, life stages, and world expansion. These remain separate roadmap work.

## Approaches

1. **Small grammar over learned object words (selected):** Parse a few explicit verbs and resolve the object through existing Norn vocabulary/confidence. Reuse current guidance and behavior scoring. Add command-triggered local speech synthesis. This builds on the prototype and preserves Norn agency, with deliberately limited commands.
2. **Direct action buttons:** Add buttons that immediately set a target or trigger eating/playing. This is simpler, but would not create the requested verb/object language interaction and could bypass needs.
3. **Free-form sentence interpretation:** Accept broader sentences and infer intent. This would require substantially more parsing and risk unpredictable behavior; an external model would also conflict with the self-contained, local prototype.

The user asked to begin the recommended typed-command and audible-reply roadmap slice. The small grammar is the implementation choice because it uses the existing language model and available actions. Speech synthesis will require `SpeechSynthesisVoice.localService === true`; remote voices are excluded. See [MDN's localService reference](https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesisVoice/localService).

## Interaction and behavior

- The command controls sit near the existing teaching controls and clearly name the currently selected Norn as the recipient.
- Examples in the UI show `eat fruit`, `play spinner`, and `push fruit`. An optional matching Norn name may precede the command. A different Norn name produces a helpful selection message.
- Reject unsupported verbs, malformed commands, unknown or insufficiently learned words, and mismatched verb/object pairs without changing guidance or learning.
- On success, resolve the learned object word to `fruit` or `spinner`, set the existing seven-second guidance for the selected Norn, record the command, and call the existing word-speaking/social-sharing path for its reply.
- A local speech toggle defaults on for the current page session. It affects only command replies. Changing it to off cancels queued output. No utterance is placed in the queue for an unsupported remote-only voice.
- Local voices may load asynchronously. If speech synthesis or a matching local voice is unavailable, display text replies and explain that audio is unavailable.
- The user command is the explicit interaction that can trigger speech. No unsolicited ambient TTS is added.

## Acceptance criteria

- A learned fruit word works with `eat` or `push`; a learned spinner word works with `play` or `push`.
- A word below confidence `0.6`, a praise/scold word, an unknown word, or an incompatible verb is rejected with clear feedback and no guidance change.
- A valid command guides only the selected Norn for the existing seven-second duration; the Norn still needs a relevant drive to complete the action.
- A valid command produces a journal/memory entry and an on-canvas learned-word reply.
- If the local voice toggle is enabled and a local voice exists, the reply is spoken. Remote-only voices are never used; unsupported speech output leaves the text interaction functional.
- Existing typed/voice teaching, pointing, praise/scold, and saves continue to use their current paths. No audio or speech queue is saved.

## Implementation review

Source and diff review will cover input parsing, name selection, vocabulary confidence and target resolution, mismatch rejection, guidance duration and agency, local-voice filtering, asynchronous voice availability, mute/cancel behavior, and unchanged save data. No automated tests will be added or run under the current developer instruction; final verification is a source review plus `git diff --check`.

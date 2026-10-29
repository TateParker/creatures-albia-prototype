# Free-Text Language Teaching — Design

**Status:** Approved and implemented

## Intent

Let the player teach each Norn user-entered words by pairing them with things and social feedback in the grove. The player selects a Norn, types a word, enters Teach mode, then selects Honey fruit, the Wind-up spinner, Praise, or Scold as its meaning. The prototype remains a local, inspectable simulation.

## Current behavior

The word selector contains only fruit and spinner. A teaching action pairs the selected word with its matching object, adds 0.38 confidence, and records a journal event and memory. A Norn starts using the word at 0.60 confidence. Praise and Scold currently modify the Norn's learned association with the most recent food or play success; they are not vocabulary targets.

## Goals

- Replace the fixed word selector with a text field for teaching one word at a time.
- Let the player pair that word with either visible object or with Praise or Scold.
- Keep object and feedback targets available through keyboard-accessible controls as well as the canvas.
- Keep learning inspectable through confidence, speech, memories, and journal events.
- Save, restore, and export taught words while preserving existing saved runs.

## Non-goals

- Teach sentences, arbitrary instructions, grammar, or open-ended conversation.
- Add speech recognition, an LLM, network access, or new physical objects.
- Change what Praise and Scold do when the player is not in Teach mode.
- Let learned words change simulation decisions or override the selected Norn's actual state.

## Approaches

1. **Teach words for objects only.** This reuses the current object-pairing flow, but does not cover the requested Praise and Scold associations.
2. **Teach words for objects and Praise/Scold targets.** The word is paired with one of four explicit concepts. This is the selected approach because it covers both things and feedback while keeping each association grounded in a specific interaction.
3. **Use Praise and Scold as reinforcement for any word.** This would require the simulation to infer which concept a free-text word refers to, broadening the learning model beyond explicit pairing.

## Interaction and learning

- Keep the selected Norn, add a labeled text field, and retain the **Teach word** control.
- In Teach mode, selecting either object through its button or the scene teaches the current word to that object. Selecting Praise or Scold teaches the current word to that feedback target; those clicks do not apply behavior feedback while Teach mode is active.
- Outside Teach mode, Point, Praise, and Scold retain their current behavior.
- Proposed input rule: accept one non-empty word of up to 24 characters, trim surrounding whitespace, and compare words without case sensitivity. Keep the player's entered capitalization for display. Reject phrases and invalid input with a clear message; remain in Teach mode so the player can correct it.
- A Norn may know multiple words for one target, but a given Norn's same normalized word maps to only one target. Teaching that word to the same target again adds the existing 0.38 confidence; trying to pair it with a different target explains the conflict and makes no change.
- Keep the current 0.60 use threshold. Norns may speak object words when seeking or using their object, and feedback words when receiving or observing the matching feedback. Nearby listeners may learn a spoken custom word using the existing sociability and distance rules.
- Show learned words and confidence in the Norn inspector, grouped by object or feedback target. Record each valid teaching and word use in the journal and memories, linking observed word learning to its source event where applicable.

## State, saves, and safety

- Store each custom word as plain text with its target and confidence, scoped to its Norn. Render it with text nodes, never as HTML.
- Extend save validation with limits on word count, word length, valid targets, and confidence. Migrate current schema-version-1 saves by preserving existing fruit and spinner confidence and initializing custom vocabulary empty. Keep download exports complete.
- Clear any active word and teaching target on cancel, Norn change, reset, and restore, following the current mode-reset behavior.
- No automated tests are planned under the repository's existing constraint; implementation review will focus on mode transitions, target collisions, legacy saves, export, and visible text handling.

## Implementation clarifications

- Custom vocabulary is capped at 32 entries per Norn. Input and restored saves use the same one-word, 24-character limit; matching uses trimmed Unicode NFKC text in lowercase.
- Hearing a spoken custom or built-in word adds 0.14 confidence to that word. Feedback speech uses the same 0.60 utterance threshold as object words, and listeners use the existing 330-pixel distance and Sociability checks.
- Save schema version 2 stores custom words and generic speech target IDs. Valid version-1 saves migrate in memory, converting object speech IDs to target IDs and retaining built-in fruit/spinner confidence; the next normal save writes version 2 under the existing lock.
- Implementation review followed the approved no-tests constraint and used source/diff review only.

## Acceptance criteria

- A player can type a word and teach it to either object, Praise, or Scold using the accessible controls or canvas where applicable.
- Teach mode never accidentally applies Praise or Scold as behavior feedback.
- Repeated valid teaching raises confidence and eventually produces a contextually grounded utterance; a nearby listener can learn the utterance.
- Custom words survive save/restore and export, and existing v1 saves still load with their fruit/spinner progress intact.
- Invalid or conflicting words leave learning unchanged and produce a clear explanation.

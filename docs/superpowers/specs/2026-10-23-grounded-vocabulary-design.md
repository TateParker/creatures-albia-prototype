# Grounded Vocabulary Learning

## Intent

Give the player a simple way to teach Mallow and Moss words that refer to visible habitat objects, then let the Norns use and learn those words through experience. The notebook and journal must show where each word association came from.

## Goals

- Teach the words `fruit` and `spinner` by pairing each with its matching habitat object.
- Track each Norn's confidence for each word from 0 to 100 percent.
- Let Norns who know an object's word say it after a related successful interaction.
- Let a nearby Norn acquire a small amount of word confidence by hearing that utterance during a shared observation.
- Keep speech, memories, and journal entries grounded in recorded simulation events.

## Non-goals

- No free-form or generative dialogue, external model, network call, or third-party library.
- No grammar system, vocabulary expansion UI, or persistence in this slice.
- No word assignment to incorrect objects; mismatched teaching attempts should explain the expected object.

## Constraints

- Preserve the self-contained static HTML build and current local-first simulation.
- Reuse the current Point interaction pattern for teach mode and the existing event/memory display.
- A word reaches speaking confidence at 60%; player teaching adds 38 percentage points and witnessed speech adds 14 points, clamped to 100%.
- A Norn may speak a known object word after successfully using that object; social learning only occurs when another Norn is close enough to observe.

## Approaches

- **Contextual teach mode (chosen):** Select a word, then click the matching object, following the familiar Point-then-click flow. It makes the mapping visible and supports grounded feedback with little UI complexity.
- Passive vocabulary acquisition: words appear through repeated exposure without a direct teaching action. This is simpler but gives the player less control and makes the evidence for learning less clear.
- Generative speech: ask a language model to create utterances. That adds services and can say things not supported by the small simulation, so it does not fit this slice.

## Behavior

The habitat controls gain a word selector and **Teach word** action. Selecting a word and starting teaching enters a mode that asks the player to click its matching object. A successful lesson increases the selected Norn's confidence, records the exact pairing, and may display a short contextual utterance if the Norn is ready to speak. A mismatched object leaves teaching mode active and states the correct match.

Each Norn has independent confidence for `fruit` and `spinner`. At 60% confidence, they may say the related word after eating or playing. A nearby observer who witnesses that utterance gains 14 percentage points and a memory explaining who said which word while using which object. The inspector shows both word confidence values.

## Builder choices

- Keep teaching success deterministic and confidence-based; no random chance is used for player-taught words.
- Keep each utterance to the relevant learned noun in this slice. Richer speech can be added after persistence and more grounded concepts exist.

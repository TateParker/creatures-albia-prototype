# Portable Norn Cognition and Godot Roadmap — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add local biochemical drives, contextual learning, and persistent memory to the browser prototype through a cognition core that can later be ported to Godot.

**Architecture:** Keep index.html as the playable browser harness and add a local cognition.js script with deterministic, data-in/data-out behavior. The browser adapter supplies observations and applies actions; the cognition core owns chemistry, action choice, compact learning state, and episode retrieval. A future Godot project will provide a separate 3D adapter and a GDScript port.

**Tech Stack:** Static HTML/CSS, vanilla JavaScript, browser localStorage and on-device SpeechRecognition in the existing adapter; future Godot/GDScript.

**Spec:** docs/superpowers/specs/2026-10-28-portable-norn-cognition-design.md

## Global Constraints

- No runtime cloud, remote model, external speech service, or runtime network dependency.
- Keep index.html playable from disk and static hosting with no build step.
- Keep browser APIs, canvas rendering, speech recognition, and persistence outside cognition.js.
- Preserve typed teaching and explicit processLocally-only push-to-talk recognition.
- Preserve save versions 1–4; the implementation schema is now version 7.
- Keep the four-Norn gameplay cap during initial browser work; use 12 Norns only as a stress scenario.
- Start at 8–12 chemical channels, 10 Hz chemistry, 5 Hz decisions, a 128-unit policy pilot, and up to 512 salient episodes per Norn. Tune only from observed behavior and profiling.
- Do not add automated test suites or run tests under the existing project constraint; use scoped source review and repeatable manual playthroughs.

## Review Focus

- Legacy saves restore every existing association, family member, and word after the schema upgrade; manually open representative version 1–4 saves.
- Speech recognition remains explicit, local-only, and independent from cognition; manually inspect API-unavailable and cancelled sessions.
- Fixed-step updates remain stable when the browser tab pauses or resumes; manually check pause, speed changes, and long frame gaps.
- Recalled memories and learning changes remain bounded and deterministic; manually repeat the same seeded scenario and inspect why scores changed.
- The 12-Norn stress scenario does not silently change the four-Norn gameplay cap; inspect both population limits and frame-time measurements.

---

### Task 1: Define the portable cognition boundary

**Files:**
- Create: cognition.js
- Modify: index.html
- Modify: README.md

**Interfaces:**
- Expose window.NornCognition.createState(seed, traits) -> CognitiveState.
- Expose window.NornCognition.advanceChemistry(state, stimuli, dt) -> chemical levels; the browser calls it at the fixed 10 Hz chemistry cadence.
- Expose window.NornCognition.decide(state, observation) -> Decision, containing actionId, actionScores, reason, and recalledEpisodeIds; the browser calls it at the 5 Hz policy cadence.
- Expose window.NornCognition.recordOutcome(state, outcome) -> LearningSummary.
- Expose window.NornCognition.serialize(state) -> plain JSON object and restore(record) -> CognitiveState or null.
- Observation uses plain data: needs/chemistry, nearby objects with IDs, categories, relative distance/direction and affordances, nearby Norns, guidance, and language signals. No DOM nodes, canvas objects, or browser APIs cross this boundary.

- [x] Add cognition.js as a normal local script and define the public API without changing existing controls.
- [x] Route getDecisionScores and the fixed-step decision scheduler through a thin adapter that builds observations and applies returned decisions.
- [ ] Manually open index.html from disk and static hosting; confirm existing point, teach, feedback, movement, command, and save behavior still works.

### Task 2: Add a small deterministic biochemical system

**Files:**
- Modify: cognition.js
- Modify: index.html — createInitialState, createHatchedNorn, update loop, inspector UI, getSaveSnapshot, restoreSaveRecord.
- Modify: README.md

**Interfaces:**
- Add named concentrations for 8–12 core signals, including glucose/energy, hunger, curiosity, fatigue, reward, punishment, stress, and social comfort.
- Add a data-driven reaction table with bounded concentrations and deterministic fixed-step updates at 10 Hz.
- Keep current hunger and curiosity display values as mapped views of the corresponding chemical levels.
- Upgrade the save schema from version 4 to 5 and migrate schemas 1–4; map old needs into chemistry and legacy learned preferences into separate action-bias values.

- [x] Add the chemistry state and initialize both starter and hatched Norns with the same named channels.
- [x] Advance chemistry at 10 Hz independently of canvas frame rate; clamp concentrations and bound catch-up work after tab stalls.
- [x] Connect food, play, rest, social attention, praise, and scolding to the relevant reaction and drive changes.
- [x] Add an inspector section for key concentrations while retaining the existing needs meters.
- [x] Manually restore representative version 1–4 saves in an isolated localhost origin, pause, change speed, and leave/resume a background tab; check that chemistry stays bounded and the Norn remains responsive.

### Task 3: Add persistent episodic memory and bounded outcome learning

**Files:**
- Modify: cognition.js
- Modify: index.html — recordEvent, recordSuccess, teachWord, shareObservation, shareFeedbackObservation, renderMemories, buildSaveRecord, restoreSaveRecord.
- Modify: README.md

**Interfaces:**
- Define an Episode record with ID, time, observation summary, actor, action, target, chemical levels before/after, outcome, linked event ID, and salience.
- Retain up to 512 salient episodes per Norn as an initial cap; keep the current recent journal limit independent.
- Retrieve up to three episodes by recency, salience, and structured context match.
- Store a compact action-association and eligibility value per action/context; apply bounded changes from reward or punishment without modifying every recurrent weight.

- [x] Record high-value action outcomes, teaching events, observed successes, and praise/scold feedback as structured episodes.
- [x] Add deterministic memory retrieval to the decision result and show recalled moments in the inspector with their journal links.
- [x] Update action/context associations with eligibility traces, weight limits, and a per-event learning cap; leave a no-op outcome unchanged.
- [x] Upgrade the save schema to version 7 in the same implementation wave, migrating versions 1–4; persist and restore episode and learning state while keeping journal and memory caps separate.
- [x] Manually teach, reward, scold, observe a peer, reload, and revisit a similar situation; inspect that the relevant memories and preference changes persist.

### Task 4: Pilot a compact recurrent decision core

**Files:**
- Modify: cognition.js
- Modify: index.html — decision adapter and choice explanation UI.
- Modify: README.md

**Interfaces:**
- Add a 128-unit recurrent state pilot to CognitiveState; initialize its fixed feature weights deterministically from a per-Norn seed that does not consume the world's RNG.
- Keep the current rule-based chooser as the safe fallback and starter bias.
- Return action scores and reason traces for fruit, spinner, rest, observe-peer, and idle actions.
- Keep online learning confined to compact action associations during this milestone.

- [x] Add the recurrent state update at 5 Hz with a commitment window that prevents target jitter.
- [x] Blend recurrent context and retrieved memories into action scores while preserving instinctive survival behavior and the rule-based fallback.
- [x] Upgrade the save schema to version 7; preserve versions 1–4 and save recurrent state and action/context associations, then rebuild runtime typed arrays from allowlisted JSON data.
- [x] Manually compare the same seeded scenarios with the old chooser and the pilot. At 20 seconds with four Norns, the pilot used recalled episodes in 380/400 choices (95%) while action counts, food/play successes, hunger, glucose, and episode count matched the legacy chooser. In a 10-second, 12-Norn stress comparison, the pilot used recalled episodes in 521/600 choices and improved food/play successes (7/6 vs 6/4), mean hunger (48.1 vs 51.6), and glucose (57.2 vs 54.4). At 40 seconds with four Norns, action distribution shifted but successes, needs, and episode count still matched.
- [x] Profile frame work for four Norns and the 12-Norn stress setup on the current Windows browser baseline; keep the 95th-percentile frame under 16.6 ms before any population-cap change is considered. Measured p95 was 0.40–0.50 ms for four Norns; the 12-Norn 10-second comparison measured 0.70 ms for the pilot and 1.10 ms for legacy in one Codex browser session.
- [x] Run the 10-second legacy/pilot comparison for all three benchmark seeds at four Norns and the 12-Norn stress profile; compare only matching seed/population/duration rows and retain all 12 results for review. The pilot recalled episodes in 1,999/2,400 choices overall (405/600 at four Norns and 1,594/1,800 at 12 Norns). All three four-Norn pairs matched the legacy chooser's action counts, successes, hunger, glucose, and episode counts. The 12-Norn pilot improved food/play successes for seed 4181996 (7/6 vs 6/4); outcomes matched for the other two seeds. Frame-work p95 ranged from 0.40 to 0.80 ms across all 12 runs, below the 16.6 ms review target.
- [x] Extend the four-Norn comparison to 20 seconds for all three seeds. The pilot recalled episodes in 855/1,200 choices (380/400, 190/400, and 285/400). Action counts, successes, hunger, glucose, and episode count matched legacy for every seed; p95 ranged from 0.40 to 0.50 ms in this browser session.

### Task 5: Integrate word learning and social experience

**Files:**
- Modify: cognition.js
- Modify: index.html — teachWord, recordWordHearing, shareSpokenWord, shareObservation, renderVocabulary, renderMemories.
- Modify: README.md

**Interfaces:**
- Keep custom word associations as concept links to existing object and feedback targets.
- Add action/context links to the episode and action-association records without changing the existing one-word push-to-talk contract.
- Socially observed words and successes enter the listener's own memory with lower salience than direct experience.

- [x] Feed typed and recognized words into the same local concept records; keep microphone and speech API calls in index.html.
- [x] Record who taught or spoke a word and the context in which it was heard.
- [x] Apply lower-weight learning from nearby Norns while preserving current sociability checks and confidence limits.
- [ ] Manually verify typed teaching, local push-to-talk, Praise/Scold teaching, peer hearing, and command replies without network access.

### Godot 3D Vertical Slice — Complete

The user authorized the Godot phase on 2026-10-28 and asked to review after the vertical slice. The implementation and verification record is in `docs/superpowers/plans/2026-10-28-godot-albia-vertical-slice.md`; design decisions are in `docs/superpowers/specs/2026-10-28-godot-albia-vertical-slice-design.md`. The browser push-to-talk recognition manual check remains deferred at the user's request; the Godot slice excludes speech input/output.

- Created `godot/` for Godot 4.7.2-stable Standard while retaining the browser reference.
- Ported chemistry, action IDs, deterministic recurrent state, learning, episodic recall, and safe JSON persistence to GDScript.
- Built a single-Norn 3D habitat with local sensing, fruit/spinner interactions, guidance, Praise/Scold, and a compact HUD.
- Matched fixed-seed browser/Godot decisions, reasons, recalls, outcomes, chemistry, and associations within floating-point noise.
- Profiled a 600-frame one-Norn scene at a 60 FPS cap and the fixed-step cognition calls; results and machine details are in `godot/README.md`.

## Review Gate

Review the Godot slice before expanding to additional Norns, production art/animation, pixel-based perception, or a full 3D habitat. Keep the browser as the cognition reference harness.

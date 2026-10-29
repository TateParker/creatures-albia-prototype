# New Albia — A Living World Prototype

A small, self-contained browser prototype inspired by the artificial-life and creature-care ideas of *Creatures* (1996). Two original, code-drawn Norns explore a habitat, respond to their needs, learn from player feedback, and watch one another. Young Norns can hatch from eggs and join the grove.

## Play

Open [`index.html`](index.html) in a modern browser. There is no build step, server, account, or network connection required.

- Select any Norn to inspect their needs, tendencies, learned associations, and event-based memories. Mallow and Moss are the original pair; young Norns join the same roster after hatching.
- Inspect **Biochemistry** for ten bounded local signals. Hunger and curiosity remain visible as needs; energy, fatigue, reward, punishment, stress, social comfort, arousal, and satiety also affect behavior.
- **Choice signals** now show five local action scores: fruit, spinner, rest, observe a nearby Norn, and idle. Norns update chemistry at 10 Hz and reconsider choices at 5 Hz; a short commitment window prevents needless target switching. Their compact 128-unit recurrent state stays local and runs without a generative model or network service.
- The visible journal remains short, while each Norn keeps up to 512 structured episodes for context-based recall. Recalled moments appear with their source journal links when available. Direct outcomes, Praise/Scold, word teaching, and noticed peer behavior add bounded learning records.
- Explore three connected regions—Sunmeadow, Softwood Grove, and Glassfall Hollow—with the **West** and **East** buttons. The selected Norn is followed as they move; scrolling pauses follow, and **Follow [name]** or selecting a Norn returns the camera to them. Honey fruit is in the starting meadow and the spinner sits across the map in Glassfall Hollow, so Norns may take a longer trip to reach what they want.
- Check **Choice signals** in the notebook to compare the Norn's current action scores and inspect the reason and recalled moments behind a choice.
- Choose **Point** and click an object, or use the **Honey fruit** and **Wind-up spinner** buttons below the scene to point the selected Norn toward one. Guidance lasts up to seven in-game seconds; **Choice signals** shows the remaining time and what the Norn would choose alone.
- Type one word (up to 24 characters), select **Teach word**, then choose Honey fruit, Wind-up spinner, **Praise**, or **Scold** as its meaning. You can point at an object in the scene or choose its accessible button. Teach the same word to the same target twice for enough confidence to start hearing it; Norns can know several words for one target, but each word has one meaning per Norn.
- For voice teaching, choose a **Word meaning**, then hold **Hold to speak** while saying one word and release to teach it. The browser may ask for microphone permission the first time. Recognition is requested on-device only and starts only while the control is held. It depends on browser support and an available local language model; if unavailable, use typed teaching. The app does not download language packs or fall back to a remote speech service.
- To command a selected Norn, try **eat fruit**, **play spinner**, or **push fruit**; you can prefix the command with the Norn's name. They must know the object word clearly first, which usually takes teaching it twice. A command guides them for up to seven in-game seconds, but their needs still determine whether they eat or play. They answer with a learned word bubble; **Speak command replies** uses a local browser voice when one is available, never a remote voice, and can be muted.
- Under **Family and inheritance**, pair the selected Norn with another Norn and choose **Lay an egg**. This small prototype lets any two Norns pair without tracking sex or mating compatibility. The camera moves to the nest so you can see the egg; choose **Follow [name]** to return to that Norn. An egg hatches after 45 in-game seconds, following pause and simulation speed. A young Norn inherits curiosity and sociability from both parents with a small variation, plus a blended coat palette. They get a fresh hatch memory but no inherited words, memories, or preferences, and can use the same teaching and command controls as the original pair. The small grove holds up to four Norns and incubating eggs combined.
- While Teach word is active, **Praise** and **Scold** buttons teach those meanings and do not give behavior feedback. Outside Teach mode, use **Praise** or **Scold** within 12 in-game seconds after a Norn eats or plays; each action accepts one response, and the immediate message names the fruit or spinner association and whether it changed or reached its limit.
- Choose **Download this run** to save a timestamped JSON snapshot of this tab's current grove, including progress that has not been autosaved yet.
- Choose **Show all moments** below the recent journal to reveal up to 12 retained observations; the newest three are visible by default.
- In a Norn's recent memories, choose **Find in journal** to reveal and focus a memory's source moment while it remains in the retained journal.
- Pause the habitat or cycle simulation speed through **1×**, **2×**, and **0.5×**. At half speed, the grove takes twice as long to simulate each in-game second. **Reset** asks before discarding this tab's progress and replacing the saved run if it can be safely updated.

The portable `cognition.js` core owns chemistry, contextual action choice, compact recurrent state, bounded action associations, and episodic recall. `index.html` adapts the browser habitat into plain structured observations and handles movement, rendering, speech, input, and persistence. A matching GDScript cognition port and playable 3D vertical slice are available in [`godot/`](godot/), with the browser remaining the behavior reference. The current browser save schema is version 7; versions 1–4 migrate into the new chemistry and learning state while preserving existing Norns, family data, words, and associations.

### Local profiling

Serve the project folder with a static HTTP server and open `index.html?benchmark=1` to compare the legacy chooser with the cognition pilot at 2, 4, or 12 Norns. Select one of the fixed seeds (4181996, 20261028, or 8675309); each run resets to that seed and reports it alongside 95th-percentile app frame work, needs, action outcomes, retained episodes, and how often the pilot scores recalled episodes. The page compares policies only when seed, population, and duration match. The 12-Norn option is a stress profile; regular gameplay remains capped at four. Benchmark mode skips save restoration and disables writes in that tab.

### Godot 3D preview

The native 3D vertical slice is available in [`godot/`](godot/). Open it with Godot 4.7.2-stable Standard. The browser version remains playable and serves as the cognition reference; see [`godot/README.md`](godot/README.md) for setup and launch notes.

The prototype models a connected three-region world, biochemical needs, movement, food, a spinner toy, player guidance, Praise and Scold, nearby social observation, grounded vocabulary, and simple inheritance. A nearby Norn's Sociability sets its chance of noticing another's success, hearing a spoken word, or noticing feedback. Norns can learn from their own outcomes and from peers, and can say a known word while seeking or using an object or after feedback. Typed teaching and push-to-talk both update the same local word associations; speech recognition requests the browser's on-device mode and has no remote fallback. Command replies use a local browser voice only when available and enabled. When browser storage and Web Locks are available, the grove saves each Norn's identity, inherited traits, needs, learning, custom words, memories, chemistry, episodes, recurrent state, eggs, and recent journal. Autosaves do not sync between browsers or devices; clearing this site's browser data removes them. Use **Download this run** to keep a separate JSON copy.

Saving and Reset share an exclusive browser lock and check that the saved run has not changed before replacing it. If another open tab changes the grove, reload the older tab to save there again; its Reset cannot replace the newer run. If safe locking or storage is unavailable, the grove remains playable in memory and the save status explains why progress is not being saved. Reset then starts a fresh grove only in that tab and preserves the existing saved run. Web Locks generally requires a secure browser context, such as the HTTPS published site. Saves requested while hiding or closing the page are best effort; closing before a pending lock is granted can lose the most recent changes.

## Scope

This is a concept prototype, not a full remake. It uses a lightweight local simulation and does not connect to a language model or send data anywhere. AI here means inspectable behavior and learning systems; an eventual generative layer could support richer expression, but should remain bounded by the simulation's actual state.

The project is an independent fan concept. It is not affiliated with or endorsed by the creators or rights holders of *Creatures*. It contains no copied game artwork or sounds.

## Publishing

The GitHub Actions workflow in `.github/workflows/deploy-pages.yml` publishes `index.html` and its local `cognition.js` dependency to GitHub Pages whenever `main` is updated. The repository must have Pages configured to use GitHub Actions.

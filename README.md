# New Albia — A Living World Prototype

A small, self-contained browser prototype inspired by the artificial-life and creature-care ideas of *Creatures* (1996). Two original, code-drawn Norns explore a habitat, respond to their needs, learn from player feedback, and watch one another.

## Play

Open [`index.html`](index.html) in a modern browser. There is no build step, server, account, or network connection required.

- Select Mallow or Moss to inspect their needs, tendencies, learned associations, and event-based memories.
- Check **Choice signals** in the notebook to see how hunger, curiosity, and learned preferences contribute to the current fruit-versus-spinner decision.
- Choose **Point** and click an object, or use the **Honey fruit** and **Wind-up spinner** buttons below the scene to point the selected Norn toward one. Guidance lasts up to seven in-game seconds; **Choice signals** shows the remaining time and what the Norn would choose alone.
- Choose **fruit** or **spinner** in the word menu, click **Teach word**, then click or activate the matching object. Teaching twice is enough to start using the word.
- Use **Praise** or **Scold** within 12 in-game seconds after a Norn eats or plays; each action accepts one response, and the immediate message names the fruit or spinner association and whether it changed or reached its limit.
- Choose **Download this run** to save a timestamped JSON snapshot of this tab's current grove, including progress that has not been autosaved yet.
- Choose **Show all moments** below the recent journal to reveal up to 12 retained observations; the newest three are visible by default.
- In a Norn's recent memories, choose **Find in journal** to reveal and focus a memory's source moment while it remains in the retained journal.
- Pause the habitat or cycle simulation speed through **1×**, **2×**, and **0.5×**. At half speed, the grove takes twice as long to simulate each in-game second. **Reset** asks before discarding this tab's progress and replacing the saved run if it can be safely updated.

The prototype models hunger, curiosity, movement, food, a spinner toy, player guidance, positive and negative feedback, nearby social observation, and grounded vocabulary. A nearby Norn's Sociability sets its chance of noticing another's success, hearing a word like “fruit” or “spinner,” or noticing your Praise or Scold. After noticing a success, it can learn the demonstrated behavior; seeing Praise or Scold can strengthen or weaken the same association. Associations have limits; the journal and memory explain when feedback cannot change one further. Norns may say a known object word when switching to that target and after using it, and a nearby listener may learn the word based on its sociability. Their notebook shows word confidence, and the journal and memories show the events behind it. When browser storage and Web Locks are available, the grove saves automatically in this browser, including each Norn's needs, learning, words, memories, and recent journal. The browser autosave does not sync to other browsers or devices; clearing this site's browser data removes it. Use **Download this run** to keep a separate JSON copy.

Saving and Reset share an exclusive browser lock and check that the saved run has not changed before replacing it. If another open tab changes the grove, reload the older tab to save there again; its Reset cannot replace the newer run. If safe locking or storage is unavailable, the grove remains playable in memory and the save status explains why progress is not being saved. Reset then starts a fresh grove only in that tab and preserves the existing saved run. Web Locks generally requires a secure browser context, such as the HTTPS published site. Saves requested while hiding or closing the page are best effort; closing before a pending lock is granted can lose the most recent changes.

## Scope

This is a concept prototype, not a full remake. It uses a lightweight local simulation and does not connect to a language model or send data anywhere. AI here means inspectable behavior and learning systems; an eventual generative layer could support richer expression, but should remain bounded by the simulation's actual state.

The project is an independent fan concept. It is not affiliated with or endorsed by the creators or rights holders of *Creatures*. It contains no copied game artwork or sounds.

## Publishing

The GitHub Actions workflow in `.github/workflows/deploy-pages.yml` publishes `index.html` to GitHub Pages whenever `main` is updated. The repository must have Pages configured to use GitHub Actions.

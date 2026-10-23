# New Albia — A Living World Prototype

A small, self-contained browser prototype inspired by the artificial-life and creature-care ideas of *Creatures* (1996). Two original, code-drawn Norns explore a habitat, respond to their needs, learn from player feedback, and watch one another.

## Play

Open [`index.html`](index.html) in a modern browser. There is no build step, server, account, or network connection required.

- Select Mallow or Moss to inspect their needs, tendencies, learned associations, and event-based memories.
- Choose **Point**, then click food or the spinner to guide the selected Norn.
- Choose **fruit** or **spinner** in the word menu, click **Teach word**, then click the matching object. Teaching twice is enough to start using the word.
- Select a Norn and use **Praise** soon after they eat or play to reinforce that action.
- Use **Scold** after a recent action to weaken that action’s learned association. Each action accepts one response, either Praise or Scold.
- Pause the habitat or change its simulation speed. **Reset** starts a fresh run.

The prototype models hunger, curiosity, movement, food, a spinner toy, player guidance, positive and negative feedback, nearby social observation, and grounded vocabulary. Norns can say a learned object word after using that object, while a nearby observer can learn the word by hearing it. Their notebook shows word confidence, and the journal and memories show the events behind it.

## Scope

This is a concept prototype, not a full remake. It uses a lightweight local simulation and does not connect to a language model or send data anywhere. AI here means inspectable behavior and learning systems; an eventual generative layer could support richer expression, but should remain bounded by the simulation's actual state.

The project is an independent fan concept. It is not affiliated with or endorsed by the creators or rights holders of *Creatures*. It contains no copied game artwork or sounds.

## Publishing

The GitHub Actions workflow in `.github/workflows/deploy-pages.yml` publishes `index.html` to GitHub Pages whenever `main` is updated. The repository must have Pages configured to use GitHub Actions.

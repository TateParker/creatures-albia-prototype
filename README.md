# New Albia — A Living World Prototype

A small, self-contained browser prototype inspired by the artificial-life and creature-care ideas of *Creatures* (1996). Two original, code-drawn Norns explore a habitat, respond to their needs, learn from player feedback, and watch one another.

## Play

Open [`index.html`](index.html) in a modern browser. There is no build step, server, account, or network connection required.

- Select Mallow or Moss to inspect their needs, tendencies, learned associations, and event-based memories.
- Choose **Point**, then click food or the spinner to guide the selected Norn.
- Select a Norn and use **Praise** soon after they eat or play to reinforce that action.
- Use **Scold** after a recent action to weaken that action’s learned association. Each action accepts one response, either Praise or Scold.
- Pause the habitat or change its simulation speed. **Reset** starts a fresh run.

The prototype models hunger, curiosity, movement, food, a spinner toy, player guidance, positive and negative feedback, and nearby social observation. Its Norns learn through small local association weights and a short event history. The journal and inspector show the events behind those memories.

## Scope

This is a concept prototype, not a full remake. It uses a lightweight local simulation and does not connect to a language model or send data anywhere. AI here means inspectable behavior and learning systems; an eventual generative layer could support richer expression, but should remain bounded by the simulation's actual state.

The project is an independent fan concept. It is not affiliated with or endorsed by the creators or rights holders of *Creatures*. It contains no copied game artwork or sounds.

## Publishing

The GitHub Actions workflow in `.github/workflows/deploy-pages.yml` publishes `index.html` to GitHub Pages whenever `main` is updated. The repository must have Pages configured to use GitHub Actions.

# Decision Transparency

## Intent

Make the existing Norn food-versus-toy preference legible in the notebook. This supports the prototype's existing goal of inspectable behavior and learning systems.

## Goals and non-goals

- Show the live need and learned-preference contributions that the decision rule compares.
- Show the same result as the existing target selector, including its rest threshold and player-point override.
- Keep the current simulation, timing, learning, and persistence behavior unchanged.
- Do not add generative explanations, new decision rules, network calls, or dependencies.

## Constraints

- Reuse the exact formulas: fruit pull is `max(0, hunger - 17) * 1.05 + learned.fruit * 35`; spinner pull is `max(0, curiosity - 16) * (0.58 + traits.curiosity * 0.46) + learned.spinner * 32`.
- A Norn has no independent target when fruit pull is below 11 and spinner pull is below 14; otherwise the larger pull wins, with ties going to the spinner.
- An active point to that Norn overrides the autonomous choice until the guidance timer expires.
- Keep the single-file browser build and current persistence schema.

## Approaches

- **Paired live pull rows (chosen by the implementer):** Show a current preference summary and two compact rows with the need and learned-preference contributions. The decision helper will feed both simulation and UI, so the explanation cannot drift from behavior.
- **Natural-language reason only:** Reuse the current reason string. This avoids visual density but hides the relative drives and habit strengths that the user wants to inspect.
- **Generative decision explanation:** Ask a language model to narrate each choice. This adds a network dependency and could invent motives beyond simulation state, so it conflicts with the grounded prototype.

## Behavior

The notebook adds a compact **Choice signals** section. It displays either the active player guidance, the autonomous top choice, or that neither need crosses its choice threshold. Fruit and spinner rows show their exact current total and the need/learned-preference contributions used to calculate it. Meters are scaled to a fixed display maximum and include accessible names and values.

## Builder choices

- Factor the existing formulas and threshold/tie rule into one read-only scoring helper used by both `chooseTarget` and the inspector.
- Keep score display precision to whole points; show component values as whole points as well.
- Do not persist display values; derive them from the live Norn fields.

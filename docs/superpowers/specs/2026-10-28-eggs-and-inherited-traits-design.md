# Eggs and Inherited Traits Design

**Status:** Implemented in the current working tree

## Goal

Add a small, inspectable family system to New Albia: the player chooses two Norns to start an egg, watches it incubate in the habitat, and meets a young Norn whose curiosity and sociability come from both parents.

## Experience

- A Family panel lets the player pair the selected Norn with another Norn and start an egg.
- Eggs incubate for 45 in-game seconds, pause with the simulation, and appear in a nest in the grove.
- Hatching adds a young Norn to the roster, with a blended coat palette and curiosity/sociability based on the parents' average plus a small seeded variation.
- The notebook identifies the Norn's generation and parents. A young Norn begins with no vocabulary or object associations and learns through the existing systems.
- The grove supports at most four living Norns and incubating eggs combined. No egg can start when this limit is reached.
- Any two existing Norns can be selected as parents; this prototype has no sex or mating-compatibility model.

## Data and Saving

- Add `eggs` and `nextNornNumber` to simulation state and snapshots.
- Save Norn names, colors, generation, and parent IDs in schema version 3.
- Continue loading schema version 1 and 2 saves as the original Mallow and Moss, with no eggs and no ancestry.
- Validate dynamic child IDs, lineage, palettes, parent references, egg parent references, incubation values, and population limits before restoring a schema-3 save.
- Persist the egg's child ID, name, inherited trait values, and blended color when it is created so loading does not reroll its inheritance.

## Boundaries

- No age progression, death, sex, mating behavior, multiple habitats, or breeding animation.
- No inherited learned vocabulary, memories, preferences, or needs.
- Keep all simulation, rendering, and persistence local in the existing self-contained page.
- Do not add or run automated tests unless the user asks. Review source and whitespace only.

## Acceptance

- The player can select two distinct Norns and start an egg when population capacity permits.
- Eggs visibly incubate and hatch according to simulation time; pausing stops incubation.
- Hatching creates a selectable, active Norn with an inspectable generation and ancestry.
- The child inherits both parent traits with bounded variation and begins with no learned words or object associations.
- Schema 1 and 2 saves still restore the original two Norns; schema 3 safely preserves children and eggs.
- README explains the family controls, limits, inheritance, and what the child does not inherit.

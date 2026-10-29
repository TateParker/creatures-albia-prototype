# Explorable Albia Design

**Status:** Implemented in the current working tree

## Goal

Make the prototype habitat feel like a connected place the player and Norns can explore, while preserving the existing needs, vocabulary, command, family, and learning systems.

## Experience

- Expand the simulation into three connected 960-unit regions: Sunmeadow, Softwood Grove, and Glassfall Hollow.
- Keep a 960-unit camera viewport and add west/east navigation plus a **Follow selected** control.
- The camera follows the selected Norn while follow mode is active. Scrolling manually pauses follow; selecting a Norn or activating guidance resumes it.
- Starting an egg focuses the nest and pauses follow so the incubation is visible; **Follow selected** returns to the Norn.
- Give each region a distinct palette and landmark treatment. Keep the nest and fruit in the starting area and move the spinner to Glassfall Hollow so a curious Norn can travel across the map.
- Keep object interactions, decision logic, and learning grounded in the existing fruit and spinner systems.

## Saving

- Bump saves to schema version 4 because Norn world positions can now exceed the old 865-unit boundary.
- Continue loading schemas 1, 2, and 3. Schema-3 family saves keep the old position bounds; schema-4 saves use the expanded world bounds.
- Do not persist camera position. On load, follow the selected Norn and show their current location.

## Boundaries

- Do not add new needs, resources, rooms with separate simulation rules, pathfinding, portals, or fast travel.
- Keep the world and camera local to the existing canvas and self-contained page.
- Do not add or run automated tests unless the user asks; perform source review and `git diff --check` only.

## Acceptance

- The viewport can navigate west and east across all three regions, and can return to the selected Norn.
- The scene and canvas clicks use the same camera coordinates, including point-to-object interaction and Norn selection.
- Norns can traverse the longer map to reach the spinner while keeping existing behavior and social learning.
- Schema 1, 2, and 3 saves still load; schema 4 preserves children, eggs, and Norns anywhere in the expanded world.

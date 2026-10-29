# Meshy Habitat Prompt Set

These prompts cover 14 approved model families. The initial 14 preview/refine pairs and one additional egg retry completed with the pinned Meshy CLI 0.4.0. Actual spend is 255 credits; the approved ceiling was 420 credits, leaving 165. The latest account balance was 860 credits on 2026-10-29. Per-asset task IDs, charges, triangle counts, paths, and review notes are in [the request manifest](meshy_output/habitat_asset_requests.json) and [the inventory](../../godot/ASSET_INVENTORY.md).

All final models requested GLB output with PBR textures at 2K. The Norn result came out seated rather than in the requested A-pose, with no rig or skin. The user approved it; it is now the runtime Norn body in a validated, admitted package. The procedural body remains as a fallback and the actor's scripted movement and drawing effector remain active. Meshy task records contain no separate license receipt; verify applicable terms before redistribution.

| Model family | Prompt |
|---|---|
| Meadow ground tile/material | A modular soft low-poly game ground tile for an original cozy fantasy habitat, rolling meadow grass with subtle clover and moss color variation, flat square surface, clean edges, no rocks or props, no text, no background. |
| Path segment | A modular low-poly worn earth and smooth stepping-stone path segment for an original cozy fantasy habitat, softly rounded edges and muted warm brown tones, clean repeatable ends, no text, no background. |
| Tree | A reusable stylized low-poly broadleaf tree for an original cozy fantasy habitat, warm tapered trunk and clustered green canopy with soft leaf color variation, sturdy simple silhouette, no text, no background. |
| Rock | A reusable low-poly mossy boulder for an original cozy fantasy habitat, rounded faceted stone with subtle gray-green surface texture, simple readable silhouette, no text, no background. |
| Nest | A small woven grass nest bowl for a gentle fantasy creature habitat, low-poly braided natural fibers, shallow oval interior, warm straw and brown color variation, no eggs, no text, no background. |
| Honey fruit | A plump golden-orange honey fruit for a cozy fantasy creature habitat, low-poly organic round body, short brown stem and one small green leaf, softly mottled edible skin texture, no text, no background. |
| Spinner | A charming low-poly wind-up spinner toy for a cozy fantasy habitat, small blue base, brass axle, colorful cross-shaped spinning arms and round center, clear separable shapes, no text, no background. |
| Drawing station | A compact freestanding wooden drawing station for a cozy fantasy creature habitat, sturdy easel-like frame, blank pale marking board and small lower shelf, leave the board face plain and unobstructed for a live texture, no text, no background. |
| Charcoal tool | A short handmade charcoal drawing stick with a simple small wooden rest, low-poly soft fantasy game prop, dark charcoal tip and warm wood, no marks or lettering, no text, no background. |
| Egg | A smooth pale cream fantasy creature egg for a cozy low-poly game, softly mottled shell with a faint warm golden highlight, symmetric oval, no cracks, no nest, no text, no background. |
| Berry bush | A reusable low-poly berry bush for a cozy fantasy creature habitat, rounded green leaf clusters, several visible dark magenta berries, short woody stems, friendly readable silhouette, no text, no background. |
| Spring | A small clear-water spring for a low-poly fantasy habitat, shallow blue pool, pale stone rim and several translucent aqua glassy shards, compact ground prop, no text, no background. |
| Echo bloom/curiosity landmark | A curious low-poly fantasy flower landmark for a gentle creature habitat, tall green stem, six soft aqua and warm gold petals around a glowing golden heart, distinctive simple silhouette, no text, no background. |
| Norn species candidate | An original gentle low-poly fantasy creature species candidate for a cozy habitat, small rounded quadruped body, large expressive eyes, soft ear-like head tufts, smooth cream and moss-green material variation, neutral A-pose with four limbs clearly separated, full body centered, no base, no text, no background. |

## Egg retry prompt

The first egg had a large shell opening and a lower crack, so the retry prompt emphasized an uninterrupted sealed shell:

> A single intact, closed, smooth fantasy creature egg for a cozy low-poly game. A complete continuous hard outer shell, fully sealed all the way around with no interior visible. Symmetrical upright oval, gently tapered at the top, softly rounded base. Uniform uninterrupted shell surface from crown to base, softly mottled pale cream with delicate warm golden speckles. No crack, no opening, no hole, no broken shell, no exposed interior, no hatching, no cutaway, no nest, no text, no background.

Texture prompt: “Pale warm cream shell with very subtle mottling and a few soft golden speckles. Keep the shell smooth, solid-looking, and completely continuous; no cracks, opening, hole, seam, exposed interior, or hatching marks.”

## Generation results

- Completed: 15 preview tasks and 15 2K PBR refine tasks across 14 model families; the extra pair is the egg retry.
- Actual Meshy task charges: 255 credits total; latest balance: 860 credits.
- Standard ground and path results started at 7,784,714 and 203,876 triangles. Blender decimation candidates reached 185,635 and 19,999 triangles respectively; the ground target of 50,000 was not reached. UVs and embedded PBR maps remain present.
- The first egg has a large opening and lower crack. The retry's preview and refined thumbnail show a complete cream egg shell without a visible crack or opening; review is limited to that rendered view.
- The spring result has a stone ring and aqua stones, but no water surface.
- The original GLBs carry normal maps but do not store tangents. Blender exported tangents for the admitted Norn; other models need tangents generated during engine import before normal-map lighting.
- The Norn model is a seated foxlike creature with 10,532 triangles and no skin or rig. Package `pkg_33b71a92373ab987f79818bf` is admitted at `godot/assets/generated/norns/albia-norn`.
- Other generated models remain in `assets/generated/meshy_output`; the drawing station's live board remains engine-authored.
- Meshy's API price list shows remesh at 5 credits per asset, while its web-app guide lists remesh at 0 credits. The local Blender decimation route was used for the ground and path; it reduces triangle counts without replacing the original files, but it is not a quad remesh.

See [the asset inventory](../../godot/ASSET_INVENTORY.md) for the complete existing/runtime mesh list and generated model details.

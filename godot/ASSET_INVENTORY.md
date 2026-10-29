# New Albia Mesh and Model Inventory

The expanded habitat runs across Sunmeadow, Softwood Grove, and Glassfall Hollow. Environment props remain a GDScript blockout. The approved Meshy Norn model is now packaged and admitted under godot/assets/generated/norns/albia-norn; the other generated model families remain review assets under assets/generated/meshy_output.

Generation used the pinned Meshy CLI 0.4.0. The approved ceiling was 420 credits; the 14 initial preview/refine pairs plus one egg retry consumed **255 credits**, leaving 165 credits under the ceiling. The latest balance is 860 credits. The task receipts and output paths are recorded in [the Meshy request manifest](../assets/generated/meshy_output/habitat_asset_requests.json). No separate license receipt is attached to the task snapshots; the Norn package records Meshy's private paid-plan output license, and the account terms should be checked before redistribution.

## Current and expanded runtime models

Counts describe active mesh instances created by scene scripts at startup, before variable Norn/egg population changes. Collision shapes, lights, labels, and the live drawing texture are listed separately because they are not mesh model families.

| Item/model family | Runtime mesh pieces and count | Current source | Visible material/texture | Interaction | Meshy family and status |
|---|---:|---|---|---|---|
| Habitat floor | 1 box, 72 × 18 world units | scripts/albia_world.gd::_build_habitat | Engine-authored dark grass material | Walkable collision floor | Ground tile generated; 7.78M triangles, review-only until reduced |
| Region ground overlays | 3 boxes, one per region | scripts/albia_world.gd::_build_habitat | Engine-authored meadow, grove, and hollow colors | Visual region cue | Ground tile generated; not integrated |
| Central travel path | 1 box, 72 units long | scripts/albia_world.gd::_add_path | Engine-authored warm earth color | Open travel corridor | Path segment generated; 203,876 triangles, review-only until reduced |
| Trees | 13 total: 13 trunks + 13 canopies | scripts/albia_world.gd::_add_tree | Engine-authored bark and region-tinted canopy colors | Scenery | Reusable tree generated; 7,065 triangles |
| Rocks | 7 | scripts/albia_world.gd::_add_rock | Engine-authored gray-green material | Scenery | Rock generated; 2,432 triangles; texture is brighter green than intended |
| Family nest | 2: bowl + rim | scripts/albia_world.gd::_build_habitat | Engine-authored woven browns | Incubation setting; no direct action | Nest generated; 4,948 triangles |
| Honey fruit | 3: fruit body + stem + leaf | scripts/albia_world.gd::_build_objects | Engine-authored orange, brown, and green materials | **eat**; action fruit; relieves hunger | Honey fruit generated; 3,129 triangles |
| Wind-up spinner | 5: base + axle + center + 2 arms | scripts/albia_world.gd::_build_objects | Engine-authored blue, brass, red, and green materials | **play**; action spinner; changes curiosity/reward | Spinner generated; 5,263 triangles |
| Drawing station | 3: frame + live-texture board panel + shelf | scripts/albia_world.gd::_build_drawing_station | Engine-authored wood; board texture is live and shared | **draw**; the board face stays engine-authored so marks remain live | Drawing station generated; 4,580 triangles; keep live board engine-authored |
| Charcoal tool | 2: wooden rest + charcoal stick | scripts/albia_world.gd::_build_drawing_station | Engine-authored wood and charcoal materials | **draw** when board and tool are visible | Charcoal tool generated; 2,100 triangles; separate rest is not distinct |
| Berry bush | 11: stem + 3 foliage clusters + 7 berries | scripts/albia_world.gd::_build_expanded_habitat_objects | Engine-authored greens and magenta berries | **forage**; action forage; relieves hunger and records its own outcome | Berry bush generated; 8,435 triangles |
| Glassfall spring | 7: water pool + stone rim + 5 glass shards | scripts/albia_world.gd::_build_expanded_habitat_objects | Engine-authored aqua and stone materials | **drink**; action drink; reduces thirst | Spring generated; 5,067 triangles; generated model has no water surface |
| Echo bloom | 8: stem + 6 petals + heart | scripts/albia_world.gd::_build_expanded_habitat_objects | Engine-authored green, aqua, and gold materials | **explore**; records a discovery outcome | Echo bloom generated; 5,054 triangles |
| Curiosity trail markers | 16: 8 markers × glow + core | scripts/albia_world.gd::_build_expanded_habitat_objects | Engine-authored pale gold and green materials | Shared explore affordance; each marker is consumed after discovery | Reuse curiosity landmark family; echo bloom is generated |
| Meshy Norn body | 1 imported model mesh + 3 scripted drawing meshes per Norn; 8 mesh instances for Mallow and Moss before population changes | scripts/norn_actor.gd::_build_body and _build_drawing_effector; res://assets/generated/norns/albia-norn/model.glb | Meshy 2K PBR maps; body is the same species appearance for each Norn; drawing tool uses the actor's procedural color | Movement, social observation, drawing motor | Package pkg_33b71a92373ab987f79818bf admitted. Static model has no skin or rig; CharacterBody3D still moves the actor. The original procedural builder remains a fallback |
| Incubating egg | 2 meshes per egg: shell + shine; variable with population | scripts/norn_egg.gd::_build_visuals | Engine-authored inherited shell tint and shine | Incubation progress, hatching | Runtime egg remains procedural. New Meshy candidate has no visible crack or opening in its thumbnail; it is not yet admitted |

### Procedural Norn fallback mesh names

If the admitted model cannot be loaded, each living Norn falls back to 19 mesh instances: Body, Belly, Head, LeftEar, RightEar, LeftEarInner, RightEarInner, LeftEyeSocket, RightEyeSocket, LeftEye, RightEye, LeftPupil, RightPupil, LeftEyelid, RightEyelid, Nose, drawing Arm, Palm, and CharcoalTip. The runtime Meshy model replaces the first 16 procedural pieces; the three drawing meshes remain scripted. Name/life-stage labels and the collision body are additional nodes, not meshes.

## Generated Meshy assets and task provenance

The ground tile and path used standard text-to-3D generation. The other families used Smart Topology T2.5 previews with a 2K PBR refine. The original 14 GLBs have UVs, normals, a base-color texture, metallic/roughness texture, and a normal map; inspected texture dimensions are 2048 × 2048. Those originals lack stored tangents. Blender generated tangents for the admitted Norn GLB; the other normal maps need tangents generated at import before use for lighting.

Each Meshy project folder contains the final model.glb, rendered thumbnail.png, external texture_0_base_color.png, texture_0_metallic.png, texture_0_roughness.png, and texture_0_normal.png, plus task JSON snapshots. The original Norn source remains under the review-candidates folder; the admitted package contains the tangent-ready GLB.

| Meshy family | Triangles | Preview task → refine task | Model path | Review |
|---|---:|---|---|---|
| Meadow ground tile/material | 7,784,714 | 01a1895b-869a-72dc-adef-3c29f4b6f8b0 → 01a1895d-93cc-74c6-853d-14c5dd8f1790 | assets/generated/meshy_output/20261029_163047_meadow-ground-tile_01a1895b/model.glb | Blender decimation candidate is 185,635 triangles (requested 50,000); UVs and PBR textures preserved; candidate path below |
| Path segment | 203,876 | 01a18966-8bfa-766f-b957-8530d352403d → 01a18967-786e-73b5-8bbf-11172be94ecf | assets/generated/meshy_output/20261029_164248_path-segment_01a18966/model.glb | Blender decimation candidate is 19,999 triangles (requested 20,000); UVs and PBR textures preserved |
| Tree | 7,065 | 01a18969-ace3-70ef-a4b2-573eeed729ae → 01a1896a-7e1d-70c2-8f36-329c545d3776 | assets/generated/meshy_output/20261029_164611_tree-smart-topology_01a18969/model.glb | Two-tier green canopy and brown trunk |
| Rock | 2,432 | 01a1896b-8b42-7165-aa71-a43800ee99ae → 01a1896d-1258-72c1-bb8d-d97d9697eec7 | assets/generated/meshy_output/20261029_164815_rock-smart-topology_01a1896b/model.glb | Faceted boulder; bright yellow-green texture spots |
| Nest | 4,948 | 01a1896f-11cd-74de-ba2c-330a97386994 → 01a1896f-cf0d-722c-9f54-f6f6eae9247e | assets/generated/meshy_output/20261029_165208_20261029-nest-smart-topology-0_01a1896f/model.glb | Clearly woven shallow bowl |
| Honey fruit | 3,129 | 01a18971-0f1d-70c7-b445-a4e116d522c8 → 01a18971-9266-74e6-8001-6d133874cbf6 | assets/generated/meshy_output/20261029_165415_20261029-honey-fruit-smart-top_01a18971/model.glb | Golden orange fruit, brown stem, green leaf |
| Spinner | 5,263 | 01a18973-49ba-731b-902e-f09bc3c9e38a → 01a18973-ebee-744a-866a-666434e182a2 | assets/generated/meshy_output/20261029_165641_20261029-spinner-smart-topolog_01a18973/model.glb | Blue base, brass hub, bright radial arms |
| Drawing station | 4,580 | 01a18974-f925-7653-8875-930d4e3c0205 → 01a18975-9693-736a-952d-b4966b4c7506 | assets/generated/meshy_output/20261029_165832_20261029-drawing-station-smart_01a18974/model.glb | Wood-framed easel with a blank panel |
| Charcoal tool | 2,100 | 01a18976-550d-7087-a5c3-5dd74b8a13c0 → 01a18976-dc4f-75f0-bd7b-d3a98c430e33 | assets/generated/meshy_output/20261029_170003_20261029-charcoal-tool-smart-t_01a18976/model.glb | Wood handle and dark tip; separate rest not visible |
| Egg, first attempt | 3,128 | 01a18977-9e43-731c-87d9-f4a14929b409 → 01a18978-2841-7724-8798-27c88a82fb54 | assets/generated/meshy_output/20261029_170125_20261029-egg-smart-topology-01_01a18977/model.glb | Large opening and small lower crack; retained for comparison, not used as the intact candidate |
| Egg, retry | 3,153 | 01a18987-b3c8-7793-a7f8-5fc11e51e35c → 01a18988-3a79-7102-9d29-38bf157d81cd | assets/generated/meshy_output/20261029_171906_egg-closed-shell-retry_01a18987/model.glb | Thumbnail shows a continuous closed shell with no visible crack or opening; 2K PBR maps |
| Berry bush | 8,435 | 01a18979-353a-7791-ba9a-5163d2fc97d6 → 01a18979-d598-71ec-a776-5373138b47a7 | assets/generated/meshy_output/20261029_170309_20261029-berry-bush-smart-topo_01a18979/model.glb | Green leaves and bright magenta berries |
| Spring | 5,067 | 01a1897a-d349-757b-a8d5-9d570ca76470 → 01a1897b-6e77-7068-8a08-fdfe75584b47 | assets/generated/meshy_output/20261029_170455_20261029-spring-smart-topology_01a1897a/model.glb | Pale stone ring and aqua interior stones; no water surface |
| Echo bloom/curiosity landmark | 5,054 | 01a1897c-40bb-708a-9cfa-fd21b47fa58e → 01a1897c-de0c-72ea-a238-3adae72b9047 | assets/generated/meshy_output/20261029_170630_20261029-echo-bloom-smart-topo_01a1897c/model.glb | Yellow petals, gold center, green stem |
| Norn species | 10,532 | 01a1897e-3f2a-77e0-a6a1-5ff5fa44f12a → 01a1897f-20f9-715a-b590-7972ffe5894e | assets/generated/meshy_output/review-candidates/norn/20261029_170840_norn-review-candidate-20261029_01a1897e/model.glb | Approved static seated foxlike model; tangent-ready version packaged and admitted to the Godot project |

### Blender-processed candidates

These are new files; original Meshy downloads remain untouched. The ground target was 50,000 triangles, but Blender's Decimate modifier retained 185,635 triangles on the scattered high-detail mesh. The path reached 19,999. Both outputs retain UVs and the three embedded 2K PBR textures. This is triangle decimation rather than quad remeshing, and neither candidate is in the runtime yet.

| Source asset | Target | Actual | Output |
|---|---:|---:|---|
| Meadow ground tile | 50,000 | 185,635 | assets/generated/meshy_output/topology-candidates/ground-tile-50000-triangles.glb |
| Path segment | 20,000 | 19,999 | assets/generated/meshy_output/topology-candidates/path-segment-20000-triangles.glb |

## Labels, non-mesh visuals, and collision

| Visual or collision family | Count/source | Notes |
|---|---|---|
| Region labels | 3 Label3D nodes | Sunmeadow, Softwood Grove, Glassfall Hollow |
| Object labels | 8 Label3D nodes at startup | Nest, honey fruit, spinner, marking board, charcoal, berry bush, spring, and echo bloom |
| Norn labels | 2 per living Norn | Name and life-stage labels, created in scripts/norn_actor.gd |
| Egg progress labels | 1 per egg | Dynamic name and incubation percentage; created in scripts/norn_egg.gd |
| Shared mark surface texture | 1 256 × 256 runtime image/texture | Engine-authored, serializable, and displayed on the drawing board and HUD; not a Meshy texture |
| Physics shapes | Per floor, Norn, egg, and interactable | Collision shapes are not rendered model meshes. Resource and landmark object IDs/affordances remain in engine scripts |
| Sky and directional lighting | 1 procedural sky/environment + 1 directional light | Engine resources rather than model assets |

## Integration state

The 14 initial model families plus one egg retry consumed 255 Meshy credits, under the 420-credit ceiling. The egg retry has a visually closed shell in the rendered thumbnail, but the Meshy GLB has not been checked from every angle. The Norn package was validated, hash-verified, and admitted at godot/assets/generated/norns/albia-norn; its static model has no rig or skin. Ground/path decimation candidates are local Blender outputs and are not runtime assets. Godot imported and rendered the Norn on 2026-10-29; the in-engine three-region walkthrough is `user://recordings/expanded-habitat-review/habitat-20261029-174511.avi`. The model's local yaw was corrected by 180 degrees before this review. Other environment assets remain review-only; the spring still lacks a water surface.

See [the Meshy prompt set](../assets/generated/meshy-prompts.md) for prompts and [the request manifest](../assets/generated/meshy_output/habitat_asset_requests.json) for task IDs, charges, output folders, and per-asset notes.

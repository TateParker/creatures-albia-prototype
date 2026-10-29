# Meshy Habitat Assets and Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Generate, inspect, package, and integrate textured Meshy models for the expanded Godot habitat, while delivering a review-only Norn candidate and a complete inventory of old and new mesh assets.

**Architecture:** Generate reusable GLB/PBR model families into the configured local asset workspace, track Meshy provenance and costs, validate bytes before project admission, then vendor approved runtime models into `godot/assets/generated/`. Keep the candidate Norn outside the runtime folder and leave character replacement for a later explicit user approval.

**Tech Stack:** Meshy CLI 0.4.0, `game-dev` 1.5.0 local asset inspect/validate/package/vendor commands, Godot 4.7.2 GLB importer, Markdown inventory.

**Spec:** `docs/superpowers/specs/2026-10-29-godot-expanded-habitat-design.md`

## Global Constraints

- Use `assets/generated/` as the write workspace and `assets/generated/meshy_output/` as the Meshy project root.
- Generate 14 reusable model families: meadow ground tile/material, path segment, tree, rock, nest, honey fruit, spinner, drawing station, charcoal tool, egg, berry bush, spring, curiosity landmark, and one shared A-pose Norn candidate.
- Request GLB and 2K PBR textures, with original soft low-poly game art and no text or background.
- Target no more than 5,000 triangles for small props and 15,000 triangles for a large combined habitat piece; inspect actual outputs and do not weaken the policy silently.
- User-facing texture delivery may remain embedded in GLB; record actual material/map names and texture dimensions in the inventory.
- Before paid generation, check authenticated status and balance, run the no-cost planner for the final prompt list, show the exact estimate, and obtain an explicit spend ceiling. Do not rerun or add a stage over that ceiling without fresh approval.
- Record the Meshy account's actual license; do not assume a plan tier. Never expose credentials or request an API key in chat.
- Build canonical packages only after presenting exact source/destination invocations and getting authorization. Verify each package before a dry-run project admission. Keep the Norn candidate outside `godot/assets/generated/`.
- Do not rig or animate the Norn candidate, and do not replace runtime Norns without the user's later approval.
- Use the Godot project's existing rendered-recording requirement after runtime asset import.

## Review Focus

1. **Meshy login, balance, or license unavailable:** stop before paid create and report the exact non-secret blocker. Verify with `auth status`, `balance`, and task license/provenance output.
2. **A texture or model is missing from a nominally successful task:** verify the task's returned asset roster and downloaded file bytes before package build.
3. **Unknown, excessive, or malformed geometry/materials:** inspect and validate each GLB against the approved triangle/texture policy before package build.
4. **A provider thumbnail is missing or does not show the subject:** report that specific asset as visually unchecked/mismatched; do not claim visual approval or regenerate without a new paid ceiling.
5. **Norn candidate is accidentally admitted or replacement-coded:** inventory it as `candidate-only`, keep it outside runtime assets, and verify code still instantiates the procedural Norn.

---

### Task 1: Resolve Meshy CLI, account status, and exact estimate without spending

**Files:**
- Read/write workspace: `assets/generated/meshy_output/`
- Read-only setup: existing `game-dev` 1.5.0 installation and configured Blender executable
- Report target: `godot/ASSET_INVENTORY.md` (created in Task 4)

- [x] **Step 1: Run the cached Meshy CLI 0.4.0 offline.** Inspect `--help` for the installed model, texture, and dry-run options. The CLI exposes 2K/4K/8K refine settings; the combined `make --dry-run` planner estimates preview and refine credits but does not expose per-call pose or resolution overrides.
- [x] **Step 2: Reconfirm local asset-tool capabilities and health.** `game-dev` reported healthy and exposed asset inspect, validation, package build/verify, and vendor admission capabilities.
- [x] **Step 3: Check authentication and balance.** The user installed Meshy CLI 0.7.0 and completed browser sign-in. `meshy auth status` reported an authenticated saved session. The first balance request failed with `UNABLE_TO_VERIFY_LEAF_SIGNATURE`; retrying with `NODE_USE_SYSTEM_CA=1` let Node.js use the Windows system CA store while preserving certificate validation. The read-only balance request succeeded: 1,115 total credits (825 monthly, 290 permanent) on 2026-10-29. No generation task has been submitted.
- [x] **Step 4: Prepare exact prompts for all 14 model families with explicit exclusions.** The prompt manifest names each asset, soft low-poly style, game use, and no-text/no-background constraints; the Norn prompt specifies a single A-pose species candidate. The CLI create command will use `--pose-mode a-pose` for its preview rather than a separate unsupported negative-prompt flag.
- [x] **Step 5: Run `meshy make --dry-run` for every prompt.** The initial CLI 0.4.0 estimate and a refreshed CLI 0.7.0 dry run each reported 20-credit preview plus 10-credit refine, totaling 420 estimated credits for 14 assets. Meshy task-level 2K/4K refine pricing is 10 credits. These dry runs submitted no provider jobs and spent no credits.
- [ ] **Step 6: Present the full estimate and ask the user to authorize a maximum credit spend.** Do not submit any `create` operation until the user sets that ceiling. If the estimate is too high, wait for the user to select a smaller asset list or approve a different ceiling.

Expected: 14 prompt records and a no-cost estimate; zero provider jobs submitted and zero credits consumed. The 420-credit estimate is available for user review, but the spend ceiling remains pending, so generation is not authorized.

---

### Task 2: Generate and texture the 14 approved model families

**Files:**
- Create under: `assets/generated/meshy_output/`
- Keep the Norn candidate under: `assets/generated/meshy_output/review-candidates/norn/`

**Interfaces:**
- Use one Meshy project rooted at `assets/generated/meshy_output/`; keep each asset's exact prompt, negative prompt, task resource, task ID, stage, and consumed-credit receipt.
- Use a text-to-3D preview followed by a textured refine stage when supported by the approved CLI settings. Export GLB with 2K PBR textures.
- Norn preview uses the A-pose option; no rigging or animation stage is included.

- [ ] **Step 1: Submit only the first approved asset task with `--async`.** Read the returned task ID from the structured JSON, initialize project bookkeeping, and wait on that exact task until terminal status.
- [ ] **Step 2: Refine the first successful preview with 2K PBR textures.** Record the new task ID and wait through its owning Meshy resource.
- [ ] **Step 3: Download the GLB and thumbnail from the returned task asset roster.** Do not guess asset keys or overwrite a pre-existing output file.
- [ ] **Step 4: Inspect the thumbnail and downloaded bytes.** Use the host image viewer for the thumbnail and `game-dev asset inspect <model.glb> --json` for file-level geometry/material details.
- [ ] **Step 5: Repeat Steps 1–4 for the remaining approved model families within the authorized ceiling.** Before each paid create, reconcile the current estimate/consumed credits against the approved maximum; stop before exceeding it.
- [ ] **Step 6: Show the model gallery and the Norn candidate preview to the user.** Label the Norn `candidate-only — runtime replacement pending user approval`.

Expected: each completed, downloaded asset has a provider task ID, actual consumed credits when reported, a readable preview when supplied, and an intact GLB. Missing previews or failed/mismatched models are reported without automatic paid retries.

---

### Task 3: Validate, package, and admit runtime assets

**Files:**
- Source: verified files under `assets/generated/meshy_output/`
- Canonical packages: `assets/generated/.game-dev/packages/`
- Runtime destination: `godot/assets/generated/`
- Create: `assets/generated/policies/godot-prop-policy.json`
- Create: `assets/generated/policies/godot-terrain-policy.json`

- [ ] **Step 1: Create the two explicit validation policies.** Set the prop policy to 5,000 maximum triangles, 4 maximum materials, required UVs/normals/base color, power-of-two textures, and 2,048 maximum texture size; set the terrain/path policy identically except for a 15,000 triangle ceiling.
- [ ] **Step 2: Inspect and validate every runtime model against its policy.** Require GLB, valid bounds, UVs, normals, base-color texture, 2K PBR maps, and the stated triangle budget. Keep validator warnings and failures in the asset receipt.
- [ ] **Step 3: Stop if normalization is needed.** Present the exact source, output path, and normalize command to the user; do not write normalized files without exact invocation authorization. Re-inspect and re-validate any authorized normalized copy.
- [ ] **Step 4: Present exact package-build invocations.** For each runtime GLB, show its source path, destination package name/version, license identifier, prompt/task provenance, and output root; obtain authorization before package construction.
- [ ] **Step 5: Build and verify each canonical package.** Use the approved license from the actual Meshy account and ensure receipt hashes cover the GLB and its embedded texture data.
- [ ] **Step 6: Dry-run each `game-dev vendor admit` against the Godot project and `godot/assets/generated/` destination.** Show the exact destination, blockers, license, and validation results; obtain explicit user confirmation for admission.
- [ ] **Step 7: Admit only verified runtime packages into `godot/assets/generated/`.** Do not admit the Norn candidate. Verify copied bytes and retain the project lock receipt.

Expected: each runtime package passes hash verification, its actual license is recorded, and the vendor lock references the exact package and destination. Package verification proves copied-byte integrity only; Task 4 provides engine import/render evidence.

---

### Task 4: Integrate model families, inventory every mesh, and show the candidate

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/norn_egg.gd`
- Modify: `godot/scripts/habitat_ui.gd` only if any runtime asset label needs a visual cue
- Create: `godot/ASSET_INVENTORY.md`
- Modify: `godot/README.md`

- [ ] **Step 1: Import the admitted GLBs in Godot 4.7.2.** Use Godot's editor/importer and inspect the import results for missing material, texture, or scene references.
- [ ] **Step 2: Replace only the approved static runtime families.** Use the generated terrain/path/tree/rock/nest/fruit/spinner/drawing-station/charcoal/egg/berry/spring/curiosity models. Preserve collision sizes, object IDs, interaction availability, labels, and the board's live texture. Keep Norn geometry procedural.
- [ ] **Step 3: Create the complete inventory table.** Include sky and directional light; one ground box and path box; four tree trunks and four canopies; two rocks; nest bowl/rim; fruit body/stem/leaf; spinner base/axle/center/two arms; drawing frame/live-texture panel/shelf; charcoal rest/stick; each Norn's 19 procedural meshes and active instance count; egg shell/shine; runtime labels; and all new GLBs. Give every row its count, current implementation/path, replacement or candidate asset, textures, affordance, Meshy task ID and prompt when generated, license, triangle/material validation, and status (planned, generated, candidate-only, admitted, imported, or visually reviewed).
- [ ] **Step 4: Mark the Norn candidate clearly.** Record its preview/GLB path as candidate-only; do not add runtime loading code or admit the package.
- [ ] **Step 5: Update README asset notes.** Document the generated asset location, local/offline runtime behavior, and the user-review gate for Norn replacement.
- [ ] **Step 6: Demonstrate imported props, retained drawing marks, egg updates, and procedural Norns during the rendered walkthrough in Task 5.**

Expected: Godot imports the admitted runtime assets, procedural Norns remain active until separate approval, egg behavior remains intact, live drawing still works, and the inventory accounts for every existing and planned/generated mesh/model with its actual status.

---

### Task 5: Capture the imported environment and finish delivery records

**Files:**
- Create or modify: `godot/tools/record_expanded_habitat_preview.gd`
- Read: `godot/tools/inspect_recording.gd`
- Outputs: temporary capture frames and the normal `user://recordings/` AVI

- [ ] **Step 1: Record a rendered non-headless run after import.** Include a view of each region, Norns using berries/spring/curiosity landmark, the spinner, drawing board, and an incubating egg. Preserve/restore the local save and keep no more than ten completed clips.
- [ ] **Step 2: Decode and inspect representative frames.** Run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/inspect_recording.gd -- <clip-path> <frame-output-folder>`; inspect representative images with the host image viewer.
- [ ] **Step 3: Update inventory receipts with the recording path and visual status.** Distinguish generated/downloaded, statically validated, imported, rendered, and human-reviewed states.
- [ ] **Step 4: Leave changes uncommitted for user review.** Do not include unrelated database/tool metadata in the implementation changes.

Expected: a decodable 1280×720 rendered clip, inspected asset frames, a complete inventory, and a Norn model candidate delivered for user review without replacing the current Norns.

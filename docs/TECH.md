# DEEP SPACE — Technical Notes

*Draft 0.1 — 2026-10-13. How the game in [`GDD.md`](GDD.md) gets built. Design decisions live in the GDD; this file covers engine, networking, rendering, pipeline and the build plan.*

---

## 1. Toolchain

| Tool | Version | Notes |
|---|---|---|
| Godot | **4.7.2** stable (`/Applications/Godot.app`) | Forward+ renderer, typed GDScript |
| netfox | **1.49.4**, upstream `main` at `cf5189d` (2026-09-26) | Vendored into `addons/`: `netfox`, `netfox.extras`, `netfox.internals`. `netfox.noray` is added later if we use it |
| Blender | **5.2.1** LTS (`/Applications/Blender.app`) | Run headless from Python generator scripts |
| asset-gen | `~/dev/asset-gen` (Go) | Turns source photos into 64×64, 16-colour seamless PSX tiles |
| Targets | Desktop (Windows, macOS, Linux) | Keyboard and mouse first |

## 2. Networking

**Model:** a listen server (the host plays), with no rollback. For co-op PvE horror, owner-authoritative movement feels immediate and avoids misprediction problems. We use netfox for:
- `NetworkTime`: a shared tick clock (default 30 Hz)
- `StateSynchronizer` and `TickInterpolator`: state replication and smoothing tied to the tick loop
- `NetworkEvents`: peer lifecycle signals

**Trust the clients; the host applies.** This is co-op, not competitive, so simple networking beats protection against cheating:
- **Clients report what they did.** "I hit the Crawler with the rivet driver for N." "I started using this terminal." "I picked up this item."
- **The host applies the result and owns the state that follows** (creature health, door state, who holds the item), then broadcasts it.
- **No server-side checks of player actions.** The host doesn't verify hits, compensate for lag, or rewind to check line of sight or range.
- **The host rejects only actions that conflict with current state**, for example a pickup of an item someone else already holds, or opening a door that's already open. First request wins.

| Thing | Authority | Sync |
|---|---|---|
| Player body, look, flashlight, animation state | **Owning client** | `StateSynchronizer` at the tick rate; `TickInterpolator` on remote peers |
| Player actions (hits, interactions, pickups, throws) | **Owning client reports**; host applies | Reliable RPC to the host → host applies it to the target's state → state is broadcast |
| Run state (map, fuel, salvage, upgrades, crew status) | Host | Reliable RPCs on change. Saved by the host to `user://` between jumps |
| Generation (sector map, systems, derelict layouts) | Host sends **seeds** | Every peer generates locally from the seed. A checksum after generation confirms the peers match. Entity IDs come from generation order, so RPCs can name generated things |
| Doors, power, terminals, hazards | Host owns the state | Changed by client-reported interactions (above); the host rejects only conflicting requests |
| Creatures | Host | Host runs the AI and its attacks on players; clients get `StateSynchronizer` and `TickInterpolator`. Player hits on creatures are client-reported, as above. If creature attacks feel unfair at higher latency, the victim's client can confirm the hit instead |
| Loose items | Host; **the carrier becomes authority while holding**, and authority returns to the host on drop | `StateSynchronizer` |
| Terminal screens | Host owns the UI state; the operator's cursor belongs to the operator | Teammates see the same screen |

**Connecting:**
- Host or join by IP from the title terminal.
- Dev flags: `--host`, `--join=<ip>`, `--port=<n>`.
- A launch script starts a host plus N clients, and netfox.extras' window tiler arranges the windows for testing on one machine.
- Players can only join mid-run while aboard LANTERN between encounters. The joining client receives the run state plus the current seeds and generates the world locally.
- **Voice is out of scope**: players use Discord. When we need play across the internet without port forwarding, we add `netfox.noray` for NAT punch-through.

## 3. World Structure

- **LANTERN stays at the origin; the world moves around it.**
  - Derelicts are brought in to the docking collar.
  - Jumps swap the `System` scene while the station stays still.
  - Players on board never stand on a moving platform.
- Encounters load into the same world space, so docking means literally walking from the station into the derelict. EVA targets sit within a few hundred metres, so no floating origin is needed.
- **Scene tree:**
  ```
  World
    Lantern     always loaded
    System      sky, star, planets; swapped on each jump
    Encounter   loaded on arrival, freed on departure
    Players
    Creatures
    Items
  ```
- **Zones:**
  - `Area3D` volumes carry the zone's gravity override, pressure state (drives O2 drain and the vacuum audio low-pass) and power state.
  - Doors connect zones, and breaches change their state.
  - Unpowered derelict zones are zero-g. Mag-boots attach to surfaces there; moonlets use about 0.16 g.
- **Player body:** `CharacterBody3D`.
  - Gravity direction and strength come from the current zone.
  - Mag-boot mode aligns the body to the surface beneath it.

## 4. Rendering (PSX)

This follows the approach on **ultraskeletal's `psx-look` branch** (`game/scripts/sim/psx*.gd*`), adapted for this project.

- **Pixelation:**
  - The root viewport uses `scaling_3d_mode = NEAREST` with `scaling_3d_scale = 1 / block`, where block = round(window short side / 270).
  - MSAA and screen-space AA are off.
  - 2D stays at native resolution, which matters for the pause and settings menus.
- **Dither:**
  - A `Psx` autoload adds a `CanvasLayer` at layer −128 (under all 2D).
  - It reads the screen texture and converts it to 15-bit colour with a 4×4 Bayer dither, using a block-sized `pixel` parameter so the pattern lines up with the 3D pixels.
  - A `global uniform bool psx_dithered` toggles it.
- **`psx.gdshaderinc`:**
  - `psx_snap(clip, VIEWPORT_SIZE)` snaps vertices to the pixel grid.
  - `psx_affine()` gives affine (non-perspective) UVs: multiply by w in the vertex shader, divide in the fragment shader.
  - `psx_dither()` does the 15-bit conversion.
- **Gotcha:** a shader that writes `POSITION` must write it in every pass, so use `POSITION = IN_SHADOW_PASS ? clip : psx_snap(...)`. Otherwise shadows collapse to a point.
- **Materials:** a small set of shared materials: PSX lit, unlit/emissive, CRT screen, skybox, planet, hyperspace tunnel.
  - Textures use nearest filtering.
  - Affine warp gets a strength uniform, in case large floor polygons warp too much.
- **Lighting:**
  - Real-time per-pixel lights only, with no baked GI (layouts are procedural).
  - Flashlights are `SpotLight3D`s with a projector texture for the lens pattern.
  - **Shadow budget:** the local player's flashlight always casts shadows. Teammates' lights cast shadows only within about 12 m, with at most 4 shadowed spots at once. Room practicals are unshadowed apart from hand-picked key lights.
  - No SSAO, SSIL, SSR or SDFGI. Environment ambient is near black in derelicts.
- **Fog:**
  - Distance fog closes in early.
  - Volumetric fog (Forward+ only) at low density in derelicts, to be judged in look-dev against cost at 270 lines.
- **Terminals:**
  - Each screen is a `SubViewport` with a Control UI, rendered onto the console mesh as a `ViewportTexture` with a CRT shader.
  - Input works by raycasting from the camera to the screen mesh and converting the hit UV into `InputEventMouse` events for the SubViewport.
  - The camera eases in until the screen fills the 270-line view; otherwise text can't be read (ultraskeletal ran into the same limit).
  - Bitmap fonts at a minimum of 8 px.

## 5. Asset Pipeline

- **Quality bar** (GDD §14): every slice model is final, not a placeholder. Scripts are the medium, not the method. Each model is **authored**: designed and modelled on purpose, not assembled from random procedural parts.
- **Per-asset process:**
  1. **Spec.** A short design note at the top of the generator covering purpose, real-world dimensions, silhouette, key details, materials and palette, and how the player uses it.
  2. **Model.** Hand-placed geometry in `bmesh`, built from shared helpers but shaped per asset. Bevels are used where they catch light, and the triangle budget goes into the silhouette first.
  3. **UVs.** Unwrapped per asset (seams placed deliberately, texel density consistent at about 32–64 texels/m for kit pieces), into its own texture or a shared kit atlas.
  4. **Texture.** Each model's own material is detailed (photo-derived tiles, edge wear from geometry, grime in crevices, stencils, labels, decals). It is **baked down** to a 64–128 px texture on the low-poly UVs, then quantized to ≤32 colours with an optional dither. Tiling kit surfaces use the `asset-gen` tiles directly.
  5. **Vertex colour.** AO and a little hand-tinted light are baked into vertex colours, PSX style.
  6. **Review.** Low-res, dithered renders from four angles plus a lit in-context shot go to `art/previews/`. I inspect every one and iterate until it meets the bar; you see them at the review checkpoint.
- **Generators:** `art/blender/<family>.py`, one per asset family (`station_kit`, `bridge_props`, `items`, `crawler`, …).
  - Shared helpers in `art/blender/lib/`:
    - mesh building (beveled boxes, panels, pipes, cables, trim)
    - UV utilities
    - bake and quantize steps
    - vertex-colour AO
    - material assignment by name
    - sockets as empties (`SOCKET_door_N`, `SOCKET_light`, …)
    - collision via Godot's import hints (`-col`, `-colonly`)
    - glTF export
    - preview renders
- **Build command:** `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P art/blender/build.py -- <targets>`. Each target writes:
  - `art/source/<name>.blend`, for inspecting or hand-tweaking. It isn't committed: generators are the source of truth, and a rebuild takes seconds
  - `assets/models/<category>/<name>.glb`
  - `art/previews/<name>.png`
- **Godot import:**
  - A post-import script swaps glTF materials for the shared PSX materials by naming convention (`M_<name>` → `res://assets/materials/<name>.tres`).
  - It also converts `SOCKET_*` empties into room-module metadata for the derelict generator.
- **Room modules:**
  - Built on a **4 m grid**: corridors are 3 m wide inside a 4 m cell, 3 m tall; doorways are 2 × 2.4 m.
  - Door sockets sit on cell edges.
  - Every module scene declares its sockets, size in cells, zone volumes, and spawn markers (loot, hazards, creatures, lore).
- **Rigs:**
  - Segmented rigid meshes, each one parented wholly to one bone, so no weight painting is needed.
  - Armatures and keyframed clips are written in the generator scripts.
  - Clips play stepped at 12–15 fps.
- **Textures:**
  - Tiling surfaces (panels, grating, rust, concrete) come from CC0 photo scans (ambientCG) run through `asset-gen`, and also feed each model's detailed material before baking.
  - Signage, labels, decals and screens are drawn procedurally. Blender's bundled Python has numpy; the system Python 3.14 has no PIL.
  - Sources are recorded in `CREDITS.md`.

## 6. Generation

- **Seeded throughout:**
  - All generation uses explicit `RandomNumberGenerator` seeds derived from the run seed and a stable label, for example `hash(run_seed, "sector1/row3/node2/layout")`.
  - Never use global randomness.
- **Sector map:** rows and nodes with weighted types, and edges that connect without crossing. Rule checks (GDD §6) run as a validation pass, with a retry on failure.
- **Derelict layouts:**
  1. Grow a room graph from the entry module.
  2. Add loops where sockets line up.
  3. Place the Prize far from the entry.
  4. Flood-fill the zones.
  5. Spend the budget on loot, hazards, creatures and lore.
  6. Hash the result for the peer checksum.

## 7. Project Layout

```
deep-space/
  project.godot
  addons/                 netfox, netfox.extras, netfox.internals
  game/
    core/                 net, run state, seeds, save, zones
    player/               controller, suit, flashlight, cuff, interaction, carry
    station/              LANTERN scenes and its consoles
    space/                sky, star, planets, hyperspace
    map/                  sector generation, nav chart UI
    encounter/            derelict generator, room modules, loot, power
    creatures/            crawler, hanger, AI
    items/                tools and pickups
    terminals/            SubViewport screen framework, CRT shader, fonts
    rendering/            psx.gdshaderinc, shared materials, Psx autoload
  assets/                 models/, materials/, textures/, audio/, fonts/
  art/
    blender/              generators + lib/
    source/               generated .blend files
    previews/             turntable renders
  tools/                  launch scripts (host + N clients), asset build
  docs/                   GDD.md, TECH.md
```

## 8. Testing

- **Headless scripts** (`godot --headless --path . -s <script>`):
  - generation determinism (the same seed gives the same hash)
  - sector map rules
  - a scene smoke test that loads every scene
- **Networking:** the multi-instance launch script with netfox's network simulator (latency and packet loss) turned on.
- **Assets:** turntable previews are reviewed for every generated model.

## 9. Milestones

| # | Milestone | Deliverable |
|---|---|---|
| M0 | **Foundations** | Godot project, netfox vendored, folder layout, git, PSX render pipeline, input map, launch scripts, Blender build harness |
| M1 | **Crew** | Networked first-person controller (owner-authoritative), flashlight, interaction, carrying, wrist cuff, visor HUD, suit O2 and pressure zones |
| M2 | **LANTERN & space** | Station kit and rooms modelled and assembled, lighting pass, sky, star and planets through the windows, terminal framework, Vitals board. **← art/feel review checkpoint** |
| M3 | **Navigation** | Sector map generation, Nav Chart terminal, jump sequence and hyperspace effect, long-range scan and progressive charting, system generation, Survey Console, fuel economy |
| M4 | **The derelict** | Docking, room-module generator and derelict kit, power zones, loot and Prize, hazards, Crawler and Hanger, death, spectating through the station and revive, extraction |
| M5 | **EVA & polish** | EVA airlock, low-gravity moonlet or relay encounter, mag-boots, audio pass, boss greybox, balancing |

**First build pass (decided 2026-10-13): environment first.**
- **Scope:** M0, the parts of M1 needed to walk the station together, all of M2, and a **model pass for the rest of the slice**:
  - derelict kit and room modules
  - Crawler and Hanger
  - player suit and first-person arms
  - items, plus Tier 0–1 weapons and energy cartridges
- **Result:** a walkable, networked LANTERN in space. It has flashlights, working consoles and a lit station, and every slice model has been built and previewed.
- **Then:** we review the look and feel together before building the gameplay loop (M3, M4 and the rest of M1).

## 10. Technical Risks

| Risk | Mitigation |
|---|---|
| Terminal text unreadable at 270 lines | Camera eases in to fill the view; large bitmap fonts; prototype in M2 |
| Shadowed-light cost with 4 flashlights in one room | Shadow budget (§4); measure early in M1 |
| Generated rooms plus dynamic lights look flat | Hand-placed practicals and decals in each module; lighting review at M2 |
| Scripted Blender models look procedural or placeholder | The authored per-asset process (§5): spec, deliberate modelling, baked textures, multi-angle review. Nothing ships without passing review |
| Generation drifting between peers | Seed discipline, a checksum on every generation, a determinism test |
| Zero-g and mag-boot controller complexity | Saved for M5; slice derelicts can start powered, with 1 g |

## 11. Decisions Log

- **2026-10-13: Textures.** CC0 photo scans from ambientCG, run through `asset-gen`. Sources are recorded in `CREDITS.md`.
- **2026-10-13: netfox.** Vendor upstream `main` (1.49.4), pinned to a commit that is recorded in §1 at vendoring time.
- **2026-10-13: Git.** A local repo; Claude commits at each meaningful step. Nothing is pushed.
- **2026-10-13: Networking trust.** Clients report their own actions and the host applies them (§2).
- **2026-10-13: Voice and connection.** Direct IP; voice through Discord.

# DEEP SPACE — Technical Notes

*Draft 0.1 — 2026-10-14. How the game in [`GDD.md`](GDD.md) gets built. Design decisions live in the GDD; this file covers engine, networking, rendering, pipeline and the build plan.*

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
| Player body, look, helmet lamp, held item, cuff, suit, animation state | **Owning client** | `StateSynchronizer` at the tick rate (`position`, `velocity`, `look`, `lamp_on`, `crouching`, `sprinting`, `held`, `held_lit`, `swings`, `cuff_up`, `o2`, `health`, `in_vacuum`); `TickInterpolator` on remote peers. Each peer animates remote suits from that state |
| Player actions (hits, interactions, pickups, throws) | **Owning client reports**; host applies | Reliable RPC to the host → host applies it to the target's state → state is broadcast |
| Run state (map, fuel, salvage, upgrades, crew status) | Host | `Run` (`game/core/run.gd`) holds the seed, the sector, where the station is, what's charted and visited, the route, the fuel rack's bays, scan, survey and refuel progress, Survey Data and the jump under way. The whole of it goes out in one reliable RPC on every change, and to each crew member who joins; timers run down on every peer, and the host finishes them. Crew report station actions (plot, scan, survey, refuel, load a cell) by RPC to the host. To be saved by the host to `user://` between jumps |
| Generation (sector map, systems, derelict layouts) | Host sends **seeds** | Every peer generates locally from the seed. A checksum after generation confirms the peers match. Entity IDs come from generation order, so RPCs can name generated things |
| Doors, power, terminals, hazards | Host owns the state | Changed by client-reported interactions (above); the host rejects only conflicting requests |
| The docking collar and its airlock | Host | `Collar` (`game/station/collar.gd`: the stage, its seconds left, whether the derelict's vented) and `Airlock` (`airlock.gd`: in, cycling out, out, cycling in) each send their whole state by reliable RPC on every change and to each crew member who joins; their timers run down on every peer and the host finishes them. Every peer poses the derelict, the tube, the hatches, the panels and the siren from that. The levers and switches are `Interactable`s reported to the host as usual |
| Creatures | Host | Host runs the AI and its attacks on players; clients get `StateSynchronizer` and `TickInterpolator`. Player hits on creatures are client-reported, as above. If creature attacks feel unfair at higher latency, the victim's client can confirm the hit instead |
| Death and bodies | The dying crew member's machine decides they're dead (`dead`, `cause`, synced); the host spawns their body and drops what they had (`LooseItems.fall`) | A body is a loose thing (`LooseBody`, a `Ragdoll`): every peer simulates its own copy from the same start, and the host sends only where it lies (`at`, its hips), easing strays back within 0.3 m (exact poses may differ). The med bay (`MedBay`) is host-owned like the collar (state by RPC); finishing, it tells the crew member's machine to `revive` |
| Loose items | Host. **Taking one moves it into the taker's own state** (their belt or hands) until they let go; letting go hands it back to the host as a loose item | `LooseItems` (a `MultiplayerSpawner`) makes each `Pickup` on every peer, late joiners included; its `MultiplayerSynchronizer` sends where it is only while it moves. A take is a reliable RPC to the host (first request wins), which removes the pickup and sends the record to the taker; a drop or throw is a reliable RPC with the record, where it left the hand and its velocity |
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
    System      sky, star, planets; swapped on each jump (hyperspace in the middle of one)
    Run         the run state; shows the world where the run says the station is
    Lantern     always loaded
    Encounter   loaded on arrival, freed on departure
    Players
    Items
  ```
- **Showing where the run is:** each peer's `Run` builds the world for the node the station is at: `StarSystem.generate(node seed)` (a Gas Giant node puts a gas giant ahead), and at a Derelict node the sample derelict (a stand-in until the generator, M4), handed to the `Collar` waiting out off the starboard bow (`--derelict` brings it to the departure point too, docked; `--derelict=away`, waiting).
- **Docking** (`Collar`, GDD §8.1): a derelict (`Derelict`, a `Deck` with an `entry` hatch) is posed from the collar's stage on every peer: waiting (14 m out along the collar's axis, then 24 m starboard and 32 m fore, turned 35°), drawn in by the tractor beam (16 s: eased to the line-up, then straight in), the tube running out (3 s, scaled along its length; solid only when it's out), the clamps (4.5 s; the derelict's hatch opens 2 s in), docked. Docked, its hatch sits on the tube's far end, one 4 m cell out from the LANTERN's collar hatch (`Collar._mouth * dock_point()⁻¹`). Undocking: the siren (10 s), then the tube in and the beam pushing it back out (19 s), vented.
- **Death** (GDD §11): suffocation (health out), or lost: off the station when the tunnel opens. The crew member's `Player` stays (hidden, no collision, no input) and a `Spectator` takes their eyes round the station's cameras (`station_camera` markers) and living teammates' helmets until the med bay `revive`s them at its pod.
- **Ragdolls** (`Ragdoll`): `ch_suit` with a `PhysicalBoneSimulator3D` and twelve `PhysicalBone3D`s built at run time (box, sphere and capsule shapes, cone joints, the cone's twist turned onto each bone). Started too soon after entering the world they never moved (or hung the engine headless), so `go_limp` waits a physics frame. Simulating only some bones left the rest misplaced, so a carried body simulates them all and steers its torso to the arms every physics frame (`hold_torso`); in first person it rides out ahead of the hands (`Items.FIRST_PERSON_BODY`) so its chest shows at the bottom of the view.
- **Riding a moving derelict:** the host moves everything loose inside it with it (`Derelict.pose_to`, `Pickup.carry`); each crew member's own machine moves them with it on their tick, by however far it's moved since their last (`Player._ride`), so netfox records it. Nobody aboard the LANTERN ever moves. In a jump, the old system stays while the drive spools (3 s), then it's hyperspace (`StarSystem.hyperspace()`, a sky shader) until the last 2 s, then the new system. Casting off frees the encounter, seals the collar, and the host clears everything loose that isn't aboard (`LooseItems.clear_outside`); docking, the host stocks the derelict (`LooseItems.stock`).
- **Pressure hatches** (`Hatch`, one on every hatch edge a `Deck` builds) swing on a hinge into the room they serve, and are solid while near shut (a box over the opening; the hatch model has no collider of its own). Whatever drives one sets `open` on every peer: the EVA airlock's stays shut for now; the collar's is its airlock's outer door; a derelict's entry is opened by the collar.
- **Airlocks** (`Airlock`): an inner `Door` (its own panels stand down for the lock's switches), an outer `Hatch`, the chamber's `Zone` and a cycle panel. The chamber's pressure is worked out from the state on every peer and set on its zone. The collar room is the docking airlock; the EVA airlock can use the same in M5.
- **Zones:**
  - `Area3D` volumes carry the zone's gravity override, pressure state (drives O2 drain and the vacuum audio low-pass) and power state.
  - Built now: a `Zone` per deck room cell, floor to ceiling, on the "zones" layer, with `pressurized` (a deck's `vacuum` lists its airless rooms; the sample derelict's breached rooms). A crew member's suit looks up the zone at their chest each tick (a point query); outside every zone is space. The collar's tube has its own zone while it's run out (the LANTERN's, so it hums), holding whatever the derelict's entry holds; an airlock's chamber follows its cycle; a derelict cast off with its hatch open vents every room. Gravity and power come later.
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
  - `psx_affine()` gives affine (non-perspective) UVs: multiply by w in the vertex shader, divide in the fragment shader. Scaled by `global uniform float psx_affine_amount`, **default 0 (off)**: on the kit's big triangles it slid UVs out of their atlas islands into dark wedges. `Psx.set_affine()` can bring it back.
  - `psx_dither()` does the 15-bit conversion.
- **Gotcha:** a shader that writes `POSITION` must write it in every pass, so use `POSITION = IN_SHADOW_PASS ? clip : psx_snap(...)`. Otherwise shadows collapse to a point.
- **True depth under the wobble:** snapping moves each corner up to half a pixel on its own, and at a glancing angle half a pixel is centimetres of depth. Layered surfaces (a panel proud of its wall, a door in its frame, a screen in its housing) cut through each other in dark wedges. So every snapped material writes `DEPTH` from the *unsnapped* surface at the pixel drawn (`psx_true_depth()`): the picture wobbles, but depth testing compares the real shapes. Shadow passes don't snap and keep `FRAGCOORD.z`.
- **Materials:** a small set of shared materials: PSX lit, unlit/emissive, CRT screen, skybox, planet, hyperspace tunnel.
  - Textures use nearest filtering.
  - Each material's `affine_amount` scales the global one, for when it's on.
- **Lighting:**
  - Real-time per-pixel lights only, with no baked GI (layouts are procedural).
  - **Helmet lamps** are `SpotLight3D`s at the lamp's lens on the left of the helmet, aimed to cross the line of sight 6 m ahead: the owner's at a fixed offset from their eye (`Player.LAMP_OFFSET`, bobbing with the view), everyone else's at the suit's `SOCKET_lamp`, which the head carries. The light is pulled back if the lens is pushed into a wall. Being off the eye, it throws shadows you can see. Held items and the first-person arms cast no shadows, so they can't shade the beam. (A projector texture for the lens pattern is still to come.)
  - **A teammate's lamp from outside** (`LampBeam`, riding their light): a faint additive cone of lit air from the lens to where a ray says the light lands (at most 7 m), soft at its rim, its far end and where it meets the room (the depth buffer). Their lens glows whenever it faces you, and pointed into your eyes it flares: a halo, a level streak, a six-point star and a faint veil, drawn over everything at a fixed screen size, as bright as the share of the lens that's in sight: the depth buffer, sampled across the lens on screen, against the lens's own distance. (A physics ray let it show past door frames, whose trim stands proud of their collision.) You never see your own light from outside.
  - **PSX+ bounce (GDD §14):** the environment runs Godot's SSIL and SSR at their default settings, so a lamp's spot lights what's around it on screen. `--no-gi` turns them off for comparison. (A custom bounce light at the spot was tried and dropped: its shadows threw odd shapes.)
  - **Shadows are Godot's defaults**: filter quality, bias, and the sun's splits and distance are all left at stock values.
  - **Shadow budget:** the local player's lamp always casts shadows. Teammates' lights cast shadows only within about 12 m, with at most 4 shadowed spots at once. Room practicals are unshadowed apart from hand-picked key lights.
  - No SSAO or SDFGI. Environment ambient is near black in derelicts.
- **Hull clearance:** hull plating stands 2 cm off the walls' outer faces and 3 cm off the ceiling and floor, and its outer face (0.56 m out from the wall line) clears the walls' outer chamfer. A plane shared with the deck, or a wall detail poking through, flickers as vertices snap.
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
  - Armatures and keyframed clips are written in the generator scripts (`lib/rig.py`). Bones run along the body, so a positive X turn pitches any bone forward over its head; `root_location` is in the model's axes.
  - Creature clips play stepped at 12 fps. **Crew clips are keyed every frame and interpolated:** with stepped keys a planted foot rides along with the body between keys and snaps back, which reads as sliding.
  - **Crew locomotion** (`characters.py`): walk, run and crouch-walk are each one stride cycle in one second, left heel strike first, generated from a gait. Each foot is planted for its stance and rides back under the body at exactly the gait's speed, with a heel-to-toe roll. The legs reach their ankle targets by two-bone IK (`rig.leg_ik`), and the hips drop as far as the planted feet need.
  - **Poses solved for what they achieve** (`rig.solve`, Nelder–Mead over FK), within each joint's natural reach:
    - The wrist cuff, lifted so its screen squarely faces the eye, upright, in the lower left of view, the hand past it relaxed (the wrist only droops palm-ward). The cuff sits square to the forearm it's on.
    - The suit's tool hold: low at the side, 35° up. It's set by where the grip goes and which way the held thing points, with the elbow a hinge and the wrist in range.
    - The first-person tool hold: the fist low in the right of the view, a tool's handle running up across it (a hammer grip) and leaning in, diagonal across the view and clear of the crosshair.
    - The swing (both rigs, `swing`, 0.6 s, played once over the right arm): from the tool hold, raised by 0.3 s, struck by 0.42, back in the hold. The suit chops overhead; the first-person arm draws the tool up to the right and brings it down across the view.
    - The carry (both rigs, `hold_carry`): a big thing by its side handles, 0.42 m apart, each gripped upright and palm-in. The suit holds it in front of the belly, clear of the chest unit and knees (the right arm solved, the left mirrored). In first person it sits low, so its top shows across the bottom of the view and the hands stay below it. The thing rides `SOCKET_carry` (the suit's chest, the arms' root), its own `SOCKET_grip` midway between its handles.
    - **Wrists never bend back** (toward the knuckles) holding something: they tilt toward the thumb or little finger, and bend palm-ward. A bent-back wrist was the giveaway in earlier holds.
  - **Sockets on bones** go in through `matrix_world`: a bone child's location counts from the bone's tail.
  - **In Godot:** `CrewAnimation` (an `AnimationTree`) blends idle/walk/run in step, crouching, and arm layers for what's held and for the cuff, playing the stride at the movement's cadence (backwards when backing up). `CrewPose` (a `SkeletonModifier3D`) then turns a suit's legs toward its direction of travel while the body faces its look, and tips the head and chest with the gaze. The camera's bob follows the same stride.
  - `tools/pose_sheet.py` renders any clip at chosen moments from a built `.blend`, for checking by eye; `--hold=<model>:<tilt>` puts an item in the rig's hand as the game does, `--carry=<model>` a big thing between the hands.
- **Items** (`game/items/items.gd`): each kind's model, name, mass, hand pose ("tool", or "carry" for two hands) and its tilt in each hand: `tilt` in the first-person fist, `glove` in the suit's. An item's `SOCKET_grip` goes on the hand's `SOCKET_grip`: the first-person fist, or the suit's right glove, across which a held thing lies the way a hanging fist holds a hammer. Things carried get a 16 px belt icon (`lib/icon.py`, `assets/icons/`) with each build.
  - **A thing carried is a record**: a Dictionary with its `kind` and any state of its own (charge, fill, value, to come). The belt is four records (`{}` empty) and `carrying` the two-handed one, all on the owner's machine; only `held`, the kind in hand, is synced.
  - **Loose, it's a `Pickup`** (`game/items/pickup.tscn`): a rigid body on the "items" layer, boxed to its model, that rests on the world and on other items and bounces off crew without blocking them; its handle (an `Interactable`, at least 22 cm a side so small things are easy to aim at) prompts TAKE, CARRY, BELT FULL or HANDS FULL for whoever's aiming at it. The host simulates it; everyone else eases toward the host's position.
  - **Stock:** a deck marks where loose things start (`Deck.stock`, markers in the "loot" group), and the host puts them out when the crew starts. `Deck.rack` marks things racked: the host holds them frozen where they hang (the kit rack's clips, `SOCKET_rack_*`) until they're taken.
  - **Letting go** (`Q`): a tap sets it down just ahead of the eye; held past 0.2 s it's thrown, at 3 to 9 m/s over the next 0.6 s, scaled by `sqrt(3 kg / mass)` (at least a quarter), plus the thrower's own speed.
- **Textures:**
  - Tiling surfaces (panels, grating, rust, concrete) come from CC0 photo scans (ambientCG) run through `asset-gen`, and also feed each model's detailed material before baking.
  - Signage, labels, decals and screens are drawn procedurally. Blender's bundled Python has numpy; the system Python 3.14 has no PIL.
  - Sources are recorded in `CREDITS.md`.
- **Impacts** in the synthesized sounds are one recipe, `_thunk` (a few milliseconds of low-passed noise rung through three low band-passes fed by that noise, so it has weight and no pitch; `seal` adds a gasket's sigh). A ringing sine "clang" (`_clunk`, and the door's first stop and slam) read as a synth, not metal; it's gone from every sound.
- **Gauge needles** are their own objects (`bridge.needle`), kept out of the bake: baked with the dial, a needle left a pale ghost of itself on the face. They wear `gauge_needle.tres`, a plain `psx_lit` material written by hand, like the lamps'.
- **Sound** (GDD §15): synthesized by `tools/build_audio.py` into `assets/audio/`, 22,050 Hz mono, from seeded noise, tuned modes and biquad filters, so a rebuild writes the same files. A loop (the hum, the drone: 8 s; the tunnel: 7 s, two whole swells) is rendered past its length and the overrun crossfaded into its start; its `.import` loops forward over the whole file (`edit/loop_mode=2`: 1 is Disabled; `edit/loop_end` its length in samples).

## 6. Generation

- **Seeded throughout:**
  - All generation uses explicit `RandomNumberGenerator` seeds derived from the run seed and a stable label, for example `hash(run_seed, "sector1/row3/node2/layout")`.
  - Never use global randomness.
- **Sector map** (`SectorMap`, `game/map/sector_map.gd`): a departure node (row 0), 7 rows of 2–4 nodes, the boss (row 8). A node is `Vector2i(index, row)`, with a type, an x across the chart and its system's seed (`Seeds.of(run_seed, "sector%d/row%d/node%d")`).
  - Edges: a single node joins all of the next row; otherwise a staircase from the first pair to the last, each step moving on in one row or both, so edges branch and merge, never cross, and every node is on one.
  - Types: weighted (GDD §6), the first row all derelicts. Two repairs follow: the third EVA in any run becomes a non-EVA type, then while some route reaches the boss without fuel, a node in rows 3–7 on such routes becomes a Gas Giant or Depot, weighted by how many of those routes pass through it.
  - `problems()` validates every rule; a map that fails is redrawn with the next attempt's label (`sector1/map/<n>`). With the repairs this doesn't happen in the test's 1,200 maps.
  - Each peer reports its chart's checksum to the host, which warns on a mismatch.
- **Star systems:** 1–5 planets; each has survey traits (`PlanetTraits`) from its own seed, so the look never depends on them. The scan's oddity names (`Oddities`) come from the system seed.
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
    core/                 net, run state, seeds, save, zones, sound
    player/               controller, suit, helmet lamp, cuff, interaction, carry
    station/              LANTERN scenes and its consoles
    space/                sky, star, planets, hyperspace
    map/                  sector generation, oddity names
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
  tools/                  launch scripts (host + N clients), asset build, QA shots and sheets
  docs/                   GDD.md, TECH.md
  tests/                  headless tests (tools/test.sh)
```

## 8. Testing

- **Headless tests** (`tests/`, all run by `tools/test.sh`, each by `godot --headless --path . -s <script>`):
  - `test_sector_map.gd`: 400 seeds × 3 sectors, every route walked from departure to boss against the GDD's rules, independently of the generator's own checks; determinism of the chart.
  - `test_determinism.gd`: derived seeds, charts and star systems (planets and traits) hash the same when built again, and differently for other seeds.
  - `test_smoke.gd`: every scene and built model loads and instances; then the world runs a jump on its own (scan, plot, lever, a cell burnt, the tunnel, arrival at a derelict, waiting and stocked); docks it (the airlock refusing to cycle out before), cycles the airlock out and undocks (the airlock brought in, the derelict drifting off vented with its loot aboard), docks again; a crew member dies (a body, their crowbar beside it), is revived from the body and, lost, cloned; then skims fuel at a gas giant, with no error logged.
  - `test_audio.gd`: every sample is 22 kHz mono and every ambience loops whole; the suit's bus bypasses the vacuum low-pass; in vacuum `Sound` muffles the world and turns the ambience down, and brings both back; in the tunnel its roar replaces the hum.
  - A test script can't name classes that reach the game's autoloads (they aren't there when it's compiled): it loads them at run time.
- **Networking:** the multi-instance launch script with netfox's network simulator (latency and packet loss) turned on.
- **Assets:** turntable previews are reviewed for every generated model; pose sheets (`tools/pose_sheet.py`) for every clip.
- **Dev flags** for unattended checks (`game/core/dev.gd`): `--check-aim` stands the crew member in front of every terminal and checks the crosshair finds it; `--check-jump` presses jump ten times and counts take-offs; `--check-lever` holds interact on what's aimed at (the Jump Lever, with `--at`, `--look` and `--route`) and says whether the jump began; `--at`, `--look`, `--belt`, `--hold`, `--move` (with `--sprint`, `--crouch`), `--cuff` and `--lamp` set up a shot; `--take`, `--use` and `--throw` act a second or two in; `--interact=<s>` holds interact that long on what's aimed at, a second and a half in or `--interact-at` seconds (the dock lever, the cycle lever, a body), and carries on; `--die=<s>` kills the local crew member then; `--clone=<s>` (host) has the med bay clone the first dead crew member; `--run-seed` picks the run, `--scanned`, `--route` and `--jump` start with the scan done, the first jump plotted, or jumping a second in, and `--derelict` docks the sample derelict at the departure point (`--derelict=away`: waiting for the collar); `--o2`, `--health` and `--battery` set the suit; `--view` looks from a fixed camera instead; `--screenshot` with `--frames`, `--shots`/`--shot-gap` takes one or a burst; `--wait-crew` holds the shot until that many crew are aboard.
- **QA tools** (`tools/`), for checking changes by eye in the real game and in Blender:
  - `shot.sh <out> <x,y,z,yaw,pitch>`: one frame from a fixed camera. For the player's own view, run the game with `-- --host --at=… --look=… [--hold/--cuff/--lamp] --screenshot=<out> --frames=150`.
  - `pair.sh <out> "<host flags>" "<client flags>"`: a host and a client on one machine; the host shoots once the client is aboard (`PAIR_SHOTS="--shots=4 --shot-gap=9"` for a burst). With `--view` in the host flags it's the way to see a teammate's suit, held item, beam or glare.
  - `pose_sheet.py`: a built rig's clips at chosen moments, from any angle or the first-person eye; `--hold` puts an item in the hand as the game does (`--carry` between the hands), `--focus`/`--lens` close in on a bone.
  - `clip_angles.py`: the turns a clip keys at a moment, for a solved pose's numbers.
  - `sheet.py`: contact sheets of several shots, and enlarged crops that keep the pixels crisp.
  - Built assets need a reimport before the game sees them: `godot --headless --path . --import`.

## 9. Milestones

| # | Milestone | Deliverable |
|---|---|---|
| M0 | **Foundations** | Godot project, netfox vendored, folder layout, git, PSX render pipeline, input map, launch scripts, Blender build harness |
| M1 | **Crew** | Networked first-person controller (owner-authoritative), helmet lamp, interaction, carrying, wrist cuff, visor HUD, suit O2 and pressure zones |
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
| Shadowed-light cost with 4 lamps in one room | Shadow budget (§4); measure early in M1 |
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
- **2026-10-13: Review fixes.**
  - Affine texture swim is off by default.
  - Light bounces (PSX+): SSIL, SSR, and a flashlight bounce light.
  - The crew's clips are interpolated, and locomotion is a generated, blended gait.
  - Held items and the cuff are mirrored to everyone.
  - One hand item at a time, the flashlight included (GDD A8, to confirm).
  - The aim ignores an interactable's own housing (`Interactable.housing`). A console's collision box enclosed its screens, so the bridge terminals couldn't be used.
- **2026-10-13: Second review.**
  - Snapped materials write true depth: the wall and door wedges were snapping, not affine.
  - Shadows back to Godot defaults; the flashlight bounce light removed (SSIL/SSR at defaults remain).
  - The cuff stands clear of the sleeve, whose edges cut its screen.
- **2026-10-13: Third review.**
  - Teammates' flashlights show a beam in the air and glare when pointed at you.
  - The suit's hold poses are solved (torch at the belly, tools low and ready), and each item has its own tilt in the glove; the flare is held a third of the way up.
  - The first-person left hand is relaxed when reading the cuff, and the cuff is square to its forearm.
  - First-person tools have their own solved hold (a hammer grip, diagonal across the view); no hold bends a wrist back.
- **2026-10-14: The helmet lamp** (GDD §17, decided 5).
  - The light is the suit's helmet lamp, on the left of the helmet, for everyone from the start; `F` toggles it (`lamp_on`, the `lamp` action, `--lamp`).
  - The handheld flashlight is gone: its model, the torch hold poses and `CrewPose`'s torch arm. `TorchBeam` is now `LampBeam`.
- **2026-10-14: Loose items and the belt** (GDD §9.4, decided 6).
  - The belt holds item records, loot as well as gear. Loose items are host-owned `Pickup`s; taking one moves its record into the taker's belt or hands, so a carried thing needs no authority handover (this replaces "the carrier becomes authority while holding").
  - `E` takes, `Q` drops (hold to throw). The visor dims a prompt that can't be acted on (BELT FULL, HANDS FULL) and drops its key.
  - The stores' fore shelf holds real O2 canisters and sealant, the docking port a power cell, and the sample derelict salvage, supplies and a plasma cutter. The shelf's collider follows its shelves.
  - Two-handed carries: the fuel cell goes in both hands (`carrying`), never the belt. While carrying: 1.6 m/s, no sprint, no drawing from the belt, no cuff. Both rigs have a solved `hold_carry`; the old hand-keyed `carry` clips are gone.
  - `pose_sheet.py` found an item's grip by `SOCKET_grip`'s world matrix, which a linked object doesn't have yet, and by prefix, which caught `SOCKET_grip_l`; it now takes the socket's location by its base name.
- **2026-10-14: Suit O2 and zones** (GDD §9.2).
  - Out of the air, the suit's O2 (360 s) runs down, three times as fast at a sprint; with none left, health runs out over 20 s (death itself comes with M4). The owner runs it; `o2`, `health` and `in_vacuum` are synced.
  - The cuff's O2 bar and heartbeat, the Vitals board (BPM, O2, VAC, where: a room aboard, DERELICT or OUTSIDE), the spine lights (green, amber, blinking red, dark) and a visor O2 gauge read them. The station's O2 rack refills a suit (REFILL).
- **2026-10-14: Use (`LMB`)** (GDD §9.5). Each kind says what use does (`Items.use_of`):
  - "swing" (crowbar, shock prod): the swing plays for everyone (`swings`, a synced count) and lands 0.36 s in on whatever's within 1.5 m; a loose thing gets knocked (a reliable RPC to the host, which applies the impulse). Creatures and hatches come later.
  - "refill" (O2 canister): 180 s of O2, and the canister's gone.
  - "strike" (flare): its record gets `burn` (60 s), and it burns down wherever it is. Lit, in a hand (`held_lit`) or loose, it carries a `Flame`: a flickering red omni light that throws shadows, and a glow. The host clears a loose flare away when it's out.
- **2026-10-14: Starting kit, lamp battery, flare light** (GDD §17, decided 7).
  - Belts start empty. The kit rack (`rm_kit_rack`, a shadow board on the docking port's aft wall) holds the crew's one crowbar and one flare; the sample derelict has a shock prod and two more flares.
  - The helmet lamp drains over 360 s lit (`battery`, synced), flickers below 15% (each peer works out the flicker from the charge, so beam and glare flicker too) and goes out when flat. The lamp charger (`rm_lamp_charger`) beside the suit room's O2 rack charges it full (CHARGE; `Player.top_up`, as the rack's REFILL).
  - A burning flare casts no shadow, so its tube can't shade its own flame; loose, its light hangs 0.3 m above it (a light at floor level only grazed the floor).
  - Wall props stand clear of the wall line by 0.13 m plus their own back: the wall kit's panels stand proud.
- **2026-10-14: Navigation, first part (M3).**
  - The run state is `Run`, host-owned and sent whole on every change (§2). Run seeds come from `--run-seed` or a fresh random one; every generated thing derives its seed from it and a label (`Seeds`).
  - Sector maps (§6): a departure node below the first row, so the first jump picks among the first row's derelicts, and the boss's way on leads to the next sector.
  - Stations: the Nav Chart plots a route (click a charted jump), the long-range scan (8 s) names the oddity and charts the next row, the Survey Console (5 s a planet) fills in traits and adds Survey Data, Engineering skims fuel at a Gas Giant or draws it at a Depot (20 s, one bay, once a system). The scan screen is round, so its findings are centred lines under the scope.
  - The Jump Lever takes a hold (`Interactable.hold`, 2 s): the visor's prompt gets a gauge, and the lever's handle is split onto a pivot that swings. It won't engage without a route, a loaded cell, or with anyone off the station (`Run.jump_blocker`).
  - The jump (§3): the camera shakes (`Run.shake`), the deck's lights and the fixtures' glow (`emission_tint` on the PSX material) go red and pulse (`Run.alarm`), the drive core blazes; hyperspace is a sky shader (`hyperspace.gdshader`) with a flash at each end.
  - Fuel is the Run's three bays; the fuel rack shows a cell in each loaded bay and loads a carried cell (the carrier's machine hands it over, `Player.take_from_hands`; if the bay's been filled meanwhile, the host sets the cell down in front). The docking port's spare cell is gone: the run starts with the GDD's 3.
  - The collar seals when nothing's docked, and both outer hatches are now solid while shut (they had no collider).
  - Tests (§8): sector map rules, determinism and a smoke test that plays a jump; `tools/test.sh` runs them.
- **2026-10-14: The chart table** (GDD §17, decided 8). `br_chart_table` replaces `br_chair` on the dais (the chair's model stays built, unused). Its hologram (`ChartTable`, at `SOCKET_holo`) redraws the Run's chart every frame: an `ImmediateMesh` of lines for row rails, routes and a ring where the station is, a `Label3D` per charted node in the VT323 pixel font, a fading cone from the lens, and a dim green light. They share `hologram.gdshader` (unshaded, additive, scanlines, a `strength` for the flicker). What glows on the table is modelled with a glowing material, not decals: a 256 texture lost a thin ring to sampling.
- **2026-10-14: Jumps, the lever's hold, the table lowered.**
  - Jump (space) was read with `is_action_just_pressed` on the movement tick, which runs 30 times a second, fewer than frames, so most presses fell between ticks (`--check-jump`: 0 of 10 before, 10 of 10 after). A press is now kept 0.2 s for the tick (`JUMP_BUFFER`); pressed just before landing, it jumps on touching down. Other one-off presses are read in `_unhandled_input`, not on the tick.
  - A hold (the Jump Lever) survives the crosshair slipping off for up to 0.3 s (`HOLD_SLACK`); the handle's box is small.
  - The dais is gone from the bridge (crew caught on its 16 cm step; the character body doesn't step up), and the chart table is lower (glass at 0.8 m) on the deck. `br_dais` and `br_chair` stay built, unused.
- **2026-10-14: Sound** (GDD §15), from the `sound-design` branch, reworked.
  - Synthesized samples (§5): the LANTERN's hum and a derelict's drone, the helmet lamp's switch, footfalls on the LANTERN's steel and on a derelict's deck (four of each), a landing, a door opening and shutting; the jump's spool, tunnel mouth, tunnel roar and exit; a console's click, confirm and refusal; a fuel cell seating; taking a thing. No breathing for now: in playtest it crowded the soundscape. The branch's lever sounds aren't in: not up to the bar yet.
  - Buses (`default_bus_layout.tres`): `World`, everything heard through the air, carries the vacuum low-pass, with `Ambient` feeding into it; `Suit` (your own lamp's switch; breathing and the radio later) goes straight to `Master`, so it stays clear in vacuum.
  - `Sound` (an autoload) listens from the crew member at this machine: the ambience of where they are, by the zone at their chest (the hum aboard, the drone in a derelict, nothing in space), crossfaded; out of the air the low-pass closes to 380 Hz and the ambience drops to −24 dB.
  - A crew member's sounds play on every peer (`Player._make_sounds`): a footfall at each heel strike of the stride, by the deck they're on and their gait; a thump coming down faster than 1.8 m/s; the lamp's switch, but not when it goes out flat. Your own are in your ears, everyone else's from where they are. `grounded` is synced for this: only the owner's body moves, so only it knew.
  - The jump, aboard (`Run`'s stages): the hum drops out at the lever and the drive spools up (3 s); the tunnel's mouth booms and its roar takes the hum's place; 2 s out, the drive winds down; the hum comes back once it's over. A crew member joining partway hears only the stages from then on.
  - Consoles: a click on every press of a screen (`Terminal.push`), a chirp when a screen sends a request (`CrtScreen.confirm`), a buzz for a button shown but not usable now, mid-jump (`CrtScreen.refuse`). Only the operator hears them, as only their machine has the presses. A bay of the fuel rack filling (loaded or skimmed) sounds from the bay, for everyone; not the bays a run starts with. Taking a thing sounds in the taker's ears.
  - A door sounds as it opens or shuts. A door set as it's built (before its first frame) starts that way at once, silently: the sample derelict is made with its doors open, which sounded every one of them at docking.
  - Fixed from the branch: the ambient loops (and the tunnel's) never looped (`edit/loop_mode=1` is Disabled; a restart on `finished` covered for it) and their crossfade left a step at the seam; a teammate's footfalls and landings never played (they waited on `is_on_floor()` and the movement tick, both the owner's alone); where you were was `x >= 14`, now the zone. Dropped from it: a slower stride while carrying, which made the feet slide (below walking pace the stride shortens at walking cadence, §5).
- **2026-10-14: Docking through the collar's airlock** (GDD §8.1, §8.3, §17 decided 9 and 10).
  - A derelict waits off the starboard bow; the dock panel's COLLAR lever (held 2 s) docks it: the tractor beam (`tractor_beam.gdshader`, built like the lamp's beam, with a spotlight on hulls alone) draws it in, the collar's tube (`lk_collar_tube`) runs out, the hulls meet (a jolt, `Collar.shake`), the clamps bite, the collar opens its hatch. Every derelict docks one cell out from the LANTERN's collar hatch; the sample's root sits at x = 4.
  - The collar room is an airlock (`Airlock`): the inner door, the outer hatch, never both open; a 5.5 s cycle (1.3 s for the door behind to shut, then the pressure). The derelict keeps its own air; the dock panel's EXT PRESS reads it once the hatch is open.
  - Undocking: the siren (10 s, abortable), the airlock forced in, the tube in, the derelict pushed off with its hatch open, vented, carrying anyone aboard. The jump casts off at once.
  - Pressure hatches swing (`Hatch`); the derelict re-bakes the hull kit (`dh_*`); the needles and lever on the panels are split off to turn.
  - The left-behind rules (GDD decided 10) are designed; until death and the Med Bay clone exist, the Jump Lever still refuses with crew off station.
  - A client never built the sample derelict that `--derelict` brought to the departure (the flag was only on the host's command line): the host now sends it in the run state (`Run.dev_derelict`).
- **2026-10-14: Death, bodies and the med bay** (GDD §11, §17 decided 11 and 12).
  - Death: suffocation, or lost to a jump (the Jump Lever no longer waits for crew off station). The dead watch through the station's cameras (six now: bridge, corridor, docking port, collar, drive room, med bay) and teammates' helmets.
  - Bodies are ragdolls, loose like items: CARRY in both arms, Q to drop or throw, INSERT at the med pod to revive (10 s). The pod's screen clones anyone dead (30 s). Online from the start; costs wait for the economy.
  - Ragdoll poses aren't synced, only where a body lies (raised in review: each peer's limbs may differ).
  - The collar's node is `DockingCollar`: a station camera named "Collar" took its name.

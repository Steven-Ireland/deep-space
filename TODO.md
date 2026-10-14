# Deep Space: status and next steps

Last updated 2026-10-14. Read this with [docs/GDD.md](docs/GDD.md) (design, look and feel) and
[docs/TECH.md](docs/TECH.md) (how it's built). The target is the **vertical slice** in GDD §16;
the build order is TECH §9.

## Where we are

The **first build pass** ("environment first", TECH §9) is done, with three rounds of review on top:

- **Foundations (M0):** Godot 4.7.2, netfox 1.49.4 vendored (no rollback), the PSX pipeline
  (vertex snap with true depth, 270-line pixelation, 15-bit dither), the Blender build harness.
- **Crew, enough to walk the station together (part of M1):** the networked first-person controller
  (owner-authoritative), gaits blended in step with legs that turn toward travel, the belt (four
  slots, `1–4`/wheel), held items mirrored to everyone, the wrist cuff (`Tab`), the visor HUD (a
  floating prompt, the belt), terminals you step up to.
- **LANTERN and space (M2):** the station kit and every room furnished, the exterior hull, bridge
  stations with live terminal screens (nav, scan, survey, vitals, cams, power, status), seeded
  star systems with sky, star and planets, the lighting pass (SSIL/SSR, Godot's default shadows).
- **Models for the rest of the slice:** the derelict kit (a hand-placed sample derelict, since
  replaced by the generator), the Crawler and the Hanger with clips, the suit and first-person arms, every slice item,
  Tier 0–1 weapons and energy cartridges.
- **Latest review fixes:**
  - teammates' lamps show a beam in the air and glare when pointed at you; the glare hides
    behind whatever's drawn in front of the lens
  - the suit's tool hold is solved (low and ready)
  - the first-person left hand is relaxed when reading the cuff, and the cuff sits square on its
    forearm
  - first-person tools (crowbar, shock prod, flare) have their own solved hold: a hammer grip,
    diagonal across the view and clear of the crosshair; no hold bends a wrist back

The **gameplay loop's crew half (most of M1, 2026-10-14)**:

- **Helmet lamp (GDD A8, decided):** on the left of every helmet from the start, `F` toggles it,
  its offset shadows visible; teammates see its beam and glare. The handheld flashlight is gone.
- **Loose items:** `E` takes a thing into the belt (loot as well as gear), `Q` sets it down, held
  `Q` throws it; the host owns what's loose, and everyone sees it land. The stores, the docking
  port and every derelict are stocked.
- **Two-handed carries:** the fuel cell, held in both hands with solved poses; slow, no sprint, no
  belt or cuff until it's set down. One waits in the docking port, one in the derelict's Prize
  room.
- **Suit O2:** per-room zones with or without air (a derelict's have none); O2 drains out of the air, faster sprinting, then health. It drives the cuff, the Vitals
  board, the spine lights and a visor O2 gauge; the suit room's O2 rack refills it.
- **Use (`LMB`):** tools swing (everyone sees it, and it knocks loose things about), an O2
  canister tops up the suit, a flare is struck and burns red for 60 s in the hand or thrown.
- **Starting kit and lamp battery:** belts start empty; the crew's one crowbar and one flare hang
  on the kit rack in the docking port. The lamp runs 6 minutes, flickers when low and recharges at
  the suit room's charger.

**Navigation, first part (M3, 2026-10-14):**

- **The run:** a seed per run, host-owned run state sent to everyone. Sectors are charted from the
  seed: a departure point, 7 rows of 2–4 systems, the boss; routes branch and merge, never cross;
  the GDD's rules hold on every route (tested).
- **The bridge works:** the long-range scan names the system's oddity and charts the next row;
  the Nav Chart shows the sector and plots a route; the Survey Console reads a planet's traits and
  adds Survey Data; Engineering shows the drive and the fuel, and skims a cell at a gas giant.
- **The jump:** hold the Jump Lever 2 s (route, a loaded cell, everyone aboard). The station
  shakes, the lights go red, the viewport flashes into a hyperspace tunnel, and 10–20 s later
  it's a new system. A derelict node brings a derelict alongside, stocked; leaving casts it off with
  anything loose left in it.
- **Fuel:** three cells loaded in the drive room's rack; a jump burns one; a carried cell loads
  into an empty bay.
- **Tests:** `tools/test.sh` runs sector map rules, determinism and a smoke test that plays a jump.

- **The chart table:** in place of the captain's chair and its dais, standing low on the deck; its
  green hologram is the sector chart, for the whole crew.
- **Fixed:** jump (space) missed most presses (read on the 30 Hz movement tick); the Jump Lever's
  hold no longer drops if the crosshair slips off the handle for a moment.
- **Sound (GDD §15):** synthesized 22 kHz samples (`tools/build_audio.py`): the LANTERN's hum
  aboard, a derelict's drone in one; footfalls in step with the stride on either deck, landings,
  the helmet lamp's switch and the doors, for the whole crew. The jump spools up, booms into a
  roaring tunnel and winds down out of it, the hum gone until it's over. Consoles click, chirp
  and buzz; a fuel cell seats with a clank; taking a thing clips it on. Out of the air the world
  is muffled and the hum drops away; the suit's own sounds stay clear. (The Jump Lever's sounds
  wait until they're up to the bar.)

**Docking (M4, first part, 2026-10-14):**

- **The derelict waits** off the starboard bow, seen from the bridge's side port, until the dock
  panel's COLLAR lever (in the docking port, held 2 s) docks it: a pale tractor beam draws it in,
  the collar's tube runs out to its hatch, the hulls meet with a jolt, the clamps bite, the collar
  opens its hatch. The panel's EXT PRESS gauge then reads what the derelict holds.
- **The collar room is an airlock**, a pressure chamber with round hatches at both ends: cycle out
  with the lever inside (the inner hatch shuts, the chamber vents, the outer hatch swings open),
  cycle back in the same way; a locked hatch's handles call it round. Suits seal (O2 running, the
  world muffled) the moment it starts cycling out. Derelicts hold no air, for now.
- **Undocking:** the lever again sounds the siren for 10 s (again to abort) and brings the airlock
  in; then the tube lets go and the beam pushes the derelict off with its hatch open, venting. Anyone
  still aboard rides it out on suit O2; docking again picks them up. A jump casts off at once.
- **Art and sound:** the derelict's own hull (teal-grey, rust, torn panels, scorch), the collar
  tube, the dock panel, swinging pressure hatches, the cycle panel's lever and needle working;
  hatch, airlock, docking and siren sounds.
- **Tests:** the smoke test docks, cycles the airlock, undocks and docks again.

**Death and the med bay (M4, 2026-10-14):**

- **Death:** suffocating, or left off the station when the jump's tunnel opens (lost: the Jump Lever
  no longer waits). A body falls limp where you died (a ragdoll), everything you had dropped round
  it; your eyes go to the station's six cameras and your teammates' helmet cams.
- **Bodies** are carried like heavy items (CARRY, both arms; Q drops or throws). Each machine lets
  its own copy fall; only where it lies is shared.
- **The med bay** is online and lit: INSERT a body at the pod to revive whoever it was (10 s), or
  CLONE anyone dead from its screen (30 s), and they step out beside it.

**The derelict generator (M4, 2026-10-14):**

- **Every derelict is grown from its node's seed** (the same on every peer) out of twelve hand-built
  modules: the entry, three corridors (straight, junction, bend), seven rooms (crew quarters, cargo
  hold, infirmary, machine shop, drive room, control with windows, suit storage) and the Prize room.
  Each module has its footprint, its door sockets and its dressing; they join door to door, turned
  to fit.
- **The plan:** 29–39 rooms grown out from the entry (never back toward the LANTERN), big enough
  that one tank of O2 won't see it all and the crew have to find their way; the Prize room a dead
  end at the far end (about ten rooms in), and two to five loops that never shorten the way to it. A quarter of the doors start shut; a room's outer wall is sometimes torn open (a breach),
  and control has its windows.
- **Dressing:** each room's furniture, strobes lit or dark or failing, cables, debris and the
  earlier wave's dead. Often one creature, sometimes none, rarely two, never near the entry or with
  the Prize: a Crawler waiting, or a Hanger over its growth (posed, until the AI).
- **Loot:** a fuel cell (drive room, else cargo, else the Prize room), and salvage, supplies, data
  cores, power cells, cartridges and tools from a budget that grows with the crew and the
  derelict's size, each where it suits (supplies in the infirmary, data in control, tools in the
  machine shop). Thin on the ground: about 0.8 finds a room for one crew.
- **The sample derelict is gone:** `--derelict` docks the departure's own. The host's log prints the
  plan and where each room lies docked.
- **Fixed:** strobes lit the hull from inside; a breach's wound faced space half the time; the
  pressure hatches (the airlock's two, a derelict's entry) had see-through gaps in the corners round
  their rings.
- **Tests:** `test_derelict_layout` checks 900 layouts from the walls the Deck builds.

Still to come: creature behaviour.

## Next: the gameplay loop (proposed order)

1. **Rest of M1, the crew:**
   - the Prize and a body as two-handed carries (with M4; the fuel cell's done)
   - what a swing does to creatures and hatches (with M4), the shock prod's stun and charge,
     sealant (with suit integrity), weapons in use (slice wrap-up)
   - suit integrity and breaches (with hazards)
2. **Rest of M3, navigation:**
   - the boss node is only a name and a way on to the next sector (its greybox is M5); saving
     between jumps
   - Signal, Anomaly, Colony, Relay and Depot nodes are names only (slice wrap-up, M5); a Depot
     gives a cell like a gas giant until salvage can be spent
3. **M4, the derelict:**
   - power zones and breakers (the drive room has a breaker box already)
   - loot: fuel, salvage, O2, power cells, data cores, sealant
   - the Prize and Prize events
   - hazards
   - Crawler AI (an eyeless sound hunter) and Hanger AI (a ceiling trap)
   - more ways to die (creatures, hazards), each specific; a death sound and the Vitals board's
     flatline
4. **Slice wrap-up:**
   - upgrades: O2 Capacity I, Med Bay
   - the Workshop's recycler and Fabricator
   - Tier 1 weapons in use, with energy cartridges
   - placeholder Signal and Anomaly nodes
   - the EVA airlock and hull exterior
   - an audio pass

## Decisions needed

- **To judge in play (2026-10-14):**
  - Carrying in first person shows only the top of the fuel cell across the bottom of the view;
    the hands stay below the frame. Higher would show the hands but hide more of the view.
  - Numbers: 6 minutes of O2, 3 a canister, 20 s to suffocate, 1.6 m/s carrying, throws of 3–9
    m/s.
  - The run starts at a departure point with nothing docked: the first derelict is one scan and
    one jump away. (`--derelict` docks the departure's own at the start for checks.)
  - Fuel: 3 cells, 8 jumps a sector; a cell from each derelict (if carried back) and one per gas
    giant (about 4 fuel stops a map). Scan 8 s, survey 5 s, skim 20 s, jumps 10–20 s.
  - The hyperspace tunnel's look, and the shake's strength.
  - Docking: the derelict 16 s coming in (and going), the tube 3 s, the clamps 4.5 s, the siren 10 s,
    an airlock cycle 5.5 s; where the derelict waits; the tractor beam's colour, width and bands; the
    jolt at contact; the tube's light (dim).
  - Sounds: the clang is out (2026-10-14). Every impact in the door, hatch, airlock and docking
    sounds is now a dull, unpitched thunk (`_thunk` in `tools/build_audio.py`: a short knock rung
    through low noise-fed resonances, a gasket's sigh on the heavy ones). Listen for whether it
    reads as weight meeting metal now, and the levels: the hatch's locking dogs, its stop.
  - Bodies: how a ragdoll falls and lies (joint limits are loose; limbs can hang straight), how a
    carried body shows in first person (its chest across the bottom of the view, the head off to
    the right) and in a teammate's arms; revive 10 s, clone 30 s.
  - Derelicts (2026-10-14: 2.5 times bigger after the first walk-through, which took two
    leisurely minutes): their size (29–39 rooms), how often doors start shut (a quarter), breaches
    (one outer room wall in ten), lit strobes (70%), and the loot (about 27 finds for one crew, 42
    for four; 0.8 a room). The creature odds stay the GDD's (none 20%, one 70%, two 10%), so in a
    derelict this size one is easy to miss until the AI hunts by sound.
  - More room modules: the rarer rooms repeat at this size (two infirmaries, machine shops and suit
    storages in most derelicts).
- **Upgrades and costs (later):** with the economy, whether the Med Bay needs its upgrade, and what
  a revive and a clone cost (a revive cheaper).
  - The chart table's hologram: its size and height over the table, how readable its marks are
    from across the bridge, how often it drops out.
- **What Survey Data is for (GDD §7).** This can wait until after the slice.
- **The beam in the air:** teammates' beams show everywhere, faintly. GDD §14 says haze makes beams
  visible in derelicts. It could be made stronger there and fainter aboard the station.

## Known issues and polish

- **The collar tube is 1,328 triangles**, over the kit pieces' 50–400; it's a one-off, closer to the
  exterior's budget.
- **The dock panel's small stencils** don't survive the texel density; only COLLAR and EXT remain.

- **Room lights leak through walls:** the ceiling OmniLights are unshadowed, so the sealed med bay
  isn't dark. Fixes: shadows on a few key fixtures, or tighter ranges.
- **Derelict rust reads grey.**
- **Triangle budgets:**
  - The suit is about 1,548 triangles, over the characters' 600–1,200 (GDD §14).
  - The first-person arms are 1,008.
- **The suit's glove is a plain box.** It reads fine at playing distance.
- **Partly verified animation:** the run is checked only in Blender pose sheets, and the strafe leg
  turn hasn't been checked in-game.
- **SSIL intensity** could be raised if rooms want more fill.
- **The lamp's beam shows 15-bit banding** up close. This is accepted as the PSX look.
- **Test shots pick up keyboard and mouse input:** the game window takes focus and captures the
  mouse, so input at the machine during a run can move a `--screenshot` shot. Keep hands off while
  one runs. (Shot runs could ignore input later, if it becomes a nuisance.)
- **The first-person right arm doesn't sway while walking with a tool:** the hold layer overrides
  it. The view still bobs.
- **Loot uses the tool hold:** fine for most things, but the O2 canister is gripped at its handle and
  sticks up across the view, and the guns point up rather than ahead until weapons get an aimed
  hold.
- **A throw has no wind-up:** the arm doesn't draw back while `Q` is held.

## Working rules

- **Docs:** GDD.md is design, look and feel only; TECH.md is technical. Keep them separate. Record
  decisions in TECH §11, and update both docs as things change.
- **Git:** local only, never pushed. Claude commits at each meaningful step, ending each message
  with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Networking:** keep it simple. Clients are trusted, the host applies their actions, and each
  crew member owns their own state.
- **Art:**
  - Every model is authored in Blender scripts (`art/blender/`) at final quality, never a
    placeholder.
  - Textures are CC0 scans from ambientCG.
  - The look is PSX with a little modern light (GDD §14).
- **Interface:** diegetic, with a grounded, minimal visor HUD.
- **Verify by eye in the real game** before calling anything done, using the tools below.

## How to build and check

- **Godot:** `/Applications/Godot.app/Contents/MacOS/Godot` (or `tools/godot.sh`). Launch a
  local crew with `tools/run.sh [clients]`.
- **Build models:** `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P
  art/blender/build.py -- <names>`. This writes the `.glb`, textures, preview and belt icon. Then
  reimport: `Godot --headless --path . --import`.
- **QA tools** (TECH §8; each script's header has its usage):

  | Tool | What it does |
  |---|---|
  | `tools/shot.sh` | One frame from a fixed camera. |
  | The game with `-- --host --at=x,y,z --look=yaw,pitch [--hold=crowbar] [--cuff] [--lamp] --screenshot=out.png --frames=150` | Your own first-person view. |
  | `tools/pair.sh out.png "<host flags>" "<client flags>"` | A teammate, seen by the host (`--view=x,y,z,yaw,pitch` in the host flags for a fixed camera). |
  | `tools/pose_sheet.py` | Clips from a built `.blend`, with `--hold`, `--focus`, `--lens` and `--size`. |
  | `tools/clip_angles.py` | A clip's bone turns. |
  | `tools/sheet.py` | Contact sheets and crisp crops. |
  | `--check-aim` | Checks every terminal can be used. |
  | `--check-jump`, `--check-lever` | Presses jump ten times and counts take-offs; holds interact on the aimed thing (the Jump Lever: `--route --at=-1.85,0,-3.2 --look=0,-22`) and says whether the jump began. |
  | `tools/test.sh [name]` | The headless tests: sector map rules, derelict layouts, determinism, audio, the smoke test. |
  | `--run-seed=n`, `--scanned`, `--route`, `--jump`, `--derelict` | The run: its seed; scanned, a route plotted, jumping a second in; the departure's own derelict docked at the start. `--operate=screen_nav` steps up to a terminal. |
- **Getting around:**
  - **Grid and directions:** a 4 m grid, with the bridge's centre at the origin. Fore is -Z,
    port is -X.
  - **Look direction:** `--look` yaw 0 faces fore (-Z), 90 faces port (-X), -90 starboard, 180 aft.
  - **The station:** open bridge floor at (-3, 0, 0.5); cabin 4 at (4.4, 0, 18.3). The station's
    doors start shut.
  - **The derelict:** alongside only at a Derelict node (the first row is all derelicts), waiting
    for the collar; or with `--derelict` (docked) or `--derelict=away` (waiting) at the departure.
    Each is grown from its node's seed (`--run-seed` picks the departure's). Docked, it lies one
    cell out from the collar, past the tube (x 14–18): its entry at (20, 0, 0), everything else east
    of x 18. The host's log prints the plan and each room's centre, docked, with what lives there;
    a room's middle is usually clear floor to shoot from. (Run 14256631's has both creatures: a
    Hanger in the corridor at (34, 0, 4), a Crawler in the one at (24, 0, 14).)

    | Area | Position (docked) |
    |---|---|
    | Collar's airlock (the collar room) | (12, 0, 0); its cycle panel by the outer hatch |
    | Dock panel | (9.7, 0, 1.6), in the docking port; stand at (8.6, 0, 1.25), `--look=-111,-36` for the lever |
    | The derelict's entry | (20, 0, 0) |

    `--interact=<s>` holds interact on what's aimed at, so a shot can dock (`--interact=2.4` at the
    lever) or cycle the airlock (stand at (12.6, 0, 1), `--look=-120,-25`, `--interact=1`);
    `--interact-at=<s>` delays it (to take a body once it's fallen).
  - **Death:** `--die=<s>` kills the local crew member then; `--clone=<s>` has the host's med bay
    clone whoever's dead. The med bay is at (4, 0, 20); its pod at (4.2, 0, 20).

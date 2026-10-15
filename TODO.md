# Deep Space: status and next steps

Last updated 2026-10-15. Read this with [docs/GDD.md](docs/GDD.md) (design, look and feel) and
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
- **The bridge works:** the scope names the system's oddity (the next row is charted by a survey
  core since M4, below); the Nav Chart shows the sector and plots a route; the Survey Console reads a planet's traits and
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


**EVA and relays (M5, first part, 2026-10-14):**

- **The generator grows in three dimensions** (`RoomLayout`): cells on levels 4 m apart, modules
  that span levels, sockets up and down through hatchways. Derelicts grow exactly as before on top
  of it; satellites stand on three to five levels.
- **Relay satellites:** at a Relay node (or `--satellite`, at the departure) a working relay is
  set out 20–28 m off the port side, its hatch facing the EVA airlock. Grown from the node's seed
  out of twelve modules (entry, nodes, a two-level shaft, passages, equipment bay, power bay,
  telemetry, stowage, propellant, feed room, shelter, the relay core as its Prize): 12–17 rooms,
  lit cold white, airless and weightless, things hanging where they were left. A live telemetry
  console, flickering racks, a working O2 rack in stowage, a fuel cell half the time. Outside: a
  white-and-gold hull, solar wings with blinking nav lamps, a dish, a strobe mast, thruster
  clusters, floodlights and a beacon over its hatch, which opens by hand.
- **The EVA airlock** off the suit room cycles like the collar's (the suit room's door into it is
  a pressure hatch now). **The harness rack** in the suit room holds four thruster harnesses: hold
  E to DON (fuelled) or STOW. Worn: 1.5 m/s on foot, no sprint.
- **Weightless crew** (the 0 g controller): haul along anything within reach and stop when you let
  go; drift out of reach; with the harness, jets push where you look (Space up, Ctrl down, Shift
  brakes) from 45 s of propellant, up to 3.5 m/s. A shorter body in the float pose fits hatches;
  things thrown push you back; loose things and bodies float. Teammates see the harness, the jets'
  puffs and the float pose, and hear the jets; the visor shows RCS under O2, the cuff a bar, the
  Vitals board SATELLITE or OUTSIDE.
- **Fixed on the way:** hull plating had no colliders (crew outside would sink into it); the hatch
  rings on walls and hull (LANTERN and derelicts too) and the dishes had faces turned inside out,
  and a wall hatch's ring bore swung off with its door: see-through round every hatch. Previews
  now cull back faces, as the game does, so that kind of fault shows at review.
- **Tests:** `test_satellite_layout` checks 900 satellites from what the Decks build; the smoke
  test cycles the EVA airlock, sets a satellite out and flies a crew member round it on the jets;
  `--check-eva` plays a whole EVA through with the keys, `--tour` shoots every room.

**Creatures (M4, 2026-10-15):**

- **They come alive** once their derelict docks, run by the host and seen by everyone (synced like
  crew; checked with a host and a client, also after a jump brings a new derelict).
- **Noise:** footfalls by gait (a crouched step carries 1.5 m, a walk 6, a sprint 16), landings,
  doors and hatches, things dropped or thrown landing (now heard: they clatter), a tool striking
  anything, a prod's jolt, a flare's hiss. Heard on the host through the derelict's rooms, over a
  0.5 m grid of its floor worked out from its colliders (a shut door muffles it).
- **The Crawler:** waits clicking, ambles; goes to listen at a quiet sound; hunts whoever made a
  loud one (3.4 m/s: sprint to outrun it) to where it heard them; feels anyone within 1.7 m;
  lunges from 2.2–3 m, strikes closer (half a crew member's health), grabs from behind (dead);
  beats at a shut door it can't open; a flare lures and holds it. A charged shock prod drops it
  for 5 s, five crowbar blows kill it, a door shut on it crushes it. Crew and it are solid to one
  another; it kicks loose things about.
- **The Hanger:** its tendrils no longer glow (only their beads, low over the deck, and its sacs);
  walk into them and they snap shut round you, draw you up and hold you looking up into it, dead
  in 3 s unless someone strikes it (your own blow counts, with a tool in hand); then it lets go
  and draws up out of reach for a while. Three crowbar blows kill it.
- **The crew:** the shock prod holds three jolts (lamps on it), filled at the lamp charger. A blow
  jolts the view, sets off the suit's alarm, flickers the visor's readouts and spatters blood on
  its glass. Deaths are `crawler`, `grabbed`, `hanger`; each flatlines in the helmet and on the
  Vitals board.
- **Art and sound:** new clips (Crawler stunned and hurt; Hanger grab as a cage, hold, hurt, draw
  up, lower, death); synthesized clatters, tool strikes, flesh hits, the prod's zap, the Crawler's
  and the Hanger's sounds, the suit's alarm and the flatline.
- **Tools:** `build.py --keep-texture` rebuilds a model (its clips) keeping its bake and UVs, for
  when the photo scans aren't to hand; `tools/build_audio.py <groups>` builds only those sounds;
  `--provoke`, `--wound`, `--debug-creatures`.
- **Tests:** `test_creatures` plays it all through headless.

**The derelict, the rest of M4 (2026-10-15):**

- **The suit's HUD and panel** (diegetic-first rescinded, GDD §10): `Tab` opens the suit panel
  (GEAR: drag, drop, draw and use the belt, item details, a doll of the suit; SUIT: vitals, O2,
  integrity, battery, propellant, dose, and the crew with their whereabouts and causes of death;
  LOGS: lore read from data cores). The visor HUD was rewritten: gauges that come and go, notices
  typed out at the top, frost on a breach, fog near the end of the O2, radiation static.
- **The communicator:** hold `V` to raise the cuff and key the radio; the cuff shows a scrolling
  spectrogram of the channel. The voice itself is still to come.
- **Suit integrity:** blows wear the suit, a hard one or any once it's frail breaches it, a breach
  leaks O2 (hiss, frost) until sealed with sealant.
- **Power:** every derelict is 3–5 sections, each with a breaker box (some charged, some wanting a
  power cell carried in). Power brings back its lights (with a stutter, some failing or broken),
  its doors and its fittings; dead doors can be pried with a crowbar (loud).
- **Secure stores:** most derelicts lock one off a corridor; its lock panel's cipher (three wheels,
  Mastermind-style answers, six tries, then a lock-out and an alarm) opens it to weapons and
  supplies.
- **The Prize is a survey core:** carried back and seated in the bridge's new core reader, it
  identifies the next row of jumps; without one the next row shows `?` and the crew jumps blind.
  Relays rack one too. (Replaces the long-range scan.)
- **Prize events:** security (lockdown, beacons, ceiling sentries that sweep and shoot, a crowbar
  forces a door, 75 s), depressurization (air round the Prize, seal failure, the wall blows out, a
  gale to the hole, VENTING doors), structural breach (shaking, falls of debris warned by dust, a
  door buckled under a heap of ceiling), infestation (a nest bursts, a Crawler after the carrier).
  Or, often, nothing.
- **Hazards:** live coolant spills once their section has power (electrocuted; Crawlers stunned),
  a leaking drive core (radiation: Geiger, RAD, irradiated), faulty doors slamming on a dying
  circuit (crushed). The dead see what killed them, and so does the Vitals board.
- **Creatures:** Hangers only where it stays dark, shy of a burning flare; a Crawler on the crew's
  heels follows them out through the collar and aboard the LANTERN, and stays (through jumps).
- **Loot uses:** data cores upload at the Survey Console for Survey Data; salvage carries a scrap
  value. (Neither buys anything yet.)
- **New models:** `it_survey_core`, `rm_core_reader`, `dk_core_cradle`, `dk_breaker`,
  `dk_lock_panel`, `dk_sentry`, `dk_beacon`, `dk_wall_blowout`, `dk_nest`, `dk_heap`, `dk_puddle`.
  The old jump-core Prize (`dk_prize_core`) is gone.
- **Fixed:** the visor's prompt box flew off on slow frames; floor and ceiling decals were lost in
  the Blender builds; the carried survey core rode below the view.
- **Tests:** `test_power`, `test_events`, `test_hazards`; following aboard in `test_creatures`;
  the survey core and data core uploads in `test_smoke`. Dev flags `--event`, `--prize-taken`,
  `--powered`.

## Next: the gameplay loop (proposed order)

1. **Rest of M1, the crew:**
   - weapons in use (slice wrap-up: the plasma cutter on creatures and sealed hatches)
   - in-game voice on the communicator (the cuff's spectrogram is ready for it)
2. **Rest of M3, navigation:**
   - the boss node is only a name and a way on to the next sector (its greybox is M5); saving
     between jumps
   - Signal, Anomaly, Colony, Relay and Depot nodes are names only (slice wrap-up, M5); a Depot
     gives a cell like a gas giant until salvage can be spent
3. **M4, the derelict:** done (above), but for:
   - the Airlock Turret upgrade (stops anything following the crew aboard), with the upgrades
   - the real sounds for everything new (stand-ins now, below) and the real photo scans for the
     new models (below)
4. **Slice wrap-up:**
   - upgrades: O2 Capacity I, Med Bay; what Survey Data and scrap buy
   - the Workshop's recycler and Fabricator
   - Tier 1 weapons in use, with energy cartridges
   - placeholder Signal and Anomaly nodes
   - the EVA airlock and hull exterior (done: EVA to relays, above)
   - an audio pass
5. **Rest of M5, EVA:**
   - the tether (proposed below, under decisions)
   - Colony nodes: a moonlet at 0.16 g, an outpost to walk to (the zone weight is ready for it)
   - relays with something wrong aboard (a Signal's twist, a creature adapted to vacuum), and
     relay power you can cut
   - mag-boots, if weightless derelicts come

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
  - EVA (2026-10-14): the harness's numbers (45 s of propellant, 1 m/s², 3.5 m/s top, braking),
    hauling (1.3 m/s, 35 cm reach), 1.5 m/s on foot with it on; the relay's distance (20–28 m) and
    size (12–17 rooms on 3–5 levels); a fuel cell in half of them; its working O2 rack (it makes a
    relay a refuelling stop for air); the cold white light; whether stepping out of the airlock
    without a harness should leave you drifting (it does: nothing's in reach in the hatchway).
  - **The tether (proposed, GDD §17):** a reel on the harness, clipped at the airlock's hatch or a
    relay's anchor ring, paying out to about 50 m, stopping you softly at its end, and reeling you
    home free of propellant. Cheapest first step: a straight line you unclip to go deep into a
    relay. The full version wraps round corners inside (a thread back through the dark). Say
    whether to build it, and which.
  - **Creatures (2026-10-15):** how lethal the Crawler is (two blows; a grab from behind is the end;
    fleeing at a walk gets you caught, so turn or sprint); its speeds (0.7 ambling, 1.5 listening,
    3.4 hunting); how far each noise carries (a crouched step 1.5 m, a walk 6, a sprint 16, a door
    18); that it can't open doors at all; how long a prod stuns (5 s) and how many blows kill it
    (five crowbar); the Hanger's 3 s, its touch radius (0.5 m), whether a victim's own blow should
    free them (it does, for solo play), how high it draws them (feet 0.38 m off the deck) and the
    view looking up into it; how long it stays drawn up (6 s struck, 12 jolted, 25 fed).
  - **The creature and impact sounds are unheard:** synthesized and checked only as spectrograms
    (clicks, slaps, shriek, snarls, gurgles, the Hanger's creak and snap, clatters, the tool's
    strike, the zap, the flatline). Listen to each, and to their levels against the drone.
- **Upgrades and costs (later):** with the economy, whether the Med Bay needs its upgrade, and what
  a revive and a clone cost (a revive cheaper).
  - The chart table's hologram: its size and height over the table, how readable its marks are
    from across the bridge, how often it drops out.
- **What Survey Data and salvage's scrap are for (GDD §7).** This can wait until after the slice.
- **To judge in play (2026-10-15), M4:**
  - Prize event odds (sector 1: nothing 40%, each event 15%; the quiet thins 8% a sector).
  - Security: 75 s of lockdown; sentries 14 m reach, 0.9 s to lock on, bursts of three at 0.1 of
    health each with 1.1 s between; a crowbar forces a door in 5 s; three blows or one jolt
    knock a sentry out. Is it fair to be caught in the Prize room by one?
  - Depressurization: 3 s of warning, a 10 s gale (2.6 m/s at the hole, reaching 10 m), 6 s of O2
    a second stripped at its height, BLOWN OUT within 1.2 m of the hole. The cradle stands in
    front of the hole, which catches whoever's dragged there.
  - Structural breach: four falls 1.7 s apart (1.3 s of dust first), 0.6 of health under one, the
    heap's 1.8 s of warning and certain death under it; shaking.
  - Infestation: 2.6 s of swelling; the hatchling hunts the carrier at once.
  - Hazards: a spill's jolt (0.3 every 0.6 s), a leaking core's dose (about a minute and a half
    beside it to a full dose, a few minutes across the room), a faulty door's cycle (open 2.4 s, lurch, 0.7 s,
    slam at three times a door's speed, 0.5 of health in the doorway, shut 1.8 s); half of drive
    cores leak, about two thirds of derelicts have a spill, half a faulty door.
  - The survey core: one a system, next row only; reading takes the old scan's 8 s. Data cores
    21–39 Survey Data each.
  - Following aboard: a Crawler heard within 8 s follows; it beats on a shut outer hatch for 5 s.
    Should the airlock's inner hatch also stop it, as a door does?
  - The suit: wear 0.7 of each blow, a breach at 0.3 or under 35%, sealant back to 60%.
- **The beam in the air:** teammates' beams show everywhere, faintly. GDD §14 says haze makes beams
  visible in derelicts. It could be made stronger there and fainter aboard the station.

## Known issues and polish

- **Placeholders to replace (2026-10-15):**
  - **Photo scans:** ambientCG couldn't be reached from the session, so every model built this
    session baked over procedural stand-ins for its scans (`mats._stand_in`: Concrete034,
    Metal009, Metal021, PaintedMetal013; `build.py` prints them as `stand_ins`). Fetch the scans
    (`tools/fetch_textures.sh`) and rebuild these: `it_survey_core`, `rm_core_reader`,
    `dk_core_cradle`, `dk_breaker`, `dk_lock_panel`, `dk_sentry`, `dk_beacon`, `dk_wall_blowout`,
    `dk_nest`, `dk_heap`, `dk_puddle`:
    `xvfb-run -a /opt/bpyenv/bin/python art/blender/build.py -- <names>`.
  - **Sounds** (left for the audio redo): the Prize events' and hazards' cues are stand-ins
    pitched from other sounds (`Sound.event`: a sentry waking, locking on, firing, struck, down;
    groan, creak, fall, collapse, blowout, a nest stirring and bursting, a spill arcing and
    jolting); so are the breaker's switch (the cell's seating), the alarm (the undock siren, again
    and again), prying (a tool's strike, low) and the Geiger's click. The radio has no voice.
- **M4, first take (2026-10-15):**
  - A Crawler following the crew aboard is moved under the LANTERN on every peer at once; that's
    untested with a client (netfox's synchronizer across a reparent). Sentries and a Prize event
    joined partway are caught up only roughly (the event's steps replay at once).
  - Sentries are lit only by their own red beam and eye: in a dark section they're hard to read
    until they wake. The beam might want a little fill.
  - The gale has no sound of its own beyond the blowout; spills' arcs are subtle at 270 lines.
  - A heap drops through the ceiling's light fixture if one's above it.

- **The collar tube is 1,328 triangles**, over the kit pieces' 50–400; it's a one-off, closer to the
  exterior's budget.
- **The dock panel's small stencils** don't survive the texel density; only COLLAR and EXT remain.

- **Room lights leak through walls:** the ceiling OmniLights are unshadowed, so the sealed med bay
  isn't dark. Fixes: shadows on a few key fixtures, or tighter ranges. In a satellite they reach
  through floors to the level above too (lit rooms everywhere, so it shows less).
- **EVA, first take:**
  - A relay's open hatch swings into its entry and covers part of the opening for a moment, as the
    LANTERN's do; the inside of the hull's collar ring reads black from up close (unlit).
  - The EVA harness is 532 triangles and its rack 1,850, over the props' 20–300.
  - You don't see your own harness in first person; teammates' jet puffs are plain pale cones.
  - A relay's loot knocked out of its hatch drifts off for good (cleared when the LANTERN leaves).
- **Creatures, first take:**
  - A teammate's prod always shows its charge lamps lit (only the holder's machine knows the
    charge).
  - The Crawler's body is a cylinder round its middle: its head and haunches can poke into a
    wall as it turns in a tight spot (not seen yet).
  - A crew member held by a Hanger hangs in the float pose; their suit isn't wrapped by the
    tendrils, which close round where a body would be.
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
- **Git:** Claude commits at each meaningful step on its working branch and pushes it and `main`
  at each major checkpoint, ending each message with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Networking:** keep it simple. Clients are trusted, the host applies their actions, and each
  crew member owns their own state.
- **Art:**
  - Every model is authored in Blender scripts (`art/blender/`) at final quality, never a
    placeholder.
  - Textures are CC0 scans from ambientCG.
  - The look is PSX with a little modern light (GDD §14).
- **Interface:** the suit's visor HUD (only what matters now) and its panel (`Tab`), grounded in
  what a suit would know (diegetic-first was rescinded, 2026-10-15).
- **Verify by eye in the real game** before calling anything done, using the tools below.

## How to build and check

- **Godot:** `/Applications/Godot.app/Contents/MacOS/Godot` (or `tools/godot.sh`). In a Linux
  cloud container: Godot's Linux build with `GODOT=` set, shots under `xvfb-run` with Mesa's
  software Vulkan (slow: use bursts), Blender as `bpy` 5.2.1 from PyPI (TECH §1). Launch a
  local crew with `tools/run.sh [clients] [host flags]` (e.g. `tools/run.sh 1 --satellite`).
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
  | `tools/test.sh [name]` | The headless tests: sector map rules, derelict and satellite layouts, determinism, audio, the smoke test. |
  | `--check-eva[=dir]`, `--tour=dir` | With `--satellite`: an EVA played through with the keys, saying how each step went; every room of the satellite shot four ways. |
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
  - **EVA:** the harness rack is on the suit room's aft wall, (-8.75, 0, 1.7) (stand at (-8.6, 0,
    0.6), `--look=180,-8`); the EVA airlock's cycle lever at (-13.6, 1.06, 1.6) (stand at
    (-12.6, 0, 1), `--look=120,-25`); out of its hatch is space, x < -14.6. A relay is alongside
    at a Relay node, or with `--satellite` at the departure; the host's log prints its plan and
    each room's middle in the world. (Run 7's: its hatch about (-40.9, -0.2, -8.8); the relay
    core at about (-51, 6.7, -10).) `--harness` starts wearing a harness; outside, `--at` floats
    you where it puts you. `--check-eva=<dir>` and `--tour=<dir>` (with `--satellite`) as above.

    **Creatures:** run 14256631's departure derelict (`--derelict`) has a Crawler waiting at
    (24, 0, 16) in a corridor (stand at (24, 0, 12.6), `--look=180,-14`) and a Hanger over (36, 0, 4)
    (stand under it to be caught; at (31, 0, 4), `--look=-90,12`, to see it). `--provoke=<s>`
    sets the Crawler hunting the nearest crew member, `--wound=<s>` strikes you,
    `--debug-creatures` logs each creature's state on every peer. Run 3 jumps from a Crawler to
    another Crawler (`--route --jump`, then dock).

    `--interact=<s>` holds interact on what's aimed at, so a shot can dock (`--interact=2.4` at the
    lever) or cycle the airlock (stand at (12.6, 0, 1), `--look=-120,-25`, `--interact=1`);
    `--interact-at=<s>` delays it (to take a body once it's fallen).
  - **Death:** `--die=<s>` kills the local crew member then; `--clone=<s>` has the host's med bay
    clone whoever's dead. The med bay is at (4, 0, 20); its pod at (4.2, 0, 20).

# DEEP SPACE — Game Design Document (working title)

*Draft 0.1 — 2026-10-14. Living document. It covers game design and look/feel only; implementation notes live in [`TECH.md`](TECH.md). Open questions and assumptions are collected in §17.*

---

## 1. Pitch

A 1–4 player co-op, first-person PSX horror roguelike. You are the last skeleton crew of **Deep Survey Station LANTERN**, a jump-capable station lightyears from a dying Earth. Chart a route across branching star maps (FTL / Slay the Spire), dock with derelicts and walk across dead moons to scavenge fuel, tools and upgrades, and survey worlds in search of one that can hold what's left of the species. The stations are dark. Something is living in them. You will die, often and horribly, and a bad death can end the run.

**References:** *Iron Lung*, *Signalis*, *Mouthwashing*, *Lethal Company* (co-op scavenging, the ship as safe haven), *Alien: Isolation* and *Dead Space* (diegetic UI, retro-futurist tech), *System Shock* (1994), *FTL* and *Slay the Spire* (route maps).

## 2. Design Pillars

1. **Light is life.** Darkness is the default state of every derelict. Light is a resource (batteries, flares, power), a tool (seeing hazards, reading rooms) and a lure (some things are drawn to it).
2. **Deliberate bodies.** Movement is slow and weighty, and every action commits you. Noise matters. Sprinting is a real decision because it burns oxygen and draws attention.
3. **Grounded information.** Most of what you know comes from the world: your suit, the station's screens, your friends' spine lights and voices. A minimal visor HUD fills the gaps. It shows only what a suit would plausibly tell you, and only when it matters.
4. **Brutal but legible.** Deaths are sudden and nasty, but always have a readable cause. Players should say "we shouldn't have opened that hatch," not "what killed me?"
5. **The route is the strategy.** Between encounters, the run is a resource puzzle: fuel, air, light, salvage, and how much risk the crew will take for a better path.

## 3. Setting & Fiction

- Earth sent survey waves outward through hyperspace over several decades. **Every wave went silent.** LANTERN is the last.
- The derelicts you find are mostly **the remains of earlier waves**: their stations, the mining colonies they founded, and the relay satellites they left behind. This is why human-built wrecks exist lightyears from home, and why all the tech shares one language. Deeper in, the structures stop being human.
- The aliens are what happened to those waves. Their biology should feel wet, wrong and only partly understood. Lore is found in data cores, terminal logs and audio recordings, never in cutscenes.
- **Tech aesthetic:** cassette futurism in the vein of the Nostromo. Chunky toggles, CRT terminals, stencilled labels, hazard stripes, cable runs and analogue gauges.

## 4. Core Loop

```
          ┌───────────────────────────── RUN ─────────────────────────────┐
          │  Sector 1 ──► Sector 2 ──► Sector 3 ──► Candidate World        │
          └────────────────────────────────────────────────────────────────┘
SECTOR:   Nav chart ─► pick next node ─► JUMP (spend fuel) ─► arrive in system
                                                                 │
SYSTEM:   long-range scan (oddity + next jumps) ─► survey planets ─► approach oddity
                                                                 │
ENCOUNTER: explore in the dark ─► find fuel / salvage / tools / data ─► survive
                                                                 │
          extract (everyone back aboard) ─► undock ─► spend salvage on upgrades ─► next node
```

- **Session target:** an encounter takes 8–15 minutes and a short node (event, refuel, depot) takes 1–3. A sector runs 35–50 minutes, and a full run is three sectors (about 2 hours). The host can save between jumps.

## 5. The Station: LANTERN

The home base is a jump-capable station on a single deck. It is warm, lit and humming, the one safe space, though something can still follow the crew aboard through an open hatch. Players spawn and respawn here, and every system the run depends on has a physical place on board.

**The bridge is the hub.** It sits at the centre of the deck and connects to almost every room:
- Its functions are split into **stations** around the room, like the bridge of the Enterprise.
- The larger rooms branch straight off the bridge.
- A **rear corridor** behind the bridge is lined with small rooms.

```
                        ░░░ forward viewport ░░░
               ┌────────────────────────────────────┐
               │   HELM                   SCIENCE   │
  Suit Room ───┤                                    ├─── Docking Port
  + EVA lock   │              BRIDGE                │     (starboard)
   (port)      │                                    │
   Workshop ───┤   OPS                ENGINEERING   ├─── Drive Room
               └─────────────────┬──────────────────┘
                                 │  rear corridor
                       cabin ────┼──── cabin
                       cabin ────┼──── cabin
                      stores ────┼──── Med Bay
```
*(Layout is indicative; final proportions come from blockout.)*

**Bridge stations:**

| Station | Function | Interfaces |
|---|---|---|
| **Helm** | Navigation and jumping | **Nav Chart** CRT (the sector chart, route selection); **Jump Lever** (hold to engage) |
| **Science** | Scanning | **Long-range scanner** (reveals this system's oddity and the next jumpable systems, §6); **Survey Console** (planet scans, §7) |
| **Ops** | Crew status and comms | **Vitals board** (each crew member's heartbeat, O2 and last-known location); station cameras; PA |
| **Engineering** | Power and drive status | Fuel and drive gauges; power distribution; breaker panel |

The forward viewport looks out onto the system.

**Rooms:**

| Room | Where | Function | Interfaces |
|---|---|---|---|
| **Suit Room / EVA Airlock** | Off the bridge (port) | Suit up, refill O2, go outside | Suit lockers, O2 refill rack, airlock cycle panel (pressure gauge, warning lights) |
| **Docking Port** | Off the bridge (starboard) | Docks with derelicts | Docking collar control lever, pressure-equalization gauge, hatch |
| **Drive Room** | Off the bridge | Fuel and jump drive | **Fuel cell slots** (physical cells are carried in and inserted); drive status gauges |
| **Workshop** | Off the bridge | Upgrades and crafting | **Recycler hopper** (drop salvage in, counter ticks up); **Fabricator** terminal |
| **Crew cabins** | Rear corridor | Spawn, lore, save point. One small cabin per crew member | Bunk, personal locker, log terminal |
| **Med Bay** | Rear corridor | Healing / revive (§11) | Offline at run start; shown dark behind glass until it's upgraded |
| **Stores** | Rear corridor | Spare supplies | Shelving for O2 canisters, lamp cells, sealant |

- **The jump procedure:**
  1. A route is selected at the Helm, a fuel cell is loaded in the Drive Room, and the outer hatches are sealed.
  2. Any player holds the Jump Lever for two seconds.
  3. The station shakes, the lights go red, and the viewport streaks into a hyperspace tunnel.
  4. 10–20 seconds later, the crew arrives somewhere new.

## 6. Navigation: Sectors & the Map

- **Structure:** each sector has 7 rows of nodes plus a boss row, with 2–4 nodes per row. Paths branch and merge without crossing, as in Slay the Spire.
- **Charting:**
  - The sector starts uncharted. Only its exit, the boss, is known.
  - The route is discovered jump by jump: on arrival, the crew runs the **long-range scan** from the Science station.
  - The scan identifies the **oddity** in this system and reveals the **next jumpable systems** with their node types. Signals show only as unidentified signals.
  - The Nav Chart keeps everything charted so far.
- **Fuel:** each jump costs one fuel cell. The run starts with 3 cells.
- **Stranding:** with no fuel the station is adrift. A "drift" event offers desperate options, such as re-entering a picked-over oddity or answering an unknown signal.

| Node | Weight | Description |
|---|---|---|
| **Derelict** | 30% | Dock with an abandoned station or ship and explore its interior |
| **Colony** | 15% | Moonwalk: a low-gravity EVA across a moonlet's surface to a mining outpost, then inside |
| **Relay** | 15% | Short zero-g EVA to a satellite or relay. Quick loot, high exposure |
| **Signal** | 15% | Unknown until arrival. Could be any encounter with a twist, a survivor, or a trap |
| **Anomaly** | 10% | FTL-style event resolved at a bridge terminal. Choices can trigger hazards or rewards |
| **Gas Giant** | 10% | Skim fuel (the "campfire" node). A risky storm event is possible |
| **Depot** | 5% | Automated cache from an earlier wave; spend salvage here |
| **Boss** | always last | Guardian encounter; clears the way to the next sector |

**Generation rules:**
- The first row is always a Derelict.
- Every path passes at least one Gas Giant or Depot before the boss.
- No more than two EVA nodes in a row.
- The Long-Range Scanner II upgrade scans two jumps ahead and identifies Signals.

**Systems:** every node is a star system made from a seed:
- Star type and colour, which set the skybox tint.
- 1–5 planets with traits: atmosphere, temperature, gravity, water, biosignatures.
- An optional asteroid field or debris.
- The oddity itself, visible through the viewport and identified by the long-range scan.

## 7. Survey

Every system has planets to scan from the Science station's **Survey Console**. A scan fills in that planet's trait readout (atmosphere, temperature, gravity, water, biosignatures) and yields **Survey Data**. **Data cores** recovered from derelicts yield more.

> **TODO: what Survey Data is used for.** It should tie into the goal of finding a habitable world. Candidates include unlocking information on the map and shaping the end of the run. Decide after the slice.

## 8. Encounters

### 8.1 Approach
- **Docking.** Station-type oddities with compatible ports are reached by docking:
  - The collar is extended from the Docking Port.
  - The derelict drifts into place, visible through the windows.
  - Pressures equalize and the hatch opens.
  - A sealed hatch needs a crowbar, a cutter or power to open.
- **EVA.**
  - The station holds position near the target.
  - Players cycle the EVA airlock and cross on foot (moonlets, at about 0.16 g) or by tether line and mag-boots (zero-g wrecks and relays).
  - Suit O2 is the clock.

### 8.2 Layouts
- Interiors are **procedurally assembled from hand-built rooms**, so every derelict is new but every room is authored.
- Each layout is built as follows:
  1. Grows a room graph out from the entry airlock.
  2. Adds a few loops.
  3. Places the **Prize** room far from the entry.
  4. Assigns **pressure zones** (vacuum or pressurized) and **power zones** (dead or live).
  5. Fills the layout from a budget: loot, hazards, lore, and a **very small** number of creatures (§8.3).
- Loot and hazard budgets scale with sector, node type and crew size. Creature counts stay low regardless.

### 8.3 Inside
- **Power.** Most derelicts are dead. Finding a breaker or carrying in a power cell restores a zone, which brings back:
  - lights, doors, lifts and terminals
  - gravity plating: dead zones are zero-g, so restoring power can drop floating debris and bodies
  - machinery, and sometimes whatever was asleep in the dark
- **Hard and lonely.**
  - A derelict holds very few living things: often one, sometimes none, rarely two.
  - Crew size scales loot and hazards, not creature count.
  - **Stillness is the baseline.** Derelicts are dead and quiet, so anything that moves is a shock.
  - Ambient movement (a body drifting in zero-g, a door cycling on a dying circuit) is used sparingly, so it stays unsettling.
  - Noise and light draw the creatures that are already there. They never summon more.
- **The Prize.** A big, two-handed objective worth carrying out: a jump core (2+ fuel), a cryo pod or an intact module.
  - Taking it **may** trigger an event, but often nothing happens.
  - The quiet is part of the design: it keeps the tension up and gives the crew real relief.
  - The odds depend on the oddity type and the sector.

  | Prize event | What happens |
  |---|---|
  | **Nothing** | The quiet holds. Common, and it should be |
  | **Security system** | The derelict's automated security wakes. Bulkheads lock down sections, alarms sound (and draw anything listening), and sentry systems come online. The crew needs an override, a cutter, or another way out |
  | **Depressurization** | The Prize was part of a seal. Sections start venting, pressure doors slam, and O2 drains on the way out |
  | **Structural breach** | The structure gives way. Corridors buckle, a section tears loose, and the route back changes |
  | **Infestation** | Something was nesting in or near it, and now it's awake. One creature, not a horde |
- **Extraction.** The crew undocks from the Docking Port once everyone is aboard and the hatch is sealed, and the Vitals board shows who is still outside. The undock lever sounds a siren for a short countdown first. **Anyone left behind is lost.**

## 9. The Player

### 9.1 Movement (deliberate, weighty)

| | Speed | Notes |
|---|---|---|
| Walk | ~2.2 m/s | Quiet |
| Sprint | ~4.0 m/s | Triples O2 use, loud, short stamina |
| Crouch | ~1.2 m/s | Near-silent; fits under vents and low pipes |
| Carry (heavy) | ~1.6 m/s | Two-handed, so no sprinting and nothing from the belt |

- **Jumps and mantling:** jumps are short. Mantling handles crates and ledges.
- **Gravity and inertia:**
  - Gravity changes by zone: 1 g on the station, 0 g in a dead derelict, about 0.16 g on moonlets.
  - Mag-boots attach to surfaces in zero-g.
  - The body has inertia (acceleration ramps, slight head bob and sway).
  - **Mouse look is never smoothed or capped**, for comfort.

### 9.2 Suit
- **Health:** shown as the wrist ECG and heartbeat audio. It does not regenerate, and heals only at the Med Bay or with stims.
- **O2:**
  - About 6 minutes in vacuum at base capacity.
  - Drains only in unpressurized zones, and faster when sprinting or when the suit is breached.
  - Refilled at O2 racks on the station or on derelicts, or from canisters.
- **Integrity:** damage can breach the suit, which leaks O2 (audible hiss, frost on the visor) until it is patched with sealant.

### 9.3 Light
- **Helmet lamp:** the main light, on every suit from the start. `F` turns it on and off.
  - It sits on the left of the helmet and points where you look, so both hands stay free: the crew can carry a fuel cell or the Prize and still see.
  - It's offset from the eye, so the shadows it casts are visible.
  - Its battery runs about 6 minutes of continuous use per cell. It flickers when low, and spare cells are loot.
- **Flares:** thrown light that burns for about 60 s, hisses and draws attention.

### 9.4 Inventory
- **Belt:** 4 slots that hold anything small, gear and loot alike: tools, weapons, salvage, O2 canisters, data cores, cartridges. This works as in *Lethal Company*: every slot your kit fills is one you can't fill with loot on the way back.
  - `1–4` or the wheel draws one into the hand.
  - `E` takes a small thing into the slot in hand if it's empty, otherwise into the first empty slot, and draws it.
  - With all four slots full, there's no room until something is dropped.
- **Hands:** the item drawn from the belt, or one large two-handed carry (a fuel cell, the Prize, a body).
  - A carry takes both hands. The belt keeps its items, but nothing can be drawn from it, and the cuff can't be raised, until the carry is set down.
  - Heavy carries slow you down and stop you sprinting. The helmet lamp keeps shining.
- **Drop and throw:** `Q` sets down what's in your hands. Hold `Q` to throw it: the longer you hold, the farther it goes. A heavy carry only goes a short way. Dropped and thrown things make noise.
- **Starting kit (Tier 0):** the helmet lamp on the suit, and a crowbar, shock prod and flares on the belt, which leaves one slot free (see A9).
- **Everyone can see it:** what's in each crew member's hands, their lamp's beam, and when they raise their cuff.
- **On death:** everything drops on the body.

### 9.5 Controls (KB+M first)
`WASD` move · mouse look · `Shift` sprint · `Ctrl` crouch · `Space` jump/mantle · `E` interact/pick up · `F` helmet lamp · `LMB` use · `RMB` alt-use/aim · `Q` drop (hold to throw) · `1–4`/wheel belt slots · `Tab` raise wrist cuff.

## 10. Interface: Diegetic First, Minimal HUD

Most information lives in the world. A small **visor HUD** fills the gaps, and it stays grounded:
- **Few elements, mostly hidden.** An element appears when it matters (O2 in vacuum or when low, integrity after a hit) and fades out afterwards.
- **It's on the glass.** Readouts are low-resolution, single-colour and sit at the visor's edges with a slight curve, as if projected onto the helmet.
- **It breaks with the suit.** Readouts flicker when the suit is damaged and distort behind visor cracks.
- **It only knows what a suit would know.** No enemy markers, minimap, objective markers or teammate outlines through walls.

| Info | In the world | On the visor HUD |
|---|---|---|
| Health | **Wrist cuff** ECG (left forearm; `Tab` raises it to read), heartbeat audio | A warning when vitals are critical |
| O2 and suit integrity | Wrist cuff; hiss and visor frost on a breach | Small gauges in vacuum, when low, or after damage |
| Held item and belt | The item in your hands; the cuff lists the belt | The belt in the lower right: four slots with icons, the one in hand raised and named. Bright when it changes, then dim |
| Interaction | — | A small centre dot, and the one-word verb ("OPEN", "TAKE") in a bordered box that floats beside the thing, tied to it by a jointed leader line that fades toward it |
| Damage | **Visor:** cracks, frost and condensation when O2 is low, a blood spatter | Readouts flicker and distort |
| Your stress | Breathing and heartbeat audio, tied to vitals and threat proximity | — |
| Other players' state | **Spine lights** on each suit (Dead Space-style) visible from behind; the item in their hand and their beam; their cuff's screen lighting up as they raise it to read; their breathing on the radio; the station's Vitals board | — |
| Helmet lamp battery | The wrist cuff, plus the lamp's flicker when low | — |
| Tool and weapon state | Each tool's own screen or indicator (scanner CRT, motion tracker, charge LEDs) | — |
| Map, route, fuel, salvage | The station's terminals and gauges (§5) | — |
| Objectives | None explicit. Nav Chart info, plus PA announcements from the station's computer, "KEEPER" | — |
| Menus | The title screen is a CRT terminal boot | Pause and settings are flat screens, styled to match |

**Terminal interaction:**
- Pressing `E` on a terminal eases the camera in until the screen fills the view, so text stays readable at 270 lines. The cursor is drawn inside the screen itself.
- `Esc` or stepping back exits.
- Teammates see the same screen contents and the operator's cursor, so they can watch over your shoulder.
- Screens use chunky bitmap fonts with a light CRT look (scanlines, slight curvature, phosphor glow).

## 11. Hazards & Death

Death is frequent and specific.

| Hazard | Death | Counter-play |
|---|---|---|
| Creatures | Grabs, lunges, executions (§12) | Light, sound discipline, doors, teamwork |
| Vacuum | Helmet breach, cycling the airlock with someone inside, a blown hatch | Read the pressure lights, patch the suit, communicate |
| O2 depletion | Suffocation (slow, audible, with a dimming visor) | Route planning, canisters |
| Decompression | Sucked out through a breach when someone opens the wrong door | Check pressure gauges before opening doors |
| Electrical | Live cables in coolant puddles | Light the floor; cut power first |
| Crush | Faulty blast doors, lifts, the docking collar | Watch the warning strobes |
| Radiation | Reactor rooms (a clicking Geiger tool) | Limit exposure |
| Falls | Shafts, lift wells (and low gravity makes jumps tempting) | Look before jumping |
| Fire / explosions | Gas leaks plus sparks or tools | Flares and cutters near leaks are a bad idea |
| Friendly fire | Weapons, flares, slamming hatches | On by default (§17) |
| Left behind | Undock or jump with someone outside | The Vitals board and the undock siren |

**What happens when you die:**
- Your body stays where it fell, and your camera moves to **LANTERN's systems**. From there you can:
  - cycle through station cameras and teammates' body cams
  - speak over the PA
  - read the Vitals board
  - operate station doors and airlocks
- Crewmates can carry your body or your **biotag** back to the Med Bay (once it's upgraded) and **revive you for salvage**.
- The run ends when no living crew remains, the station is destroyed, or the crew is permanently stranded.

## 12. Creatures

**Few and singular.** Each creature is a presence the crew has to think about for the whole encounter, never part of a wave (§8.3). It should be rare to see one, and frightening when you do.

**Vertical slice:**
- **Crawler** *(the sound hunter)*:
  - An elongated, eyeless thing that moves on all fours. It may once have been crew.
  - Hunts by sound: sprinting, dropped items, doors, tools.
  - Its states are wander → investigate → hunt → lunge. Two hits kill, and a grab from behind is an instant execution.
  - It ignores lamp beams. A hissing flare can lure it.
  - It can be stunned with a shock prod, cut down slowly with the plasma cutter, or crushed in a door or airlock. Reinforces the "move intentionally" pillar.
- **Hanger** *(the ceiling trap)*:
  - Hangs in dark rooms with long, translucent tendrils that are only visible under a lamp beam.
  - Touching a tendril yanks you up. You die within about 3 s unless a teammate hits it.
  - Teaches players to use the light and look up.

**Roster ideas (post-slice):**
- **Moth:** drawn to light, so you go dark to survive (the reverse of the usual rule).
- **Mimic:** wears a dead crew member's suit lights. The wrist cuff's crew pings don't match.
- **Husk:** a corpse that isn't one. It rises when a zone's power returns.
- **Drifter:** a zero-g predator in debris fields, and the only real threat outside.

**Sector 1 boss: "The Warden".**
- A huge creature fused into the flagship of the previous survey wave. Tools can't kill it.
- The arena is the flagship's ring corridor. To retrieve the **Nav Key** needed to jump to Sector 2, the crew must:
  1. Route power to the cargo airlock.
  2. Lure the Warden inside.
  3. **Vent it into space.**
- For the slice, this is a greybox node and a written design only.

**Creature presentation:**
- Wet, fleshy, bone-white bodies with faint bioluminescent sacs, so a creature is sometimes visible in the dark and that glimpse is a warning.
- Animation runs at about 12 fps, stepped.

## 13. Items, Tools & Upgrades

**Resources:**
- **Fuel cells:** heavy, physical, carried by hand.
- **Salvage:** fed into the recycler hopper; this is the currency.
- **Survey Data:** from scans and data cores.
- **Energy cartridges:** the one ammo type for every weapon. They are rare in levels, and the Fabricator can print them only at a steep salvage cost, so every shot is a trade against upgrades.

**Weapons: from improvised to heavy.** A run starts avoidance-first. Weapons are **found, not fabricated**, and get bigger, more complex and more damaging as the run goes deeper:

| Tier | Where it turns up | Weapons | Character |
|---|---|---|---|
| **0: Improvised** | Starting kit | Crowbar, shock prod (recharges at the station), flares | Stun, deter and buy time. Killing even a Crawler is a messy, risky fight |
| **1: Industrial** | Sector 1 | Plasma cutter (mining tool: precise, slow, also cuts hatches), rivet driver (single heavy bolts, loud) | One-handed tools pressed into service. A Crawler dies to a few good hits |
| **2: Security** | Sector 2 | Pulse carbine (standard security issue from the earlier waves), arc projector (chains between targets, including teammates) | Two-handed and loud |
| **3: Heavy / exotic** | Sector 3 | Mass driver, incinerator, a weapon grown from alien tissue | Heavy, slow to ready and devastating; they drain cartridges fast |

- **Bigger weapons cost more:**
  - **Charge:** each cartridge holds a fixed charge, and heavier weapons drain more per shot.
  - **Weight:** heavy weapons slow you down and block sprinting.
  - **Noise:** they draw anything listening.
  - **Handling:** they add charge-up, overheating, and a manual cartridge swap that leaves you exposed.
- **Where to find them:** Prize rooms, armouries, Depots, and the bodies of earlier waves' security crew.
- **Charge readout:** each weapon shows its remaining charge on the weapon itself (LEDs or a needle).
- **On death:** weapons drop with everything else, so losing an armed crew member means sending someone to recover the gun.
- **Bosses:** the Warden-class bosses stay unkillable by weapons. Weapons buy time; the environment wins the fight.

**Tools (found or fabricated):**

| Tool | Use |
|---|---|
| Lamp cell | Recharges the helmet lamp |
| Sealant patch | Fixes a suit breach |
| O2 canister | Refills suit O2 |
| Power cell | Powers a derelict zone |
| Motion tracker | Shows movement on a small CRT; it pings, and the pings are audible to creatures |
| Survey scanner | Highlights loot, hazards and lore within a room |
| Tether gun | Zero-g traversal; can pull a teammate back |

**Station upgrades** (Fabricator, paid in salvage):
- **O2 Capacity I/II**
- **Long-Range Scanner II:** scans two jumps ahead and identifies Signals
- **Docking Clamp II:** docks with more oddity types
- **Med Bay / Clone Vat:** enables revive
- **Drive Efficiency:** occasional free jumps
- **Airlock Turret:** stops anything following the crew aboard while docked

## 14. Art Direction

**Quality bar.** The PSX limits are a style, not an excuse. Every model in the slice is final, not a placeholder:
- **Silhouette:** strong and readable at 270 lines.
- **Detail:** purposeful, telling you what the thing is and what it's for (handles, vents, labels, wear where hands and boots go).
- **Textures:** carry the grime, scuffs, stencils and colour of the tech language. Nothing ships flat-shaded or untextured.
- **Consistency:** the station, derelicts, items and creatures read as one world.

**The PSX look:**

| Element | Rule |
|---|---|
| Resolution | The world is drawn at about 270 lines (roughly the PS1's 320 × 240), shown as big square pixels with no smoothing |
| Colour | 15-bit colour with a 4×4 ordered dither; players can turn the dither off |
| Wobble | Geometry snaps to whole pixels, so objects jitter as they move |
| Textures | Unfiltered: 64×64 or 128×128 with ≤16–32 colours each. Perspective-correct: the PS1's affine swim tore the big wall and floor triangles, so it's off (a setting can bring it back) |
| Poly budgets (triangles) | Characters 600–1,200 · creatures 400–900 · view-model tools 150–400 · props 20–300 · kit pieces 50–400 · LANTERN exterior 2–4k |
| Bodies | Characters and creatures are built from **segmented rigid parts** that don't stretch or bend at the joints, PSX style |
| Animation | Creatures move at 12 fps, stepped. The crew's motion is smooth so feet stay planted as they walk, and it blends between standing, walking, running and crouching |
| A little modern light (PSX+) | Light bounces: lit surfaces, a lamp's spot most of all, light their neighbours a little, and glossy surfaces and glass show screen-space reflections. Shadows are plain. Still no motion blur, little or no bloom, and no ambient occlusion beyond the baked vertex AO |

**Lighting (the main atmospheric tool):**
- **LANTERN:** warm sodium-amber practicals, off-white panels, CRT green and amber screens. It reads as home.
- **Derelicts:** ambient light near black with a slight blue tint. At most 1–2 broken, flickering practicals per room, with red emergency strobes and rotating beacons. The helmet lamp carries the scene.
- **Helmet lamp:** casts hard shadows, and a dirty-lens pattern shows in the beam. The beam is your whole view of a room, so what it reveals and what it leaves in shadow are the main horror tools.
- **Fog:** closes in early, as on the PSX. A light haze in derelicts makes lamp beams visible. This is a deliberate anachronism, to be judged in look-dev.

**Space:**
- A starfield and nebula sky, dithered and tinted by the star type.
- The local star, glaring.
- Low-poly planets with banded PSX textures and a thin atmosphere rim.
- A streaking hyperspace tunnel for jumps.

**Palette:**
- **Station:** amber, cream, safety orange, CRT green.
- **Derelicts:** teal-grey, rust, and red emergency light.
- **Aliens:** bone, flesh pink, and bioluminescent cyan.

## 15. Audio Direction

- Low-fi sound: 22 kHz samples, short reverb tails, sparse droning music.
- **Vacuum rule:** in unpressurized zones, outside sound is heavily low-passed (you "hear" through contact). Your own breathing and the radio stay clear.
- The station hum is a comfort, and its absence is a warning.
- Creatures are mostly heard before they are seen: directional clicks, wet movement, distant impacts.
- The PA voice of the station computer, KEEPER, is dry and clipped.

## 16. Vertical Slice

**What a player experiences:** 1–4 players spawn aboard LANTERN in deep space and play one full loop:
1. Plot a route on the Nav Chart and jump.
2. Arrive in a new system, run the long-range scan, and survey a planet.
3. Dock with a derelict and explore it in the dark.
4. Recover fuel and salvage, facing the Crawler, the Hanger and environmental hazards. Die in specific ways and be revived.
5. Extract, load fuel, and jump on.

The whole Sector 1 map is generated and playable. The boss node exists as a greybox placeholder.

**Slice content:**

| Area | Content |
|---|---|
| **LANTERN** | **Bridge hub** with forward viewport and four stations: Helm (Nav Chart, Jump Lever), Science (long-range scanner, Survey Console), Ops (Vitals board, cameras, PA), Engineering (gauges, breakers). **Off the bridge:** Suit Room and EVA airlock, Docking Port and collar, Drive Room (drive, fuel slots), Workshop (recycler hopper, Fabricator). **Rear corridor:** crew cabins, stores, Med Bay (offline). Hull exterior visible from EVA |
| **Derelict** | The station's tech language, decayed: broken panels, debris, cable spills, blood and growth, emergency strobes, breaker boxes. 6–10 room types, plus a Prize room and an exterior hull |
| **Space** | Starfield and nebula skies, star types, a planet set, debris and asteroids, hyperspace tunnel |
| **Items** | Helmet lamp, fuel cell, salvage, O2 canister, power cell, data core, sealant patch; first-person arms |
| **Weapons** | Tier 0 (crowbar, shock prod, flares) and Tier 1 (plasma cutter, rivet driver); energy cartridges |
| **Characters** | Player suit (with spine lights), Crawler, Hanger |
| **Upgrades** | O2 Capacity I, Med Bay (if revive is gated behind it) |
| **Events** | Prize events (security system, depressurization, structural breach, infestation, or nothing); the Signal and Anomaly nodes use simple placeholder versions |

## 17. Open Questions & Working Assumptions

**Decided (2026-10-13):**
1. **First build pass: environment first.** LANTERN, space, and the models for the rest of the slice, then a review before the gameplay loop. The slice above stays the target; the build order is in [`TECH.md`](TECH.md) §9.
2. **Death: station link plus revive** (§11).
3. **Combat:** start avoidance-first with improvised weapons. Weapons are found as the run progresses, growing in complexity, size and damage, and all use scarce energy cartridges (§13).
4. **Voice and connection:** direct IP for now, with voice through Discord. There is no in-game voice in the slice.

**Decided (2026-10-14):**

5. **The light is a helmet lamp from the start** (was A8). Both hands stay free, so the crew can still see while carrying something two-handed. There is no Helmet Lamp upgrade, and no handheld flashlight.
6. **The belt holds loot as well as gear**, as in *Lethal Company* (§9.4). Two-handed carries stay out of the belt and take both hands.

**Working assumptions** (correct me if any are wrong):
- **A1.** LANTERN *is* the jump vessel. The station travels with you; there is no separate ship.
- **A2.** Run length: 3 sectors at roughly 35–50 minutes each, with saves between jumps.
- **A3.** Mid-run joining is allowed only aboard LANTERN between encounters.
- **A4.** Keyboard and mouse first; gamepad later.
- **A5.** Friendly fire is on.
- **A6.** Encounter interiors are procedurally assembled from hand-built rooms. Boss arenas are fully hand-built.
- **A7.** Difficulty scales with crew size. Solo must be viable.
- **A9.** The starting kit (crowbar, shock prod, flares) starts on the belt, so a crew member heads out with one free slot and drops gear to make room for more. (The alternative: the kit is racked in the Suit Room and each crew member chooses what to take.)

**TODO:**
- What Survey Data is used for (§7).

**Descoped for now:**
- Transit events (power failures, hull breaches or stowaways during jumps).

**Parked ideas:**
- **Cryo sleepers:** LANTERN carries thousands of colonists in cryo. Station damage costs sleepers, and the count is the run's score.
- **Two-person jump:** a jump that needs two people at once (solo: a timed sequence).
- In-game proximity voice, with radios as items for long range (deferred; Discord for now).
- A Mimic that spoofs crew pings.

# Deep Space: status and next steps

Last updated 2026-10-13. Read this with [docs/GDD.md](docs/GDD.md) (design, look and feel) and
[docs/TECH.md](docs/TECH.md) (how it's built). The target is the **vertical slice** in GDD §16;
the build order is TECH §9.

## Where we are

The **first build pass** ("environment first", TECH §9) is done, with three rounds of review on top:

- **Foundations (M0):** Godot 4.7.2, netfox 1.49.4 vendored (no rollback), the PSX pipeline
  (vertex snap with true depth, 270-line pixelation, 15-bit dither), the Blender build harness.
- **Crew, enough to walk the station together (part of M1):** the networked first-person controller
  (owner-authoritative), gaits blended in step with legs that turn toward travel, the belt (four
  slots, `1–4`/wheel, `F` for the flashlight), held items mirrored to everyone, the wrist cuff
  (`Tab`), the visor HUD (a floating prompt, the belt), terminals you step up to.
- **LANTERN and space (M2):** the station kit and every room furnished, the exterior hull, bridge
  stations with live terminal screens (nav, scan, survey, vitals, cams, power, status), seeded
  star systems with sky, star and planets, the lighting pass (SSIL/SSR, Godot's default shadows).
- **Models for the rest of the slice:** the derelict kit and a hand-placed sample derelict at the
  collar, the Crawler and the Hanger with clips, the suit and first-person arms, every slice item,
  Tier 0–1 weapons and energy cartridges.
- **Latest review fixes:**
  - teammates' flashlights show a beam in the air and glare when pointed at you; the glare hides
    behind whatever's drawn in front of the lens
  - the suit's hold poses are solved (torch level in front of the belly, tools low and ready)
  - the first-person left hand is relaxed when reading the cuff, and the cuff sits square on its
    forearm

The **gameplay loop doesn't exist yet**: no pickups, O2, jumps, docking, creature behaviour or
death. The consoles and cuff show placeholder numbers.

## Now (before the loop)

- [ ] **First-person tool grips.** The crowbar, shock prod and flare sit oddly in the
      first-person fist, as the suit's did. Give them the treatment the suit got: solve the
      view-model hold for where the grip goes and where the tool points, with natural wrist limits,
      and review each in first person (`--hold=<kind>`).

## Next: the gameplay loop (proposed order)

1. **Rest of M1, the crew:**
   - pick up (`E`), drop and throw (`Q`), with the carrier taking authority while holding
     (TECH §2)
   - two-handed carries (fuel cell, the Prize, a body) that slow you and take your hand light
   - use (`LMB`) for tools and weapons (the arms already have a swing clip)
   - suit O2 and pressure zones, driving the cuff, the Vitals board and the spine lights
   - needs decision A8 first (below)
2. **M3, navigation:**
   - sector map generation (all of Sector 1, the boss node a greybox)
   - the Nav Chart terminal and the Jump Lever
   - the jump sequence and hyperspace tunnel
   - long-range scan and progressive charting
   - the Survey Console
   - fuel economy: a cell per jump
   - star systems are already seeded (`StarSystem`); the screens exist as mock-ups
3. **M4, the derelict:**
   - docking
   - the room-module generator from the derelict kit: 6–10 room types, a Prize room, an
     exterior hull
   - power zones and breakers
   - loot: fuel, salvage, O2, power cells, data cores, sealant
   - the Prize and Prize events
   - hazards
   - Crawler AI (an eyeless sound hunter) and Hanger AI (a ceiling trap)
   - death in specific ways, spectating through the station's cameras, and revive
   - extraction
4. **Slice wrap-up:**
   - upgrades: Helmet Lamp, O2 Capacity I, Med Bay
   - the Workshop's recycler and Fabricator
   - Tier 1 weapons in use, with energy cartridges
   - placeholder Signal and Anomaly nodes
   - the EVA airlock and hull exterior
   - an audio pass
5. **Tests TECH §8 promises but that don't exist yet:**
   - headless generation determinism
   - sector map rules
   - a scene smoke test

   Write them alongside M3.

## Decisions needed

- **A8 (GDD §17): the flashlight hand.** Does the flashlight take the hand like any belt item, as
  now, or go in the off hand alongside a one-handed tool? Decide before carrying is built.
- **What Survey Data is for (GDD §7).** This can wait until after the slice.
- **The beam in the air:** teammates' beams show everywhere, faintly. GDD §14 says haze makes beams
  visible in derelicts. It could be made stronger there and fainter aboard the station.

## Known issues and polish

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
- **The torch beam shows 15-bit banding** up close. This is accepted as the PSX look.

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
  | The game with `-- --host --at=x,y,z --look=yaw,pitch [--hold=crowbar] [--cuff] [--flashlight] --screenshot=out.png --frames=150` | Your own first-person view. |
  | `tools/pair.sh out.png "<host flags>" "<client flags>"` | A teammate, seen by the host (`--view=x,y,z,yaw,pitch` in the host flags for a fixed camera). |
  | `tools/pose_sheet.py` | Clips from a built `.blend`, with `--hold`, `--focus`, `--lens` and `--size`. |
  | `tools/clip_angles.py` | A clip's bone turns. |
  | `tools/sheet.py` | Contact sheets and crisp crops. |
  | `--check-aim` | Checks every terminal can be used. |
- **Getting around:**
  - **Grid and directions:** a 4 m grid, with the bridge's centre at the origin. Fore is -Z,
    port is -X.
  - **Look direction:** `--look` yaw 0 faces fore (-Z), 90 faces port (-X), -90 starboard, 180 aft.
  - **The station:** open bridge floor at (-3, 0, 0.5); cabin 4 at (4.4, 0, 18.3). The station's
    doors start shut.
  - **The derelict:** its doors start open.

    | Area | Position |
    |---|---|
    | Entry | (16, 0, 0) |
    | Corridor | (20, 0, 0) to (20, 0, 4) |
    | L-shaped room | x 20–28, z -4 to 0 |
    | Prize room | (22, 0, 8.5) |

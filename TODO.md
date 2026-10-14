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
- **Models for the rest of the slice:** the derelict kit and a hand-placed sample derelict at the
  collar, the Crawler and the Hanger with clips, the suit and first-person arms, every slice item,
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
  port and the sample derelict are stocked.
- **Two-handed carries:** the fuel cell, held in both hands with solved poses; slow, no sprint, no
  belt or cuff until it's set down. One waits in the docking port, one in the derelict's Prize
  room.
- **Suit O2:** per-room zones with or without air (the sample derelict's breached rooms have
  none); O2 drains out of the air, faster sprinting, then health. It drives the cuff, the Vitals
  board, the spine lights and a visor O2 gauge; the suit room's O2 rack refills it.
- **Use (`LMB`):** tools swing (everyone sees it, and it knocks loose things about), an O2
  canister tops up the suit, a flare is struck and burns red for 60 s in the hand or thrown.

Still to come: jumps, docking, creature behaviour, death. The nav, scan, survey and power screens
show placeholder numbers.

## Next: the gameplay loop (proposed order)

1. **Rest of M1, the crew:**
   - the Prize and a body as two-handed carries (with M4; the fuel cell's done)
   - what a swing does to creatures and hatches (with M4), the shock prod's stun and charge,
     sealant (with suit integrity), weapons in use (slice wrap-up)
   - the helmet lamp's battery (6 minutes a cell, flicker when low, lamp cells as loot: needs a
     lamp cell model), suit integrity and breaches
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
   - upgrades: O2 Capacity I, Med Bay
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

- **A9 (GDD §17): where the starting kit starts.** On the belt (as now: crowbar, shock prod and
  flare, one slot free), or racked in the Suit Room so each crew member chooses what to take?
- **To judge in play (2026-10-14):**
  - A teammate's lamp glares whenever they look at you, so talking face to face is blinding.
    Realistic; it could be softened at close range.
  - Carrying in first person shows only the top of the fuel cell across the bottom of the view;
    the hands stay below the frame. Higher would show the hands but hide more of the view.
  - Numbers: 6 minutes of O2, 3 a canister, 20 s to suffocate, 1.6 m/s carrying, throws of 3–9
    m/s.
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

# Prototype implementation plan

A Godot prototype to validate the control model, movement rules, and core Striker/Shaper mechanics from [GAME_DESIGN.md](./GAME_DESIGN.md). It is a disposable rules testbed, not the final game: the final game is 3D in Unreal Engine, so invest in clear rules and debug tooling, not visuals.

The prototype serves two equal purposes:

- **Hands-on play** with a physical Xbox controller in an open-ended sandbox, to judge feel, speed of decisions, and readability.
- **Automated tests** that drive the same simulation headlessly, to verify the movement rules precisely.

## Scope

### In scope

- Hex grid map with blocked and cleared terrain; cleared tiles stay cleared.
- Core (seven hexes) with HP that enemies attack.
- Shapers: move, clear blocked terrain.
- Strikers: attack-move, Assault and Guard forms, automatic combat.
- Ground enemies that attack units and the Core, using passages the player opens.
- Control model and gamepad controls (one selected unit, one selected tile, no groups).
- Default action on A with preview, and explained rejection of invalid actions.
- Movement rules (sections 1-6 of [Movement](./GAME_DESIGN.md#movement)).
- Open-ended sandbox for hands-on play.
- First-playtest scenarios from [First playtest](./GAME_DESIGN.md#first-playtest), as automated tests and as loadable sandbox setups.
- A simple opposing-entry policy for section 3.2 (see [Opposing entry policy](#opposing-entry-policy)).

### Out of scope

- Fog of war: everything is visible; routes are planned on full terrain knowledge.
- Energy and training: each setup defines its starting units (three or four by default, up to eight). D-pad left/right stay unassigned.
- Win and loss conditions, end screens, and campaign structure. The sandbox never ends; it is reset instead.
- Emitters: no capture, conversion, shields, or strength scaling. Ground enemies come from scripted **spawn points** instead.
- Flying enemies and the air layer. Keep the layer concept in the occupancy data model so it can be added later, but implement only ground.
- Art, audio, menus, saving, mouse and touch input.

## Environment

- **Godot:** `D:\app\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64.exe` (editor) and `Godot_v4.7.2-stable_win64_console.exe` (headless runs and tests, prints to the terminal). This is the standard build, so use **GDScript**.
- **Native builds:** `D:\app\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat` sets up the MSVC x64 environment. Only needed if a GDExtension (C++, via godot-cpp and SCons) becomes necessary, for example for pathfinding performance. Run it and the build in the same `cmd.exe` process:

  ```powershell
  & $env:ComSpec /c 'call "D:\app\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul && cd /d D:\dev\src\rts1\prototype\native && scons platform=windows'
  ```

  Not expected for this scope; GDScript should be sufficient for eight units and a few dozen enemies.

- **Running:**

  ```powershell
  # Editor
  & "D:\app\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64.exe" --path D:\dev\src\rts1\prototype -e
  # Play
  & "D:\app\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64.exe" --path D:\dev\src\rts1\prototype
  # Headless tests
  & "D:\app\Godot_v4.7.2-stable\Godot_v4.7.2-stable_win64_console.exe" --headless --path D:\dev\src\rts1\prototype --script res://tests/run_tests.gd
  ```

## Architecture

**Simulation and presentation are separate.** This mirrors the design's "logic is discrete; motion is smooth" and keeps the rules portable to Unreal.

- **Simulation (`sim/`):** plain GDScript classes (`RefCounted`), no nodes, no rendering, no input. Advanced by a fixed tick (start at 20 ticks/s) from `_physics_process` or by tests directly. Deterministic: stable unit IDs, stable tile order, no randomness without a seeded RNG.
- **Presentation (`view/`):** `Node2D` scenes that read simulation state each frame and interpolate unit positions between hex centres using step progress.
- **Input (`input/`):** translates gamepad state into commands (`select_next`, `move_cursor(dir)`, `default_action`, `toggle_form`, ...) and sends them to the simulation. The simulation never reads input directly, so tests issue the same commands.
- **Tuning (`data/tuning.tres` or `tuning.json`):** speeds, HP, damage, ranges, cooldowns, form-change time, clear time, enemy spawn interval, opposing entry policy. All numbers are placeholders; the design defines none.
- **Setups (`scenarios/*.json`):** map size, terrain, Core position, starting units, enemy spawn points and spawn settings, camera start. The same files are loaded by the sandbox for play and by tests.

### Proposed layout

```text
prototype/
  project.godot
  sim/
    hex.gd            # axial coordinates, neighbours, distance, line, stable ordering
    grid.gd           # terrain, structure footprints
    occupancy.gd      # logical occupancy and stopping claims, per layer
    pathfinding.gd    # A* on known terrain
    unit.gd           # shared unit state: id, side, tile, step, claim, order, hp
    movement.gd       # step requests, claims, cancellation, return, transit rules
    striker.gd        # forms, attack-move, combat
    shaper.gd         # move, clear, pending work
    enemy.gd          # ground enemy behaviour
    combat.gd         # target selection, cooldowns, damage
    simulation.gd     # tick order, command handling, win/lose
  view/
    main.tscn         # root: camera, map, units, HUD
    map_view.gd
    unit_view.gd
    cursor_view.gd
    hud.gd            # action preview, rejection messages, form-change progress
    debug_overlay.gd  # occupancy, claims, routes, blocked reasons
  input/
    gamepad_input.gd
  data/
    tuning.json
  scenarios/
    sandbox.json
    shared_destination.json
    ...
  tests/
    run_tests.gd      # minimal headless runner; exits with non-zero code on failure
    test_hex.gd
    test_movement.gd
    ...
```

## Hex grid

- Pointy-top hexes with axial coordinates `(q, r)`, following the Red Blob Games hex grid guide.
- Stable tile order for tie-breaking: sort by `r`, then `q`.
- Core footprint: centre plus its six neighbours. Ground units cannot enter footprints.
- Map size targets about four viewports at a fixed zoom (roughly 2x2 screens at 1080p). The camera pans; zoom is fixed.

## Controls

The physical Xbox One controller (USB or Bluetooth) is the primary input. Godot supports it through its built-in joypad support and SDL controller mappings, so no extra plugin is needed. Define actions in the Input Map:

| Action | Binding | Behaviour |
| --- | --- | --- |
| `unit_prev` / `unit_next` | LB / RB | Cycle living units in stable order, wrapping; preserve tile and camera. |
| `cursor_*` | Left stick | Step the selected tile in one of six hex directions. Deadzone, angle snapped to six sectors, initial delay then repeat rate (both in tuning). |
| `camera_pan` | Right stick | Pan the camera continuously, clamped to the map. |
| `default_action` | A | Execute the selected unit's default action on the selected tile. |
| `cancel` | B | Cancel an open interaction; does not stop units or clear selection. Little to cancel in this scope; keep the binding. |
| `ability` | X | Striker: change form. |
| `pause` | Menu | Pause the simulation. |

- Y and the D-pad remain unassigned for gameplay.
- Keyboard fallback bindings for development only (not a design target).
- Highlight the selected unit and tile clearly; show an offscreen indicator pointing to the selected unit.
- The cursor should optionally follow the camera edge so it never leaves the screen (tune during play).
- Show a small controller status indicator (connected device name, or "no controller") and handle connect/disconnect while running via `Input.joy_connection_changed`.
- Read stick and button state through Input Map actions only, so dead zones and bindings can be changed in one place.
- Verify early (milestone 2) on the actual controller: button mapping, stick directions, dead zones, and cursor repeat feel.

## Sandbox

The sandbox is the main play mode: open-ended, no win or loss, always resettable.

- Starts from a setup file (default `scenarios/sandbox.json`): a small clearing around the Core, blocked terrain around it, and enemy spawn pockets behind the terrain.
- Enemies spawn continuously from spawn points at a configurable interval while spawning is enabled.
- When the Core reaches zero HP, show "Core destroyed" and keep the simulation paused until reset; nothing else ends the session.
- Sandbox commands, on the keyboard so the gamepad stays reserved for the design's controls:

| Key | Command |
| --- | --- |
| F1 | Toggle debug overlay. |
| F2 | Toggle enemy spawning. |
| F3 | Spawn one enemy at the nearest spawn point to the cursor. |
| F4 | Toggle Core and player-unit invulnerability. |
| F5 | Reset the current setup. |
| F6 | Cycle to the next setup file (including the playtest scenarios). |
| Space | Pause/resume (also Menu on the gamepad). |
| Period | Advance one tick while paused. |
| `-` / `+` | Slow down / speed up simulation time (0.25x to 4x). |

## Default action

| Unit | Selected tile | Action |
| --- | --- | --- |
| Striker | Any reachable tile | Attack-move. |
| Shaper | Cleared ground | Move. |
| Shaper | Blocked terrain | Clear (from a valid adjacent work position). |

- Preview the action (icon/text and planned route) before A is pressed.
- Invalid or unreachable: show the reason, keep the existing order. Never substitute another action.
- Selecting a tile with an enemy does not turn attack-move into pursuit.

## Movement rules

Implement [Movement](./GAME_DESIGN.md#movement) literally; it is the riskiest part and the main reason for the prototype.

- **Per unit:** logical tile, optional in-progress step (`from`, `to`, progress, `returning` flag), optional stopping claim, order (target, kind), pending target state (`moving`, `holding`, `blocked`).
- **Occupancy per layer** (only ground used): settled occupants, stopping claims, and entering steps by side.
- **Step request checks**, immediately before each step starts:
  - Not into terrain or structure footprints.
  - Not into a tile an enemy occupies or is entering (section 3.1).
  - A final step requires a free stopping claim, granted atomically with the step (section 2.1).
  - Entering a friendly-occupied stretch requires a known route to a free stopping position (section 6.2).
- **Alternative stopping tile** (section 2.2): free reachable tile minimising walking distance to the target, then route length from the current tile, then stable tile order. Show the chosen destination.
- **Simultaneous friendly claims** (section 2.3): resolve in stable unit-ID order within a tick; losers choose alternatives.
- **Enemy cut-off** (section 3.1): settle at the nearest free reachable tile, keep the target, show it as blocked by an enemy, retry each tick.
- **Opposing entry** (section 3.2): see [Opposing entry policy](#opposing-entry-policy).
- **Logical position** (section 4): occupancy transfers on arrival; combat uses logical positions; death removes unit, claims and step immediately.
- **Cancellation and return** (section 5): accept orders immediately; continue if the new route starts with the current step, otherwise return to the source at normal speed with occupancy kept at the source; release stopping claims immediately; orders during return replace the pending order only.
- **Transit** (section 6): a unit not on its claimed stopping tile cannot attack, work, or change form, but can be attacked.
- Form changes cannot be cancelled; movement orders received during one run after it finishes.

### Opposing entry policy

A simple first policy for section 3.2, to refine if play shows problems.

**First come, first served; ties go to the player.**

1. Step requests are evaluated once per tick, at the start of the tick.
2. A request into a tile that an enemy already occupies or is entering is denied (section 3.1). This alone resolves every conflict where the requests happen in different ticks: the earlier step wins.
3. If player and enemy units request the same tile in the same tick, the player's request is granted and the enemy's is denied.
4. Between friendlies of the same side, existing rules apply: pass-through is compatible, and stopping claims resolve by stable unit ID (section 2.3).
5. A denied unit follows section 3.1: it keeps its target, settles at the nearest free reachable tile if necessary, and retries next tick. A Striker fights from there.

Why this policy: it is deterministic and easy to reason about in tests and while playing, and favouring the player makes the defender's positioning predictable, which suits the design goal that failures should be understandable.

What to watch for in play:

- Enemies that never get through a contested gap because the player always wins ties (unintended invulnerable chokepoints).
- Units on both sides waiting for each other next to the same tile without anyone moving (livelock).
- Whether ties are common enough to matter at all; log how often rule 3 triggers in the debug overlay.

Implement the policy behind a single function with a tuning switch (`opposing_entry_policy`), so alternatives can be tried without touching the movement code. Candidates if needed: enemy wins ties; alternate the winner per tile; the unit that has waited longest wins.

## Units

### Striker

- Assault: faster, lower HP, shorter range and sight.
- Guard: slower, higher HP, longer range.
- X starts the form change (several seconds, in tuning). Show progress.
- Attack-move: hold when a visible enemy is in range or the route is cut; continue when clear; never leave the route to pursue. Settled Strikers fight automatically.

### Shaper

- Cannot fight.
- Clear: move to a free valid adjacent work position (section 2.4), then clear over time. If no work position is free, hold at the nearest free reachable tile and keep the work pending.
- Finishes assigned work unattended.

### Ground enemy

- Spawns from spawn points in pockets of cleared terrain that are initially disconnected from the player's area. The sandbox spawns continuously (see [Sandbox](#sandbox)); tests spawn enemies explicitly.
- Targets: nearest player unit or the Core reachable over cleared terrain; attacks what blocks its way (a Guard plugging a gap gets fought, not bypassed).
- Uses the same movement rules as player units, from the other side.
- Simple behaviour is fine; the point is to put pressure on routes and test enemy blocking.

### Core

- Seven-hex structure with HP. Reaching zero HP pauses the sandbox until reset. No training or income in this scope.

## Combat

- Range counted in hexes between logical positions.
- Automatic target selection: nearest enemy in range, ties by stable ID.
- Attack cooldowns per unit; movement can cancel an attack before firing (forfeit) or interrupt its animation after firing without resetting the cooldown.
- Simple line or flash for shots; HP bars.

## Debug tooling

All on the keyboard (see [Sandbox](#sandbox) for keys), so the gamepad stays reserved for the design's controls:

- Occupancy and stopping claims per tile, coloured by owner.
- Planned routes and chosen alternative destinations.
- Unit state labels: order, step, holding/blocked reason, transit.
- Count of opposing-entry ties resolved by the policy.
- Tick stepping, time scale, reset, and setup switching.

## Tests

Use a minimal headless test runner (`tests/run_tests.gd`, extends `SceneTree`) that instantiates the simulation from a setup file, issues commands, advances ticks, and asserts state. Exit with a non-zero code on failure. GUT can replace it later if it becomes useful.

Tests and hands-on play share everything below the input layer: the same setup files, the same commands, the same simulation. Each test setup can also be loaded in the sandbox (F6) to reproduce a test situation by hand with the controller.

Cover at least the scenarios from [First playtest](./GAME_DESIGN.md#first-playtest):

- Shared and crowded destinations, including a nearer unit ordered after a distant one.
- Friendly crossings from different directions and passage through stationary Guards.
- A blocked unit overlapping a friendly, including loss of every reachable stopping position.
- Opposing entry requests (including the tie policy) and interrupted movement toward a work position.
- Mid-step reversal and retargeting: claim release, logical occupancy, return time, and repeated cancellation without speed or attack-rate gains.

Plus unit tests for hex maths, pathfinding, and alternative-destination selection.

## Milestones

1. **Project skeleton:** Godot project, fixed-tick simulation loop, setup loading, hex maths with tests.
2. **Map and controls:** render hexes, Core, units; camera pan; hex cursor on left stick; LB/RB cycling; selection highlights and offscreen indicator; controller status. Check on the physical Xbox controller.
3. **Basic movement:** pathfinding, step-by-step movement with smooth interpolation, A to move, action preview and rejection messages. First hands-on session.
4. **Full movement rules:** stopping claims, alternatives, friendly passage, transit, cancellation and return; debug overlay; movement tests.
5. **Shaper clearing:** clear order, work positions, pending work.
6. **Strikers and enemies:** forms, combat, attack-move holding, ground enemy spawning, enemy blocking, opposing entry policy; Core HP.
7. **Sandbox and playtest setups:** sandbox commands, one setup per playtest item; tune numbers by playing with the controller; record findings against [GAME_DESIGN.md](./GAME_DESIGN.md).

Milestones 1-3 give a playable controller test early; milestone 4 is the core of the prototype.

## Open decisions

- **Opposing entry policy:** start with [the simple policy](#opposing-entry-policy); replace it if play shows problems.
- **All numeric values:** placeholders in tuning, adjusted during play.

## Carrying results to Unreal

- The validated rules, edge cases, test scenarios, and tuning values transfer; code does not.
- Keep findings in the design document, not only in code.
- Still to test later in Unreal: readability of hexes and units under a 3D camera, cursor visibility over terrain, and fixed-zoom feel on a TV.

# Rules prototype

A Godot 4.7.2 (GDScript) prototype of the rules in [GAME_DESIGN.md](../GAME_DESIGN.md), built to [PROTOTYPE_PLAN.md](../PROTOTYPE_PLAN.md). Hexes, a Core, Shapers clearing terrain, Strikers with Assault and Guard forms, ground enemies, and the movement rules from sections 1-6, played with a gamepad in a sandbox.

## Running

```powershell
$godot = "D:\app\Godot_v4.7.2-stable"
# Play
& "$godot\Godot_v4.7.2-stable_win64.exe" --path D:\dev\src\rts1\prototype
# Editor
& "$godot\Godot_v4.7.2-stable_win64.exe" --path D:\dev\src\rts1\prototype -e
# Headless rules tests (exit code 1 on failure); optional filter matches "file::test"
& "$godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path D:\dev\src\rts1\prototype --script res://tests/run_tests.gd -- [filter]
# Windowed smoke test of the presentation; optional screenshot directory
& "$godot\Godot_v4.7.2-stable_win64_console.exe" --path D:\dev\src\rts1\prototype --script res://tests/smoke_view.gd -- [screenshot_dir]
# Web build into ../build/web; the folder must exist (deploying to GitHub Pages: see PROTOTYPE_PLAN.md, "Web build")
New-Item -ItemType Directory -Force D:\dev\src\rts1\build\web | Out-Null
& "$godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path D:\dev\src\rts1\prototype --export-release "Web"
```

## Controls

| Gamepad | Keyboard fallback | Action |
| --- | --- | --- |
| LB / RB | Q / R | Previous / next living unit (wraps; tile and camera kept). |
| Left stick | W E / A D / Z X (hex directions) | Move the selected tile; six sectors, initial delay then repeat. |
| Right stick | Arrow keys | Pan the camera (clamped to the map; the tile follows the screen edge). |
| A | Enter | Default action on the selected tile (preview shown before pressing). |
| B | Backspace | Cancel an open interaction (none in this scope; never stops units). |
| X | F | Striker: change form. |
| Menu | Space | Pause / resume. |

Sandbox commands (keyboard only):

| Key | Command |
| --- | --- |
| F1 | Debug overlay: claims by owner, entering steps, routes, alternatives, unit state, tie count. |
| F2 | Toggle enemy spawning. |
| F3 | Spawn one enemy at the spawn point nearest the selected tile. |
| F4 | Toggle Core and player-unit invulnerability. |
| F5 | Reset the current setup (also reloads `data/tuning.json`). |
| F6 | Next setup file. |
| `.` | Advance one tick while paused. |
| `-` / `+` | Simulation speed 0.25x to 4x. |
| H | Toggle the help text. |

All bindings live in [input/bindings.gd](input/bindings.gd) and are registered into the InputMap at startup; dead zones and repeat timings are in `data/tuning.json` under `input`.

## Layout

- `sim/`: the rules as plain `RefCounted` scripts linked with `preload` (no nodes, input, or rendering). Deterministic: fixed tick (20/s), stable unit IDs, stable tile order (`r`, then `q`).
  - `simulation.gd`: tick order, setup loading, commands, action preview and rejection reasons, invariants.
  - `movement.gd`: stopping positions (2.2), claims, step requests, friendly transit, enemy blocking, opposing entry policy, cancellation and return.
  - `control.gd`: the control model (one selected unit, one selected tile). Input and tests drive it the same way.
  - `hex.gd`, `grid.gd`, `occupancy.gd`, `pathfinding.gd`, `unit.gd`, `combat.gd`, `striker.gd`, `shaper.gd`, `enemy.gd`.
- `view/`: `main.tscn`/`main.gd` (fixed-tick loop, camera, sandbox commands), map, unit, cursor, HUD, and debug overlay views. Unit positions are interpolated between ticks.
- `input/`: bindings and stick handling (deadzone, sector snapping with hysteresis, repeat).
- `data/tuning.json`: every number (placeholders).
- `scenarios/*.json`: setups shared by the sandbox (F6) and the tests.
- `tests/`: `run_tests.gd` runner and test files; `smoke_view.gd` windowed smoke test.

## Setup files

```json
{
  "name": "Shown in the HUD",
  "description": "Shown when the setup loads",
  "rows": ["#####", "#.C.#", "#.S.#"],
  "units": [{ "type": "striker", "form": "guard", "pos": [col, row] }, { "type": "shaper", "pos": [col, row] }],
  "enemies": [{ "pos": [col, row] }],
  "spawning": { "enabled": true, "interval": 6.0 },
  "enemy_ai": true,
  "camera": [col, row],
  "tuning": { "opposing_entry_policy": "enemy_wins_ties" }
}
```

Rows use odd-r offset coordinates (odd rows shifted right): `#` blocked, `.` cleared, `C` Core centre (the centre and its six neighbours form the footprint), `S` enemy spawn point, space for off-map. Unit IDs follow the listed order (players first, then enemies). `tuning` is deep-merged over `data/tuning.json`.

## Decisions and assumptions

These filled gaps the design left open. After playtesting they have been folded into [GAME_DESIGN.md](../GAME_DESIGN.md); the design is the reference if the two differ.

- **Opposing entry policy:** `player_wins_ties` (configurable to `enemy_wins_ties`). Earlier requests always win; requests in the same tick are evaluated player side first, then by unit ID. The debug overlay counts the ties the policy resolved.
- **Pathfinding:** breadth-first search rather than A*. Every step costs the same, so routes are equally short and ties resolve in stable direction order.
- **Transit:** a unit that is in transit cannot attack, work, or change form. Strikers cannot attack while changing form.
- **Attack-move:** an attack-moving Striker holds on its current tile when an enemy is in range and the tile is a free stopping position. While passing over a friendly it keeps moving to the next free tile, then holds there. It never pursues, and it continues when nothing is in range.
- **Enemies:** an enemy attack-moves toward the nearest Core attack position or player unit, measured by walking distance over terrain. It holds to fight anything in range.
- **Physical controller:** the stick feel, button mapping, and dead zones still need checking on the Xbox controller (milestone 2). The automated smoke test injects the same InputMap actions instead.

# RTS1: Think Strategy 1st - Game concept

**Survive the attacks, clear a path, and take the enemy's Emitters.**

An abstract RTS with few units: easy to understand, demanding to master. The enemy can already reach you; you must create a route to reach it. Single-player first; multiplayer is a future direction. Designed for gamepad first; mouse and touch use the same scheme.

The intended experience is **turning vulnerability into control through your own decisions**. You begin with a Core in a small clearing, surrounded by impassable terrain and threatened by flying enemies. Opening a route creates opportunity; committing forces creates anxiety; capturing an Emitter brings income, ground to hold, and one less direction to watch.

## Roles

- **Core:** your base; its destruction means defeat.
- **Shapers:** clear terrain and capture Emitters. They cannot fight.
- **Strikers:** mobile units that fight flying and ground enemies. A Striker has two forms: **Assault**, fast and mobile, and **Guard**, slow but tougher, reaching and seeing farther. Shifting form takes several seconds; it is a commitment.
- **Emitters:** produce enemies while the enemy holds them and energy while you hold them. Capture all to win.

## Terrain and tiles

The map is a hex grid. Terrain is the enemy's advantage: flying enemies cross blocked terrain freely; you must clear tiles to move on the ground and reach Emitters. Cleared tiles stay cleared.

The shape of the route is the player's choice. A narrow corridor funnels ground enemies into Guard Strikers; a wide clearing offers room but a wider front. A Guard Striker can plug a gap, but enemies fight it rather than walk past. Ground enemies eventually use the passages you open: more access is not always better.

Ground and air are separate movement layers. One settled unit per tile per layer; friendlies pass through each other, hostiles block each other. Logic is discrete; motion is smooth. The Core and Emitters occupy seven hexes; everything else one. Range is counted in hexes. The rules are defined in [Movement](#movement).

The map is about four console viewports at a single fixed zoom. Phones show less of the map and swipe to pan; the map does not change.

## Economy

One resource, **energy**. The Core supplies basic income and trains units, with a fixed maximum of eight Shapers and Strikers combined. Dedicated buttons queue training without selecting the Core. Energy buys units. Captured Emitters are the only way to get more energy, and each extends the ground you must defend. The rules are defined in [Economy rules](#economy-rules).

## Emitters

A Shaper captures an Emitter by standing next to it; the Emitter keeps producing until the capture completes. Enemy strength depends only on how many Emitters the enemy holds: capture one and the rest grow stronger; lose one and it resumes production while the rest relax. Total pressure stays roughly constant, so the last Emitter is the hardest. Strength changes ramp up and down smoothly. Ground enemies recapture Emitters the same way Shapers do. The rules are defined in [Emitter rules](#emitter-rules).

Some Emitters **shield** another: the shielded Emitter cannot be captured while the enemy holds its overseer, and the overseer sits deeper in the terrain. The order of capture is a puzzle.

## Fog of war

Unexplored terrain is hidden. Explored terrain stays on the map but greys out when no unit or structure sees it. Remembered terrain is reliable; remembered enemies are not.

## Controls

Micro demands fast decisions, not precise aiming. Control is strictly single-unit: one selected unit and one selected hex tile, with no groups or select-all command. One button executes the selected unit's default action on the selected tile; combat targeting is automatic. No modifier chords, timed holds, or wheels are needed. The scheme is defined in [Control model](#control-model), [Gamepad controls](#gamepad-controls), and [Default action: A](#default-action-a).

## Play

**Defend -> clear -> capture -> hold**, while protecting the Core. Macro decisions allocate energy, Shapers, and routes. Micro decisions position individual Strikers, choose their form, protect Shapers, and decide when to advance or withdraw. Units must remain useful unattended: Guards hold their positions, Shapers complete assigned work, and attack-moving Strikers do not leave their route to pursue.

Each meaningful choice exchanges one advantage for another: a Striker in Guard form at home versus one advancing, a direct assault versus a defensible route, another Emitter's income versus another front to hold. Maps must make these alternatives useful in different circumstances.

The central learning challenge is **recognizing when and where you can safely advance**. Early situations introduce attack patterns, defensive coverage, and the cost of dividing your force separately; later ones combine them through different terrain, Emitter placement, and attack directions. Clear feedback should make failures understandable and suggest a better next attempt.

The design test: can players explain a consequential choice, recognize why it succeeded or failed, and apply that understanding to a new situation?

Open: Shaper repair or augmentation, destroying an Emitter instead of capturing it, additional Emitter types, additional Striker forms.

Design interpretation: Jesse Schell's [The Art of Game Design](https://schellgames.com/art-of-game-design/) informs the intended experience and meaningful choices; Raph Koster's [A Theory of Fun for Game Design](https://www.oreilly.com/library/view/theory-of-fun/9781449363208/) informs learning through problem mastery and variation.

---

# Game design

The following gamepad scheme and movement rules develop the [game concept](#game-concept). This is a prototype design to validate through play.

The [rules prototype](prototype/README.md) validated the control model, the default action, Striker forms, Shaper clearing, ground enemies, and the movement rules: they play well and feel good on a gamepad.

## Control model

**One selected unit. One selected tile. No groups.**

- At most eight units, counting Shapers and Strikers together.
- LB/RB always cycle through living units in stable order, wrapping at either end.
- Cycling units preserves the selected tile and camera position. To send several units toward the same destination: A, RB, A, RB, A.
- The Core and Emitters are not part of the unit cycle.
- Clearly highlight the selected unit and tile, with an offscreen indicator for the unit when needed: an arrow at the screen edge pointing toward the unit, labelled with its name.
- The left stick snaps to the six hex directions, with hysteresis between neighbouring directions so the tile does not jitter. Pushing the stick moves the tile one hex and holding the stick repeats the move after a short pause.
- The selected tile and the camera stay coupled: panning keeps the tile inside the view, and stepping the tile scrolls the camera to keep it visible. The camera is clamped to the map.

## Gamepad controls

| Input       | Action                                                               |
| ---         | ---                                                                  |
| LB / RB     | Select previous / next unit.                                         |
| Left stick  | Step the selected tile through the hex grid.                         |
| Right stick | Pan the camera.                                                      |
| A           | Execute the selected unit's default action on the selected tile.     |
| B           | Cancel an open interaction; do not stop the unit or clear selection. |
| X           | Unit-specific ability: change form for a Striker.                    |
| Y           | Reserved for another unit-specific ability; currently unassigned.    |
| D-pad left  | Train a Shaper at the Core.                                          |
| D-pad right | Train a Striker at the Core.                                         |
| Menu        | Pause.                                                               |

Other buttons remain unassigned until needed. No modifier chords, timed holds, radial menus, or group-selection modes.

## Default action: A

| Unit    | Selected tile   | Action                                                                        |
| ---     | ---             | ---                                                                           |
| Striker | Destination     | Attack-move: advance, fighting enemies met along the route, without pursuing. |
| Shaper  | Clear ground    | Move.                                                                         |
| Shaper  | Blocked terrain | Clear.                                                                        |
| Shaper  | Emitter         | Capture, or contest a recapture of a player-held one.                         |

Show the action before A is pressed, including the planned route and, when section 2.2 substitutes a destination, the tile the unit will actually stop on. This preview is what makes alternative destinations readable rather than surprising. Invalid or unreachable actions explain why and preserve the existing order. Selecting an enemy tile does not change a Striker's attack-move into a pursuit order.

Units must work without constant attention: Guards hold their positions, and Shapers finish assigned work.

An attack-moving Striker holds when a visible enemy is in range: it finishes its current step and, if that tile is a free stopping position, claims it and fights from there. While passing over a friendly it cannot fight, so it keeps moving along its route and holds at the first free stopping position where an enemy is still in range; it never backtracks to fight. When enemies cut its route (section 3.1), it settles at the nearest free tile it can reach (chosen as in section 2.2) and fights from there. It continues toward its target when no visible enemy is in range and a route is open. It never leaves its route to pursue. A settled Striker also fights automatically.

A Striker cannot attack while changing form, so a form change in contact is a real commitment. Several Shapers may clear the same tile or capture the same Emitter from different work positions; their work combines, so extra Shapers speed up the job.

## Ground enemies

A ground enemy attack-moves toward the nearest target by walking distance over cleared terrain: a player unit or a tile adjacent to its structure target. It holds and fights anything in range, never pursues, re-evaluates its target periodically, and follows the same movement rules as player units with the sides reversed.

Its structure target is the Core. If the player holds any Emitters, every `recapture_effort`th ground enemy spawned on the map (initially every 5th) targets the most recently captured Emitter. One map-wide counter decides this.

## Flying enemies

A flyer moves on the air layer and ignores terrain. It attack-moves toward the Core and fights it on arrival. A player unit that damages it becomes its target: it moves to that unit, fights it, and when the attacker dies or the flyer is damaged by another unit, it switches to the newest attacker; with no attacker left, it resumes the Core.

## Movement

**Friendly passage, exclusive stopping, no hostile crossing.** Ground and air apply these rules separately. Ground units use cleared terrain and cannot enter structure footprints; flyers ignore terrain.

A movement order is executed as a series of discrete steps between neighboring tiles. A planned route grants no permission to move: every step must satisfy the applicable movement rules before it starts. Animation is continuous; logical movement follows these steps.

Plan routes using known terrain. A target with no route on known terrain is invalid and is rejected under the default-action rules. Visible enemies never make a target unreachable; they block entry under section 3. End movement once settled. If no valid stopping position is reachable, remain visibly blocked.

The logic is deterministic. It advances in fixed ticks, and every duration (steps, returns, form changes, clearing, attack timing) is a whole number of ticks. Units resolve in stable ID order, and **stable tile order** means row, then column. Routes are shortest by step count, with ties broken by a fixed direction order. Animation interpolates between ticks.

### 1. Friendlies never block passage

Friendlies may traverse the same tile simultaneously in any direction, including through another unit's stopping position.

### 2. Only one unit may claim a stopping position

1. A final step and its stopping claim are granted together, only if both are permitted, immediately before movement starts. If already on the stopping tile, claim it immediately if free. Release the source claim when the first departing step completes.
2. If the target is occupied or claimed by another friendly, choose a free reachable tile by shortest walking distance to the target, then shortest route from the current tile, then stable tile order. Show the chosen destination.
3. If multiple friendlies claim the same stopping position simultaneously, allow one; the others choose alternatives using the previous rule. Friendly pass-through requests do not conflict.
4. For clearing and capture, choose only among valid adjacent work positions: free stopping positions reachable over known terrain. If none is free, hold at the nearest free tile it can reach, keep the work pending, and continue when a work position frees.

### 3. Enemies block entry

1. A step may not enter a tile that an enemy occupies or is entering. If visible enemies cut off every route to the target, the unit does not give up the target: it moves to the nearest free tile it can reach (chosen as in section 2.2), settles there, and shows the target as blocked by an enemy. While holding, a Striker fights and a Shaper waits. When a route opens, the unit continues to its target.
2. If opposing units request the same destination, the earlier request wins: a tile that an enemy is already entering is blocked under the previous rule. Requests made in the same tick are a tie, and **the player wins ties**. Detect ties before granting stopping claims; otherwise the winner's claim makes the loser look claim-blocked instead of tie-blocked. Compatible friendly pass-through requests may proceed; denied requests follow the previous rule. Ties are uncommon because both sides must request the same tile in the same tick; the policy favours the player and is simple to explain.

### 4. Logical position changes on arrival

Move smoothly between neighboring hex centers at the unit's movement speed. Logical occupancy stays at the source until arrival, then transfers to the destination; combat range uses logical positions. Death immediately removes the unit, its stopping claims, and its in-progress step.

### 5. Cancelling frees the destination immediately

1. Accept movement orders immediately. During A -> B, continue if the new route starts with A -> B; otherwise return to A before taking another direction. If a new order continues the step but no longer stops at B, release B's stopping claim immediately.
2. On cancellation, the unit stops claiming entry into B. If B was its stopping position, release that stopping claim immediately. Keep logical occupancy at A throughout the return. Friendlies remain free to pass.
3. Return at normal speed, taking time proportional to distance travelled. Orders during return replace the pending order but do not interrupt the return; entering B later needs a fresh step check.
4. Movement can cancel an attack before firing, forfeiting it, or interrupt its remaining animation after firing without resetting its cooldown. Form changes cannot be cancelled; movement orders received during a form change execute after it finishes.

### 6. Overlap is transit, not a fighting position

1. A passing unit remains attackable but cannot attack, work, or change form until it occupies a stopping position it has claimed. The stationary unit acts normally.
2. Enter a friendly-occupied stretch only with a known route to a free stopping position. If no stopping position remains reachable during passage, remain visibly blocked and subject to the overlap restrictions.

### Movement decision tree

Apply new orders using section 5. At tile boundaries, use this summary of the rules above; every requested step remains subject to sections 2 and 3.

```text
Step, return, or form change in progress? -> Follow sections 4 and 5.
In friendly transit? -> Follow section 6.
Holding with a pending target? -> Settled under section 3; resume when permitted.
No movement/work order? -> Hold position.
Attack-move combat? -> Follow the default-action rules.
At the destination/work position? -> Settle or work under section 2.
Otherwise -> Request the next step under sections 2 and 3.
  No route? -> Follow the movement introduction's stopping rule.
```

## Economy rules

Numbers in this section and the next are initial values; the tuning file mirrors them under the keys shown in backticks.

- Energy is capped at `energy_cap` (100). The Core grants `core_income` energy per second (2).
- Each captured Emitter adds `emitter_cap_bonus` to the cap and `emitter_income` energy per second while the player holds it.
- Training rules are deferred until the training buttons are prototyped.

## Emitter rules

### Capture

1. A Shaper captures an Emitter from an adjacent work position, chosen under section 2.4 of Movement. Only a settled Shaper works (section 6); several Shapers combine, so extra Shapers speed up the capture.
2. Capture progress is tracked per side and shown as a visible progress bar. One Shaper completes a capture in `capture_time` seconds. When no capturer of a side is adjacent, that side's progress decays at the same rate it builds.
3. A capture is **contested** while both sides have a capturer adjacent: neither side's progress changes. Both sides contest the same way; a Shaper ordered onto a player-held Emitter counts as a capturer.
4. The Emitter keeps producing throughout the capture. Production stops the moment the capture completes, both sides' progress resets, and the Emitter starts paying income.
5. Ground enemies recapture a player-held Emitter the same way, by standing adjacent. Flyers cannot capture.
6. A shielded Emitter cannot be captured while the enemy holds its overseer; a Shaper ordered to capture it is rejected with that reason.

### Production

1. Enemy strength is a single map-wide spawn budget, `spawn_budget` enemies per second, divided equally across enemy-held Emitters. When the count changes, each Emitter's share ramps linearly over `spawn_ramp_time` seconds.
2. An Emitter's **pocket** is the cleared ground reachable on foot from its footprint. An Emitter has a **clear path** when its pocket contains a tile adjacent to the Core.
3. The Emitter alternates flyer and ground spawns. Without a clear path, once its **garrison** of ground enemies in the pocket reaches `garrison_fill` (50%) of the pocket's tiles, ground spawns become flyers instead; a garrison unit lost to fire over the terrain is replaced by the next ground spawn. Garrison units are ordinary ground enemies: with no route to their target they settle and fight whatever comes in range (section 3.1), and they advance as soon as a route exists.
4. Opening a route therefore changes where the pressure comes from, not how much there is: flyers that could reach the Core anywhere become ground enemies funnelled into the route the player opened.
5. Spawns appear on a free tile of the pocket adjacent to the footprint, in stable tile order; flyers on the air layer. If no tile is free, the spawn waits.

## Playtests

### First playtest

Done with the [rules prototype](prototype/README.md), which covered three or four units, cycling and tile targeting, sending several units to one destination, and rescuing a Shaper without disturbing defenders. Control and movement play well and feel good; no new controls were needed, and B still has no interaction to cancel.

These movement scenarios are now setup files shared by the sandbox and an automated test suite, which also checks the rules' invariants under randomised orders and confirms determinism:

- Shared and crowded destinations, including a nearer unit ordered after a distant one.
- Friendly crossings from different directions and passage through stationary Guards.
- A blocked unit overlapping a friendly, including loss of every reachable stopping position.
- Opposing entry requests and interrupted movement toward a work position.
- Mid-step reversal and retargeting, including stopping-claim release, logical occupancy, return time, and repeated cancellation without speed or attack-rate gains.

Keep new rules expressible as setups and tests the same way.

### Next playtest

Add energy, training, Emitters (capture, garrison, recapture, shields), flyers with attacker retargeting, and fog of war. Check that LB/RB cycling stays quick with eight units under active pressure, that the training buttons work without breaking focus, and whether play reveals a concrete need for Y or for B. Add controls only when play reveals a concrete need.

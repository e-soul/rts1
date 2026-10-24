# Game concept

**Survive the attacks, clear a path, and take the enemy's Emitters.**

An abstract RTS with few units: easy to understand, demanding to master. The enemy can already reach you; you must create a route to reach it. Single-player first; multiplayer is a future direction. Designed for gamepad first; mouse and touch use the same scheme.

The intended experience is **turning vulnerability into control through your own decisions**. You begin with a Core in a small clearing, surrounded by impassable terrain and threatened by flying enemies. Opening a route creates opportunity; committing forces creates anxiety; capturing an Emitter brings income, ground to hold, and one less direction to watch.

## Roles

- **Core:** your base; its destruction means defeat.
- **Shapers:** clear terrain and convert neutralized Emitters. They cannot fight.
- **Strikers:** mobile units that fight flying enemies, ground enemies, and structures. A Striker has two forms: **Assault**, fast and mobile, and **Guard**, slow but tougher, reaching and seeing farther. Shifting form takes several seconds; it is a commitment.
- **Emitters:** produce enemies while the enemy holds them and energy while you hold them. Capture all to win.

## Terrain and tiles

The map is a hex grid. Terrain is the enemy's advantage: flying enemies cross blocked terrain freely; you must clear tiles to move on the ground and reach Emitters. Cleared tiles stay cleared.

The shape of the route is the player's choice. A narrow corridor funnels ground enemies into Guard Strikers; a wide clearing offers room but a wider front. A Guard Striker can plug a gap, but enemies fight it rather than walk past. Ground enemies eventually use the passages you open: more access is not always better.

Ground and air are separate movement layers. One settled unit per tile per layer; moving friendlies can pass through each other at normal speed without displacing stationary units. There is no teleportation or permanent stacking. A passing unit remains attackable; if trapped overlapping a friendly, it waits visibly and cannot attack, work, or change form until clear. Hostile units block passage on their layer. Logic is discrete; motion is smooth. The Core and Emitters occupy seven hexes; everything else one. Range is counted in hexes.

The map is about four console viewports at a single fixed zoom. On a gamepad the right stick pans the camera; cycling units preserves the selected tile and camera position. Phones show less of the map and swipe to pan; the map does not change.

## Economy

One resource, **energy**. The Core supplies basic income and trains units, with a fixed maximum of eight Shapers and Strikers combined. Dedicated buttons queue training without selecting the Core. Energy buys units. Captured Emitters are the only expansions: each adds income and extends the ground you must defend.

## Emitters

Strikers neutralize an Emitter; a Shaper converts it. Enemy strength depends only on how many Emitters the enemy holds: capture one and the rest grow stronger; lose one and it resumes production while the rest relax. Total pressure stays roughly constant, so the last Emitter is the hardest. Strength changes ramp rather than snap.

Enemies retake a captured Emitter by reaching it and holding it for a visible countdown; defeating them resets it.

Some Emitters **shield** another: the shielded Emitter cannot be harmed while its overseer stands, and the overseer sits deeper in the terrain. The order of capture is a puzzle, not a list.

## Fog of war

Unexplored terrain is hidden. Explored terrain stays on the map but greys out when no unit or structure sees it. Remembered terrain is reliable; remembered enemies are not.

## Controls

Micro demands fast decisions, not precise aiming. Control is strictly single-unit: one selected unit and one selected hex tile, with no groups or select-all command. LB/RB always cycle through Shapers and Strikers. The left stick steps through tiles; the right stick pans the camera.

A executes the selected unit's default action on the selected tile: attack-move for a Striker; move, clear, or convert for a Shaper, depending on the tile. Combat targeting is automatic. X and Y are reserved for unit-specific abilities, such as changing Striker form. B cancels an open interaction without stopping the unit. D-pad left trains a Shaper; D-pad right trains a Striker. No modifier chords, timed holds, or wheels are needed. The gamepad scheme is listed in [Game design](#game-design).

## Play

**Defend -> clear -> capture -> hold**, while protecting the Core. Macro decisions allocate energy, Shapers, and routes. Micro decisions position individual Strikers, choose their form, protect Shapers, and decide when to advance or withdraw. Units must remain useful unattended: Guards hold their positions, Shapers complete assigned work, and attack-moving Strikers do not chase enemies far from their route.

Each meaningful choice exchanges one advantage for another: a Striker in Guard form at home versus one advancing, a direct assault versus a defensible route, another Emitter's income versus another front to hold. Maps must make these alternatives useful in different circumstances.

The central learning challenge is **recognizing when and where you can safely advance**. Early situations introduce attack patterns, defensive coverage, and the cost of dividing your force separately; later ones combine them through different terrain, Emitter placement, and attack directions. Clear feedback should make failures understandable and suggest a better next attempt.

The design test: can players explain a consequential choice, recognize why it succeeded or failed, and apply that understanding to a new situation?

Open: Shaper repair or augmentation, destroying an Emitter instead of capturing it, additional Emitter types, additional Striker forms.

Design interpretation: Jesse Schell's [The Art of Game Design](https://schellgames.com/art-of-game-design/) informs the intended experience and meaningful choices; Raph Koster's [A Theory of Fun for Game Design](https://www.oreilly.com/library/view/theory-of-fun/9781449363208/) informs learning through problem mastery and variation.

---

# Game design

The following gamepad scheme and movement rules develop the [game concept](#game-concept). This is a prototype design to validate through play.

## Control model

**One selected unit. One selected tile. No groups.**

- At most eight units, counting Shapers and Strikers together.
- LB/RB always cycle through living units in stable order, wrapping at either end.
- Cycling units preserves the selected tile and camera position. To send several units toward the same destination: A, RB, A, RB, A.
- The Core and Emitters are not part of the unit cycle. There are no gates or construction.
- Clearly highlight the selected unit and tile, with an offscreen indicator for the unit when needed.

## Gamepad controls

| Input | Action |
| --- | --- |
| LB / RB | Select previous / next unit. |
| Left stick | Step the selected tile through the hex grid. |
| Right stick | Pan the camera. |
| A | Execute the selected unit's default action on the selected tile. |
| B | Cancel an open interaction; do not stop the unit or clear selection. |
| X | Unit-specific ability: change form for a Striker. |
| Y | Reserved for another unit-specific ability; currently unassigned. |
| D-pad left | Train a Shaper at the Core. |
| D-pad right | Train a Striker at the Core. |
| Menu | Pause. |

Other buttons remain unassigned until needed. No modifier chords, timed holds, radial menus, or group-selection modes.

## Default action: A

| Unit | Selected tile | Action |
| --- | --- | --- |
| Striker | Destination | Attack-move: advance and engage enemies along the route without chasing far away. |
| Shaper | Clear ground | Move. |
| Shaper | Blocked terrain | Clear. |
| Shaper | Neutralized Emitter | Convert. |

Show the action before A is pressed. Invalid or unreachable actions explain why and preserve the existing order; never silently substitute another action. Selecting an enemy tile does not change a Striker's attack-move into a pursuit order.

Units must work without constant attention: Guards hold their positions, and Shapers finish assigned work.

An attack-moving Striker fights only while occupying a stopping position it has claimed. It retains its movement target during combat and resumes when no visible enemy is in range, without pursuing off-route. A settled Striker also fights automatically.

## Movement

**Friendly passage, exclusive stopping, no hostile crossing.** Ground and air apply these rules separately. Ground units use cleared terrain and cannot enter structure footprints; flyers ignore terrain.

A movement order is executed as a series of discrete steps between neighboring tiles. A planned route grants no permission to move: every step must satisfy the applicable movement rules before it starts. Animation is continuous; logical movement follows these steps.

Plan routes using known terrain and visible enemies. If an accepted movement order has no route to its target, abandon that target and use the current tile as the stopping target under section 2. End movement once settled; settling does not complete interrupted clearing or conversion. If no valid stopping position is reachable, remain visibly blocked.

### 1. Friendlies never block passage

Friendlies may traverse the same tile simultaneously in any direction, including through another unit's stopping position.

### 2. Only one unit may claim a stopping position

1. A final step and its stopping claim are granted together, only if both are permitted, immediately before movement starts. If already on the stopping tile, claim it immediately if free. Release the source claim when the first departing step completes.
2. If the target is occupied or claimed by another friendly, choose a free reachable tile by minimum hex distance to the target, then shortest route from the current tile, then stable tile order. Show the chosen destination.
3. If multiple friendlies claim the same stopping position simultaneously, allow one; the others choose alternatives using the previous rule. Friendly pass-through requests do not conflict.
4. For clearing and conversion, choose only among valid adjacent work positions.

### 3. Enemies block entry

1. Before starting a step, check that no enemy occupies or is already entering the destination. If entry is denied, abandon the original movement target and use the current tile as the stopping target, applying section 2. End movement once settled. This is a stopping position, not a work position; settling does not complete interrupted clearing or conversion.
2. If opposing units request the same destination at the same time, select a winning side using a conflict-resolution policy (not yet defined). Compatible friendly pass-through requests may proceed; denied requests follow the previous rule.

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
Settling after interruption? -> Follow section 2 and the blocked-position rule.
No movement/work order? -> Hold position.
Attack-move combat? -> Follow the default-action rules.
At the destination/work position? -> Settle or work under section 2.
Otherwise -> Request the next step under sections 2 and 3.
  No route? -> Follow the movement introduction's stopping rule.
```

## Training

- Each training-button press queues one unit, reserving energy and capacity; holding does not repeat purchases.
- Show costs, queue progress, and capacity. Reject requests exceeding available energy or the eight-unit limit with clear feedback.
- Training and arrival never change selection or the camera.

## First playtest

Start with three or four units before testing the eight-unit ceiling. Check that cycling and tile targeting are quick, that several units can be sent to the same destination comfortably, and that rescuing a Shaper does not cause accidental orders to defenders. Add controls only when play reveals a concrete need.

Test these scenarios against the movement rules:

- Shared and crowded destinations, including a nearer unit ordered after a distant one.
- Friendly crossings from different directions and passage through stationary Guards.
- A blocked unit overlapping a friendly, including loss of every reachable stopping position.
- Opposing entry requests and interrupted movement toward a work position.
- Mid-step reversal and retargeting, including stopping-claim release, logical occupancy, return time, and repeated cancellation without speed or attack-rate gains.

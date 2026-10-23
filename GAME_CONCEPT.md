# Game concept

**Survive the attacks, clear a path, and take the enemy's Emitters.**

An abstract RTS with few units: easy to understand, demanding to master. The enemy can already reach you; you must create a route to reach it. Single-player first; multiplayer is a future direction. Designed for gamepad first; mouse and touch use the same scheme.

The intended experience is **turning vulnerability into control through your own decisions**. You begin with a Core in a small clearing, surrounded by impassable terrain and threatened by flying enemies. Opening a route creates opportunity; committing forces creates anxiety; capturing an Emitter brings income, ground to hold, and one less direction to watch.

## Roles

- **Core:** your base; its destruction means defeat.
- **Shapers:** clear terrain, build structures, and convert neutralized Emitters. They cannot fight.
- **Strikers:** mobile units that fight flying enemies, ground enemies, and structures. A Striker has two forms: **Assault**, fast and mobile, and **Guard**, slow but tougher, reaching and seeing farther. Shifting form takes several seconds; it is a commitment.
- **Emitters:** produce enemies while the enemy holds them and energy while you hold them. Capture all to win.

## Terrain and tiles

The map is a hex grid. Terrain is the enemy's advantage: flying enemies cross blocked terrain freely; you must clear tiles to move on the ground, build, and reach Emitters. Cleared tiles stay cleared.

The shape of the route is the player's choice. A narrow corridor funnels ground enemies into Guard Strikers; a wide clearing offers room but a wider front. Shapers can build a **gate** in a one-tile corridor that opens and closes on command. A Guard Striker can also plug a gap, but enemies fight it rather than walk past. Ground enemies eventually use the passages you open: more access is not always better.

One unit per tile, on two layers: ground and air. Logic is discrete; motion is smooth. Friendly units swap tiles when they meet; hostile units fight. Nothing pushes anything out of its tile. The Core and Emitters occupy seven hexes; everything else one. Range is counted in hexes.

The map is about four console viewports at a single fixed zoom. On a gamepad every location is one pan away and the camera follows the selection. Phones show less of the map and swipe to pan; the map does not change.

## Economy

One resource, **energy**. The Core supplies basic income and produces units. Energy buys units and structures. Captured Emitters are the only expansions: each adds income and extends the ground you must defend.

## Emitters

Strikers neutralize an Emitter; a Shaper converts it. Enemy strength depends only on how many Emitters the enemy holds: capture one and the rest grow stronger; lose one and it resumes production while the rest relax. Total pressure stays roughly constant, so the last Emitter is the hardest. Strength changes ramp rather than snap.

Enemies retake a captured Emitter by reaching it and holding it for a visible countdown; defeating them resets it.

Some Emitters **shield** another: the shielded Emitter cannot be harmed while its overseer stands, and the overseer sits deeper in the terrain. The order of capture is a puzzle, not a list.

## Fog of war

Unexplored terrain is hidden. Explored terrain stays on the map but greys out when no unit or structure sees it. Remembered terrain is reliable; remembered enemies are not.

## Controls

Micro demands fast decisions, not precise aiming. All commands are dedicated buttons or cycling; no hold-to-activate, no wheels. Everything controllable (Core, Strikers, Shapers, gates) sits in a short list; shoulder buttons cycle through it and one button selects all Strikers. Orders target hex tiles through a snapping cursor on the analog stick. Combat targeting is automatic; the player chooses where units stand and which kind of target they prefer. One button shifts form; one button retreats the selection to the Core. **No order takes more than two inputs.**

## Play

**Defend -> clear -> capture -> hold**, while protecting the Core. Macro decisions allocate energy, Shapers, and routes. Micro decisions position Strikers, choose their form, protect Shapers, and time gates and retreats. Routine actions require little attention.

Each meaningful choice exchanges one advantage for another: a Striker in Guard form at home versus one advancing, a direct assault versus a defensible route, another Emitter's income versus another front to hold. Maps must make these alternatives useful in different circumstances.

The central learning challenge is **recognizing when and where you can safely advance**. Early situations introduce attack patterns, defensive coverage, and the cost of dividing your force separately; later ones combine them through different terrain, Emitter placement, and attack directions. Clear feedback should make failures understandable and suggest a better next attempt.

The design test: can players explain a consequential choice, recognize why it succeeded or failed, and apply that understanding to a new situation?

Open: Shaper repair or augmentation, destroying an Emitter instead of capturing it, additional Emitter types, additional Striker forms.

Design interpretation: Jesse Schell's [The Art of Game Design](https://schellgames.com/art-of-game-design/) informs the intended experience and meaningful choices; Raph Koster's [A Theory of Fun for Game Design](https://www.oreilly.com/library/view/theory-of-fun/9781449363208/) informs learning through problem mastery and variation.

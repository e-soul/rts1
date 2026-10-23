# Game concept

**Survive the attacks, clear a path, and take the enemy's Emitters.**

An abstract RTS with few units: easy to understand, demanding to master. The enemy can already reach you, but you must create a route to reach it. Single-player comes first; multiplayer remains a future direction. The game is designed for gamepad first; mouse and touch follow from the same scheme.

The intended experience is **turning vulnerability into control through your own decisions**. Begin with a Core in a small clearing, surrounded by impassable terrain and threatened by flying enemies. Opening a route creates opportunity; committing forces creates anxiety; capturing an Emitter brings income, ground to hold, and one less direction to watch.

Four roles define the game:

- **Core:** your base; its destruction means defeat.
- **Shapers:** clear terrain, construct structures, and convert neutralized Emitters. They cannot fight.
- **Strikers:** mobile squads that fight flying enemies, ground enemies, and structures. A squad can **root** in place: rooted, it is tougher, reaches farther, and sees farther, but cannot move. Rooting and unrooting take several seconds, so rooting is a commitment, not a toggle.
- **Emitters:** produce enemies while the enemy holds them and produce energy while you hold them. Capture all to win.

## Terrain

The map is a grid of hex tiles. Terrain is the enemy's advantage: flying enemies cross blocked terrain freely, while you must clear tiles to move on the ground, build, and approach Emitters. Cleared tiles stay cleared.

A skilled player turns terrain to their advantage. The shape of the route is the player's choice: a narrow corridor funnels ground enemies into rooted Strikers; a wide clearing offers build space but a wider front. Terrain left uncleared remains a wall. Shapers can build a **gate** in a one-tile corridor, which opens and closes on command. A rooted squad can also plug a gap, but enemies will fight it rather than walk past.

Ground enemies eventually use the passages you open, challenging the assumption that more access is always beneficial.

## Economy

One resource, **energy**. The Core supplies basic income and produces units. Energy buys units and structures. Captured Emitters are the only expansions: each one you hold adds income, and each one extends the ground you must defend.

## Emitters

Strikers neutralize an Emitter; a Shaper then converts it. Enemy strength depends only on how many Emitters the enemy holds: capture one and the remaining Emitters grow stronger; lose one and it resumes production while the others relax. Total pressure stays roughly constant, so the last Emitter is the hardest. Changes in strength ramp over a few seconds rather than snapping.

Enemies retake a captured Emitter by reaching it and holding it for a visible countdown; defeating them resets it. Progress is measured in territory held, not in kills.

Some Emitters **shield** another: the shielded Emitter cannot be harmed while its overseer stands, and the overseer sits deeper in the terrain. The order of capture is therefore a puzzle, not a list. Further Emitter types remain open for later.

## Fog of war

Unexplored terrain is hidden. Explored terrain stays on the map but greys out without a unit or structure nearby to see it. Remembered terrain is reliable; remembered enemies are not. Rooted Strikers extend your sight.

## Controls

Micro should demand fast decisions, not precise aiming. Everything controllable (Core, squads, Shapers, gates) sits in a short list; the shoulder buttons cycle through it and one button selects all Strikers. Orders target hex tiles through a snapping cursor on the analog stick. Combat targeting is automatic; the player chooses only where units stand and which kind of target they prefer. One button retreats the selection to the Core. The rule: **no order takes more than two inputs**. If the game needs more than a handful of controllable things on screen, the control scheme has failed.

## Play

**Defend -> clear -> capture -> hold**, while continuing to protect the Core. Macro decisions allocate energy, Shapers, and routes. Micro decisions position and root squads, protect Shapers, time gates, and time retreats. Routine actions require little attention.

Each meaningful choice exchanges one advantage for another: a squad rooted at home versus a squad advancing, a direct assault versus a defensible route, another Emitter's income versus another front to hold. Maps must make these alternatives useful in different circumstances. Success should visibly change the situation: cleared space stays open, captured Emitters pay, and attack directions consolidate.

The central learning challenge is **recognizing when and where you can safely advance**. Players learn attack patterns, defensive coverage, and the consequences of dividing their force. Early situations introduce these relationships separately; later ones combine them through different terrain, Emitter placement, and attack directions. Clear feedback should make failures understandable and suggest a better next attempt.

The design test is whether players can explain a consequential choice, recognize why it succeeded or failed, and apply that understanding to a new situation. Shaper repair or augmentation, destroying an Emitter instead of capturing it, and additional Emitter types remain open.

Design interpretation: Jesse Schell's [The Art of Game Design](https://schellgames.com/art-of-game-design/) informs the intended experience and meaningful choices; Raph Koster's [A Theory of Fun for Game Design](https://www.oreilly.com/library/view/theory-of-fun/9781449363208/) informs learning through problem mastery and variation.

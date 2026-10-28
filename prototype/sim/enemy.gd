extends RefCounted
## Ground enemies: attack-move toward the nearest player unit or the Core reachable over
## cleared terrain. They use the same movement rules as player units, so a Guard that
## plugs a gap gets fought rather than bypassed.

const Pathfinding = preload("res://sim/pathfinding.gd")
const Combat = preload("res://sim/combat.gd")
const Unit = preload("res://sim/unit.gd")


static func update(sim) -> void:
	if not sim.enemy_ai:
		return
	var interval := maxi(1, int(sim.tuning.enemy_retarget_ticks))
	if sim.tick_count % interval != 0 and not sim.enemies_need_target:
		return
	sim.enemies_need_target = false
	var field := target_field(sim)
	for e in sim.units:
		if e.is_player():
			continue
		if not field.label.has(e.tile):
			continue
		var target_id: int = field.label[e.tile]
		var target_tile: Vector2i = sim.core_center
		if target_id != Combat.CORE_ID:
			target_tile = sim.get_unit(target_id).tile
		if e.order == null or e.order.kind != "attack_move" or e.order.target != target_tile:
			sim.issue_order(e, "attack_move", target_tile)


## Walking distance from every passable tile to the nearest player target, labelled
## with the target id. Sources in stable ID order (Core first).
static func target_field(sim) -> Dictionary:
	var sources := []
	var labels := []
	if sim.core_alive():
		for t in sim.grid.adjacent_positions(sim.core_center):
			sources.append(t)
			labels.append(Combat.CORE_ID)
	for u in sim.units:
		if u.is_player():
			sources.append(u.tile)
			labels.append(u.id)
	return Pathfinding.labelled_field(sim.grid, sources, labels)


# --- Spawning -----------------------------------------------------------------------

static func update_spawning(sim, dt: float) -> void:
	if not sim.spawning_enabled or sim.spawn_points.is_empty():
		return
	sim.spawn_timer -= dt
	if sim.spawn_timer > 0.0:
		return
	sim.spawn_timer += float(sim.spawn_interval)
	for i in range(sim.spawn_points.size()):
		var sp: Vector2i = sim.spawn_points[(sim.next_spawn_index + i) % sim.spawn_points.size()]
		if spawn_near(sim, sp) != null:
			sim.next_spawn_index = (sim.next_spawn_index + i + 1) % sim.spawn_points.size()
			return


## Spawns an enemy on the free tile nearest the spawn point (within a few tiles).
static func spawn_near(sim, sp: Vector2i) -> Variant:
	if sim.enemy_count() >= int(sim.tuning.max_enemies):
		return null
	var field := Pathfinding.distance_field(sim.grid, [sp], 0, {})
	var best: Variant = null
	var best_d := 1 << 30
	for t in field:
		var d: int = field[t]
		if d > 3 or not sim.occupancy.is_empty(sim.units, t, 0):
			continue
		if d < best_d or (d == best_d and (t.y < best.y or (t.y == best.y and t.x < best.x))):
			best = t
			best_d = d
	if best == null:
		return null
	return sim.add_unit(Unit.ENEMY, Unit.Side.ENEMY, best, "")

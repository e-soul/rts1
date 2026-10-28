extends RefCounted
## Automatic combat: nearest hostile in range (ties by stable ID), wind-up, cooldown.
## Range is counted in hexes between logical positions. Only settled units attack.

const Hex = preload("res://sim/hex.gd")

## Target ID used for the Core; units start at 1, so the Core wins ID ties.
const CORE_ID := 0


static func distance_to_core(sim, tile: Vector2i) -> int:
	var best := 1 << 30
	for f in sim.core_tiles:
		best = mini(best, Hex.distance(tile, f))
	return best


## Nearest hostile within `rng` of the unit's logical tile: unit id, CORE_ID, or -1.
static func nearest_target(sim, unit, rng: int) -> int:
	var best_id := -1
	var best_d := 1 << 30
	if not unit.is_player() and sim.core_alive():
		var d := distance_to_core(sim, unit.tile)
		if d <= rng:
			best_id = CORE_ID
			best_d = d
	for u in sim.units:
		if u.side == unit.side:
			continue
		var d := Hex.distance(unit.tile, u.tile)
		if d <= rng and (d < best_d or (d == best_d and u.id < best_id)):
			best_id = u.id
			best_d = d
	return best_id


static func attack_range(sim, unit) -> int:
	return int(sim.stats(unit).get("range", 0))


static func can_attack_kind(sim, unit) -> bool:
	return float(sim.stats(unit).get("damage", 0.0)) > 0.0


## Used by attack-move: a visible enemy is in range (everything is visible here).
static func enemy_in_range(sim, unit) -> bool:
	if not can_attack_kind(sim, unit):
		return false
	return nearest_target(sim, unit, attack_range(sim, unit)) != -1


static func update(sim, dt: float) -> void:
	for u in sim.units.duplicate():
		if not u.alive or not can_attack_kind(sim, u):
			continue
		var stats: Dictionary = sim.stats(u)
		u.cooldown = maxf(0.0, u.cooldown - dt)
		if not u.can_act():
			# Movement cancels an attack before firing: the wind-up is forfeited.
			u.windup = -1.0
			continue
		var target := nearest_target(sim, u, int(stats.range))
		if target == -1:
			u.windup = -1.0
			continue
		if u.windup < 0.0:
			if u.cooldown > 0.0:
				continue
			u.windup = float(stats.get("windup", 0.0))
			u.windup_target = target
		elif target != u.windup_target:
			u.windup_target = target
		u.windup -= dt
		if u.windup <= 0.0:
			u.windup = -1.0
			u.cooldown = float(stats.cooldown)
			u.shots_fired += 1
			_hit(sim, u, target, float(stats.damage))


static func _hit(sim, attacker, target_id: int, damage: float) -> void:
	if target_id == CORE_ID:
		sim.emit_event({"type": "shot", "unit": attacker.id, "from": attacker.tile, "to": sim.core_center, "side": attacker.side})
		sim.damage_core(damage)
		return
	var target = sim.get_unit(target_id)
	if target == null:
		return
	sim.emit_event({"type": "shot", "unit": attacker.id, "from": attacker.tile, "to": target.tile, "side": attacker.side})
	sim.damage_unit(target, damage)

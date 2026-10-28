extends RefCounted
## Shaper work: clear blocked terrain from a claimed adjacent work position (section 2.4).
## Several Shapers on the same tile add their work together.

const Hex = preload("res://sim/hex.gd")
const Unit = preload("res://sim/unit.gd")


static func is_work_position(sim, unit) -> bool:
	if unit.order == null or unit.order.kind != "clear":
		return false
	return Hex.distance(unit.tile, unit.order.target) == 1 and sim.grid.is_passable(unit.tile)


static func update(sim, dt: float) -> void:
	var clear_time := float(sim.tuning.clear_time)
	for u in sim.units:
		if u.kind != Unit.SHAPER or not u.can_act() or not is_work_position(sim, u):
			continue
		var t: Vector2i = u.order.target
		if not sim.grid.is_blocked(t):
			continue
		u.status = "working"
		u.reason = "Clearing"
		var done: float = sim.grid.clear_progress.get(t, 0.0) + dt
		sim.grid.clear_progress[t] = done
		if done >= clear_time - 1e-6:
			sim.grid.set_cleared(t)
			sim.emit_event({"type": "cleared", "tile": t, "unit": u.id})
			for other in sim.units:
				if other.order != null and other.order.kind == "clear" and other.order.target == t:
					other.order = null
					other.status = "idle"
					other.reason = ""


static func clear_progress(sim, t: Vector2i) -> float:
	return float(sim.grid.clear_progress.get(t, 0.0)) / float(sim.tuning.clear_time)

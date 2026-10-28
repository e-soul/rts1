extends RefCounted
## Striker forms. Assault: faster, lower HP, shorter range. Guard: slower, tougher,
## longer range. Changing form takes time and cannot be cancelled; movement orders
## received meanwhile execute after it finishes (section 5.4).

const Unit = preload("res://sim/unit.gd")


static func other_form(form: String) -> String:
	return "guard" if form == "assault" else "assault"


## Returns "" if the form change may start, otherwise the reason it is rejected.
static func form_change_rejection(unit) -> String:
	if unit == null or not unit.alive:
		return "No unit selected"
	if unit.kind != Unit.STRIKER:
		return "%s has no ability" % unit.kind.capitalize()
	if unit.is_changing_form():
		return "Form change in progress (cannot be cancelled)"
	if not unit.is_settled():
		return "In transit: must stand on its claimed stopping position"
	return ""


static func start_form_change(sim, unit) -> void:
	unit.form_change_left = float(sim.tuning.form_change_time)
	unit.windup = -1.0
	unit.status = "changing_form"
	unit.reason = "Changing to %s" % other_form(unit.form).capitalize()
	sim.emit_event({"type": "form_change_started", "unit": unit.id})


static func form_change_progress(sim, unit) -> float:
	if not unit.is_changing_form():
		return 0.0
	return 1.0 - unit.form_change_left / float(sim.tuning.form_change_time)


static func update(sim, dt: float) -> void:
	for u in sim.units:
		if not u.is_changing_form():
			continue
		u.form_change_left -= dt
		if u.form_change_left <= 1e-6:
			u.form_change_left = 0.0
			var ratio: float = u.hp / u.max_hp
			u.form = other_form(u.form)
			u.max_hp = float(sim.stats(u).hp)
			u.hp = u.max_hp * ratio
			u.status = "idle"
			u.reason = ""
			sim.emit_event({"type": "form_changed", "unit": u.id, "form": u.form})

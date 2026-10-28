extends RefCounted
## Shared helpers for tests: setup construction, ticking with invariant checks, asserts.

const Sim = preload("res://sim/simulation.gd")
const Hex = preload("res://sim/hex.gd")
const Unit = preload("res://sim/unit.gd")
const PlayerControl = preload("res://sim/control.gd")

var current := ""
var failures: Array[String] = []
static var _tuning: Dictionary = {}


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current, msg])


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		fail(msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("%s expected <%s> got <%s>" % [msg, expected, actual])


## Offset (col, row) to axial, matching the rows in setups.
static func T(col: int, row: int) -> Vector2i:
	return Hex.offset_to_axial(col, row)


static func tuning() -> Dictionary:
	if _tuning.is_empty():
		_tuning = Sim.load_tuning()
	return _tuning


## Builds a simulation from inline rows. Units: [type, col, row, form?].
func make(rows: Array, units: Array = [], enemies: Array = [], extra: Dictionary = {}) -> Sim:
	var data := {"name": current, "rows": rows, "units": [], "enemies": [], "enemy_ai": false}
	for u in units:
		var d := {"type": u[0], "pos": [u[1], u[2]]}
		if u.size() > 3:
			d.form = u[3]
		data.units.append(d)
	for e in enemies:
		data.enemies.append({"pos": [e[0], e[1]]})
	for k in extra:
		data[k] = extra[k]
	var s := Sim.new()
	s.load_setup(data, tuning())
	return s


func load_scenario(name: String) -> Sim:
	return Sim.from_file("res://scenarios/%s.json" % name, tuning())


## Ticks n times, checking invariants every tick.
func run(s: Sim, n: int) -> void:
	for i in range(n):
		s.tick()
		_invariants(s)


## Ticks until cond() is true; returns ticks taken or -1 after max_ticks.
func run_until(s: Sim, cond: Callable, max_ticks: int = 2000) -> int:
	for i in range(max_ticks):
		if cond.call():
			return i
		s.tick()
		_invariants(s)
	return -1 if not cond.call() else max_ticks


func _invariants(s: Sim) -> void:
	var errs := s.check_invariants()
	if not errs.is_empty():
		fail("tick %d invariant: %s" % [s.tick_count, errs[0]])


func order(s: Sim, u, kind: String, col: int, row: int) -> void:
	s.issue_order(u, kind, T(col, row))


func settled_at(u, col: int, row: int) -> bool:
	return u.alive and u.is_settled() and u.tile == T(col, row)


## An open field of cleared tiles.
static func field(cols: int, rows: int) -> Array:
	var out := []
	for r in range(rows):
		out.append(".".repeat(cols))
	return out

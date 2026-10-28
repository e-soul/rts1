extends RefCounted
## Deterministic fixed-tick simulation. No nodes, rendering, or input: the presentation
## and the tests drive it through the same commands.
##
## Tick order:
##   1. Form changes progress.
##   2. Steps advance; arrivals transfer logical occupancy (section 4).
##   3. Enemy AI picks targets.
##   4. Step requests are evaluated once, in policy order (sections 2, 3, 6).
##   5. Shapers work.
##   6. Combat.
##   7. Enemy spawning.

const Hex = preload("res://sim/hex.gd")
const Grid = preload("res://sim/grid.gd")
const Occupancy = preload("res://sim/occupancy.gd")
const Unit = preload("res://sim/unit.gd")
const Movement = preload("res://sim/movement.gd")
const Pathfinding = preload("res://sim/pathfinding.gd")
const Combat = preload("res://sim/combat.gd")
const Striker = preload("res://sim/striker.gd")
const Shaper = preload("res://sim/shaper.gd")
const Enemy = preload("res://sim/enemy.gd")

const TUNING_PATH := "res://data/tuning.json"
const SCENARIO_DIR := "res://scenarios"

var tuning: Dictionary = {}
var setup: Dictionary = {}
var setup_name := ""
var grid = Grid.new()
var occupancy = Occupancy.new()
var units: Array = []          # alive units, sorted by id
var next_id := 1
var tick_count := 0
var dt := 0.05

var core_center := Vector2i.ZERO
var core_tiles: Array[Vector2i] = []
var core_hp := 0.0
var core_max_hp := 0.0
var core_destroyed := false
var has_core := false

var spawn_points: Array[Vector2i] = []
var spawning_enabled := false
var spawn_interval := 6.0
var spawn_timer := 0.0
var next_spawn_index := 0
var enemy_ai := true
var enemies_need_target := true

var invulnerable := false
var opposing_ties := 0
var camera_start := Vector2i.ZERO
var events: Array = []


# --- Loading ------------------------------------------------------------------------

static func load_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Cannot read %s" % path)
		return null
	return JSON.parse_string(text)


static func load_tuning() -> Dictionary:
	return load_json(TUNING_PATH)


## Setup files in cycle order: sandbox first, then the rest alphabetically.
static func list_setups() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(SCENARIO_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(SCENARIO_DIR + "/" + f)
	out.sort()
	var sandbox := SCENARIO_DIR + "/sandbox.json"
	if out.has(sandbox):
		out.erase(sandbox)
		out.push_front(sandbox)
	return out


static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if out.has(k) and out[k] is Dictionary and over[k] is Dictionary:
			out[k] = deep_merge(out[k], over[k])
		else:
			out[k] = over[k]
	return out


static func from_file(path: String, base_tuning: Variant = null) -> Variant:
	var s = load("res://sim/simulation.gd").new()
	var data: Variant = load_json(path)
	if data == null:
		return null
	if base_tuning == null:
		base_tuning = load_tuning()
	s.load_setup(data, base_tuning)
	s.setup_name = path.get_file().get_basename()
	return s


func load_setup(data: Dictionary, base_tuning: Dictionary) -> void:
	setup = data
	setup_name = data.get("name", "setup")
	tuning = deep_merge(base_tuning, data.get("tuning", {}))
	dt = 1.0 / float(tuning.get("tick_rate", 20))
	grid = Grid.new()
	occupancy = Occupancy.new()
	units.clear()
	next_id = 1
	tick_count = 0
	events.clear()
	opposing_ties = 0
	core_destroyed = false
	has_core = false
	core_tiles.clear()
	spawn_points.clear()

	var rows: Array = data.rows
	grid.setup_from_rows(rows)
	for row in range(rows.size()):
		var line: String = rows[row]
		for col in range(line.length()):
			var t := Hex.offset_to_axial(col, row)
			match line[col]:
				"C":
					core_center = t
					has_core = true
				"S":
					spawn_points.append(t)
	spawn_points.sort_custom(Hex.less)
	if has_core:
		core_tiles.append(core_center)
		core_tiles.append_array(Hex.neighbors(core_center))
		for f in core_tiles:
			grid.terrain[f] = Grid.Terrain.CLEARED
			grid.footprint[f] = "core"
		grid.version += 1
	core_max_hp = float(tuning.core_hp)
	core_hp = core_max_hp

	for u in data.get("units", []):
		add_unit(u.type, Unit.Side.PLAYER, _pos(u.pos), u.get("form", "assault"))
	for e in data.get("enemies", []):
		add_unit(Unit.ENEMY, Unit.Side.ENEMY, _pos(e.pos), "")

	var spawning: Dictionary = data.get("spawning", {})
	spawning_enabled = spawning.get("enabled", false)
	spawn_interval = float(spawning.get("interval", tuning.spawn_interval))
	spawn_timer = spawn_interval
	next_spawn_index = 0
	enemy_ai = data.get("enemy_ai", true)
	enemies_need_target = true
	camera_start = _pos(data.camera) if data.has("camera") else core_center


static func _pos(p: Array) -> Vector2i:
	return Hex.offset_to_axial(int(p[0]), int(p[1]))


# --- Units --------------------------------------------------------------------------

func stats(unit) -> Dictionary:
	return tuning.units[unit.stats_key()]


func speed(unit) -> float:
	return float(stats(unit).speed)


func add_unit(kind: String, side: int, tile: Vector2i, form: String) -> Variant:
	if not grid.is_passable(tile) or not occupancy.is_empty(units, tile, Occupancy.GROUND):
		push_error("Cannot place %s at %s" % [kind, Hex.axial_to_offset(tile)])
		return null
	var u = Unit.new()
	u.id = next_id
	next_id += 1
	u.kind = kind
	u.side = side
	u.form = form if kind == Unit.STRIKER else ""
	u.tile = tile
	u.max_hp = float(stats(u).hp)
	u.hp = u.max_hp
	occupancy.claim(u.layer, tile, u.id)
	u.claim = tile
	units.append(u)
	enemies_need_target = true
	emit_event({"type": "spawned", "unit": u.id, "tile": tile})
	return u


func get_unit(id: int) -> Variant:
	for u in units:
		if u.id == id:
			return u
	return null


func player_units() -> Array:
	return units.filter(func(u): return u.is_player())


func enemy_units() -> Array:
	return units.filter(func(u): return not u.is_player())


func enemy_count() -> int:
	return enemy_units().size()


func core_alive() -> bool:
	return has_core and core_hp > 0.0


## Section 4: death immediately removes the unit, its claims, and its step.
func kill(unit) -> void:
	if not unit.alive:
		return
	unit.alive = false
	if unit.claim != null:
		occupancy.release(unit.layer, unit.claim, unit.id)
	if unit.stop_claim != null:
		occupancy.release(unit.layer, unit.stop_claim, unit.id)
	unit.claim = null
	unit.stop_claim = null
	unit.step = null
	units.erase(unit)
	enemies_need_target = true
	emit_event({"type": "died", "unit": unit.id, "tile": unit.tile, "side": unit.side})


func damage_unit(unit, amount: float) -> void:
	if invulnerable and unit.is_player():
		return
	unit.hp -= amount
	if unit.hp <= 0.0:
		kill(unit)


func damage_core(amount: float) -> void:
	if invulnerable or not core_alive():
		return
	core_hp = maxf(0.0, core_hp - amount)
	if core_hp <= 0.0:
		core_destroyed = true
		emit_event({"type": "core_destroyed"})


func emit_event(e: Dictionary) -> void:
	e["tick"] = tick_count
	events.append(e)


func take_events() -> Array:
	var out := events
	events = []
	return out


# --- Tick ---------------------------------------------------------------------------

## Advances one fixed tick. Does nothing once the Core is destroyed (paused until reset).
func tick() -> void:
	if core_destroyed:
		return
	tick_count += 1
	Striker.update(self, dt)
	for u in units:
		Movement.advance(self, u, dt)
	Enemy.update(self)
	Movement.request_phase(self)
	Shaper.update(self, dt)
	Combat.update(self, dt)
	Enemy.update_spawning(self, dt)


func run_ticks(n: int) -> void:
	for i in range(n):
		tick()


func run_seconds(seconds: float) -> void:
	run_ticks(int(ceil(seconds / dt - 1e-6)))


# --- Commands -----------------------------------------------------------------------

## Replaces the unit's order (accepted immediately, section 5).
func issue_order(unit, kind: String, target: Vector2i) -> void:
	unit.order = Unit.Order.new(kind, target)
	Movement.on_order_changed(self, unit)


## What A would do for the unit on the tile, with the planned route. Never substitutes
## another action: invalid targets return ok = false with the reason.
func preview_default_action(unit_id: int, tile: Vector2i) -> Dictionary:
	var res := {"ok": false, "action": "", "text": "", "reason": "", "route": [], "stop": null, "kind": ""}
	var u = get_unit(unit_id)
	if u == null or not u.is_player():
		res.reason = "No unit selected"
	elif not grid.in_map(tile):
		res.reason = "Outside the map"
	elif grid.footprint.has(tile):
		res.reason = "Core footprint: ground units cannot enter it"
	elif u.kind == Unit.STRIKER:
		if grid.is_blocked(tile):
			res.reason = "Blocked terrain: a Shaper must clear it first"
		elif not grid.terrain_reachable(u.tile, tile):
			res.reason = "No route on known terrain"
		else:
			res.action = "attack_move"
			res.text = "Attack-move"
	elif u.kind == Unit.SHAPER:
		if grid.is_blocked(tile):
			if grid.adjacent_positions(tile).is_empty():
				res.reason = "No work position next to this tile"
			elif not grid.terrain_reachable(u.tile, tile):
				res.reason = "No route on known terrain to a work position"
			else:
				res.action = "clear"
				res.text = "Clear"
		elif not grid.terrain_reachable(u.tile, tile):
			res.reason = "No route on known terrain"
		else:
			res.action = "move"
			res.text = "Move"
	if res.action == "":
		return res
	res.ok = true
	var blocked := Occupancy.hostile_blocked(units, u.side, u.layer)
	var choice := Movement.choose_stop(self, u, Unit.Order.new(res.action, tile), blocked)
	res.kind = choice.kind
	res.stop = choice.stop
	if choice.stop != null:
		res.route = Pathfinding.route(choice.search, choice.stop)
	match choice.kind:
		"alternative":
			res.text += " (destination taken: stops nearby)"
		"work_pending":
			res.text += " (work positions taken: waits nearby)"
		"enemy_blocked":
			res.text += " (blocked by enemy: holds nearest)"
		"no_stop":
			res.text += " (no free stopping position now)"
	if u.is_changing_form():
		res.text += " after form change"
	return res


func command_default_action(unit_id: int, tile: Vector2i) -> Dictionary:
	var res := preview_default_action(unit_id, tile)
	if res.ok:
		issue_order(get_unit(unit_id), res.action, tile)
		emit_event({"type": "order", "unit": unit_id, "action": res.action, "tile": tile})
	else:
		emit_event({"type": "rejected", "unit": unit_id, "reason": res.reason})
	return res


func command_toggle_form(unit_id: int) -> Dictionary:
	var u = get_unit(unit_id)
	var reason := Striker.form_change_rejection(u)
	if reason != "":
		emit_event({"type": "rejected", "unit": unit_id, "reason": reason})
		return {"ok": false, "reason": reason}
	Striker.start_form_change(self, u)
	return {"ok": true, "reason": ""}


## Sandbox: spawn one enemy at the spawn point nearest the tile.
func spawn_enemy_near(tile: Vector2i) -> Variant:
	if spawn_points.is_empty():
		return null
	var best: Vector2i = spawn_points[0]
	for sp in spawn_points:
		if Hex.distance(sp, tile) < Hex.distance(best, tile):
			best = sp
	return Enemy.spawn_near(self, best)


# --- Invariants (used by tests and the debug overlay) -------------------------------

func check_invariants() -> Array[String]:
	var errors: Array[String] = []
	var claims: Dictionary = occupancy.claims[Occupancy.GROUND]
	for t in claims:
		var u = get_unit(claims[t])
		if u == null:
			errors.append("claim at %s held by dead unit %d" % [t, claims[t]])
		elif u.claim != t and u.stop_claim != t:
			errors.append("claim at %s not recorded on unit %d" % [t, u.id])
	for u in units:
		if u.claim != null and occupancy.claim_owner(u.layer, u.claim) != u.id:
			errors.append("unit %d claim %s missing" % [u.id, u.claim])
		if u.stop_claim != null and occupancy.claim_owner(u.layer, u.stop_claim) != u.id:
			errors.append("unit %d stop claim %s missing" % [u.id, u.stop_claim])
		if not grid.is_passable(u.tile):
			errors.append("unit %d on impassable %s" % [u.id, u.tile])
		if u.step != null and Hex.distance(u.step.from, u.step.to) != 1:
			errors.append("unit %d step not between neighbours" % u.id)
		if u.step != null and u.step.from != u.tile:
			errors.append("unit %d logical tile left source before arrival" % u.id)
	for a in units:
		for b in units:
			if a.side == b.side or a.id >= b.id:
				continue
			var ta := _footprint_now(a)
			for t in _footprint_now(b):
				if ta.has(t):
					errors.append("hostile units %d and %d share %s" % [a.id, b.id, t])
	return errors


func _footprint_now(u) -> Dictionary:
	var out := {u.tile: true}
	if u.step != null and not u.step.returning:
		out[u.step.to] = true
	return out
